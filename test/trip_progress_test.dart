import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:guidy_app/screens/trip/trip_progress.dart';
import 'package:guidy_app/utils/route_progress.dart';

// A straight north-south line: 0.001 deg of latitude is ~111 m.
LatLng at(double metresNorth) => LatLng(30 + metresNorth / 111195, 31);

void main() {
  group('StepTracker', () {
    final stepPoints = [at(0), at(1000), at(2000)];

    StepCheck check(StepTracker t, double m, {int step = 0, RouteProgress? progress, bool alarm = true}) =>
        t.check(at(m), step: step, stepPoints: stepPoints, progress: progress, alarmAllowed: alarm);

    test('far from the next stop: nothing happens', () {
      final c = check(StepTracker(), 500);
      expect([c.alarm, c.atNextPoint, c.advanceTo], [false, false, null]);
    });

    test('the alarm fires once, ~150 m out, and again only after moving on', () {
      final t = StepTracker();
      expect(check(t, 860).alarm, isTrue); // 140 m out
      expect(check(t, 870).alarm, isFalse);
      t.onAdvanced();
      expect(check(t, 1860, step: 1).alarm, isTrue);
    });

    test('no alarm when switched off, or right on top of the stop', () {
      expect(check(StepTracker(), 860, alarm: false).alarm, isFalse);
      expect(check(StepTracker(), 990).alarm, isFalse); // 10 m: too late to warn
    });

    test('within 100 m of the next stop: move on to it', () {
      final c = check(StepTracker(), 920);
      expect(c.atNextPoint, isTrue);
      expect(c.alarm, isTrue);
    });

    test('passing steps along the route takes two fixes in a row', () {
      final route = [at(0), at(1000), at(2000)];
      final progress = RouteProgress(route, stepPoints);
      final t = StepTracker();
      // 1.5 km along, 0 m from any step point: route progress says step 1.
      expect(check(t, 1500, progress: progress).advanceTo, isNull);
      expect(check(t, 1510, progress: progress).advanceTo, 1);
    });

    test('after going back by hand, auto-advance waits until the rider has moved on', () {
      final progress = RouteProgress([at(0), at(1000), at(2000)], stepPoints);
      final t = StepTracker();
      t.onAdvanced();
      t.hold(at(950)); // asked to go back 50 m from the next stop
      // Still standing there: neither "within 100 m of the next stop" nor the
      // route-progress vote may snap the trip forward again.
      for (final m in [950.0, 960.0, 980.0]) {
        final c = check(t, m, progress: progress);
        expect([c.atNextPoint, c.advanceTo], [false, null], reason: '$m m');
      }
      // Moved 100 m on (>60 m from where they asked): auto-advance is back.
      expect(check(t, 1050, progress: progress).atNextPoint, isTrue);
    });

    test('the hold is cleared by a new step, and the alarm re-arms', () {
      final t = StepTracker();
      expect(check(t, 860).alarm, isTrue);
      t.onAdvanced();
      t.hold(at(860));
      expect(check(t, 870).alarm, isTrue, reason: 'back on this step, the stop alarm fires again');
      t.onAdvanced();
      expect(check(t, 920).atNextPoint, isTrue, reason: 'a manual step forward drops the hold');
    });

    test('a single jump ahead does not count', () {
      final progress = RouteProgress([at(0), at(1000), at(2000)], stepPoints);
      final t = StepTracker();
      expect(check(t, 1500, progress: progress).advanceTo, isNull);
      expect(check(t, 300, progress: progress).advanceTo, isNull); // back: vote reset
      expect(check(t, 1500, progress: progress).advanceTo, isNull);
    });
  });

  // Beta report: standing right at the boarding spot, the sheet said
  // "0 m to On the road to Bank of Alexandria" and the trip never moved on.
  // The sheet counted metres along the route; the step moved on by the
  // straight line to the next step's own point (100 m), or by a two-fix
  // vote that any off-route fix reset, and a "back" tap held it until the
  // rider walked 60 m away. Now a walk ends by the sheet's own measure.
  group('StepTracker: walks', () {
    // Walk 300 m north to the street, then a minibus 2 km east along it.
    LatLng ne(double north, double east) => LatLng(30 + north / 111195, 31 + east / 96300);
    final street = [for (var e = 0.0; e <= 2000; e += 100) ne(300, e)];
    final walk = [for (var n = 0.0; n < 300; n += 50) ne(n, 0)];
    final route = [...walk, ...street];
    final instructions = <Map<String, dynamic>>[
      {'action': 'walk_to_station', 'station': 'On the road to Bank of Alexandria'},
      {'action': 'board', 'hail': true, 'vehicle_type': 'minibus', 'station': 'On the road to Bank of Alexandria'},
      {'action': 'arrive', 'station': 'Hegaz'},
    ];
    // The walk's own point at its start, or (as the backend may send it)
    // at its end, the stop: both must work.
    final pointsAtStart = [ne(0, 0), ne(300, 0), ne(300, 2000)];
    final pointsAtEnd = [ne(300, 0), ne(300, 0), ne(300, 2000)];

    StepCheck walkCheck(StepTracker t, LatLng here, List<LatLng?> points, RouteProgress p,
            {StepEnd end = StepEnd.street, double accuracy = 15}) =>
        t.check(here, step: 0, stepPoints: points, progress: p, alarmAllowed: true, end: end, accuracy: accuracy);

    bool movedOn(StepCheck c) => c.atNextPoint || c.advanceTo != null;

    test('how each step ends', () {
      final metro = [
        {'action': 'walk_to_station'},
        {'action': 'board', 'vehicle_type': 'metro'},
        {'action': 'walk_to_transfer'},
        {'action': 'transfer', 'vehicle_type': 'microbus'},
        {'action': 'arrive'},
        {'action': 'walk_to_destination'},
      ];
      expect([for (var i = 0; i < metro.length; i++) StepEnd.of(metro, i)],
          [StepEnd.station, StepEnd.ride, StepEnd.street, StepEnd.ride, StepEnd.walk, StepEnd.walk]);
      expect(StepEnd.of(instructions, 0), StepEnd.street);
    });

    test('the arrival radius follows the fix\'s accuracy, 25 to 40 m (twice at a station)', () {
      expect(StepTracker.arrivalRadius(StepEnd.walk, 0), 25);
      expect(StepTracker.arrivalRadius(StepEnd.street, 32), 32);
      expect(StepTracker.arrivalRadius(StepEnd.walk, 300), 40);
      expect(StepTracker.arrivalRadius(StepEnd.station, 10), 50);
    });

    for (final (name, points) in [('point at the start', pointsAtStart), ('point at the end', pointsAtEnd)]) {
      test('noisy fixes hovering 10-20 m short of the point move the trip on ($name)', () {
        final progress = RouteProgress(route, points);
        final t = StepTracker();
        // Approaching: nothing yet.
        for (final n in [100.0, 200.0, 250.0]) {
          expect(movedOn(walkCheck(t, ne(n, 0), points, progress)), isFalse, reason: '$n m');
        }
        // Standing 10-20 m short, the fix wandering a few metres sideways.
        final c = walkCheck(t, ne(285, 6), points, progress);
        expect(c.atNextPoint, isTrue);
        // Whatever the first fix there is, it moves on at once.
        for (final (n, e) in [(280.0, -7.0), (290.0, 4.0), (282.0, 8.0)]) {
          expect(walkCheck(StepTracker(), ne(n, e), points, RouteProgress(route, points)).atNextPoint, isTrue,
              reason: '$n north, $e east');
        }
      });

      test('the sheet never sits on "0 m": whenever it shows 0, the step moves on ($name)', () {
        final progress = RouteProgress(route, points);
        final t = StepTracker();
        var shownZero = 0;
        // A walk up to the stop and on past it along the street, with
        // sideways wander, one fix a metre or two on.
        for (var n = 240.0; n <= 300; n += 1.5) {
          final here = ne(n, (n * 7 % 11) - 5);
          final left = TripProgress.stepLeft(here, step: 0, stepPoints: points, progress: progress);
          final c = walkCheck(t, here, points, progress);
          if (left != null && (left / 10).round() * 10 == 0) {
            shownZero++;
            expect(movedOn(c), isTrue, reason: 'the sheet shows 0 m at $n m north');
          }
          if (movedOn(c)) break;
        }
        expect(shownZero, lessThanOrEqualTo(1), reason: 'moved on by the first "0 m" at the latest');
      });
    }

    test('not before: 60 m short of the point stays on the walk', () {
      final progress = RouteProgress(route, pointsAtEnd);
      expect(movedOn(walkCheck(StepTracker(), ne(240, 0), pointsAtEnd, progress)), isFalse);
    });

    test('a poorer fix gets a wider radius', () {
      final progress = RouteProgress(route, pointsAtStart);
      expect(walkCheck(StepTracker(), ne(265, 0), pointsAtStart, progress, accuracy: 8).atNextPoint, isFalse);
      expect(walkCheck(StepTracker(), ne(265, 0), pointsAtStart, progress, accuracy: 40).atNextPoint, isTrue);
    });

    test('a minibus is waved down anywhere on its street: reaching it is enough', () {
      // Out of a side street 120 m east of the walk, onto the minibus's
      // street 80 m past the stop.
      final progress = RouteProgress(route, pointsAtStart);
      final here = ne(300, 80);
      expect(walkCheck(StepTracker(), here, pointsAtStart, progress).atNextPoint, isTrue);
      // A rail station is not: its gates are at the station.
      final t = StepTracker();
      expect(walkCheck(t, here, pointsAtStart, progress, end: StepEnd.station).atNextPoint, isFalse);
    });

    test('a street only counts near the stop, not where the line loops back later', () {
      // The line comes back past the walk's start 1.5 km into the ride.
      final loop = [...walk, ne(300, 0), ne(300, 700), ne(-50, 700), ne(-50, 0), ne(-50, -700)];
      final points = [ne(0, 0), ne(300, 0), ne(-50, -700)];
      final progress = RouteProgress(loop, points);
      expect(movedOn(walkCheck(StepTracker(), ne(-40, 0), points, progress)), isFalse);
    });

    test('well past the point takes two fixes in a row (one may be a GPS jump)', () {
      final progress = RouteProgress(route, pointsAtStart);
      final t = StepTracker();
      // 150 m past the stop along the street, for a walk to a station
      // (no street rule): too far past for one fix.
      final c1 = walkCheck(t, ne(300, 150), pointsAtStart, progress, end: StepEnd.station);
      expect(movedOn(c1), isFalse);
      final c2 = walkCheck(t, ne(300, 155), pointsAtStart, progress, end: StepEnd.station);
      expect(c2.advanceTo, 1);
    });

    test('an off-route fix neither counts towards the vote nor breaks it', () {
      final progress = RouteProgress(route, pointsAtStart);
      final t = StepTracker();
      expect(movedOn(walkCheck(t, ne(300, 150), pointsAtStart, progress, end: StepEnd.station)), isFalse);
      expect(movedOn(walkCheck(t, ne(450, 150), pointsAtStart, progress, end: StepEnd.station)), isFalse);
      expect(walkCheck(t, ne(300, 160), pointsAtStart, progress, end: StepEnd.station).advanceTo, 1);
    });

    test('back by hand before reaching the point: arriving still moves the trip on', () {
      // The trip used to hold until the rider was 60 m from where they
      // tapped back, so a rider who tapped back 40 m out and walked to the
      // stop waited there on "0 m".
      final progress = RouteProgress(route, pointsAtEnd);
      final t = StepTracker()
        ..onAdvanced()
        ..hold(ne(260, 0));
      expect(movedOn(walkCheck(t, ne(260, 0), pointsAtEnd, progress)), isFalse);
      expect(movedOn(walkCheck(t, ne(270, 0), pointsAtEnd, progress)), isFalse);
      expect(walkCheck(t, ne(290, 0), pointsAtEnd, progress).atNextPoint, isTrue);
    });

    test('back by hand at the point: held there until the rider moves on', () {
      final progress = RouteProgress(route, pointsAtEnd);
      final t = StepTracker()
        ..onAdvanced()
        ..hold(ne(295, 0));
      for (final (n, e) in [(295.0, 0.0), (285.0, 5.0), (300.0, -4.0), (300.0, 30.0)]) {
        expect(movedOn(walkCheck(t, ne(n, e), pointsAtEnd, progress)), isFalse, reason: '$n, $e');
      }
      expect(walkCheck(t, ne(300, 80), pointsAtEnd, progress).atNextPoint, isTrue);
    });
  });

  group('TripProgress', () {
    test('destination: planned coordinates, else the end of the route', () {
      expect(TripProgress.destinationOf({'end_lat': '30.1', 'end_lon': 31.2}, const []), const LatLng(30.1, 31.2));
      expect(TripProgress.destinationOf({}, [at(0), at(5)]), at(5));
      expect(TripProgress.destinationOf({}, const []), isNull);
    });

    test('remaining: metres along the route, minutes at the trip pace', () {
      final route = [at(0), at(1000), at(2000)];
      final now = DateTime(2026, 10, 13, 9);
      final r = TripProgress.remaining(
        at(500),
        instructions: [{}, {}, {}],
        step: 0,
        stepPoints: [at(0), at(1000), at(2000)],
        progress: RouteProgress(route, [at(0), at(1000), at(2000)]),
        destination: at(2000),
        plannedMinutes: 40,
        now: now,
      )!;
      expect(r.meters, closeTo(1500, 5));
      expect(r.minutes, closeTo(30, 0.2)); // 1500 of 2000 m at 40 min
      expect(r.arrival.difference(now).inMinutes, 30);
    });

    test('remaining: nothing to measure without steps', () {
      expect(
        TripProgress.remaining(at(0),
            instructions: const [], step: 0, stepPoints: const [], progress: null, destination: null, plannedMinutes: 30),
        isNull,
      );
    });
  });
}
