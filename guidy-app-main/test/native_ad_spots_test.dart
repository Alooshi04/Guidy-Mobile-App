import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/LineDetailScreen.dart';
import 'package:guidy_app/screens/LinesScreen.dart';
import 'package:guidy_app/screens/RailNetworkMapScreen.dart';
import 'package:guidy_app/screens/RouteOptionsScreen.dart';
import 'package:guidy_app/screens/TripRecapScreen.dart';
import 'package:guidy_app/services/api_service.dart';
import 'package:guidy_app/services/reference_cache.dart';
import 'package:guidy_app/widgets/native_ad_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Native ad slots at the foot of Route Options, Lines (categories, and in the
// feed), Line detail, the Station Directory and the Trip recap. Under test no
// ad ever loads, so a slot draws nothing: these tests check that the
// NativeAdCard is in the tree where it belongs, and nowhere else.

final Finder _ads = find.byType(NativeAdCard);

Widget _app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

class _FakeApi extends ApiService {
  _FakeApi(this.count);
  final int count;

  @override
  Future<List<Map<String, dynamic>>> searchRoutes({
    String query = '',
    String? vehicleType,
    String lang = 'en',
    int limit = 40,
  }) async =>
      [
        for (var i = 0; i < count; i++)
          {
            'route_id': 'B$i',
            'vehicle_type': 'bus',
            'number': '${100 + i}',
            'description': 'Line $i',
            'stop_count': 12,
            'fare_egp': 10,
          },
      ];
}

Map<String, dynamic> _option() => {
      'type': 'Recommended',
      'time': '40',
      'fare_egp': 7.5,
      'fare_total_egp': 7.5,
      'distance_m': 9000,
      'segments': [],
      'instructions': [
        {'action': 'walk_to_station', 'station': 'Sidi Gaber', 'lat': 31.21, 'lon': 29.94, 'distance_m': 350},
        {
          'action': 'board',
          'station': 'Sidi Gaber',
          'lat': 31.21,
          'lon': 29.94,
          'route_id': 'BUS_871',
          'route_number': '871',
          'vehicle_type': 'bus',
          'fare_egp': 7.5,
          'stops_count': 12,
          'ride_min': 25,
          'alight_station': 'Mahattet Masr',
        },
        {'action': 'arrive', 'station': 'Mahattet Masr', 'lat': 31.19, 'lon': 29.90},
      ],
    };

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Lines feed slots', () {
    test('none for a list shorter than 8, or exactly 8 (a row must follow)', () {
      expect(LinesScreen.feedSlots(0), isEmpty);
      expect(LinesScreen.feedSlots(7), equals([0, 1, 2, 3, 4, 5, 6]));
      expect(LinesScreen.feedSlots(8).whereType<Null>(), isEmpty);
      expect(LinesScreen.feedSlots(8).length, 8);
    });

    test('one slot after every 8th row, never two in a row', () {
      final slots = LinesScreen.feedSlots(20);
      expect(slots.length, 22);
      expect([for (var i = 0; i < slots.length; i++) if (slots[i] == null) i], [8, 17]);
      for (var i = 1; i < slots.length; i++) {
        expect(slots[i] == null && slots[i - 1] == null, isFalse);
      }
      expect(slots.last, 19, reason: 'the page ends on a row, not an ad');
      expect(slots.whereType<int>().toList(), [for (var i = 0; i < 20; i++) i]);
    });
  });

  testWidgets('Lines categories: one card at the foot of the tile grid', (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(LinesScreen(api: _FakeApi(0))));
    await tester.pumpAndSettle();
    expect(_ads, findsOneWidget);
    expect(tester.widget<NativeAdCard>(_ads).template.toString(), contains('small'));
  });

  Future<void> openBusList(WidgetTester tester, int lines) async {
    tester.view.physicalSize = const Size(800, 9000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(LinesScreen(api: _FakeApi(lines))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bus'));
    await tester.pumpAndSettle();
  }

  testWidgets('Lines list: an ad after the 8th and 16th row of a full page', (tester) async {
    await openBusList(tester, 25);
    expect(_ads, findsNWidgets(2));
    // Between rows 8/9 and 16/17: the card sits below the 8th row's text.
    final eighth = tester.getTopLeft(find.text('107')).dy;
    final ninth = tester.getTopLeft(find.text('108')).dy;
    final ad = tester.getTopLeft(_ads.first).dy;
    expect(ad, greaterThan(eighth));
    expect(ad, lessThanOrEqualTo(ninth));
  });

  testWidgets('Lines list: none for a short list', (tester) async {
    await openBusList(tester, 6);
    expect(find.text('105'), findsOneWidget);
    expect(_ads, findsNothing);
  });

  testWidgets('Line detail: a card after the report link, below the last stop', (tester) async {
    await ReferenceCache.write('route_detail_AD_LINE_en', {
      'route_id': 'AD_LINE',
      'number': '7',
      'vehicle_type': 'bus',
      'description': '',
      'directions': [
        {
          'from': 'A',
          'towards': 'C',
          'stops': [
            {'stop_id': 'a', 'name': 'Stop Aaa', 'lat': 30.05, 'lon': 31.23},
            {'stop_id': 'b', 'name': 'Stop Bbb', 'lat': 30.06, 'lon': 31.24},
            {'stop_id': 'c', 'name': 'Stop Ccc', 'lat': 30.07, 'lon': 31.25},
          ],
          'points': <dynamic>[],
        },
      ],
    }, persist: false);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(const LineDetailScreen(routeId: 'AD_LINE', fallbackTitle: 'Line 7')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // The map view opens first on some builds; the stop list holds the slot.
    if (_ads.evaluate().isEmpty) {
      final toggle = find.byIcon(Icons.format_list_bulleted_rounded);
      if (toggle.evaluate().isNotEmpty) {
        await tester.tap(toggle.first);
        await tester.pump(const Duration(milliseconds: 500));
      }
    }
    expect(_ads, findsOneWidget);
    expect(tester.getTopLeft(_ads).dy, greaterThan(tester.getTopLeft(find.text('Stop Ccc')).dy));
  });

  testWidgets('Station Directory: a card after the last line card, none on an empty search', (tester) async {
    tester.view.physicalSize = const Size(800, 9000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(const RailNetworkMapScreen()));
    await tester.pumpAndSettle();
    expect(_ads, findsNothing, reason: 'the map tab has no slot');
    await tester.tap(find.text('Station Directory'));
    await tester.pumpAndSettle();
    expect(_ads, findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'zzzzzz-no-such-station');
    await tester.pumpAndSettle();
    expect(_ads, findsNothing);
  });

  testWidgets('Route Options: a card after the last route card', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(RouteOptionsScreen(
      startLat: 31.24,
      startLon: 29.98,
      startName: 'Victoria',
      endLat: 31.19,
      endLon: 29.90,
      endName: 'Mahattet Masr',
      initialData: {
        'success': true,
        'options': [_option(), _option()],
      },
      showMap: false,
    )));
    await tester.pumpAndSettle();
    expect(_ads, findsOneWidget);
    expect(tester.getTopLeft(_ads).dy, greaterThan(tester.getBottomLeft(find.byKey(const ValueKey('route-card-1'))).dy));
  });

  testWidgets('Trip recap: a card at the foot of the list, above the pinned Start button', (tester) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    final option = _option();
    await tester.pumpWidget(_app(TripRecapScreen(
      option: option,
      pathData: option,
      startName: 'Dokki Square',
      endName: 'Tahrir Square',
    )));
    await tester.pumpAndSettle();
    expect(_ads, findsOneWidget);
  });
}
