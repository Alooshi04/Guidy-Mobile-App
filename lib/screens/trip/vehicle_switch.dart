import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;

import '../../services/instruction_formatter.dart';

/// What switching a step to another vehicle changed beyond the step itself.
typedef VehicleSwitchChange = ({
  num fareDelta,
  int? waitDelta,
  bool moved,
  LatLng? movedTo,
});

/// Puts the rider on [opt] (one of the step's `boarding_options`) for
/// [step], editing the step in place: the line, its names, fare and wait.
/// A line boarding a short walk away moves the leg to its stop ([moved],
/// and [movedTo] when that stop has coordinates).
///
/// Returns the fare change (EGP) and, when the option has a live ETA or a
/// headway, the wait change (minutes) for the trip's totals.
///
/// [walkBefore] is the walk step that leads to [step], if there is one: it
/// follows the leg to its new stop (its place and length).
VehicleSwitchChange applyVehicleSwitch(Map<String, dynamic> step, Map<String, dynamic> opt,
    {Map<String, dynamic>? walkBefore}) {
  final List options = step['boarding_options'] ?? [];
  for (final o in options) {
    if (o is Map) o['is_primary'] = (o['route_id'] == opt['route_id']);
  }

  final oldLegFare = InstructionFormatter.asNum(step['fare_egp']) ?? 0;
  final newLegFare = InstructionFormatter.asNum(opt['fare_egp']) ?? oldLegFare;

  // A line boarding a short walk away moves the leg to its stop, and the
  // leg says the walks (to it, and from where it lets the rider off).
  final moved = InstructionFormatter.legMovedTo(opt);
  LatLng? movedTo;
  if (moved.isNotEmpty) {
    step.addAll(moved);
    if (walkBefore != null) InstructionFormatter.walkFollowsLeg(walkBefore, moved);
    final lat = InstructionFormatter.asNum(moved['lat']), lon = InstructionFormatter.asNum(moved['lon']);
    if (lat != null && lon != null) movedTo = LatLng(lat.toDouble(), lon.toDouble());
  }
  step['fare_egp'] = newLegFare;
  step['route_number'] = opt['route_number'];
  for (final k in const ['route_variant', 'route_description']) {
    step[k] = opt[k];
    step['${k}_en'] = opt['${k}_en'];
    step['${k}_ar'] = opt['${k}_ar'];
  }
  // What to ask the new line's driver: its own alight stop's name.
  for (final k in const ['ask_driver_en', 'ask_driver_ar']) {
    if (opt[k] != null) step[k] = opt[k];
  }
  step['vehicle_type'] = opt['vehicle_type'];
  step['route_id'] = opt['route_id'];
  if (opt['direction_id'] != null) step['direction_id'] = opt['direction_id'];
  step['agency'] = opt['agency'];
  step['is_green_bus'] = opt['is_green_bus'] ?? false;

  // The wait: a live ETA, else half the typical headway.
  int? waitDelta;
  final num? newWait = opt['eta_sec'] != null
      ? InstructionFormatter.asNum(opt['eta_sec'])! / 60
      : (opt['typical_headway_min'] != null ? InstructionFormatter.asNum(opt['typical_headway_min'])! / 2 : null);
  if (newWait != null) {
    final newWaitMin = newWait.ceil();
    waitDelta = newWaitMin - (InstructionFormatter.asNum(step['wait_min'])?.toInt() ?? 0);
    step['wait_min'] = newWaitMin;
  }

  return (fareDelta: newLegFare - oldLegFare, waitDelta: waitDelta, moved: moved.isNotEmpty, movedTo: movedTo);
}
