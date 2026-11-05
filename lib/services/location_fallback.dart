import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Google's "Location Accuracy" prompt, and what to do once a rider says no.
///
/// On Android the plugin asks Google Play services for a fix. When the
/// phone's Google Location Accuracy is off, Play services shows "For a
/// better experience, your device will need to use Location Accuracy" with
/// a "No thanks" button, and asks again on the next request. Every screen
/// that wants a fix is such a request (Home on opening, the search screen,
/// the trip's stream, recenter), so a declined prompt came straight back and
/// the trip screen was unusable until the rider gave in.
///
/// After the first decline every later request goes through Android's own
/// LocationManager, which has no such prompt and still reads the GPS.
class LocationFallback {
  LocationFallback._();

  static bool _useLocationManager = false;

  /// True once the Location Accuracy prompt has been declined this session.
  static bool get usingLocationManager => _useLocationManager;

  @visibleForTesting
  static void reset() => _useLocationManager = false;

  /// Call with whatever a location request threw. Returns true when it was
  /// the prompt being declined, which switches later requests to
  /// LocationManager and means the failed request is worth retrying.
  static bool noteError(Object error) {
    if (error is! LocationServiceDisabledException) return false;
    final firstTime = !_useLocationManager;
    _useLocationManager = true;
    return firstTime;
  }

  /// Settings for a one-off fix.
  static LocationSettings fix({
    required LocationAccuracy accuracy,
    Duration? timeLimit,
    TargetPlatform? platform,
  }) {
    if ((platform ?? defaultTargetPlatform) == TargetPlatform.android && _useLocationManager) {
      return AndroidSettings(accuracy: accuracy, timeLimit: timeLimit, forceLocationManager: true);
    }
    return LocationSettings(accuracy: accuracy, timeLimit: timeLimit);
  }
}
