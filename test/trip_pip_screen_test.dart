import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show GoogleMap;
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/MapScreen.dart';
import 'package:guidy_app/services/trip_pip.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _trip() => {
      'instructions': [
        {'action': 'walk_to_station', 'station': 'Ramses', 'lat': 30.05, 'lon': 31.24, 'distance_m': 200},
        {'action': 'board', 'station': 'Ramses', 'route_id': 'R1', 'route_number': '66', 'vehicle_type': 'minibus', 'lat': 30.05, 'lon': 31.24},
        {'action': 'arrive', 'station': 'Tahrir', 'lat': 30.06, 'lon': 31.25},
      ],
      'option': {'type': 'Recommended', 'time': '30', 'fare_egp': 10},
      'segments': [],
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('guidy/pip');
  late List<String> calls;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add('${call.method}:${call.arguments}');
      return null;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MapScreen(pathData: _trip()),
    ));
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('a trip on screen offers the floating window, and withdraws it when the trip closes', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await open(tester);
    expect(calls, ['setAvailable:true']);
    await tester.pumpWidget(const SizedBox());
    expect(calls, ['setAvailable:true', 'setAvailable:false']);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('in the floating window: the map and a one-card rundown, no controls or sheet', (tester) async {
    await open(tester);
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);

    TripPip.active.value = true;
    await tester.pump();
    expect(find.byKey(const ValueKey('pip_rundown')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('pip_rundown')), matching: find.text('Walk to Ramses')),
        findsOneWidget);
    expect(find.byType(DraggableScrollableSheet), findsNothing);
    expect(find.byKey(const ValueKey('guidy-tool-rail-menu')), findsNothing);

    TripPip.active.value = false;
    await tester.pump();
    expect(find.byKey(const ValueKey('pip_rundown')), findsNothing);
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
  });

  testWidgets('a sheet left open closes as the window opens, and takes the keyboard with it', (tester) async {
    await open(tester);
    final sheet = showModalBottomSheet<bool>(
      context: tester.element(find.byType(MapScreen)),
      builder: (_) => const TextField(key: ValueKey('report_comment')),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.showKeyboard(find.byKey(const ValueKey('report_comment')));
    expect(tester.testTextInput.isVisible, isTrue);

    TripPip.active.value = true;
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const ValueKey('report_comment')), findsNothing);
    expect(tester.testTextInput.isVisible, isFalse);
    expect(await sheet, isNull); // dismissed: callers read that as "no"
    expect(find.byKey(const ValueKey('pip_rundown')), findsOneWidget);
    TripPip.active.value = false;
    await tester.pump();
  });

  testWidgets('the map keeps the rider clear of the sheet wherever the sheet is', (tester) async {
    await open(tester);
    final height = tester.getSize(find.byType(MapScreen)).height;
    double mapBottom() => tester.widget<GoogleMap>(find.byType(GoogleMap)).padding.bottom;
    double sheetCovers() => height - tester.getTopLeft(find.byKey(const ValueKey('sheet_body'))).dy;

    // The sheet opens half-way up: the map's bottom padding must cover it,
    // or the rider's dot (placed in the padded box) sits under the sheet.
    await tester.pump(const Duration(milliseconds: 600));
    expect(mapBottom(), closeTo(sheetCovers(), height * 0.03));

    // Pulled down to its lowest stop: the padding follows it down.
    await tester.drag(find.byKey(const ValueKey('trip-sheet-grab')), Offset(0, height * 0.4));
    await tester.pump(const Duration(milliseconds: 600));
    expect(mapBottom(), closeTo(sheetCovers(), height * 0.03));
  });

  // 1.0.11 (18): the sheet rebuilt the screen as it moved, and each rebuild
  // handed DraggableScrollableSheet a new snapSizes list, which it takes as
  // changed snap sizes and snaps back -- so a finger dragging the trip cards
  // got them pulled back to where they were, frame after frame.
  testWidgets('a finger dragging the trip sheet moves it, frame by frame', (tester) async {
    await open(tester);
    final height = tester.getSize(find.byType(MapScreen)).height;
    double sheetTop() => tester.getTopLeft(find.byKey(const ValueKey('sheet_body'))).dy;
    final before = sheetTop();

    final finger = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('trip-sheet-grab'))));
    for (var i = 0; i < 12; i++) {
      await finger.moveBy(Offset(0, -height * 0.025));
      await tester.pump(const Duration(milliseconds: 16));
    }
    // Still held: the sheet is where the finger took it.
    expect(sheetTop(), lessThan(before - height * 0.2));
    await finger.up();
    await tester.pump(const Duration(milliseconds: 600));
    // Let go above the half stop, it settles at the top one.
    expect(sheetTop(), lessThan(before - height * 0.2));
  });

  // Tester request: pull the card over the map from its top, or scroll the
  // steps under it without the card moving.
  testWidgets('dragging the steps scrolls them; the card stays put', (tester) async {
    await open(tester);
    double sheetTop() => tester.getTopLeft(find.byKey(const ValueKey('sheet_body'))).dy;
    final before = sheetTop();
    await tester.drag(find.byKey(const ValueKey('trip-sheet-steps')), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(sheetTop(), closeTo(before, 1));
    await tester.drag(find.byKey(const ValueKey('trip-sheet-steps')), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(sheetTop(), closeTo(before, 1));
  });

  // Android shrinks the window a frame before it says the trip is in the
  // floating window: the sheet, squeezed while being laid out, rebuilt the
  // trip screen mid-frame ("setState() called during build").
  testWidgets('the window shrinking before it floats leaves the screen whole', (tester) async {
    tester.view.devicePixelRatio = 2.625;
    tester.view.physicalSize = const Size(1080, 2340);
    addTearDown(tester.view.reset);
    await open(tester);
    tester.view.physicalSize = const Size(1080, 608);
    await tester.pump();
    expect(tester.takeException(), isNull);
    TripPip.active.value = true;
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('pip_rundown')), findsOneWidget);
    TripPip.active.value = false;
    tester.view.physicalSize = const Size(1080, 2340);
    await tester.pump();
  });

  testWidgets('a full screen above the trip is left alone', (tester) async {
    await open(tester);
    Navigator.of(tester.element(find.byType(MapScreen)))
        .push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('recap'))));
    await tester.pump(const Duration(milliseconds: 600));

    TripPip.active.value = true;
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('recap'), findsOneWidget);
    TripPip.active.value = false;
    await tester.pump();
  });
}
