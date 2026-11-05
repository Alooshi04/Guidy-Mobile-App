import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:guidy_app/utils/route_progress.dart';

// A straight 3 km road north from (30.0, 31.0); 0.001 deg lat ~ 111 m.
List<LatLng> road() => [for (var i = 0; i <= 27; i++) LatLng(30.0 + i * 0.001, 31.0)];
LatLng at(double km, {double eastM = 0}) => LatLng(30.0 + km * 1000 / 111320, 31.0 + eastM / (111320 * 0.866));

void main() {
  // walk_to_station (start), board (0.3 km), walk_to_transfer (1.5 km), transfer (1.7 km), arrive (2.8 km)
  final steps = <LatLng?>[at(0), at(0.3), at(1.5), at(1.7), at(2.8)];

  test('moves on when a stop was passed far to the side of its point', () {
    final p = RouteProgress(road(), steps);
    // On the road 150 m past the transfer point, never within 100 m of it.
    expect(p.stepAt(at(1.65), 1), 2);
  });

  test('skips several steps at once after riding straight past them', () {
    final p = RouteProgress(road(), steps);
    expect(p.stepAt(at(2.0), 1), 3);
  });

  test('stays put when off the route (GPS jump)', () {
    final p = RouteProgress(road(), steps);
    expect(p.stepAt(at(2.0, eastM: 400), 1), 1);
  });

  test('never goes backwards', () {
    final p = RouteProgress(road(), steps);
    expect(p.stepAt(at(0.2), 3), 3);
  });

  test('does not move on before reaching the step', () {
    final p = RouteProgress(road(), steps);
    expect(p.stepAt(at(1.4), 1), 1);
  });

  test('a route that doubles back matches the first pass, not the return', () {
    final out = [for (var i = 0; i <= 10; i++) LatLng(30.0 + i * 0.001, 31.0)];
    final back = [for (var i = 10; i >= 0; i--) LatLng(30.0 + i * 0.001, 31.0003)]; // ~30 m east
    final p = RouteProgress([...out, ...back], [out.first, out[5], back[5]]);
    // At out[3]: the return leg passes 30 m away, but the rider is on step 0.
    expect(p.stepAt(out[3], 0), 0);
    // On the outbound leg, past step 1, the return-leg step is still ahead.
    expect(p.stepAt(out[8], 1), 1);
    // Riding on round the turn and back to that stop: reached.
    var step = 1;
    for (final fix in [out[9], out[10], back[1], back[2], back[3], back[4], back[5]]) {
      step = p.stepAt(fix, step);
    }
    expect(step, 2);
  });

  test('recovers after one fix ran far ahead', () {
    final p = RouteProgress(road(), steps);
    p.stepAt(at(2.5), 1); // a bad fix (MapScreen needs two in a row to act)
    expect(p.stepAt(at(1.0), 1), 1);
    expect(p.stepAt(at(1.6), 1), 2);
  });

  test('metres left to a step', () {
    final p = RouteProgress(road(), steps);
    expect(p.metersToStep(at(1.0), 1, 2), closeTo(500, 15));
    expect(p.metersToStep(at(1.0, eastM: 400), 1, 2), isNull);
  });
}
