import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show GoogleMap;
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/RouteOptionsScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_google_maps_platform.dart';

// The route cards are a sheet over the map (owner, 2026-10-14): it opens
// where the cards always started, under a map 36% of the screen tall, and
// only a drag moves it -- up over the whole map, or down to the map alone.

Map<String, dynamic> _option(String type, int minutes) => {
      'type': type,
      'time': minutes,
      'distance_m': 9000,
      'fare_egp': 10,
      'fare_total_egp': 10,
      'instructions': [
        {'action': 'board', 'route_number': '$minutes', 'vehicle_type': 'bus', 'distance_m': 9000},
      ],
    };

final Map<String, dynamic> _data = {
  'success': true,
  'options': [for (var i = 0; i < 5; i++) _option(i == 0 ? 'Recommended' : 'Alternative', 30 + i)],
};

void main() {
  late double screenHeight;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleMapsFlutterPlatform.instance = FakeGoogleMapsPlatform();
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.resetPhysicalSize);
    screenHeight = 2400 / 2.5;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: RouteOptionsScreen(
        startLat: 30.04, startLon: 31.23, startName: 'A', endLat: 30.06, endLon: 31.25, endName: 'B',
        initialData: _data,
      ),
    ));
    await tester.pump();
    await tester.pump(FakeGoogleMapsPlatform.viewCreationDelay);
    await tester.pump(const Duration(milliseconds: 300));
  }

  Finder handle() => find.byKey(const ValueKey('route-sheet-handle'));
  double sheetTop(WidgetTester tester) => tester.getTopLeft(handle()).dy;
  double mapTop(WidgetTester tester) => tester.getTopLeft(find.byType(GoogleMap)).dy;

  testWidgets('it opens under a map 36% of the screen tall, as before', (tester) async {
    await open(tester);
    expect(sheetTop(tester) - mapTop(tester), closeTo(screenHeight * 0.36, 1));
  });

  testWidgets('pulled up, the cards cover the map', (tester) async {
    await open(tester);
    await tester.drag(handle(), Offset(0, -screenHeight * 0.5));
    await tester.pumpAndSettle();
    expect(sheetTop(tester), closeTo(mapTop(tester), 1));
  });

  testWidgets('pulled down, only the map and the grab strip are left', (tester) async {
    await open(tester);
    await tester.drag(handle(), Offset(0, screenHeight * 0.6));
    await tester.pumpAndSettle();
    final startButton = tester.getTopLeft(find.byType(SafeArea).last).dy;
    expect(sheetTop(tester), greaterThan(startButton - 120));
    // At rest, the map frames the route in the part left uncovered.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 100));
    final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
    expect(map.padding.bottom, lessThan(140));
  });

  testWidgets('dragging the cards scrolls them; the sheet stays put', (tester) async {
    await open(tester);
    final before = sheetTop(tester);
    await tester.drag(find.byKey(const ValueKey('route-sheet-cards')), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(sheetTop(tester), closeTo(before, 1));
    await tester.drag(find.byKey(const ValueKey('route-sheet-cards')), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(sheetTop(tester), closeTo(before, 1));
  });

  testWidgets('a quick flick on the handle goes to the next stop', (tester) async {
    await open(tester);
    await tester.fling(handle(), const Offset(0, -80), 1500);
    await tester.pumpAndSettle();
    expect(sheetTop(tester), closeTo(mapTop(tester), 1));
  });

  testWidgets('back from a route detail page, the sheet is where it was', (tester) async {
    await open(tester);
    final before = sheetTop(tester);
    await tester.tap(find.textContaining('31').first);
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(sheetTop(tester), closeTo(before, 1));
  });
}
