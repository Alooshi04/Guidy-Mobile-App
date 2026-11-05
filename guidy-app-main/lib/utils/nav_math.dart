import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/location_fallback.dart';

/// The decisions the navigation screen makes from GPS and the compass, as
/// plain functions so they can be tested without a map or a phone.
class NavMath {
  NavMath._();

  /// Distance in metres (haversine).
  static double distanceM(LatLng a, LatLng b) {
    const r = 6371000.0;
    final p1 = a.latitude * math.pi / 180, p2 = b.latitude * math.pi / 180;
    final dp = p2 - p1, dl = (b.longitude - a.longitude) * math.pi / 180;
    final h = math.sin(dp / 2) * math.sin(dp / 2) + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
    return 2 * r * math.asin(math.min(1.0, math.sqrt(h)));
  }

  /// [t] of the way from one heading to another, the short way round.
  /// Shortest angular distance between two bearings, in degrees. Without the
  /// wrap, 359 and 1 read as 358 degrees apart instead of 2.
  static double angularDistance(double a, double b) {
    final double d = (a - b).abs() % 360;
    return d > 180 ? 360 - d : d;
  }

  static double lerpHeading(double from, double to, double t) {
    double diff = (to - from + 180) % 360 - 180;
    if (diff < -180) diff += 360;
    return (from + diff * t + 360) % 360;
  }

  /// How close the rider must be to the destination for the trip to count
  /// as finished.
  static const double arrivalRadiusM = 60;

  /// Whether a trip is over. Reaching the last step is not enough: a
  /// walk-only trip has one step, and used to "arrive" on the first fix.
  static bool hasArrived({required bool onLastStep, LatLng? here, LatLng? destination}) {
    if (!onLastStep) return false;
    if (here == null || destination == null) return true;
    return distanceM(here, destination) <= arrivalRadiusM;
  }

  /// Whether a new fix is just a standing phone's position wandering
  /// within its accuracy (so the dot shouldn't move).
  static bool isStandingNoise({
    required double speed,
    required double accuracy,
    required LatLng shown,
    required LatLng fix,
  }) {
    if (speed >= 0.6) return false;
    return distanceM(shown, fix) < math.max(4.0, accuracy * 0.6);
  }

  /// Moving faster than this (m/s), faster than a walk, the arrow and the
  /// map follow the GPS course. Slower, the course is noise (see
  /// NavCamera.minSpeedForHeading, the same speed).
  static const double courseSpeed = 1.5;

  /// Where the rider's arrow should point: the direction of travel while
  /// moving (the phone may be in a pocket, or sideways on a bus), the
  /// compass when standing, and [fallback] (the route ahead) with neither.
  static double arrowHeading({
    required double speed,
    required double course,
    double? compass,
    required double fallback,
  }) {
    final moving = speed >= courseSpeed && course >= 0 && course < 360;
    if (moving) return course;
    if (compass != null) return compass;
    return fallback;
  }

  /// Arrival time from where the rider is: the share of the drawn route
  /// still ahead, at the trip's planned pace.
  static DateTime? estimateArrival({
    required List<LatLng> route,
    required LatLng here,
    required double plannedMinutes,
    DateTime? now,
  }) {
    if (route.length < 2 || plannedMinutes <= 0) return null;
    final cum = <double>[0];
    for (var i = 1; i < route.length; i++) {
      cum.add(cum.last + distanceM(route[i - 1], route[i]));
    }
    final total = cum.last;
    if (total <= 0) return null;
    var best = 0;
    var bestD = double.infinity;
    for (var i = 0; i < route.length; i++) {
      final d = distanceM(here, route[i]);
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    final left = ((total - cum[best]) / total * plannedMinutes).clamp(0, plannedMinutes);
    return (now ?? DateTime.now()).add(Duration(seconds: (left * 60).round()));
  }

  /// Within this of the route (or the fix's accuracy, up to [snapMaxM]),
  /// the dot is drawn on the route instead of where the fix says. Kept
  /// under the 15-30 m between a Cairo main road and its service road, so
  /// a rider on the wrong one is drawn there.
  static const double snapRadiusM = 12;
  static const double snapMaxM = 20;

  /// With a known position along the route, only the stretch from this far
  /// behind it ...
  static const double snapBehindM = 60;

  /// ... to this far ahead is considered: never a later leg that happens
  /// to pass close by (a metro line under the street being walked).
  static const double snapAheadM = 300;

  /// [fix] moved onto the closest point of [route] when it is close enough
  /// that the gap is GPS error, not the rider being elsewhere. A raw fix
  /// wanders a few metres side to side every second; on the line, the dot
  /// glides along the street instead of zig-zagging across it.
  ///
  /// [nearAlong] is how far along the route the rider last was (metres),
  /// when known.
  static LatLng snapToRoute(List<LatLng> route, LatLng fix, {required double accuracy, double? nearAlong}) {
    if (route.length < 2) return fix;
    const mPerDeg = 111320.0;
    final cosLat = math.cos(fix.latitude * math.pi / 180);
    final limit = math.max(snapRadiusM, math.min(accuracy, snapMaxM));
    LatLng? best;
    var bestD = double.infinity;
    var segStart = 0.0;
    for (var i = 0; i < route.length - 1; i++) {
      final a = route[i], b = route[i + 1];
      final segLen = distanceM(a, b);
      final segFrom = segStart;
      segStart += segLen;
      if (nearAlong != null && (segStart < nearAlong - snapBehindM || segFrom > nearAlong + snapAheadM)) continue;
      final ax = (a.longitude - fix.longitude) * mPerDeg * cosLat, ay = (a.latitude - fix.latitude) * mPerDeg;
      final dx = (b.longitude - a.longitude) * mPerDeg * cosLat, dy = (b.latitude - a.latitude) * mPerDeg;
      final len2 = dx * dx + dy * dy;
      final t = len2 == 0 ? 0.0 : (-(ax * dx + ay * dy) / len2).clamp(0.0, 1.0);
      final x = ax + t * dx, y = ay + t * dy;
      final d = math.sqrt(x * x + y * y);
      if (d < bestD) {
        bestD = d;
        best = LatLng(a.latitude + (b.latitude - a.latitude) * t, a.longitude + (b.longitude - a.longitude) * t);
      }
    }
    return best != null && bestD <= limit ? best : fix;
  }

  /// The GPS stream for navigation. On Android the plugin's own default is
  /// one fix every FIVE seconds, whatever the accuracy asked for -- the dot
  /// glided for a second and then stood still for four, and the distance
  /// left updated just as rarely.
  ///
  /// [foreground] (Android) runs the stream as a foreground service, so
  /// fixes keep coming with the app in the background (a trip in progress).
  static LocationSettings navLocationSettings(TargetPlatform platform, {ForegroundNotificationConfig? foreground}) {
    switch (platform) {
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
          intervalDuration: const Duration(seconds: 1),
          // After a declined Location Accuracy prompt: no more prompts.
          forceLocationManager: LocationFallback.usingLocationManager,
          foregroundNotificationConfig: foreground,
        );
      case TargetPlatform.iOS:
        return AppleSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
          activityType: ActivityType.otherNavigation,
          pauseLocationUpdatesAutomatically: false,
        );
      default:
        return const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 1);
    }
  }
}
