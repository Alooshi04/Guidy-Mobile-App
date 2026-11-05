import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart' show CameraPosition, LatLng;

import '../../utils/nav_math.dart';
import 'nav_camera.dart';

/// What the frame loop should do after a [TripPuck.tick].
class PuckFrame {
  const PuckFrame({this.push = false, this.stop = false});

  /// Something visibly changed: redraw the dot (and place the camera when
  /// following).
  final bool push;

  /// Arrived, facing the right way, camera settled: stop drawing frames
  /// until something changes (a fix, the compass, a re-centre).
  final bool stop;
}

/// The rider's dot and, in follow mode, the camera, frame by frame.
///
/// Each fix sets a target, and the dot moves to it in a straight line over
/// the time the fix took to arrive, so a moving rider glides at a steady
/// speed. Standing still, GPS noise inside the fix's accuracy is ignored.
/// The arrow follows the GPS course faster than a walk and the compass
/// slower, both smoothed, and a compass wobble of a few degrees doesn't
/// turn it. The camera sits on the dot every frame, so the dot stays put on
/// screen instead of sliding around under a camera that runs ahead of it,
/// and turns only for a sustained change of direction (see BearingHold).
///
/// Pure arithmetic over an injected clock; the screen owns the ticker, the
/// marker and the map.
class TripPuck {
  TripPuck({required this.zoom, required this.tilt, Duration Function()? clock, DateTime Function()? wallClock})
      : _now = clock ?? (Stopwatch()..start()).elapsedFn,
        _wallNow = wallClock ?? DateTime.now,
        _camZoom = zoom,
        _camTilt = tilt;

  /// The camera's settled zoom and tilt in follow mode.
  final double zoom;
  final double tilt;

  final Duration Function() _now;
  final DateTime Function() _wallNow;

  /// How long the last moving fix's course holds the arrow. After that the
  /// compass has it back: fixes can stop coming (the floating window, a
  /// stalled GPS) and the arrow must not freeze on an old course.
  static const Duration courseStale = Duration(seconds: 4);

  /// At most ~30 pushes to the map a second.
  static const Duration pushEvery = Duration(milliseconds: 33);

  /// How quickly the arrow follows the compass: readings are averaged over
  /// about this long, which takes out a hand's shake and a walker's sway.
  static const double compassSmoothingS = 0.35;

  /// A smoothed compass this close to where the arrow points is the same
  /// heading: the arrow stays put instead of creeping with the phone.
  static const double compassDeadband = 10;

  /// How far the camera turns towards its bearing each push (~30 a
  /// second): a 90 degree turn eases in over about a second.
  static const double cameraTurn = 0.08;

  LatLng? _fixFrom;
  LatLng? _fixTo;
  Duration _fixStart = Duration.zero;
  Duration _fixDuration = const Duration(milliseconds: 1000);
  DateTime? _lastFixAt;
  LatLng? _shownPos;
  double _shownHeading = 0;
  double _headingTarget = 0;
  bool _headingFromCourse = false;
  DateTime? _courseAt;
  double? _course;
  double? _compassHeading;
  DateTime? _compassAt;
  Duration _lastPush = Duration.zero;
  LatLng? _pushedPos;
  double _pushedHeading = -1;

  // The camera, as the frame loop last placed it.
  LatLng? _camPos;
  double _camBearing = 0;
  double _camBearingTarget = 0;
  final BearingHold _camHold = BearingHold();
  double _camZoom;
  double _camTilt;

  /// Where the dot is drawn now, and which way its arrow points.
  LatLng? get shownPos => _shownPos;
  double get shownHeading => _shownHeading;

  /// The bearing the camera turns towards (the way the rider is going),
  /// at once: the first placement of the map.
  set cameraBearingTarget(double bearing) {
    _camHold.reset(bearing);
    _camBearingTarget = _camHold.bearing!;
  }

  /// Put the dot at [p] at once (the phone's cached position).
  void showAt(LatLng p) {
    _fixTo = p;
    _fixFrom = p;
    _fixDuration = Duration.zero;
  }

  /// A new GPS fix, already snapped to the route. [routeHeading] is the
  /// heading the map should face for it (NavCamera.headingFor).
  void feed(LatLng fix, {required double speed, required double accuracy, required double course, required double routeHeading}) {
    final now = _wallNow();
    final shown = _shownPos;

    // Standing still, a phone's position wanders within its accuracy.
    // Moving the dot for that is the jitter riders see at a bus stop.
    if (shown != null && _fixTo != null) {
      if (NavMath.isStandingNoise(speed: speed, accuracy: accuracy, shown: _fixTo!, fix: fix)) {
        _updateHeadingTargets(speed: speed, course: course, routeHeading: routeHeading);
        return;
      }
    }

    final gap = _lastFixAt == null ? const Duration(milliseconds: 800) : now.difference(_lastFixAt!);
    _lastFixAt = now;
    _fixFrom = shown ?? fix;
    _fixTo = fix;
    _fixStart = _now();
    // Cover the distance in about the time the next fix will take to come,
    // so the dot arrives as the next one does: steady speed, no stop-go.
    final ms = gap.inMilliseconds.clamp(300, 1500);
    _fixDuration = Duration(milliseconds: shown == null ? 0 : ms);
    // A jump (tunnel, first fix after a gap) is not travel: go straight there.
    if (shown != null && NavCamera.distance(shown, fix) > 150) _fixDuration = Duration.zero;
    _updateHeadingTargets(speed: speed, course: course, routeHeading: routeHeading);
  }

  void _updateHeadingTargets({required double speed, required double course, required double routeHeading}) {
    final moving = speed >= NavMath.courseSpeed && course >= 0 && course < 360;
    final wasCourse = _headingFromCourse;
    if (moving) {
      _courseAt = _wallNow();
      // Half of each new course: a bus's is good to a few degrees, a
      // jogger's to a dozen or so.
      final c = _course;
      _course = c == null || !wasCourse ? course : NavMath.lerpHeading(c, course, 0.5);
    }
    // The map turns with the way the rider is going (or the route when they
    // walk or stand), never with the compass -- a map that spins as the
    // phone wobbles is unreadable -- and only for a sustained turn.
    _camBearingTarget = _camHold.update(routeHeading);
    final compass = _compassHeading;
    _headingFromCourse = moving || compass == null;
    // Without a compass, the way the map faces, which is steady.
    final aim = NavMath.arrowHeading(
      speed: speed,
      course: moving ? _course! : -1,
      compass: compass,
      fallback: _camBearingTarget,
    );
    if (!moving && compass != null && !wasCourse) {
      _aimAtCompass(aim);
    } else {
      _headingTarget = aim; // handed over between course and compass: all the way
    }
  }

  void _aimAtCompass(double compass) {
    if (NavMath.angularDistance(compass, _headingTarget) >= compassDeadband) _headingTarget = compass;
  }

  /// A compass reading (where the top of the screen points). True when the
  /// arrow should turn, so the frame loop must run.
  bool onCompass(double heading) {
    final h = (heading % 360 + 360) % 360;
    final now = _wallNow();
    final prev = _compassHeading, prevAt = _compassAt;
    _compassAt = now;
    if (prev == null || prevAt == null) {
      _compassHeading = h;
    } else {
      // Averaged over time, not per reading: the compass's rate varies by
      // phone.
      final dt = (now.difference(prevAt).inMicroseconds / 1e6).clamp(0.016, 1.0);
      _compassHeading = NavMath.lerpHeading(prev, h, 1 - math.exp(-dt / compassSmoothingS));
    }
    final compass = _compassHeading!;
    if (_headingFromCourse) {
      final at = _courseAt;
      if (at != null && now.difference(at) < courseStale) return false;
      _headingFromCourse = false;
      _headingTarget = compass;
    } else {
      _aimAtCompass(compass);
    }
    return NavMath.angularDistance(_headingTarget, _shownHeading) >= 0.4;
  }

  /// One frame: move the dot along its leg and ease the arrow. [follow]:
  /// the camera tracks the dot; [hasMap]: there is a map to move.
  PuckFrame tick({required bool follow, required bool hasMap}) {
    final now = _now();
    if (_fixTo == null) return const PuckFrame();
    final from = _fixFrom ?? _fixTo!;
    final ms = _fixDuration.inMilliseconds;
    final t = ms <= 0 ? 1.0 : ((now - _fixStart).inMilliseconds / ms).clamp(0.0, 1.0);
    _shownPos = _lerp(from, _fixTo!, t);
    _shownHeading = NavMath.lerpHeading(_shownHeading, _headingTarget, 0.18);

    if (now - _lastPush < pushEvery) return const PuckFrame();
    final movedM = _pushedPos == null ? 999.0 : NavCamera.distance(_pushedPos!, _shownPos!);
    final turned = _pushedHeading < 0 ? 999.0 : NavMath.angularDistance(_pushedHeading, _shownHeading);
    final bool camBusy = follow &&
        hasMap &&
        (_camPos == null ||
            NavCamera.distance(_camPos!, _shownPos!) > 0.5 ||
            NavMath.angularDistance(_camBearing, _camBearingTarget) > 0.3 ||
            (_camZoom - zoom).abs() > 0.01 ||
            (_camTilt - tilt).abs() > 0.1);
    if (movedM < 0.05 && turned < 0.4 && !camBusy) {
      return PuckFrame(stop: t >= 1.0 && NavMath.angularDistance(_shownHeading, _headingTarget) < 0.4);
    }
    _lastPush = now;
    _pushedPos = _shownPos;
    _pushedHeading = _shownHeading;
    return const PuckFrame(push: true);
  }

  /// The next camera position in follow mode, eased towards the dot.
  /// [mapNow] is where the map is (the first placement starts from there,
  /// not from north-up). Null before there is a dot.
  CameraPosition? placeCamera(CameraPosition? mapNow) {
    final target = _shownPos;
    if (target == null) return null;
    if (_camPos == null && mapNow != null) {
      _camBearing = mapNow.bearing;
      _camZoom = mapNow.zoom;
      _camTilt = mapNow.tilt;
    }
    // Far away (just re-centred, or the first fix): glide there; otherwise
    // sit exactly on the dot so it doesn't slide around the screen.
    final cam = _camPos;
    _camPos = (cam == null || NavCamera.distance(cam, target) < 25) ? target : _lerp(cam, target, 0.2);
    _camBearing = NavMath.lerpHeading(_camBearing, _camBearingTarget, cameraTurn);
    _camZoom += (zoom - _camZoom) * 0.2;
    _camTilt += (tilt - _camTilt) * 0.2;
    return CameraPosition(target: _camPos!, zoom: _camZoom, tilt: _camTilt, bearing: _camBearing);
  }

  /// Re-centre: glide the camera back from [mapNow] to the dot, facing
  /// [bearing], starting on the next frame.
  void recenterFrom(CameraPosition? mapNow, {required double bearing}) {
    if (mapNow != null) {
      _camPos = mapNow.target;
      _camBearing = mapNow.bearing;
      _camZoom = mapNow.zoom;
      _camTilt = mapNow.tilt;
    }
    _camHold.reset(bearing);
    _camBearingTarget = _camHold.bearing!;
    _lastPush = Duration.zero;
  }

  static LatLng _lerp(LatLng a, LatLng b, double t) =>
      LatLng(a.latitude + (b.latitude - a.latitude) * t, a.longitude + (b.longitude - a.longitude) * t);
}

extension on Stopwatch {
  Duration Function() get elapsedFn => () => elapsed;
}

/// A light filter on GPS fixes for the rider's dot (the trip's steps read
/// the raw fix). Each fix is weighed by its accuracy against how far the
/// rider can have gone since the last one, so a phone's position wandering
/// a few metres back and forth at a walk becomes a steady line, while a bus
/// is followed without lag: on the move faster than a walk, the rider is
/// first carried on along their course.
///
/// Pure; times come from the fixes.
class FixSmoother {
  LatLng? _at;
  double _variance = 0; // m^2
  DateTime? _time;

  /// A fix is never trusted to better than this (an emulator says 0).
  static const double minAccuracyM = 3;

  /// How fast the rider may have moved without the fix saying so (m/s): a
  /// brisk walk. Faster, the fix's own speed.
  static const double minSpeedNoise = 3;

  /// A jump this far, or a gap this long, starts afresh: a tunnel, the
  /// first fix after the app was away.
  static const double resetM = 150;
  static const Duration resetAfter = Duration(seconds: 10);

  /// The last smoothed position.
  LatLng? get position => _at;

  LatLng add(
    LatLng fix, {
    required double accuracy,
    required double speed,
    required double course,
    required DateTime at,
  }) {
    final acc = math.max(accuracy.isFinite ? accuracy : 0.0, minAccuracyM);
    final prev = _at, t0 = _time;
    if (prev == null ||
        t0 == null ||
        at.isBefore(t0) ||
        at.difference(t0) > resetAfter ||
        NavCamera.distance(prev, fix) > resetM) {
      _at = fix;
      _variance = acc * acc;
      _time = at;
      return fix;
    }
    final dt = math.max(at.difference(t0).inMilliseconds / 1000, 0.1);
    final v = speed.isFinite ? math.max(speed, 0.0) : 0.0;
    var predicted = prev;
    if (v >= NavMath.courseSpeed && course >= 0 && course < 360) predicted = _offset(prev, course, v * dt);
    final q = math.max(v, minSpeedNoise) * dt;
    final variance = _variance + q * q;
    final k = variance / (variance + acc * acc);
    _at = LatLng(
      predicted.latitude + (fix.latitude - predicted.latitude) * k,
      predicted.longitude + (fix.longitude - predicted.longitude) * k,
    );
    _variance = (1 - k) * variance;
    _time = at;
    return _at!;
  }

  static LatLng _offset(LatLng p, double bearing, double metres) {
    final b = bearing * math.pi / 180;
    final dLat = metres * math.cos(b) / 111320;
    final dLon = metres * math.sin(b) / (111320 * math.cos(p.latitude * math.pi / 180));
    return LatLng(p.latitude + dLat, p.longitude + dLon);
  }
}
