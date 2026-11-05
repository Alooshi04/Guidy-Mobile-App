import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/RouteOptionsScreen.dart';
import 'package:guidy_app/services/api_service.dart';

import 'support/fake_google_maps_platform.dart';

// The same crash as LineDetailScreen's (Crashlytics, 1.0.0: "GoogleMapController
// ... was used after the associated GoogleMap widget had already been
// disposed"): a filter chip refetches, the map gives way to the loading
// cards, and the screen kept that map's controller. Picking a card before
// the new map had reported in moved the camera of the map that was gone.

const _start = (lat: 30.038, lon: 31.21);
const _end = (lat: 29.98, lon: 31.13);

final Map<String, dynamic> _data = {
  'success': true,
  'options': [
    {
      'type': 'Recommended',
      'time': 59,
      'distance_m': 13670,
      'fare_egp': 20,
      'fare_total_egp': 20,
      'vehicle_type': 'bus',
      'instructions': [
        {'action': 'board', 'route_number': '1073', 'vehicle_type': 'bus', 'distance_m': 13000},
      ],
    },
    {
      'type': 'Cheapest',
      'time': 141,
      'distance_m': 14256,
      'fare_egp': 10,
      'fare_total_egp': 10,
      'vehicle_type': 'microbus',
      'instructions': [],
    },
  ],
};

void main() {
  late FakeGoogleMapsPlatform maps;

  setUp(() {
    maps = FakeGoogleMapsPlatform();
    GoogleMapsFlutterPlatform.instance = maps;
    ApiService.clearRouteCache();
    // The refetch with the metro left out finds its answer in the cache.
    for (final lang in const ['en', 'ar']) {
      ApiService.cacheRoute(
        startLat: _start.lat,
        startLon: _start.lon,
        endLat: _end.lat,
        endLon: _end.lon,
        lang: lang,
        excludeMetro: true,
        data: _data,
      );
    }
  });

  tearDown(ApiService.clearRouteCache);

  testWidgets('picking a card after a filter refetch, before the new map is back, leaves the old map alone',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: RouteOptionsScreen(
        startLat: _start.lat,
        startLon: _start.lon,
        startName: 'A',
        endLat: _end.lat,
        endLon: _end.lon,
        endName: 'B',
        initialData: _data,
      ),
    ));
    await tester.pump();
    await tester.pump(FakeGoogleMapsPlatform.viewCreationDelay); // the first map reports in
    await tester.pump(const Duration(milliseconds: 300)); // and frames the routes

    final l10n = AppLocalizations.of(tester.element(find.byType(RouteOptionsScreen)));
    await tester.tap(find.text(l10n.excludeMetro));
    await tester.pump(); // the map gives way to the loading cards
    await tester.pump(); // the results are back, with a new map that has not reported in

    expect(maps.createdMapIds, hasLength(2));
    // The 141-minute route's card (it reads "2 h" over "21 min").
    await tester.tap(find.byKey(const ValueKey('route-card-1')));
    await tester.pump();
    await tester.pump(FakeGoogleMapsPlatform.viewCreationDelay);
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(maps.cameraUpdates[maps.createdMapIds.first], hasLength(1)); // only its own first framing
  });
}
