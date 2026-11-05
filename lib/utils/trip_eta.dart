import 'dart:math' as math;

import '../services/instruction_formatter.dart';

/// Time and distance left on a trip, from the steps themselves.
///
/// The arrival time used to be the share of the drawn line still ahead times
/// the planned trip time. A metro line covers kilometres in minutes and a
/// walk crawls, so a rider who had finished a long ride still saw most of
/// the trip's time left, and one about to walk 1 km after a short ride saw
/// almost none. Each step here runs at its own pace.
class TripEta {
  TripEta._();

  /// The engine's walking pace: 75 m a minute (1.25 m/s).
  static const double walkMetersPerMin = 75;

  static const _walks = {'walk_to_station', 'continue_walk', 'walk_to_transfer', 'walk_to_destination'};

  static double? _n(Object? v) => InstructionFormatter.asNum(v)?.toDouble();

  /// Minutes left: what is left of step [current] ([metersLeftInStep] of it),
  /// plus every later step in full. Null when the steps carry no timing.
  static double? minutesLeft(List steps, int current, double metersLeftInStep) {
    if (current < 0 || current >= steps.length) return null;
    var total = 0.0;
    var known = false;
    for (var i = current; i < steps.length; i++) {
      final s = steps[i];
      if (s is! Map) continue;
      final action = s['action'];
      final here = i == current;
      if (_walks.contains(action)) {
        final d = here ? metersLeftInStep : (_n(s['distance_m']) ?? 0);
        total += math.max(0, d) / walkMetersPerMin;
        known = true;
      } else if (action == 'board' || action == 'transfer') {
        final rideMin = _n(s['ride_min']);
        final rideM = _n(s['ride_m']);
        if (rideMin == null) continue;
        known = true;
        if (here && rideM != null && rideM > 0) {
          // On board: the ride left at this vehicle's average pace.
          total += math.min(rideM, math.max(0, metersLeftInStep)) / rideM * rideMin;
        } else {
          total += (here ? 0 : (_n(s['wait_min']) ?? 0)) + rideMin;
        }
      }
    }
    return known ? total : null;
  }

  /// "440 m" / "2.3 km" ("2.3 كم" in Arabic).
  static String distanceLabel(double meters, {required bool isArabic}) {
    // Rounded first: 996 m is "1.0 km", not "1000 m".
    final m = (meters / 10).round() * 10;
    if (m >= 1000) return '${(meters / 1000).toStringAsFixed(1)} ${isArabic ? 'كم' : 'km'}';
    return '$m ${isArabic ? 'م' : 'm'}';
  }
}
