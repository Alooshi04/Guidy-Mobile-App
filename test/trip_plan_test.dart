import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/theme/guidy_ui.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:guidy_app/screens/trip/trip_plan.dart';

const _teal = Color(0xFF00A6A6);

void main() {
  test('steps, their points, fare and time come from the option', () {
    final plan = TripPlan.fromPathData({
      'instructions': [
        {'action': 'walk_to_station', 'lat': 30.05, 'lon': 31.24},
        {'action': 'board'},
        {'action': 'arrive', 'lat': 30.06, 'lon': 31.25},
      ],
      'option': {'fare_total_egp': 22, 'time': 41},
    }, defaultColor: _teal);
    expect(plan.instructions, hasLength(3));
    expect(plan.stepPoints, [const LatLng(30.05, 31.24), null, const LatLng(30.06, 31.25)]);
    expect(plan.totalFare, 22);
    expect(plan.totalDurationMinutes, 41);
  });

  test('no total fare: the steps are added up, and 10 if they have none', () {
    final summed = TripPlan.fromPathData({
      'instructions': [
        {'fare_egp': 8},
        {'fare_egp': '7'},
      ],
    }, defaultColor: _teal);
    expect(summed.totalFare, 15);
    expect(summed.totalDurationMinutes, 30);

    expect(TripPlan.fromPathData({'instructions': []}, defaultColor: _teal).totalFare, 10);
  });

  // 1.0.11 (19): a 5.5 EGP trip showed as 5 EGP on the trip screen.
  test('a fare with piastres keeps them', () {
    expect(TripPlan.fromPathData({'instructions': [], 'option': {'fare_total_egp': 5.5}}, defaultColor: _teal).totalFare, 5.5);
    final summed = TripPlan.fromPathData({
      'instructions': [
        {'action': 'board', 'fare_egp': 5.5},
        {'action': 'board', 'fare_egp': 3.25},
      ],
    }, defaultColor: _teal);
    expect(summed.totalFare, 8.75);
  });

  test('an unreadable option keeps the steps and leaves fare and time unknown', () {
    final plan = TripPlan.fromPathData({
      'instructions': [
        {'lat': 30.0, 'lon': 31.0},
      ],
      'option': 'not a map',
    }, defaultColor: _teal);
    expect(plan.stepPoints, [const LatLng(30.0, 31.0)]);
    expect(plan.totalFare, isNull);
    expect(plan.totalDurationMinutes, isNull);
  });

  test('segments: walks and rides in order, empty ones dropped, colours resolved', () {
    final plan = TripPlan.fromPathData({
      'color': '#112233',
      'segments': [
        {'is_walk': true, 'points': [{'lat': 30.0, 'lon': 31.0}, {'lat': 30.001, 'lon': 31.0}]},
        {'vehicle_type': 'bus', 'points': []},
        {'vehicle_type': 'bus', 'color': '#ff0000', 'points': [{'lat': 30.001, 'lon': 31.0}, {'lat': 30.01, 'lon': 31.0}]},
        {'vehicle_type': 'metro', 'points': [{'lat': 30.01, 'lon': 31.0}, {'lat': 91, 'lon': 31.0}]},
      ],
    }, defaultColor: _teal);
    expect(plan.routeColor, const Color(0xFF112233));
    expect(plan.segments.map((s) => s.isWalk), [true, false, false]);
    // Rides take the app's line colour, not the server's (owner, 2026-10-22).
    expect(plan.segments.map((s) => s.color),
        [TripPlan.walkSegmentColor, GuidyModeStyle.color('bus'), GuidyModeStyle.color('metro')]);
    expect(plan.segments.last.points, [const LatLng(30.01, 31.0)]); // lat 91 dropped
    expect(plan.allPoints, hasLength(5));
    expect(plan.walkSegments, hasLength(1));
  });

  test('a missing or bad route colour falls back to the default', () {
    expect(TripPlan.fromPathData({}, defaultColor: _teal).routeColor, _teal);
    expect(TripPlan.fromPathData({'color': 'teal'}, defaultColor: _teal).routeColor, _teal);
  });
}
