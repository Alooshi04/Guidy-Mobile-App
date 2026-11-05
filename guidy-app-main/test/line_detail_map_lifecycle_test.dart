import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/LineDetailScreen.dart';
import 'package:guidy_app/services/reference_cache.dart';
import 'package:guidy_app/theme/guidy_ui.dart';

import 'support/fake_google_maps_platform.dart';

// Crashlytics, 1.0.0: "GoogleMapController for map ID 1 was used after the
// associated GoogleMap widget had already been disposed", thrown from
// _LineDetailScreenState._fitRouteBounds. The list view, and a reload after
// a language switch, throw the map away; the screen kept that map's
// controller and moved its camera before the new map had reported in.

const _routeId = 'TEST_LINE';

/// Two directions over the same three stops; the stops alone are the
/// route shape (no points), so the route spans exactly
/// 30.05..30.07 N, 31.23..31.25 E.
final Map<String, dynamic> _line = {
  'route_id': _routeId,
  'number': '7',
  'vehicle_type': 'bus',
  'description': '',
  'directions': [
    {
      'from': 'A',
      'towards': 'C',
      'stops': [
        {'stop_id': 'a', 'name': 'A', 'lat': 30.05, 'lon': 31.23},
        {'stop_id': 'b', 'name': 'B', 'lat': 30.06, 'lon': 31.24},
        {'stop_id': 'c', 'name': 'C', 'lat': 30.07, 'lon': 31.25},
      ],
      'points': <dynamic>[],
    },
    {
      'from': 'C',
      'towards': 'A',
      'stops': [
        {'stop_id': 'c', 'name': 'C', 'lat': 30.07, 'lon': 31.25},
        {'stop_id': 'b', 'name': 'B', 'lat': 30.06, 'lon': 31.24},
        {'stop_id': 'a', 'name': 'A', 'lat': 30.05, 'lon': 31.23},
      ],
      'points': <dynamic>[],
    },
  ],
};

final Object _framesWholeRoute = CameraUpdate.newLatLngBounds(
  LatLngBounds(southwest: const LatLng(30.05, 31.23), northeast: const LatLng(30.07, 31.25)),
  48,
).toJson();

Widget _app(Locale locale) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const LineDetailScreen(routeId: _routeId, fallbackTitle: 'Line 7'),
    );

final Finder _mapListToggle = find.byWidgetPredicate(
    (w) => w is Icon && (w.icon == Icons.map_rounded || w.icon == Icons.format_list_bulleted_rounded));

void main() {
  late FakeGoogleMapsPlatform maps;

  setUp(() async {
    maps = FakeGoogleMapsPlatform();
    GoogleMapsFlutterPlatform.instance = maps;
    await ReferenceCache.write('route_detail_${_routeId}_en', _line, persist: false);
    await ReferenceCache.write('route_detail_${_routeId}_ar', _line, persist: false);
  });

  Future<void> openLine(WidgetTester tester) async {
    await tester.pumpWidget(_app(const Locale('en')));
    await tester.pump();
  }

  Future<void> toggleMapList(WidgetTester tester) async {
    await tester.tap(_mapListToggle);
    await tester.pump();
  }

  /// Every map built so far reports in, and the frame it asks for runs.
  Future<void> letMapsReportIn(WidgetTester tester) => tester.pump(FakeGoogleMapsPlatform.viewCreationDelay);

  testWidgets('back on the map after the list, the route is framed on the new map and the old one is left alone',
      (tester) async {
    await openLine(tester);
    await toggleMapList(tester); // list -> map
    await letMapsReportIn(tester);
    await toggleMapList(tester); // map -> list: that map is gone
    await toggleMapList(tester); // list -> a new map
    await letMapsReportIn(tester);

    expect(tester.takeException(), isNull);
    expect(maps.createdMapIds, hasLength(2));
    expect(maps.cameraUpdates[maps.lastMapId]!.map((u) => u.toJson()), anyElement(equals(_framesWholeRoute)));
  });

  testWidgets('picking a direction while the map is still coming back does not move the map that is gone',
      (tester) async {
    await openLine(tester);
    await toggleMapList(tester); // list -> map
    await letMapsReportIn(tester);
    await toggleMapList(tester); // map -> list: that map is gone
    await toggleMapList(tester); // list -> a new map, not reported in yet

    await tester.tap(find.byType(GuidyPill).at(1));
    await tester.pump();
    await letMapsReportIn(tester);

    expect(tester.takeException(), isNull);
  });

  testWidgets('after a language switch reloads the line, picking a direction before the map is back is safe',
      (tester) async {
    await openLine(tester);
    await toggleMapList(tester); // list -> map
    await letMapsReportIn(tester);

    await tester.pumpWidget(_app(const Locale('ar'))); // reload: the map gives way to a spinner
    await tester.pump(); // the line is back, and a new map, not reported in yet

    await tester.tap(find.byType(GuidyPill).at(1));
    await tester.pump();
    await letMapsReportIn(tester);

    expect(tester.takeException(), isNull);
    expect(maps.createdMapIds, hasLength(2));
  });
}
