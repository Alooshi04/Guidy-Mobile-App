import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:guidy_app/utils/nav_math.dart';
import 'package:guidy_app/utils/trip_eta.dart';

void main() {
  // Walk 750 m (10 min), wait 4 + ride 12 min (6000 m), get off, walk 300 m (4 min).
  final steps = [
    {'action': 'walk_to_station', 'distance_m': 750},
    {'action': 'board', 'wait_min': 4, 'ride_min': 12, 'ride_m': 6000},
    {'action': 'arrive'},
    {'action': 'walk_to_destination', 'distance_m': 300},
  ];

  group('Minutes left on a trip', () {
    test('at the start it is every step: 10 + 4 + 12 + 4', () {
      expect(TripEta.minutesLeft(steps, 0, 750), closeTo(30, 0.01));
    });

    test('half way through the first walk, half of it is left', () {
      expect(TripEta.minutesLeft(steps, 0, 375), closeTo(25, 0.01));
    });

    test('on the bus, the ride left is at the bus\'s own pace, and the wait is over', () {
      // 3000 m of 6000 m left = 6 of 12 min, then the 4 min walk.
      expect(TripEta.minutesLeft(steps, 1, 3000), closeTo(10, 0.01));
    });

    test('on the last walk, only it is left', () {
      expect(TripEta.minutesLeft(steps, 3, 150), closeTo(2, 0.01));
    });

    test('steps with no timing at all give no answer, so the caller can fall back', () {
      expect(TripEta.minutesLeft([{'action': 'board'}], 0, 1000), isNull);
    });
  });

  group('Distance left', () {
    test('formats metres under a kilometre, rounded to tens', () {
      expect(TripEta.distanceLabel(437, isArabic: false), '440 m');
      expect(TripEta.distanceLabel(2345, isArabic: false), '2.3 km');
      expect(TripEta.distanceLabel(2345, isArabic: true), '2.3 كم');
      expect(TripEta.distanceLabel(996, isArabic: false), '1.0 km');
    });
  });

  group('Snapping the dot to the route', () {
    final route = [const LatLng(30.0, 31.0), const LatLng(30.0, 31.01)];

    test('a fix a few metres off the line is drawn on it', () {
      final snapped = NavMath.snapToRoute(route, const LatLng(30.00008, 31.005), accuracy: 10);
      expect(snapped.latitude, closeTo(30.0, 1e-7));
      expect(snapped.longitude, closeTo(31.005, 1e-6));
    });

    test('a rider who has really left the route is drawn where they are', () {
      const away = LatLng(30.001, 31.005); // ~110 m off
      expect(NavMath.snapToRoute(route, away, accuracy: 10), away);
    });

    test('a parallel street 18 m away is not the route', () {
      const parallel = LatLng(30.000162, 31.005); // 18 m north
      expect(NavMath.snapToRoute(route, parallel, accuracy: 10), parallel);
    });

    test('a later leg running close by is not where the rider is', () {
      // East 960 m, up 30 m, then back west: the way back passes 8 m from
      // a rider still on the way out (22 m from it).
      final outAndBack = [
        const LatLng(30.0, 31.0),
        const LatLng(30.0, 31.01),
        const LatLng(30.00027, 31.01),
        const LatLng(30.00027, 31.0),
      ];
      const walker = LatLng(30.0002, 31.002);
      expect(NavMath.snapToRoute(outAndBack, walker, accuracy: 10, nearAlong: 190), walker);
    });

    test('no route: the fix as is', () {
      const p = LatLng(30.0, 31.0);
      expect(NavMath.snapToRoute(const [], p, accuracy: 10), p);
    });
  });

  group('GPS stream settings', () {
    test('Android asks for a fix every second, not the plugin default of five', () {
      final s = NavMath.navLocationSettings(TargetPlatform.android);
      expect(s, isA<AndroidSettings>());
      expect((s as AndroidSettings).intervalDuration, const Duration(seconds: 1));
      expect(s.accuracy, LocationAccuracy.bestForNavigation);
    });

    test('iOS keeps updating while still and uses the navigation activity type', () {
      final s = NavMath.navLocationSettings(TargetPlatform.iOS);
      expect(s, isA<AppleSettings>());
      expect((s as AppleSettings).pauseLocationUpdatesAutomatically, isFalse);
      expect(s.activityType, ActivityType.otherNavigation);
    });
  });
}
