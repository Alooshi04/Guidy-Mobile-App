import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show CameraPosition, LatLng;
import 'package:guidy_app/screens/trip/nav_camera.dart';
import 'package:guidy_app/screens/trip/trip_puck.dart';
import 'package:guidy_app/utils/nav_math.dart';

// ~111 m per 0.001 deg of latitude.
LatLng at(double metresNorth) => LatLng(30 + metresNorth / 111195, 31);

class _Clocks {
  Duration frame = Duration.zero;
  DateTime wall = DateTime(2026, 10, 13, 9);
  void advance(int ms) {
    frame += Duration(milliseconds: ms);
    wall = wall.add(Duration(milliseconds: ms));
  }
}

void main() {
  late _Clocks clocks;
  late TripPuck puck;
  setUp(() {
    clocks = _Clocks();
    puck = TripPuck(zoom: 17.5, tilt: 50, clock: () => clocks.frame, wallClock: () => clocks.wall);
  });

  void feed(double m, {double speed = 5, double course = 0}) =>
      puck.feed(at(m), speed: speed, accuracy: 5, course: course, routeHeading: 0);

  test('nothing to draw before the first fix', () {
    final f = puck.tick(follow: true, hasMap: true);
    expect([f.push, f.stop], [false, false]);
    expect(puck.shownPos, isNull);
  });

  test('the first fix is drawn at once', () {
    feed(0);
    clocks.advance(40);
    expect(puck.tick(follow: false, hasMap: false).push, isTrue);
    expect(puck.shownPos, at(0));
  });

  test('a moving rider glides to the next fix over the gap between fixes', () {
    feed(0);
    clocks.advance(40);
    puck.tick(follow: false, hasMap: false);
    clocks.advance(960); // the next fix comes 1 s after the first
    feed(20);
    clocks.advance(500);
    puck.tick(follow: false, hasMap: false);
    expect(puck.shownPos!.latitude, closeTo(at(10).latitude, 1e-6)); // halfway
  });

  test('a jump of more than 150 m is not travel: straight there', () {
    feed(0);
    clocks.advance(40);
    puck.tick(follow: false, hasMap: false);
    clocks.advance(1000);
    feed(400);
    clocks.advance(40);
    puck.tick(follow: false, hasMap: false);
    expect(puck.shownPos, at(400));
  });

  test('standing still, noise within the accuracy does not move the dot', () {
    feed(0, speed: 0);
    clocks.advance(40);
    puck.tick(follow: false, hasMap: false);
    clocks.advance(1000);
    feed(2, speed: 0.1);
    clocks.advance(500);
    puck.tick(follow: false, hasMap: false);
    expect(puck.shownPos, at(0));
  });

  test('settled and not following: the loop stops', () {
    feed(0);
    var stopped = false;
    for (var i = 0; i < 60 && !stopped; i++) {
      clocks.advance(40);
      stopped = puck.tick(follow: false, hasMap: false).stop;
    }
    expect(stopped, isTrue);
  });

  test('standing, the compass turns the arrow and wakes the loop', () {
    // A fix before any compass reading follows the course; the next fix
    // after one hands the arrow to the compass.
    puck.onCompass(90);
    feed(0, speed: 0);
    expect(puck.onCompass(90), isTrue);
    for (var i = 0; i < 60; i++) {
      clocks.advance(40);
      puck.tick(follow: false, hasMap: false);
    }
    expect(puck.shownHeading, closeTo(90, 1));
  });

  test('moving, the arrow follows the course, not the compass', () {
    feed(0, speed: 5, course: 180);
    expect(puck.onCompass(90), isFalse);
  });

  test('the camera starts from where the map is and eases to the follow zoom', () {
    feed(0);
    clocks.advance(40);
    puck.tick(follow: true, hasMap: true);
    final first = puck.placeCamera(const CameraPosition(target: LatLng(30, 31), zoom: 12, tilt: 0))!;
    expect(first.target, at(0));
    expect(first.zoom, closeTo(12 + (17.5 - 12) * 0.2, 1e-9));
    CameraPosition? cam;
    for (var i = 0; i < 80; i++) {
      cam = puck.placeCamera(null);
    }
    expect(cam!.zoom, closeTo(17.5, 0.01));
    expect(cam.tilt, closeTo(50, 0.1));
  });

  // Tester report: minimise the trip and the arrow stops following the
  // phone until the trip is restarted. The last fix said "moving", then no
  // more fixes came, and the compass was ignored from then on.
  test('the compass takes the arrow back when the moving fixes stop coming', () {
    feed(0, speed: 8, course: 90);
    expect(puck.onCompass(200), isFalse); // moving: the arrow follows the course
    clocks.advance(TripPuck.courseStale.inMilliseconds + 100);
    expect(puck.onCompass(200), isTrue);
    for (var i = 0; i < 60; i++) {
      clocks.advance(33);
      puck.tick(follow: false, hasMap: false);
    }
    expect(puck.shownHeading, closeTo(200, 1));
  });

  test('a fix before the first compass reading does not lock the compass out', () {
    feed(0, speed: 0, course: -1);
    clocks.advance(500);
    expect(puck.onCompass(120), isTrue);
  });

  // Beta report: "In Google Maps, when I walk, the arrow doesn't keep
  // jumping up and down and moving randomly, and the map doesn't flip
  // every little bit."
  group('walking', () {
    final route = [at(0), at(2000)];

    /// [seconds] of a walk north at about 1.3 m/s: a fix a second that
    /// wanders a few metres, a GPS course that swings (and now and then
    /// points backwards), and a phone that sways in the hand. Returns the
    /// camera bearings and arrow headings drawn, a frame every 33 ms.
    ({List<double> camera, List<double> arrow}) walk(int seconds, {double speedSwing = 0.15}) {
      final rnd = math.Random(3);
      final smoother = FixSmoother();
      final camera = <double>[], arrow = <double>[];
      var last = 0.0;
      for (var ms = 0; ms < seconds * 1000; ms += 33) {
        clocks.advance(33);
        final t = ms / 1000;
        // Sway: 15 degrees either way, a bit over once a second, plus jitter.
        puck.onCompass(15 * math.sin(2 * math.pi * 1.2 * t) + rnd.nextDouble() * 6 - 3);
        if (ms % 990 < 33) {
          final speed = 1.3 + (rnd.nextDouble() * 2 - 1) * speedSwing;
          final course = rnd.nextInt(9) == 0 ? 180.0 : rnd.nextDouble() * 60 - 30;
          final raw = LatLng(at(1.3 * t + rnd.nextDouble() * 6 - 3).latitude, 31 + (rnd.nextDouble() * 8 - 4) / 96300);
          final fix = smoother.add(raw, accuracy: 10, speed: speed, course: course, at: clocks.wall);
          last = NavCamera.headingFor(speed: speed, course: course, here: fix, route: route, last: last);
          puck.feed(fix, speed: speed, accuracy: 10, course: course, routeHeading: last);
        }
        puck.tick(follow: true, hasMap: true);
        final cam = puck.placeCamera(null);
        if (cam != null && t > 3) {
          camera.add(cam.bearing);
          arrow.add(puck.shownHeading);
        }
      }
      return (camera: camera, arrow: arrow);
    }

    double worst(List<double> headings, double around) =>
        headings.map((h) => NavMath.angularDistance(h, around)).reduce(math.max);

    test('the map stays put and the arrow steady', () {
      puck.cameraBearingTarget = 0;
      final drawn = walk(40);
      expect(worst(drawn.camera, 0), lessThan(1), reason: 'the map never turns');
      expect(worst(drawn.arrow, 0), lessThan(12), reason: 'the arrow sways a little, never flips');
    });

    test('around the brisk-walk speed where the course takes over, the map still stays put', () {
      puck.cameraBearingTarget = 0;
      final drawn = walk(40, speedSwing: 0.5); // 0.8-1.8 m/s
      expect(worst(drawn.camera, 0), lessThan(1));
    });

    test('standing at a corner, the map does not flip between its two roads', () {
      puck.cameraBearingTarget = 0;
      feed(0, speed: 0);
      // Where the drawn route turns, a standing rider's wander puts them
      // before the corner on one fix and after it on the next.
      for (final h in [0.0, 90.0, 0.0, 90.0, 90.0, 0.0, 90.0, 0.0, 0.0, 90.0, 90.0, 0.0]) {
        clocks.advance(1000);
        puck.feed(at(0), speed: 0.2, accuracy: 10, course: -1, routeHeading: h);
        for (var i = 0; i < 30; i++) {
          clocks.advance(33);
          puck.tick(follow: true, hasMap: true);
          expect(puck.placeCamera(null)!.bearing, closeTo(0, 0.01));
        }
      }
    });

    test('a real turn turns the map, smoothly', () {
      puck.cameraBearingTarget = 0;
      feed(0);
      final bearings = <double>[];
      for (var i = 0; i < 4; i++) {
        clocks.advance(1000);
        puck.feed(at(10.0 * i), speed: 5, accuracy: 5, course: 90, routeHeading: 90);
        for (var f = 0; f < 30; f++) {
          clocks.advance(33);
          puck.tick(follow: true, hasMap: true);
          bearings.add(puck.placeCamera(null)!.bearing);
        }
      }
      expect(bearings.last, closeTo(90, 2));
      for (var i = 1; i < bearings.length; i++) {
        expect(NavMath.angularDistance(bearings[i], bearings[i - 1]), lessThan(8), reason: 'no jump at frame $i');
      }
    });

    test('a compass wobble of a few degrees does not move the arrow', () {
      puck.onCompass(40);
      feed(0, speed: 0);
      for (var i = 0; i < 60; i++) {
        clocks.advance(33);
        puck.tick(follow: false, hasMap: false);
      }
      final settled = puck.shownHeading;
      for (var i = 0; i < 120; i++) {
        clocks.advance(33);
        puck.onCompass(40 + (i.isEven ? 6 : -6));
        puck.tick(follow: false, hasMap: false);
      }
      expect(NavMath.angularDistance(puck.shownHeading, settled), lessThan(0.5));
    });
  });

  group('FixSmoother', () {
    final t0 = DateTime(2026, 11, 3, 9);

    test('takes the wander out of a walk without trailing far behind', () {
      final rnd = math.Random(11);
      final s = FixSmoother();
      var rawSide = 0.0, smoothSide = 0.0, lag = 0.0;
      for (var i = 0; i < 60; i++) {
        final side = rnd.nextDouble() * 12 - 6;
        final p = s.add(LatLng(at(1.3 * i).latitude, 31 + side / 96300),
            accuracy: 10, speed: 1.3, course: -1, at: t0.add(Duration(seconds: i)));
        if (i < 10) continue;
        rawSide += side * side;
        smoothSide += math.pow((p.longitude - 31) * 96300, 2);
        lag = math.max(lag, (at(1.3 * i).latitude - p.latitude) * 111195);
      }
      expect(math.sqrt(smoothSide / 50), lessThan(math.sqrt(rawSide / 50) * 0.7));
      expect(lag, lessThan(6));
    });

    test('keeps up with a bus', () {
      final s = FixSmoother();
      late LatLng p;
      for (var i = 0; i < 30; i++) {
        p = s.add(at(10.0 * i), accuracy: 8, speed: 10, course: 0, at: t0.add(Duration(seconds: i)));
      }
      expect((at(290).latitude - p.latitude).abs() * 111195, lessThan(1));
    });

    test('a jump or a long gap starts afresh', () {
      final s = FixSmoother();
      s.add(at(0), accuracy: 5, speed: 0, course: -1, at: t0);
      expect(s.add(at(400), accuracy: 5, speed: 0, course: -1, at: t0.add(const Duration(seconds: 1))), at(400));
      expect(s.add(at(420), accuracy: 5, speed: 0, course: -1, at: t0.add(const Duration(seconds: 30))), at(420));
    });
  });
}
