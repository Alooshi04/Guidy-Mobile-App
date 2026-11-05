import 'dart:math';

import 'api_service.dart';

/// Crowdsourced live-vehicle tracking, rider side.
///
/// Guidy has no dedicated vehicle-tracking hardware or driver-side app --
/// the only source of real-time position for "is my bus actually close"
/// is riders' own phones, reported while they're actively riding a leg
/// the app told them to board. This service is the thin client half of
/// that: it knows which transit leg (route_id/direction_id) the rider is
/// currently on, throttles and forwards GPS fixes to the backend, and
/// closes out the session when the rider stops riding that leg.
///
/// It deliberately does NOT own a location stream itself -- MapScreen
/// already runs a Geolocator position stream for the "distance to next
/// stop" feature, and this piggybacks on those same fixes via
/// [onPositionUpdate] rather than opening a second GPS subscription
/// (unnecessary battery cost, and two independent streams would just
/// report near-duplicate fixes anyway).
///
/// See raptor_engine.py's _find_equivalent_routes() and live_tracking.py
/// on the backend for what these reports power: a real-time ETA
/// attached to every route that could substitute for the one the rider
/// was routed onto, instead of the app committing to a single
/// potentially-wrong GTFS timetable number.
class LiveTrackingService {
  final ApiService _apiService = ApiService();

  String? _sessionId;
  String? _routeId;
  String? _directionId;
  DateTime? _lastReportAt;
  // Last position actually SENT, not the last fix received -- movement is
  // measured from what the server already knows, not from a fix we chose
  // to skip.
  double? _lastSentLat;
  double? _lastSentLon;
  final List<Map<String, double>> _recordedTrackPoints = [];

  // Geolocator's stream (distanceFilter: 2 in MapScreen) can fire every
  // couple of meters, far more often than is useful or considerate to
  // report to the backend -- 8s comfortably keeps up with a moving bus
  // for ETA purposes without hammering the server on every fix.
  static const Duration _minReportInterval = Duration(seconds: 8);

  // A vehicle that has not moved has nothing new to tell the server, and
  // in Cairo traffic that is a large share of any trip: a bus at a light,
  // in a jam, or waiting at a terminus still produced a request every 8
  // seconds. Below this distance a fix is treated as the same position.
  //
  // 10m is deliberately conservative rather than aggressive. At 8s
  // intervals it only suppresses vehicles under ~4.5 km/h -- genuinely
  // stopped ones. A bus merely crawling at 5 km/h covers 11m per interval
  // and still reports at full rate, so the ETA a rider sees while traffic
  // is bad, which is exactly when they care most, is unchanged.
  static const double _movedEnoughMetres = 10;

  // ...but silence cannot be indefinite. The backend drops a session
  // after POSITION_TTL_SEC (90s, see live_tracking.py) without a report,
  // and a dropped session reads to the next rider as "no vehicle here" --
  // strictly worse than a slightly stale position. So a stationary
  // vehicle still reports on this heartbeat, comfortably inside that
  // window even if one report is lost.
  static const Duration _heartbeat = Duration(seconds: 30);

  bool get isTracking => _sessionId != null;

  /// Call when the rider's current step becomes a transit leg (a
  /// 'board' or 'transfer' step with a real route_id) so subsequent GPS
  /// fixes get attributed to the right route+direction. Safe to call
  /// repeatedly with the same leg -- it's a no-op unless the leg
  /// actually changed. Switching to a genuinely different leg
  /// automatically closes out whichever one was active before, since a
  /// rider can only be riding one vehicle at a time.
  void startLeg({required String routeId, required String directionId}) {
    if (_sessionId != null && _routeId == routeId && _directionId == directionId) {
      return;
    }
    endLeg();
    // Not a real vehicle id (crowdsourced phone data has no way to know
    // one) -- just a client-generated tag for "one continuous ride",
    // unique enough per leg-start to not collide with a previous ride
    // on the same route by the same phone.
    _sessionId = '${DateTime.now().millisecondsSinceEpoch}_${routeId.hashCode}';
    _routeId = routeId;
    _directionId = directionId;
    _lastReportAt = null;
    _lastSentLat = null;
    _lastSentLon = null;
    _recordedTrackPoints.clear();
  }

  /// Feed one GPS fix in. Silently ignored if the rider isn't currently
  /// on a tracked transit leg (walking, or the map isn't tracking yet),
  /// and throttled to [_minReportInterval] otherwise.
  void onPositionUpdate(double lat, double lon) {
    if (_sessionId == null || _routeId == null) return;
    _recordedTrackPoints.add({'lat': lat, 'lon': lon});

    final now = DateTime.now();
    final sinceLast = _lastReportAt == null ? null : now.difference(_lastReportAt!);

    // Rate floor: never more often than every 8s, whatever the GPS does.
    if (sinceLast != null && sinceLast < _minReportInterval) return;

    // Stationary suppression, bounded by the heartbeat above.
    if (sinceLast != null &&
        sinceLast < _heartbeat &&
        _lastSentLat != null &&
        _metresBetween(_lastSentLat!, _lastSentLon!, lat, lon) < _movedEnoughMetres) {
      return;
    }

    _lastReportAt = now;
    _lastSentLat = lat;
    _lastSentLon = lon;
    _apiService.reportLivePosition(
      sessionId: _sessionId!,
      routeId: _routeId!,
      directionId: _directionId ?? '',
      lat: lat,
      lon: lon,
    );
  }

  /// Equirectangular approximation. Over the tens of metres this is asked
  /// about it differs from the haversine by far less than a phone's own
  /// GPS error, and it avoids a trig-heavy call on every location fix.
  static double _metresBetween(double lat1, double lon1, double lat2, double lon2) {
    const double metresPerDegree = 111320;
    final dLat = (lat2 - lat1) * metresPerDegree;
    final dLon = (lon2 - lon1) * metresPerDegree * cos(lat1 * pi / 180);
    return sqrt(dLat * dLat + dLon * dLon);
  }

  /// Call when the rider stops being on a transit leg: they've walked on
  /// to a transfer/destination, arrived, or left the map screen
  /// entirely. Tells the backend to drop this session immediately
  /// rather than waiting for it to time out on its own, so a
  /// just-alighted rider's last position doesn't linger as a false
  /// "the vehicle is still here" signal for someone else's ETA.
  /// If the recorded track is valid and covers real distance, it is submitted
  /// to the backend to refine the user GTFS shape feed.
  void endLeg() {
    if (_sessionId != null && _routeId != null && _recordedTrackPoints.length >= 5) {
      double totalDist = 0;
      for (int i = 1; i < _recordedTrackPoints.length; i++) {
        totalDist += _metresBetween(
          _recordedTrackPoints[i - 1]['lat']!,
          _recordedTrackPoints[i - 1]['lon']!,
          _recordedTrackPoints[i]['lat']!,
          _recordedTrackPoints[i]['lon']!,
        );
      }
      if (totalDist >= 300) {
        _apiService.submitUserRouteTrace(
          sessionId: _sessionId!,
          routeId: _routeId!,
          directionId: _directionId ?? '',
          points: List<Map<String, double>>.from(_recordedTrackPoints),
        );
      }
    }

    if (_sessionId != null) {
      _apiService.endLiveSession(_sessionId!);
    }
    _sessionId = null;
    _routeId = null;
    _directionId = null;
    _lastReportAt = null;
    _lastSentLat = null;
    _lastSentLon = null;
    _recordedTrackPoints.clear();
  }
}
