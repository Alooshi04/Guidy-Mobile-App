import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:guidy_app/utils/nav_math.dart';

void main() {
  const tahrir = LatLng(30.044397, 31.235717);
  const museum = LatLng(30.048317, 31.233667);

  group('Arrival', () {
    test('a walk-only trip does not end at its start (reported bug)', () {
      // One step: the rider is on the last step from the first fix.
      expect(NavMath.hasArrived(onLastStep: true, here: tahrir, destination: museum), isFalse);
    });
    test('it ends within 60 m of the destination', () {
      expect(NavMath.hasArrived(onLastStep: true, here: const LatLng(30.04820, 31.23380), destination: museum), isTrue);
    });
    test('not before the last step, however close', () {
      expect(NavMath.hasArrived(onLastStep: false, here: museum, destination: museum), isFalse);
    });
  });

  group('The arrow', () {
    test('standing: GPS wander inside the accuracy does not move the dot', () {
      expect(NavMath.isStandingNoise(speed: 0.1, accuracy: 12, shown: tahrir, fix: const LatLng(30.04445, 31.23575)),
          isTrue);
    });
    test('moving: every fix moves the dot', () {
      expect(NavMath.isStandingNoise(speed: 4, accuracy: 12, shown: tahrir, fix: const LatLng(30.04445, 31.23575)),
          isFalse);
    });
    test('standing: a real step away moves it', () {
      expect(NavMath.isStandingNoise(speed: 0.2, accuracy: 5, shown: tahrir, fix: const LatLng(30.0446, 31.2357)),
          isFalse);
    });
    test('on a bus it points where the bus goes, not where the phone faces', () {
      expect(NavMath.arrowHeading(speed: 8, course: 90, compass: 200, fallback: 0), 90);
    });
    test('standing it points where the phone faces', () {
      expect(NavMath.arrowHeading(speed: 0.3, course: 90, compass: 200, fallback: 0), 200);
    });
    test('without a compass it points along the route', () {
      expect(NavMath.arrowHeading(speed: 0.3, course: 90, compass: null, fallback: 45), 45);
    });
    test('headings turn the short way round', () {
      expect(NavMath.lerpHeading(350, 10, 0.5), closeTo(0, 1e-9));
    });
  });

  group('Arrival time for a live share', () {
    final route = [const LatLng(30.0, 31.0), const LatLng(30.0, 31.01), const LatLng(30.0, 31.02)];
    final now = DateTime(2026, 9, 24, 12);
    test('half the route left is half the planned time', () {
      final eta = NavMath.estimateArrival(route: route, here: const LatLng(30.0, 31.01), plannedMinutes: 40, now: now);
      expect(eta!.difference(now).inMinutes, 20);
    });
    test('at the end it is now; with no route there is none', () {
      expect(NavMath.estimateArrival(route: route, here: const LatLng(30.0, 31.02), plannedMinutes: 40, now: now), now);
      expect(NavMath.estimateArrival(route: const [], here: route.first, plannedMinutes: 40), isNull);
    });
  });
}
