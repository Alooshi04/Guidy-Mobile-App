import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// One look for route lines on every map in the app.
///
/// Rides are a solid line in the line's colour over a darker outline, so a
/// light-coloured line still reads on a light map and two crossing lines
/// stay apart. Walks are a row of round blue dots about one dot apart,
/// drawn over the rides: Google Maps' walking directions, which riders
/// already read as "walk here".
class RouteLineStyle {
  RouteLineStyle._();

  // Google's walking blue, and its lighter dark-theme blue.
  static const Color walkLight = Color(0xFF1A73E8);
  static const Color walkDark = Color(0xFF8AB4F8);

  static Color walkColor(bool dark) => dark ? walkDark : walkLight;

  /// The outline under a ride line: the same hue, darker.
  static Color casingFor(Color c) => Color.lerp(c, Colors.black, 0.35)!;

  static List<Polyline> ride(
    String id,
    List<LatLng> pts,
    Color color, {
    double width = 6,
    int zIndex = 2,
    bool consumeTapEvents = false,
    VoidCallback? onTap,
  }) =>
      [
        Polyline(
          polylineId: PolylineId('${id}_casing'),
          points: pts,
          width: (width + 4).round(),
          color: casingFor(color),
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          zIndex: zIndex,
          consumeTapEvents: consumeTapEvents,
          onTap: onTap,
        ),
        Polyline(
          polylineId: PolylineId(id),
          points: pts,
          width: width.round(),
          color: color,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          zIndex: zIndex + 1,
          consumeTapEvents: consumeTapEvents,
          onTap: onTap,
        ),
      ];

  static Polyline walk(
    String id,
    List<LatLng> pts, {
    required bool dark,
    int width = 9,
    int zIndex = 4,
    Color? color,
    bool consumeTapEvents = false,
    VoidCallback? onTap,
  }) =>
      Polyline(
        polylineId: PolylineId(id),
        points: pts,
        width: width,
        color: color ?? walkColor(dark),
        // Android draws the dot at the line width in dp but the gap in raw
        // pixels, so 3x the width is about one dot of space on the usual
        // 2.6-3.5x screens.
        patterns: [PatternItem.dot, PatternItem.gap(width * 3.0)],
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        zIndex: zIndex,
        consumeTapEvents: consumeTapEvents,
        onTap: onTap,
      );
}
