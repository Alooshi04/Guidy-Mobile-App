import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/MapScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Location that answers the permission check only when told to, the way
/// a rider takes their time over the permission prompt.
class _SlowPermissionGeolocator extends GeolocatorPlatform {
  final permission = Completer<LocationPermission>();
  int streams = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() => permission.future;

  @override
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) async => null;

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    streams++;
    return const Stream.empty();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('leaving the trip before permission is answered starts no GPS stream', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('guidy/pip'), (_) async => null);
    final original = GeolocatorPlatform.instance;
    final geo = _SlowPermissionGeolocator();
    GeolocatorPlatform.instance = geo;
    addTearDown(() {
      GeolocatorPlatform.instance = original;
      messenger.setMockMethodCallHandler(const MethodChannel('guidy/pip'), null);
    });

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MapScreen(pathData: const {
        'instructions': [
          {'action': 'walk_to_station', 'station': 'Ramses', 'lat': 30.05, 'lon': 31.24, 'distance_m': 200},
          {'action': 'arrive', 'station': 'Tahrir', 'lat': 30.06, 'lon': 31.25},
        ],
        'option': {'type': 'Recommended', 'time': '30', 'fare_egp': 10},
        'segments': [],
      }),
    ));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.pumpWidget(const SizedBox()); // the rider backs out
    geo.permission.complete(LocationPermission.whileInUse);
    await tester.pump();

    expect(geo.streams, 0);
    expect(tester.takeException(), isNull); // no write to a disposed notifier
  });
}
