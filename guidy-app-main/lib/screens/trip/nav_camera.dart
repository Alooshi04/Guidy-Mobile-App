import 'dart:math' as math;

import 'package:flutter/painting.dart' show EdgeInsets;
import 'package:geolocator/geolocator.dart' show Geolocator;
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng, LatLngBounds;

import '../../utils/nav_math.dart';

/// The trip camera's arithmetic: which way to point the map, and how to
/// frame it. Pure; the screen's frame loop does the moving.
abstract final class NavCamera {
  /// Where the rider's dot sits within the visible band of map, measured
  /// from the top. 0.5 would centre them; 0.72 leaves roughly two-thirds of
  /// the view for what's coming.
  static const double puckFraction = 0.72;

  /// Below this speed the reported course is noise. GPS derives heading
  /// from successive fixes, so a rider standing at a bus stop produces a
  /// heading that spins, and at a walk (1.2-1.4 m/s) it swings by tens of
  /// degrees from one fix to the next and points backwards whenever a fix
  /// lands behind the last one. It was 0.7 m/s: the map turned with every
  /// swing while walking, and the arrow (on the compass) looked as if it
  /// flipped up and down under it.
  static const double minSpeedForHeading = NavMath.courseSpeed;

  /// How far ahead along the route its direction is read: closer points
  /// turn with every kink in the drawn line.
  static const double lookAheadM = 20;

  /// Forward bearing in degrees (0..360) from [start] to [end].
  static double bearing(LatLng start, LatLng end) {
    final b = Geolocator.bearingBetween(start.latitude, start.longitude, end.latitude, end.longitude);
    return (b + 360) % 360;
  }

  /// Metres between two points.
  static double distance(LatLng p1, LatLng p2) =>
      Geolocator.distanceBetween(p1.latitude, p1.longitude, p2.latitude, p2.longitude);

  /// The way the route goes from [here]: from the closest point of the
  /// route to the point [lookAheadM] further along it. [nearAlong] (metres
  /// along, when known) keeps the match to the stretch the rider is on, not
  /// a later leg that passes close by. [fallback] when the route is too
  /// short to say.
  ///
  /// It used to aim at the first route VERTEX 15 m from the rider, starting
  /// from the nearest vertex. On a long straight road the nearest vertex is
  /// behind the rider for half of every segment, so the map pointed back
  /// the way they came, then forward again a few steps on.
  static double forwardRouteBearing(List<LatLng> route, LatLng here, {required double fallback, double? nearAlong}) {
    if (route.length < 2) return fallback;
    const mPerDeg = 111320.0;
    final cosLat = math.cos(here.latitude * math.pi / 180);
    final cum = <double>[0];
    for (var i = 1; i < route.length; i++) {
      cum.add(cum.last + distance(route[i - 1], route[i]));
    }
    var bestAlong = 0.0;
    var bestD = double.infinity;
    for (var i = 0; i < route.length - 1; i++) {
      if (nearAlong != null &&
          (cum[i + 1] < nearAlong - NavMath.snapBehindM || cum[i] > nearAlong + NavMath.snapAheadM)) {
        continue;
      }
      final a = route[i], b = route[i + 1];
      final ax = (a.longitude - here.longitude) * mPerDeg * cosLat, ay = (a.latitude - here.latitude) * mPerDeg;
      final dx = (b.longitude - a.longitude) * mPerDeg * cosLat, dy = (b.latitude - a.latitude) * mPerDeg;
      final len2 = dx * dx + dy * dy;
      final t = len2 == 0 ? 0.0 : (-(ax * dx + ay * dy) / len2).clamp(0.0, 1.0);
      final x = ax + t * dx, y = ay + t * dy;
      final d = x * x + y * y;
      if (d < bestD) {
        bestD = d;
        bestAlong = cum[i] + t * (cum[i + 1] - cum[i]);
      }
    }
    if (bestD == double.infinity) return forwardRouteBearing(route, here, fallback: fallback);
    final from = _pointAlong(route, cum, bestAlong);
    final ahead = _pointAlong(route, cum, bestAlong + lookAheadM);
    // At the very end: the last stretch's direction.
    if (distance(from, ahead) < 1) return bearing(route[route.length - 2], route.last);
    return bearing(from, ahead);
  }

  static LatLng _pointAlong(List<LatLng> route, List<double> cum, double along) {
    if (along <= 0) return route.first;
    for (var i = 0; i < route.length - 1; i++) {
      if (cum[i + 1] < along) continue;
      final len = cum[i + 1] - cum[i];
      final t = len <= 0 ? 0.0 : (along - cum[i]) / len;
      final a = route[i], b = route[i + 1];
      return LatLng(a.latitude + (b.latitude - a.latitude) * t, a.longitude + (b.longitude - a.longitude) * t);
    }
    return route.last;
  }

  /// The heading to point the map at for a fix: the GPS course while
  /// moving faster than a walk, else the way the route goes from there.
  /// [here] is the dot (smoothed and on the route), not the raw fix.
  static double headingFor({
    required double speed,
    required double course,
    required LatLng here,
    required List<LatLng> route,
    required double last,
    double? nearAlong,
  }) {
    if (speed >= minSpeedForHeading && course >= 0 && course < 360) return course;
    return forwardRouteBearing(route, here, fallback: last, nearAlong: nearAlong);
  }

  /// The smallest box around [points] (at least one).
  static LatLngBounds boundsOf(List<LatLng> points) {
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));
  }

  /// Map padding for a screen [height] whose sheet covers [sheetFraction]
  /// of it. In follow mode the extra top inset is what pushes the rider's
  /// dot down to [puckFraction] of the visible band -- the map centres the
  /// camera target inside the padded box, so padding the TOP moves the
  /// target down the screen. In the floating window the rundown card
  /// covers the bottom third instead.
  static EdgeInsets padding({
    required double height,
    required double sheetFraction,
    required bool follow,
    required bool floatingWindow,
  }) {
    if (floatingWindow) return EdgeInsets.only(bottom: height * 0.34);
    final double bottom = height * sheetFraction;
    if (!follow) return EdgeInsets.only(bottom: bottom);
    final double band = height - bottom;
    // centre of padded box = top + (band - top)/2, solved for the target
    // position we want: top = 2 * (band * puckFraction) - band.
    final double top = (band * (2 * puckFraction - 1)).clamp(0.0, band * 0.6);
    return EdgeInsets.only(top: top, bottom: bottom);
  }
}

/// The map's bearing in follow mode, held steady as Google Maps holds it.
///
/// A heading from a new fix turns the map only when it is more than
/// [threshold] degrees from the bearing now, on [sustainFixes] fixes in a
/// row that agree with each other; the map then turns to their average.
/// Smaller differences never turn it, so the map doesn't creep with every
/// wobble, and one wild fix (a GPS course at a walk, a fix behind the last
/// one, a corner of the drawn route) never turns it either. Standing still
/// or walking slowly, the map stays put.
class BearingHold {
  BearingHold({this.threshold = 25, this.sustainFixes = 3});

  /// Degrees.
  final double threshold;
  final int sustainFixes;

  double? _bearing;
  final List<double> _pending = [];

  /// The bearing to show; null before the first heading.
  double? get bearing => _bearing;

  /// Point the map at [bearing] now: the first placement, a re-centre.
  void reset(double bearing) {
    _bearing = _norm(bearing);
    _pending.clear();
  }

  /// A heading from a new fix. Returns the bearing to show.
  double update(double heading) {
    final h = _norm(heading);
    final b = _bearing;
    if (b == null) return _bearing = h;
    if (NavMath.angularDistance(h, b) <= threshold) {
      _pending.clear();
      return b;
    }
    // A new direction has to be the same new direction each time.
    if (_pending.isNotEmpty && NavMath.angularDistance(h, meanHeading(_pending)) > threshold) _pending.clear();
    _pending.add(h);
    if (_pending.length >= sustainFixes) {
      _bearing = meanHeading(_pending);
      _pending.clear();
    }
    return _bearing!;
  }

  /// The average of [headings], the short way round (350 and 10 average to
  /// 0, not 180).
  static double meanHeading(List<double> headings) {
    var x = 0.0, y = 0.0;
    for (final h in headings) {
      x += math.cos(h * math.pi / 180);
      y += math.sin(h * math.pi / 180);
    }
    return _norm(math.atan2(y, x) * 180 / math.pi);
  }

  static double _norm(double h) => (h % 360 + 360) % 360;
}
