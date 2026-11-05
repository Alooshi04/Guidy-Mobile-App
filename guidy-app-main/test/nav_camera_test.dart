import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:guidy_app/screens/trip/nav_camera.dart';
import 'package:guidy_app/utils/nav_math.dart';

// Beta report: "In Google Maps, when I walk, the arrow doesn't keep jumping
// up and down and the map doesn't flip every little bit."
LatLng ne(double north, double east) => LatLng(30 + north / 111195, 31 + east / 96300);

void main() {
  group('BearingHold', () {
    test('a jittery walk keeps the map still', () {
      final hold = BearingHold()..reset(0);
      // GPS course at a walk: tens of degrees either way, now and then
      // pointing back the way the rider came.
      final rnd = math.Random(7);
      for (var i = 0; i < 200; i++) {
        final h = i % 17 == 0 ? 180.0 : (rnd.nextDouble() * 50 - 25);
        expect(hold.update(h), 0, reason: 'fix $i: $h');
      }
    });

    test('noise either side of north does not wrap the map round', () {
      final hold = BearingHold()..reset(355);
      for (final h in [10.0, 340.0, 15.0, 350.0, 5.0, 335.0]) {
        expect(hold.update(h), 355);
      }
    });

    test('a sustained turn turns it, once, to the new way', () {
      final hold = BearingHold()..reset(0);
      expect(hold.update(88), 0);
      expect(hold.update(93), 0);
      expect(hold.update(90), closeTo(90, 1));
      expect(hold.update(85), closeTo(90, 1), reason: 'and holds there');
    });

    test('two different wild headings in a row are not a turn', () {
      final hold = BearingHold()..reset(0);
      for (final h in [90.0, 200.0, 95.0, 270.0, 100.0, 0.0, 85.0]) {
        expect(hold.update(h), 0, reason: '$h');
      }
    });

    test('the first heading is taken as it is', () {
      expect(BearingHold().update(123), 123);
    });

    test('average heading, the short way round', () {
      expect(BearingHold.meanHeading([350, 10]), closeTo(0, 1e-6));
      expect(BearingHold.meanHeading([80, 100]), closeTo(90, 1e-6));
    });
  });

  group('the route\'s way', () {
    // One straight 1 km segment north: only two vertices.
    final road = [ne(0, 0), ne(1000, 0), ne(1000, 500)];

    test('forward, wherever the rider is along a long straight segment', () {
      // The nearest vertex is behind the rider for the first half of the
      // segment; the map used to point back at it.
      for (final n in [10.0, 200.0, 400.0, 499.0, 501.0, 700.0, 975.0]) {
        final b = NavCamera.forwardRouteBearing(road, ne(n, 4), fallback: -1);
        expect(NavMath.angularDistance(b, 0), lessThan(1), reason: '$n m along');
      }
    });

    test('round the corner, the new way', () {
      final b = NavCamera.forwardRouteBearing(road, ne(1000, 50), fallback: -1);
      expect(NavMath.angularDistance(b, 90), lessThan(1));
    });

    test('a later leg passing close by does not count', () {
      // Out north, back south 20 m to the east.
      final outAndBack = [ne(0, 0), ne(500, 0), ne(500, 20), ne(0, 20)];
      final b = NavCamera.forwardRouteBearing(outAndBack, ne(200, 12), fallback: -1, nearAlong: 200);
      expect(NavMath.angularDistance(b, 0), lessThan(1));
    });

    test('at a walk the map follows the route, not the GPS course', () {
      final route = [ne(0, 0), ne(1000, 0)];
      double at(double speed, double course) =>
          NavCamera.headingFor(speed: speed, course: course, here: ne(300, 0), route: route, last: 0);
      expect(at(1.3, 180), closeTo(0, 1), reason: 'a walker\'s course is noise');
      expect(at(1.4, 75), closeTo(0, 1));
      expect(at(6, 75), 75, reason: 'on a vehicle the course is good');
    });
  });
}
