import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:guidy_app/screens/trip/trip_location.dart';

class _FakeGeolocator extends GeolocatorPlatform {
  _FakeGeolocator({this.serviceOn = true, this.permission = LocationPermission.whileInUse, this.gate});

  final bool serviceOn;
  final LocationPermission permission;

  /// The permission check waits for this: a rider taking their time.
  final Completer<void>? gate;
  final fixes = StreamController<Position>.broadcast();
  int streams = 0;
  final settings = <LocationSettings?>[];

  /// The first stream fails when it asks for the foreground service.
  bool failServiceStream = false;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceOn;

  @override
  Future<LocationPermission> checkPermission() async {
    await gate?.future;
    return permission;
  }

  @override
  Future<LocationPermission> requestPermission() async => permission;

  @override
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) async => null;

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    streams++;
    settings.add(locationSettings);
    final wantsService = locationSettings is AndroidSettings && locationSettings.foregroundNotificationConfig != null;
    if (failServiceStream && wantsService) return Stream<Position>.error(StateError('not allowed'));
    return fixes.stream;
  }
}

Position _fix(double lat) => Position(
      latitude: lat,
      longitude: 31,
      timestamp: DateTime(2026, 10, 13),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GeolocatorPlatform original;
  setUp(() => original = GeolocatorPlatform.instance);
  tearDown(() => GeolocatorPlatform.instance = original);

  ({TripLocation loc, List<Position> fixes, List<LocationProblem> problems}) make() {
    final fixes = <Position>[];
    final problems = <LocationProblem>[];
    final loc = TripLocation(
      onPosition: fixes.add,
      onLastKnown: (_) {},
      onHeading: (_) {},
      onProblem: problems.add,
    );
    return (loc: loc, fixes: fixes, problems: problems);
  }

  test('fixes arrive while running and stop after dispose', () async {
    final geo = _FakeGeolocator();
    GeolocatorPlatform.instance = geo;
    final t = make();
    await t.loc.start();
    geo.fixes.add(_fix(30));
    await Future<void>.delayed(Duration.zero);
    t.loc.dispose();
    geo.fixes.add(_fix(30.1));
    await Future<void>.delayed(Duration.zero);
    expect(t.fixes.map((p) => p.latitude), [30]);
  });

  test('disposed while the permission prompt is up: no stream, no problem reported', () async {
    final gate = Completer<void>();
    final slow = _FakeGeolocator(gate: gate);
    GeolocatorPlatform.instance = slow;
    final t = make();
    final started = t.loc.start();
    t.loc.dispose();
    gate.complete();
    await started;
    expect(slow.streams, 0);
    expect(t.problems, isEmpty);
  });

  test('location off, and "don\'t ask again", are reported as such', () async {
    GeolocatorPlatform.instance = _FakeGeolocator(serviceOn: false);
    var t = make();
    await t.loc.start();
    expect(t.problems, [LocationProblem.off]);

    GeolocatorPlatform.instance = _FakeGeolocator(permission: LocationPermission.deniedForever);
    t = make();
    await t.loc.start();
    expect(t.problems, [LocationProblem.blocked]);
  });

  test('a stream error that has no fallback is reported as lost', () async {
    final geo = _FakeGeolocator();
    GeolocatorPlatform.instance = geo;
    final t = make();
    await t.loc.start();
    geo.fixes.addError(StateError('gps gone'));
    await Future<void>.delayed(Duration.zero);
    expect(t.problems, [LocationProblem.lost]);
    t.loc.dispose();
  });

  group('foreground service', () {
    const config = ForegroundNotificationConfig(notificationTitle: 't', notificationText: 'x');
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    bool hasService(LocationSettings? s) => s is AndroidSettings && s.foregroundNotificationConfig != null;

    test('the stream runs as a service when given a config, and says so', () async {
      final geo = _FakeGeolocator();
      GeolocatorPlatform.instance = geo;
      final states = <bool>[];
      final loc = TripLocation(
        onPosition: (_) {},
        onLastKnown: (_) {},
        onHeading: (_) {},
        onProblem: (_) {},
        foreground: () => config,
        onForegroundService: states.add,
      );
      await loc.start();
      expect(hasService(geo.settings.single), isTrue);
      expect(states, [true]);
      loc.dispose();
      expect(states, [true, false]);
    });

    test('endBackground goes on listening without the service', () async {
      final geo = _FakeGeolocator();
      GeolocatorPlatform.instance = geo;
      final states = <bool>[];
      final fixes = <Position>[];
      final loc = TripLocation(
        onPosition: fixes.add,
        onLastKnown: (_) {},
        onHeading: (_) {},
        onProblem: (_) {},
        foreground: () => config,
        onForegroundService: states.add,
      );
      await loc.start();
      loc.endBackground();
      expect(hasService(geo.settings.last), isFalse);
      expect(states, [true, false]);
      geo.fixes.add(_fix(30));
      await Future<void>.delayed(Duration.zero);
      expect(fixes, hasLength(1));
      loc.dispose();
    });

    test('a service that cannot start falls back to a plain stream, not "lost"', () async {
      final geo = _FakeGeolocator()..failServiceStream = true;
      GeolocatorPlatform.instance = geo;
      final problems = <LocationProblem>[];
      final fixes = <Position>[];
      final loc = TripLocation(
        onPosition: fixes.add,
        onLastKnown: (_) {},
        onHeading: (_) {},
        onProblem: problems.add,
        foreground: () => config,
      );
      await loc.start();
      await Future<void>.delayed(Duration.zero);
      expect(geo.streams, 2);
      expect(hasService(geo.settings.last), isFalse);
      expect(problems, isEmpty);
      geo.fixes.add(_fix(30));
      await Future<void>.delayed(Duration.zero);
      expect(fixes, hasLength(1));
      loc.dispose();
    });
  });
}
