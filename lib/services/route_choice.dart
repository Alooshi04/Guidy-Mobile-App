import 'instruction_formatter.dart';

/// The lines a rider picked for a route's rides: instruction index ->
/// index in that ride's `boarding_options`.
typedef LineChoices = Map<int, int>;

class RouteChoice {
  RouteChoice._();

  /// Puts each ride's planned line first in its `boarding_options` (the
  /// backend sends them by frequency), the rest keeping their order. Done
  /// once when a route arrives, so every list and every picked index agrees.
  static void plannedLineFirst(Map option) {
    final steps = option['instructions'];
    if (steps is! List) return;
    for (final s in steps) {
      if (s is! Map || s['boarding_options'] is! List) continue;
      final opts = s['boarding_options'] as List;
      final at = opts.indexWhere((o) => o is Map && o['is_primary'] == true);
      if (at > 0) opts.insert(0, opts.removeAt(at));
    }
  }

  static bool _isRide(Map s) => s['action'] == 'board' || s['action'] == 'transfer';

  /// The boarding option picked for the ride at [stepIndex] of [option], or
  /// the ride's own line when none was picked.
  static int pickedIndex(Map<String, dynamic> option, LineChoices choices, int stepIndex) {
    final steps = option['instructions'] as List? ?? const [];
    final step = stepIndex < steps.length && steps[stepIndex] is Map ? steps[stepIndex] as Map : const {};
    final opts = step['boarding_options'] as List? ?? const [];
    final pick = choices[stepIndex];
    if (pick != null && pick >= 0 && pick < opts.length) return pick;
    final own = opts.indexWhere((o) => o is Map && o['is_primary'] == true);
    return own < 0 ? 0 : own;
  }

  /// [option] with every ride switched to the line the rider picked, and
  /// the total fare moved by the difference.
  static Map<String, dynamic> apply(Map<String, dynamic> option, LineChoices choices) {
    final result = Map<String, dynamic>.from(option);
    final steps = [
      for (final i in (option['instructions'] as List? ?? const []))
        if (i is Map) Map<String, dynamic>.from(i),
    ];
    num fareDelta = 0;
    String? firstVehicleType;
    String? firstRouteNumber;
    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      if (!_isRide(step)) continue;
      final opts = step['boarding_options'] as List? ?? const [];
      final pick = choices[i];
      final chosen = pick != null && pick >= 0 && pick < opts.length && opts[pick] is Map
          ? Map<String, dynamic>.from(opts[pick] as Map)
          : null;
      if (chosen != null && chosen['is_primary'] != true) {
        final oldFare = InstructionFormatter.asNum(step['fare_egp']) ?? 0;
        final newFare = InstructionFormatter.asNum(chosen['fare_egp']) ?? oldFare;
        fareDelta += newFare - oldFare;
        // A line boarding a short walk away moves the leg to its stop, and
        // the leg says the walks (InstructionFormatter.legMovedTo).
        final moved = InstructionFormatter.legMovedTo(chosen);
        if (i > 0 && '${steps[i - 1]['action']}'.contains('walk')) InstructionFormatter.walkFollowsLeg(steps[i - 1], moved);
        steps[i] = {
          ...step,
          ...moved,
          for (final k in const ['route_variant', 'route_description']) ...{
            '${k}_en': chosen['${k}_en'],
            '${k}_ar': chosen['${k}_ar'],
          },
          'route_id': chosen['route_id'],
          'direction_id': chosen['direction_id'],
          'vehicle_type': chosen['vehicle_type'],
          'route_number': chosen['route_number'],
          'route_variant': chosen['route_variant'],
          'route_description': chosen['route_description'],
          'agency': chosen['agency'],
          'is_green_bus': chosen['is_green_bus'] ?? false,
          'fare_egp': newFare,
        };
      }
      firstVehicleType ??= steps[i]['vehicle_type']?.toString();
      firstRouteNumber ??= steps[i]['route_number']?.toString();
    }
    result['instructions'] = steps;
    if (fareDelta != 0) {
      final base = InstructionFormatter.asNum(option['fare_total_egp'] ?? option['fare_egp']) ?? 0;
      result['fare_total_egp'] = base + fareDelta;
      result['fare_egp'] = base + fareDelta;
    }
    if (firstVehicleType != null) result['vehicle_type'] = firstVehicleType;
    result['route_number'] = firstRouteNumber;
    return result;
  }
}
