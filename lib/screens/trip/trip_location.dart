import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_device_compass/flutter_device_compass.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/location_fallback.dart';
import '../../utils/nav_math.dart';

/// Why a trip has no position.
enum LocationProblem {
  /// Location is off, or the rider said no this time.
  off,

  /// "Don't ask again": only system settings can turn it back on.
  blocked,

  /// It worked and then stopped (underground on Line 3, a GPS error).
  lost,
}

/// The trip's sources of position and heading: the location permission,
/// the GPS stream (falling back to Android's LocationManager when the
/// Location Accuracy prompt is turned down) and the compass.
///
/// Owns every subscription it starts and cancels them in [stop] and
/// [dispose]. After [dispose] nothing starts and no callback fires, however
/// late a permission prompt is answered.
class TripLocation {
  TripLocation({
    required this.onPosition,
    required this.onLastKnown,
    required this.onHeading,
    required this.onProblem,
    this.foreground,
    this.onForegroundService,
  });

  /// The foreground-service notification for the GPS stream (Android), or
  /// null for none. Read each time the stream starts. With it, location
  /// keeps coming with the app in the background, which the step
  /// notification and the near-stop alert depend on (see TripNotification).
  final ForegroundNotificationConfig? Function()? foreground;

  /// Whether the stream is running as a foreground service.
  final void Function(bool running)? onForegroundService;

  /// Every GPS fix.
  final void Function(Position position) onPosition;

  /// The phone's cached position, once, before the first fix.
  final void Function(Position position) onLastKnown;

  /// Compass heading in degrees, where the top of the screen points.
  final void Function(double heading) onHeading;

  final void Function(LocationProblem problem) onProblem;

  StreamSubscription<Position>? _positions;
  StreamSubscription<CompassEvent>? _compass;
  bool _disposed = false;

  /// False once the trip is over (arrived, ended, timed out): the stream
  /// carries on without the service, so the screen still has a position.
  bool _keepAlive = true;
  bool _service = false;

  /// Handles every permission outcome. `deniedForever` -- what you get
  /// after "Don't ask again" -- has its own problem: only settings fix it.
  Future<void> start() async {
    try {
      // Every await below can outlast the trip (the rider backs out while
      // the permission prompt is up): stop there, or a GPS stream starts
      // with nothing left to cancel it.
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (_disposed) return;
      if (!serviceOn) {
        onProblem(LocationProblem.off);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (_disposed) return;
      if (permission == LocationPermission.deniedForever) {
        onProblem(LocationProblem.blocked);
        return;
      }
      if (permission == LocationPermission.denied) {
        onProblem(LocationProblem.off);
        return;
      }

      // 1. Fast path: the cached position, with zero latency.
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null && !_disposed) onLastKnown(last);
      } catch (_) {}

      // 2. The stream. It has no distance filter, so its first fix comes as
      // soon as there is one; a separate one-off poll alongside it only
      // meant a second Location Accuracy prompt.
      _listen();
    } catch (e) {
      debugPrint("Could not start location tracking: $e");
      if (!_disposed) onProblem(LocationProblem.lost);
    }
  }

  void _listen() {
    // After dispose, a new stream would never be cancelled.
    if (_disposed) return;
    _positions?.cancel();
    final config = _keepAlive && defaultTargetPlatform == TargetPlatform.android ? foreground?.call() : null;
    _setService(config != null);
    _positions = Geolocator.getPositionStream(
      locationSettings: NavMath.navLocationSettings(defaultTargetPlatform, foreground: config),
    ).listen(
      (Position position) {
        if (!_disposed) onPosition(position);
      },
      onError: (Object e) {
        debugPrint("Position stream error: $e");
        if (_disposed) return;
        // The service could not start (not allowed from here, a missing
        // permission): the trip still needs a position, so listen without it.
        if (_service) {
          _keepAlive = false;
          _listen();
          return;
        }
        // The Location Accuracy prompt was turned down: listen again through
        // Android's LocationManager, which doesn't ask, instead of leaving
        // the trip without a position.
        if (LocationFallback.noteError(e)) {
          _listen();
          return;
        }
        onProblem(LocationProblem.lost);
      },
      cancelOnError: false,
    );
  }

  void startCompass() {
    try {
      _compass = FlutterCompass.eventsFor(CompassUpdateOptions.fine)?.listen(
        (CompassEvent event) {
          if (_disposed) return;
          final heading = event.heading;
          if (heading != null && heading.isFinite) onHeading(heading);
        },
        onError: (Object e) {
          debugPrint("Compass stream error: $e");
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint("Could not start compass tracking: $e");
    }
  }

  void _setService(bool running) {
    if (_service == running) return;
    _service = running;
    onForegroundService?.call(running);
  }

  /// The trip is over: ends the foreground service (its notification goes
  /// with it) and keeps listening in the foreground.
  void endBackground() {
    if (!_keepAlive && !_service) return;
    _keepAlive = false;
    if (_positions != null) _listen();
  }

  /// Stops GPS and compass. They do not restart on their own.
  void stop() {
    _setService(false);
    _positions?.cancel();
    _positions = null;
    _compass?.cancel();
    _compass = null;
  }

  void dispose() {
    _disposed = true;
    stop();
  }
}
