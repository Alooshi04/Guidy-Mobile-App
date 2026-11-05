import 'package:geolocator/geolocator.dart' show Geolocator;
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;

import '../../l10n/app_localizations.dart';
import '../../services/instruction_formatter.dart';
import '../../services/step_copy.dart';
import '../../utils/nav_math.dart';
import '../../utils/route_progress.dart';

/// The live line on the trip sheet's step card, in place of the step's
/// planned distance (StepCopy.countdown): "You have arrived", a countdown
/// along the route ("Get off at Kids Land in about 4 min", "450 m left,
/// about 6 min"), else the same words from the straight-line distance to
/// the next stop. Empty: no position yet, so the planned line stands (the
/// card would otherwise say the planned distance twice). Null: nothing new
/// to say (keep the line as it is).
String? nextStopLine(
  AppLocalizations l10n, {
  required List<dynamic> instructions,
  required int step,
  required List<LatLng?> stepPoints,
  required LatLng? here,
  required LatLng? destination,
  required RouteProgress? progress,
  required bool isArabic,
}) {
  if (instructions.isEmpty) return null;
  final bool onLastStep = step >= instructions.length - 1;
  if (onLastStep && NavMath.hasArrived(onLastStep: true, here: here, destination: destination)) {
    return l10n.youHaveArrived;
  }
  if (here == null) return '';

  // A live countdown in words, along the route.
  if (progress != null) {
    final left = progress.metersToStep(here, step, step + 1);
    final live = left == null ? null : StepCopy.live(l10n, instructions, step, left);
    if (live != null) return live;
  }

  // Off the route (or none drawn): the straight line to the next stop.
  final int next = onLastStep ? step : step + 1;
  final LatLng? target = onLastStep ? destination : (next < stepPoints.length ? stepPoints[next] : null);
  if (target == null) return '';
  final dist = Geolocator.distanceBetween(here.latitude, here.longitude, target.latitude, target.longitude);

  String station = _station(next < instructions.length ? instructions[next] : null, isArabic);
  if (station.isEmpty) station = _station(instructions[step], isArabic);
  if (dist < 100) return station.isNotEmpty ? l10n.arrivingAt(station) : l10n.youHaveArrived;

  final live = StepCopy.live(l10n, instructions, step, dist);
  if (live != null) return live;
  if (station.isEmpty) return '';
  return dist > 1000
      ? l10n.distanceKmTo((dist / 1000).toStringAsFixed(1), station)
      : l10n.distanceMTo('${(dist / 10).round() * 10}', station);
}

String _station(dynamic step, bool isAr) =>
    step is Map ? (InstructionFormatter.localized(step, 'station', isAr: isAr) ?? '') : '';
