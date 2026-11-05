import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:guidy_app/screens/trip/trip_live_share.dart';
import 'package:guidy_app/services/share_links.dart';

void main() {
  test('summary: destination, steps without extras, route at 5 decimals', () {
    final s = TripLiveShare.summaryOf(
      pathData: {
        'segments': [
          {'is_walk': true, 'color': '#00ff00', 'points': [{'lat': 30.0444123, 'lon': 31.2357777}]},
          {'vehicle_type': 'walk', 'points': []},
          'not a segment',
        ],
      },
      instructions: [
        {'action': 'board', 'route_number': '66', 'station': 'Ramses', 'secret_internal': 1},
        'not a step',
      ],
      destName: 'Tahrir',
      startName: null,
      end: const LatLng(30.05, 31.24),
      plannedMinutes: 25,
    );
    expect(s['dest_name'], 'Tahrir');
    expect(s['end'], {'lat': 30.05, 'lon': 31.24});
    expect(s['planned_minutes'], 25);
    expect(s['steps'], [
      {'action': 'board', 'vehicle_type': null, 'route_number': '66', 'route_variant': null, 'station': 'Ramses', 'towards': null},
    ]);
    expect(s['segments'], [
      {'color': '#00ff00', 'is_walk': true, 'points': [[30.04441, 31.23578]]},
      {'color': null, 'is_walk': true, 'points': []},
    ]);
  });

  test('summary: no end point, no end key', () {
    final s = TripLiveShare.summaryOf(
        pathData: const {}, instructions: const [], destName: '', startName: 'A', end: null, plannedMinutes: null);
    expect(s.containsKey('end'), isFalse);
  });

  test('start: starting while the server answers, and null when it fails', () async {
    final answer = Completer<LiveTripShare?>();
    final live = TripLiveShare(startShare: (_) => answer.future);
    final started = live.start(const {});
    expect(live.starting, isTrue);
    answer.complete(null);
    expect(await started, isNull);
    expect(live.starting, isFalse);
    expect(live.current, isNull);
  });

  test('ending with no share running does nothing', () {
    final live = TripLiveShare(startShare: (_) async => null);
    live.end(const LatLng(30, 31), step: 0);
    live.arrived(const LatLng(30, 31), step: 0);
    live.onFix(const LatLng(30, 31), step: 0);
    expect(live.current, isNull);
  });
}
