import 'dart:async';

import 'package:flutter/painting.dart' show Color;
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;

import '../../services/share_links.dart';
import '../../theme/guidy_ui.dart';
import 'trip_plan.dart';

/// The trip's "follow my trip" share, while there is one: starting it once,
/// sending the rider's position when it is due, and ending it.
///
/// The sheet that asks whether to stop, and the system share dialog, stay
/// with the screen.
class TripLiveShare {
  TripLiveShare({this.startShare = LiveTripShare.start});

  /// Creates the share on the server. Null when that failed.
  final Future<LiveTripShare?> Function(Map<String, dynamic> summary) startShare;

  /// The running share, or null.
  LiveTripShare? current;

  /// A share is being created: don't start a second one.
  bool starting = false;

  /// Starts a share from [summary] (see [summaryOf]). Call only when not
  /// [starting]. Null when the server could not create one.
  Future<LiveTripShare?> start(Map<String, dynamic> summary) async {
    assert(!starting);
    starting = true;
    try {
      return current = await startShare(summary);
    } finally {
      starting = false;
    }
  }

  /// A GPS fix: sent when the share is due one (every few seconds).
  void onFix(LatLng here, {required int step, double? heading, DateTime? eta}) {
    final share = current;
    if (share == null || !share.isDue) return;
    unawaited(share.update(lat: here.latitude, lon: here.longitude, step: step, heading: heading, eta: eta));
  }

  /// Sends [here] now, due or not: right after starting, so the follower
  /// isn't left with no position.
  void sendNow(LatLng here, {required int step, DateTime? eta}) {
    unawaited(current?.update(lat: here.latitude, lon: here.longitude, step: step, eta: eta, force: true));
  }

  /// The rider arrived: the follower sees "arrived". The share stays until
  /// its server-side grace period ends it.
  void arrived(LatLng here, {required int step}) {
    unawaited(current?.update(lat: here.latitude, lon: here.longitude, step: step, status: 'arrived', force: true));
  }

  /// The rider stopped sharing, or left the trip: the follower sees
  /// "ended". [here] null: nothing to send (no fix yet).
  void end(LatLng? here, {required int step}) {
    final share = current;
    current = null;
    if (share == null || share.ended || here == null) return;
    unawaited(share.update(lat: here.latitude, lon: here.longitude, step: step, status: 'ended', force: true));
  }

  /// What the person following the trip sees that doesn't change: where
  /// it goes, the steps, and the route drawn at 5 decimals (~1 m).
  static Map<String, dynamic> summaryOf({
    required Map<String, dynamic> pathData,
    required List<dynamic> instructions,
    required String destName,
    required String? startName,
    required LatLng? end,
    required int? plannedMinutes,
  }) {
    List<List<double>> pts(Object? seg) => [
          for (final p in TripPlan.pointsOfSegment(seg is Map ? seg : const {}))
            [double.parse(p.latitude.toStringAsFixed(5)), double.parse(p.longitude.toStringAsFixed(5))],
        ];
    final segs = pathData['segments'];
    // The follower sees each ride in its line's colour, as the rider does.
    final colors = segs is List ? GuidyModeStyle.segmentColors(segs, instructions) : const <Color?>[];
    return {
      'dest_name': destName,
      'start_name': startName,
      if (end != null) 'end': {'lat': end.latitude, 'lon': end.longitude},
      'planned_minutes': plannedMinutes,
      'steps': [
        for (final st in instructions)
          if (st is Map)
            {
              'action': st['action'],
              'vehicle_type': st['vehicle_type'],
              'route_number': st['route_number'],
              'route_variant': st['route_variant'],
              'station': st['station'],
              'towards': st['towards'],
            },
      ],
      'segments': [
        if (segs is List)
          for (var i = 0; i < segs.length; i++)
            if (segs[i] case final Map seg)
              {
                'color': colors[i] == null ? seg['color'] : GuidyModeStyle.hex(colors[i]!),
                'is_walk': seg['is_walk'] == true || seg['vehicle_type'] == 'walk',
                'points': pts(seg),
              },
      ],
    };
  }
}
