import 'package:geolocator/geolocator.dart' show Geolocator;
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;

import '../../services/transit_modes.dart';
import '../../utils/route_progress.dart';
import '../../utils/trip_eta.dart';
import 'trip_plan.dart';

/// How a step ends, which decides how close to its end counts as there.
enum StepEnd {
  /// On a vehicle, at the stop to get off or change at.
  ride,

  /// On foot to a bus, minibus or microbus. They are waved down anywhere
  /// along their street (owner rule), so reaching the street is enough.
  street,

  /// On foot to a metro or other rail station. It is entered through
  /// gates that can be most of a platform's length from the station's
  /// point, and GPS fades once inside.
  station,

  /// Any other walk: to the destination, or on from where a ride ended.
  walk;

  /// How step [step] of [instructions] ends.
  static StepEnd of(List<dynamic> instructions, int step) {
    Object? at(int i) => i >= 0 && i < instructions.length ? instructions[i] : null;
    if (TripPlan.isRide(at(step))) return ride;
    final next = at(step + 1);
    if (!TripPlan.isRide(next)) return walk;
    return TransitModes.isRail((next as Map)['vehicle_type']?.toString()) ? station : street;
  }
}

/// What one GPS fix means for a step that is not the last.
class StepCheck {
  const StepCheck({this.alarm = false, this.near = false, this.atNextPoint = false, this.advanceTo});

  /// Fire the stop alarm now (once per step): ~150 m before the next stop.
  /// Only on a ride.
  final bool alarm;

  /// Heads-up for the phone's notification (once per step): within
  /// [StepTracker.nearM] of the next stop. Earlier than [alarm], which is
  /// for the rider looking at the screen; a vehicle covers 150 m in
  /// seconds. Only on a ride.
  final bool near;

  /// At the next step's point (see [StepTracker.check]): move on to it.
  final bool atNextPoint;

  /// Past the next step's point to the side, or past several steps between
  /// fixes, on two fixes in a row: move on to this step.
  final int? advanceTo;
}

/// Decides when the rider has reached a step, from GPS fixes. Pure: the
/// trip screen does what the answer says (redraw, record, buzz).
///
/// Holds only what has to survive between fixes: whether this step's alarm
/// has fired, and the two-fix vote that stops one GPS jump skipping a step.
class StepTracker {
  bool _alarmFired = false;
  bool _nearFired = false;
  int? _candidate;
  int _votes = 0;
  LatLng? _holdAt;

  /// Whether the hold has been weighed against a fix yet (see [hold]).
  bool _holdChecked = false;

  /// Metres the rider has to move from where they asked to go back a step
  /// before GPS may move the trip on again.
  static const double holdRadiusM = 60;

  /// About half a minute of a bus ride at speed, a few minutes in traffic:
  /// far enough to gather one's things.
  static const double nearM = 400;

  /// On a ride, the stop counts as reached this close (straight line): the
  /// next card ("get off here") shows while the vehicle pulls in.
  static const double rideArrivalM = 100;

  /// How much of a ride's street counts as "the street" for a walk to it:
  /// enough to come out a block further on, not so much that a line that
  /// loops back past the walk's start would end the walk there.
  static const double streetAheadM = 300;

  /// How close to the end of a walk counts as there: the fix's accuracy,
  /// at least 25 m (GPS in a Cairo street wanders 10-20 m on a good fix)
  /// and at most 40 m. Twice that for a rail station's gates.
  static double arrivalRadius(StepEnd end, double accuracy) {
    final r = (accuracy.isFinite ? accuracy : 0.0).clamp(25.0, 40.0);
    return end == StepEnd.station ? r * 2 : r;
  }

  /// The rider went back a step by hand while standing at [at]. If they
  /// were already at the step's end there, GPS would move the trip straight
  /// on again, so auto-advance is held until they have moved on
  /// [holdRadiusM] from here. If they were still short of it (they went
  /// back before getting there), the hold is dropped and reaching the end
  /// moves the trip on as usual. Held regardless, a rider who went back
  /// 40 m out and walked on to the stop waited there on "0 m".
  void hold(LatLng? at) {
    _holdAt = at;
    _holdChecked = false;
  }

  /// [step] is the current step, not the last one. [alarmAllowed] is the
  /// rider's alarm switch, and false when the next step has no station to
  /// name. [end] is how the step ends (see [StepEnd.of]); [accuracy] the
  /// fix's, in metres.
  ///
  /// A walk is done when the metres left on it, as the trip sheet shows
  /// them (see [TripProgress.stepLeft]), are within [arrivalRadius], or
  /// for a walk to the street, when the rider is that close to the ride's
  /// street. One measure for both, so the sheet can never sit on "0 m"
  /// without the trip moving on.
  StepCheck check(
    LatLng here, {
    required int step,
    required List<LatLng?> stepPoints,
    required RouteProgress? progress,
    required bool alarmAllowed,
    StepEnd end = StepEnd.ride,
    double accuracy = 0,
  }) {
    final int next = step + 1;
    final LatLng? target = next < stepPoints.length ? stepPoints[next] : null;
    // A step without usable coordinates can't be reached by distance; the
    // route-progress check below still moves past it.
    final double distance = target == null
        ? double.infinity
        : Geolocator.distanceBetween(here.latitude, here.longitude, target.latitude, target.longitude);

    // "Get off soon" means nothing on foot: the walk to the stop was
    // buzzing and bannering about the stop the rider was walking to.
    final bool riding = end == StepEnd.ride;
    var alarm = false;
    if (riding && alarmAllowed && !_alarmFired && distance <= 150 && distance > 15) {
      _alarmFired = true;
      alarm = true;
    }

    var near = false;
    if (riding && alarmAllowed && !_nearFired && distance <= nearM && distance > 15) {
      _nearFired = true;
      near = true;
    }

    final bool arrived;
    if (riding) {
      arrived = distance < rideArrivalM;
    } else {
      final radius = arrivalRadius(end, accuracy);
      final left = TripProgress.stepLeft(here, step: step, stepPoints: stepPoints, progress: progress, signed: true);
      // Near the end, one fix is enough. Well past it (more than the
      // radius on), a fix may be a GPS jump: that is the two-fix vote's.
      final atEnd = left != null && left <= radius && left >= -radius;
      final onStreet = end == StepEnd.street &&
          (progress?.distanceToLeg(here, next, aheadM: streetAheadM) ?? double.infinity) <= radius;
      arrived = atEnd || onStreet;
    }

    final hold = _holdAt;
    if (hold != null) {
      // Weighed on the first fix after going back (see [hold]).
      final keep = _holdChecked || arrived;
      _holdChecked = true;
      final moved = Geolocator.distanceBetween(here.latitude, here.longitude, hold.latitude, hold.longitude);
      if (keep && moved <= holdRadiusM) return StepCheck(alarm: alarm, near: near);
      _holdAt = null;
    }

    if (arrived) return StepCheck(alarm: alarm, near: near, atNextPoint: true);

    // Off the route, a fix says nothing about progress: it neither counts
    // towards the vote nor breaks it. A rider hovering at the edge of GPS
    // range kept losing the vote that would have moved them on.
    if (progress != null && !progress.isOnRoute(here, step)) return StepCheck(alarm: alarm, near: near);
    final reached = progress?.stepAt(here, step) ?? step;
    if (reached > step) {
      _votes = reached == _candidate ? _votes + 1 : 1;
      _candidate = reached;
      if (_votes >= 2) return StepCheck(alarm: alarm, near: near, advanceTo: reached);
    } else {
      _candidate = null;
      _votes = 0;
    }
    return StepCheck(alarm: alarm, near: near);
  }

  /// The screen moved on to a new step: a fresh alarm and a fresh vote.
  void onAdvanced() {
    _alarmFired = false;
    _nearFired = false;
    _holdAt = null;
    _candidate = null;
    _votes = 0;
  }
}

/// What is left of a trip: minutes, metres and the clock time it ends.
typedef Remaining = ({double minutes, double meters, DateTime arrival});

/// Trip arithmetic that needs no screen.
abstract final class TripProgress {
  /// Where the trip ends: the coordinates it was planned to, or the end of
  /// the drawn route when those are missing.
  static LatLng? destinationOf(Map<String, dynamic> pathData, List<LatLng> route) {
    double? d(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
    final lat = d(pathData['end_lat']);
    final lon = d(pathData['end_lon']);
    if (lat != null && lon != null) return LatLng(lat, lon);
    return route.isNotEmpty ? route.last : null;
  }

  /// Minutes and metres left from [here], each step at its own pace (see
  /// TripEta). Off the route, the straight line to the next step stands in
  /// for what is left of this one. [plannedMinutes] is the whole trip's.
  static Remaining? remaining(
    LatLng here, {
    required List<dynamic> instructions,
    required int step,
    required List<LatLng?> stepPoints,
    required RouteProgress? progress,
    required LatLng? destination,
    required int? plannedMinutes,
    DateTime? now,
  }) {
    if (instructions.isEmpty) return null;
    final stepLeft =
        TripProgress.stepLeft(here, step: step, stepPoints: stepPoints, progress: progress, fallback: destination);
    final double? totalLeft = progress?.metersToStep(here, step, instructions.length);
    if (stepLeft == null) return null;
    final meters = totalLeft ?? (destination == null ? stepLeft : _distance(here, destination));
    final minutes = TripEta.minutesLeft(instructions, step, stepLeft) ??
        (progress != null && progress.totalM > 0 ? meters / progress.totalM * (plannedMinutes ?? 30) : null);
    if (minutes == null) return null;
    return (
      minutes: minutes,
      meters: meters,
      arrival: (now ?? DateTime.now()).add(Duration(seconds: (minutes * 60).round())),
    );
  }

  /// Metres left on step [step]: along the route to the next step's point,
  /// else (off the route, or no route) the straight line to it, or to
  /// [fallback] past the last step. Null with nothing to measure to.
  ///
  /// What the trip sheet counts down (nextStopLine) and what StepTracker
  /// moves a walk on by: one measure for both. With [signed] it goes below
  /// zero once the rider is past the point along the route.
  static double? stepLeft(
    LatLng here, {
    required int step,
    required List<LatLng?> stepPoints,
    required RouteProgress? progress,
    bool signed = false,
    LatLng? fallback,
  }) {
    final next = step + 1;
    final along = signed ? progress?.toStep(here, step, next) : progress?.metersToStep(here, step, next);
    if (along != null) return along;
    final target = next < stepPoints.length ? stepPoints[next] : fallback;
    return target == null ? null : _distance(here, target);
  }

  static double _distance(LatLng a, LatLng b) =>
      Geolocator.distanceBetween(a.latitude, a.longitude, b.latitude, b.longitude);
}
