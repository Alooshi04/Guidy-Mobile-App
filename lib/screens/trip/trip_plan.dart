import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;

import '../../services/instruction_formatter.dart';
import '../../theme/guidy_ui.dart';
import '../../utils/polyline_utils.dart';

/// One drawn piece of a trip: a walk or a ride, in order.
class TripSegment {
  const TripSegment({required this.points, required this.isWalk, required this.color});

  final List<LatLng> points;
  final bool isWalk;

  /// The ride's line colour (the trip's own when the segment names none).
  /// Walks are recoloured for the theme where they are drawn.
  final Color color;
}

/// A trip as the server planned it (the route's `pathData`), parsed once.
///
/// Pure data: no widgets, no map. The trip screen copies these into its own
/// state, which a vehicle switch then changes.
///
/// Every part parses on its own and falls back on its own, as the screen
/// always did: a malformed option still leaves the steps, and malformed
/// segments still leave the fare.
class TripPlan {
  TripPlan._({
    required this.instructions,
    required this.stepPoints,
    required this.totalFare,
    required this.totalDurationMinutes,
    required this.routeColor,
    required this.segments,
  });

  /// The steps, as the server sent them ([] if there are none).
  final List<dynamic> instructions;

  /// Each step's position, or null for a step without one. Same length as
  /// [instructions].
  final List<LatLng?> stepPoints;

  /// EGP. The option's total; else the steps' fares added up; else 10.
  /// Null only if the option could not be read at all.
  /// EGP, with piastres (5.5).
  final num? totalFare;

  /// Minutes, 30 when the plan gives none. Null only if the option could
  /// not be read at all.
  final int? totalDurationMinutes;

  final Color routeColor;
  final List<TripSegment> segments;

  /// Every segment's points, end to end.
  List<LatLng> get allPoints => [for (final s in segments) ...s.points];

  List<List<LatLng>> get walkSegments => [for (final s in segments) if (s.isWalk) s.points];

  static const Color walkSegmentColor = Color(0xFF2A9D8F);

  factory TripPlan.fromPathData(Map<String, dynamic> pathData, {required Color defaultColor, bool dark = false}) {
    var instructions = <dynamic>[];
    final stepPoints = <LatLng?>[];
    num? totalFare;
    int? totalDurationMinutes;
    try {
      final raw = pathData['instructions'];
      if (raw is List) {
        instructions = raw;
        stepPoints.addAll(raw.map(latLngOf));
      }
      final opt = pathData['option'] as Map<String, dynamic>?;
      totalFare = InstructionFormatter.asNum(
        opt?['fare_total_egp'] ?? opt?['fare_egp'] ?? pathData['fare_total_egp'] ?? pathData['fare_egp'],
      );
      if (totalFare == null || totalFare == 0) {
        num sum = 0;
        for (final s in instructions) {
          if (s is Map && s['fare_egp'] != null) {
            sum += InstructionFormatter.asNum(s['fare_egp']) ?? 0;
          }
        }
        totalFare = sum > 0 ? sum : 10;
      }
      totalDurationMinutes = InstructionFormatter.asNum(
            opt?['time'] ??
                opt?['raw_time'] ??
                pathData['duration_minutes'] ??
                pathData['time'] ??
                pathData['raw_time'],
          )?.toInt() ??
          30;
    } catch (e) {
      debugPrint("Could not parse instructions: $e");
    }

    var routeColor = defaultColor;
    try {
      routeColor = parseColor(pathData['color']) ?? defaultColor;
    } catch (e) {
      debugPrint("Could not parse route colour: $e");
    }

    final segments = <TripSegment>[];
    try {
      final raw = pathData['segments'];
      if (raw is List) {
        // Each ride in its line's colour, as everywhere else in the app.
        final colors = GuidyModeStyle.segmentColors(raw, instructions, dark: dark);
        for (var i = 0; i < raw.length; i++) {
          final segment = raw[i];
          if (segment is! Map) continue;
          final pts = pointsOfSegment(segment);
          if (pts.isEmpty) continue;
          final bool isWalk = segment['is_walk'] == true || segment['vehicle_type'] == 'walk';
          segments.add(TripSegment(
            points: pts,
            isWalk: isWalk,
            color: isWalk ? walkSegmentColor : (colors[i] ?? routeColor),
          ));
        }
      }
    } catch (e) {
      debugPrint("Could not parse route segments: $e");
    }

    return TripPlan._(
      instructions: instructions,
      stepPoints: stepPoints,
      totalFare: totalFare,
      totalDurationMinutes: totalDurationMinutes,
      routeColor: routeColor,
      segments: segments,
    );
  }

  /// Whether [step] is on a vehicle (board or transfer). Only then do the
  /// stop alarm and the "get ready" notification mean anything.
  static bool isRide(Object? step) => step is Map && (step['action'] == 'board' || step['action'] == 'transfer');

  /// A segment's points: its encoded polyline, else its point list.
  static List<LatLng> pointsOfSegment(dynamic segment) {
    if (segment is! Map) return <LatLng>[];
    final encoded = segment['points_encoded'];
    if (encoded is String && encoded.isNotEmpty) {
      final decoded = PolylineUtils.decode(encoded);
      return decoded.map((p) => LatLng(p['lat']!, p['lon']!)).toList();
    }
    return pointsOf(segment['points']);
  }

  static List<LatLng> pointsOf(dynamic raw) {
    if (raw is! List) return <LatLng>[];
    final out = <LatLng>[];
    for (final p in raw) {
      final ll = latLngOf(p);
      if (ll != null) out.add(ll);
    }
    return out;
  }

  /// `{lat, lon}` as a position, or null if either is missing or out of range.
  static LatLng? latLngOf(dynamic p) {
    if (p is! Map) return null;
    final lat = p['lat'], lon = p['lon'];
    if (lat is! num || lon is! num) return null;
    if (lat.abs() > 90 || lon.abs() > 180) return null;
    return LatLng(lat.toDouble(), lon.toDouble());
  }

  /// `#rrggbb` or `#aarrggbb`, else null.
  static Color? parseColor(dynamic raw) {
    if (raw is! String) return null;
    final hex = raw.replaceFirst('#', '');
    if (hex.length != 6 && hex.length != 8) return null;
    final v = int.tryParse(hex.length == 6 ? 'ff$hex' : hex, radix: 16);
    return v == null ? null : Color(v);
  }
}
