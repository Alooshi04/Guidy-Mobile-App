import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../services/instruction_formatter.dart';
import '../../services/walk_feedback_service.dart';

/// Where each walking step of a trip starts and ends, for "this walk is
/// wrong" and walk traces.
///
/// The drawn walks are the truth: the n-th walking step is the n-th walk
/// segment of the route, when the two lists are the same length. If they
/// are not (a malformed route), the steps' own points stand in: a walk ends
/// at the next step's point (the trip's destination for the last step) and
/// starts where the step before it ended (the trip's start for the first).
class WalkStepEnds {
  WalkStepEnds._();

  static bool isWalkStep(Object? step) => step is Map<String, dynamic> && InstructionFormatter.iconKey(step) == 'walk';

  /// The walk described for step [index], or null when it is not a walk or
  /// has no usable ends.
  static WalkStepInfo? of({
    required String tripId,
    required List instructions,
    required List<LatLng?> stepPoints,
    required List<List<LatLng>> walkSegments,
    required int index,
    LatLng? tripStart,
    LatLng? destination,
  }) {
    if (index < 0 || index >= instructions.length || !isWalkStep(instructions[index])) return null;
    final walkSteps = [for (var i = 0; i < instructions.length; i++) if (isWalkStep(instructions[i])) i];
    LatLng? start, end;
    if (walkSteps.length == walkSegments.length) {
      final seg = walkSegments[walkSteps.indexOf(index)];
      if (seg.length >= 2) {
        start = seg.first;
        end = seg.last;
      }
    }
    if (start == null || end == null) {
      end = index + 1 < stepPoints.length ? stepPoints[index + 1] : destination;
      start = index == 0 ? tripStart : (index < stepPoints.length ? stepPoints[index] : null);
      end ??= destination;
    }
    if (start == null || end == null) return null;
    final m = instructions[index] as Map<String, dynamic>;
    return WalkStepInfo(
      tripId: tripId,
      stepIndex: index,
      start: start,
      end: end,
      plannedDistanceM: InstructionFormatter.asNum(m['distance_m']) ?? 0,
    );
  }
}
