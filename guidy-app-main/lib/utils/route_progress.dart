import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'nav_math.dart';

/// Where the rider is along the drawn route, and so which step they're on.
///
/// Navigation used to move on only within 100 m of the next step's exact
/// point, and only one step at a time: a stop passed 150 m to the side, or
/// two steps passed between fixes, left the trip stuck. Here every step is
/// a distance along the route, and the rider is too.
class RouteProgress {
  RouteProgress(this.route, List<LatLng?> stepPoints) : _cum = _cumulative(route) {
    var floor = 0.0;
    for (final p in stepPoints) {
      // A step's point lies on the route: the closest point after the
      // previous step's is where it is, even where the route doubles back
      // along the same road.
      final hit = p == null ? null : _project(p, floor, firstStretch: false);
      _stepAlong.add(hit?.along);
      if (hit != null) floor = hit.along;
    }
  }

  final List<LatLng> route;
  final List<double> _cum;
  final List<double?> _stepAlong = [];

  /// How far along the rider was at the last fix that matched. Fixes are
  /// matched from here on, so a route that comes back along the same road
  /// (out and back on two sides of one street) is followed round the turn
  /// instead of the return leg being read as the way out.
  double? _lastAlong;

  /// Further than this from the line, a fix says nothing about progress.
  static const double maxOffRouteM = 60;

  /// A step counts as reached this close before its point.
  static const double passedSlackM = 25;

  /// How far behind the current step a fix may still match.
  static const double _backtrackM = 50;

  double get totalM => _cum.isEmpty ? 0 : _cum.last;

  /// How far along the route (metres) the last matched fix was; null
  /// before one has matched.
  double? get lastAlong => _lastAlong;

  static List<double> _cumulative(List<LatLng> r) {
    final out = <double>[];
    for (var i = 0; i < r.length; i++) {
      out.add(i == 0 ? 0 : out[i - 1] + NavMath.distanceM(r[i - 1], r[i]));
    }
    return out;
  }

  /// The closest point of the route at or after [minAlong] within
  /// [maxOffRouteM] of [p]. With [firstStretch], only the first stretch of
  /// route that passes that close counts: a GPS fix on the way out must not
  /// match the same road on the way back, further along.
  ({double along, double off})? _project(LatLng p, double minAlong, {bool firstStretch = true}) {
    if (route.length < 2) return null;
    const mPerDeg = 111320.0;
    final cosLat = math.cos(p.latitude * math.pi / 180);
    ({double along, double off})? best;
    for (var i = 0; i < route.length - 1; i++) {
      if (_cum[i + 1] < minAlong) continue;
      final a = route[i], b = route[i + 1];
      final ax = (a.longitude - p.longitude) * mPerDeg * cosLat, ay = (a.latitude - p.latitude) * mPerDeg;
      final dx = (b.longitude - a.longitude) * mPerDeg * cosLat, dy = (b.latitude - a.latitude) * mPerDeg;
      final len2 = dx * dx + dy * dy;
      final segLen = _cum[i + 1] - _cum[i];
      var t = len2 == 0 ? 0.0 : (-(ax * dx + ay * dy) / len2).clamp(0.0, 1.0);
      if (segLen > 0 && _cum[i] + t * segLen < minAlong) t = ((minAlong - _cum[i]) / segLen).clamp(0.0, 1.0);
      final x = ax + t * dx, y = ay + t * dy;
      final off = math.sqrt(x * x + y * y);
      if (off <= maxOffRouteM) {
        if (best == null || off < best.off) best = (along: _cum[i] + t * segLen, off: off);
      } else if (best != null && firstStretch) {
        break; // left the first matching stretch
      }
    }
    return best;
  }

  ({double along, double off})? _rider(LatLng here, int current) {
    final stepFrom = (current < _stepAlong.length ? _stepAlong[current] : null) ?? 0;
    final last = _lastAlong;
    if (last != null && last > stepFrom) {
      final hit = _project(here, math.max(0, last - _backtrackM));
      if (hit != null) return hit;
      // Nothing near from there: a bad fix may have run it ahead. Fall
      // back to the current step.
    }
    return _project(here, math.max(0, stepFrom - _backtrackM));
  }

  /// Whether [here] is within [maxOffRouteM] of the route where the rider
  /// can be on step [current]: whether the fix says anything at all.
  bool isOnRoute(LatLng here, int current) => _rider(here, current) != null;

  /// The furthest step the rider has reached; [current] if the fix is off
  /// the route. Never earlier than [current].
  int stepAt(LatLng here, int current) {
    final hit = _rider(here, current);
    if (hit == null) return current;
    _lastAlong = hit.along;
    var step = current;
    for (var k = current + 1; k < _stepAlong.length; k++) {
      final s = _stepAlong[k];
      if (s != null && s <= hit.along + passedSlackM) step = k;
    }
    return step;
  }

  /// Metres along the route from [here] to step [target] (the route's end
  /// for a target past the last step); null off the route.
  double? metersToStep(LatLng here, int current, int target) {
    final left = toStep(here, current, target);
    return left == null ? null : math.max(0, left);
  }

  /// As [metersToStep], but below zero once the rider is past the step:
  /// -30 is 30 m beyond it. Being at a point and having gone well past it
  /// are not the same thing to a step that moves on (see StepTracker).
  double? toStep(LatLng here, int current, int target) {
    final hit = _rider(here, current);
    if (hit == null) return null;
    final s = target < _stepAlong.length ? _stepAlong[target] : totalM;
    if (s == null) return null;
    return s - hit.along;
  }

  /// Metres from [here] to the first [aheadM] of the route from step
  /// [step]'s point on (never beyond the step after it): for a ride, the
  /// street it runs along. Null when the step has no point on the route.
  double? distanceToLeg(LatLng here, int step, {double aheadM = double.infinity}) {
    if (route.length < 2 || step < 0 || step >= _stepAlong.length) return null;
    final from = _stepAlong[step];
    if (from == null) return null;
    final after = step + 1 < _stepAlong.length ? _stepAlong[step + 1] : null;
    final to = math.min(after ?? totalM, from + aheadM);
    const mPerDeg = 111320.0;
    final cosLat = math.cos(here.latitude * math.pi / 180);
    double? best;
    for (var i = 0; i < route.length - 1; i++) {
      if (_cum[i + 1] < from) continue;
      if (_cum[i] > to) break;
      final a = route[i], b = route[i + 1];
      final ax = (a.longitude - here.longitude) * mPerDeg * cosLat, ay = (a.latitude - here.latitude) * mPerDeg;
      final dx = (b.longitude - a.longitude) * mPerDeg * cosLat, dy = (b.latitude - a.latitude) * mPerDeg;
      final len2 = dx * dx + dy * dy;
      final segLen = _cum[i + 1] - _cum[i];
      // Only the part of this segment inside the leg's stretch.
      final lo = segLen > 0 ? ((from - _cum[i]) / segLen).clamp(0.0, 1.0) : 0.0;
      final hi = segLen > 0 ? ((to - _cum[i]) / segLen).clamp(0.0, 1.0) : 1.0;
      final t = (len2 == 0 ? 0.0 : -(ax * dx + ay * dy) / len2).clamp(lo, hi);
      final x = ax + t * dx, y = ay + t * dy;
      final d = math.sqrt(x * x + y * y);
      if (best == null || d < best) best = d;
    }
    return best;
  }
}
