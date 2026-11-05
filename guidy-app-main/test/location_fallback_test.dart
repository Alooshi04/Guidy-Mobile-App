import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:guidy_app/services/location_fallback.dart';
import 'package:guidy_app/utils/nav_math.dart';

// A declined "Location Accuracy" prompt used to come straight back on every
// location request. After the first decline, requests use Android's own
// LocationManager, which never shows it.
void main() {
  setUp(LocationFallback.reset);

  test('requests start on the normal provider', () {
    final s = LocationFallback.fix(accuracy: LocationAccuracy.high, platform: TargetPlatform.android);
    expect(s, isNot(isA<AndroidSettings>()));
    expect((NavMath.navLocationSettings(TargetPlatform.android) as AndroidSettings).forceLocationManager, isFalse);
  });

  test('a declined prompt switches every later request to LocationManager', () {
    expect(LocationFallback.noteError(const LocationServiceDisabledException()), isTrue, reason: 'first time: retry');
    final s = LocationFallback.fix(
      accuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 4),
      platform: TargetPlatform.android,
    ) as AndroidSettings;
    expect(s.forceLocationManager, isTrue);
    expect(s.timeLimit, const Duration(seconds: 4));
    expect((NavMath.navLocationSettings(TargetPlatform.android) as AndroidSettings).forceLocationManager, isTrue);
  });

  test('only the first decline asks for a retry, so the trip cannot loop', () {
    expect(LocationFallback.noteError(const LocationServiceDisabledException()), isTrue);
    expect(LocationFallback.noteError(const LocationServiceDisabledException()), isFalse);
  });

  test('other errors leave things alone', () {
    expect(LocationFallback.noteError(const PermissionDeniedException('no')), isFalse);
    expect(LocationFallback.noteError(Exception('boom')), isFalse);
    expect(LocationFallback.usingLocationManager, isFalse);
  });

  test('iOS and others are unaffected', () {
    LocationFallback.noteError(const LocationServiceDisabledException());
    final s = LocationFallback.fix(accuracy: LocationAccuracy.high, platform: TargetPlatform.iOS);
    expect(s, isNot(isA<AndroidSettings>()));
  });
}
