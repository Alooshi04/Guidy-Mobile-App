import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../utils/nav_math.dart';
import 'api_service.dart';

/// A ride a rider took during a long walk that Guidy didn't suggest
/// ("I took a vehicle"): its type and fare, and the path, distance and time
/// recorded while on it. Sent to the backend's review queue
/// (ride_reports.py); nothing changes routing by itself.
class RideReport {
  RideReport({required this.vehicleType, required this.fareEgp, required this.plannedStep, DateTime? now})
      : startedAt = now ?? DateTime.now(),
        id = '${(now ?? DateTime.now()).millisecondsSinceEpoch}';

  static const int maxPoints = 2000;

  /// Closer than this to the last kept fix is GPS wander, not travel.
  static const double minStepM = 10;

  final String id;
  final String vehicleType;
  final num fareEgp;
  final Map<String, dynamic> plannedStep;
  final DateTime startedAt;
  DateTime? endedAt;
  double distanceM = 0;
  final List<List<num>> _points = [];

  bool get isRecording => endedAt == null;

  void addFix(double lat, double lon, DateTime t) {
    if (!isRecording) return;
    if (_points.isNotEmpty) {
      final last = LatLng(_points.last[0].toDouble(), _points.last[1].toDouble());
      final d = NavMath.distanceM(last, LatLng(lat, lon));
      if (d < minStepM) return;
      distanceM += d;
    }
    if (_points.length < maxPoints) _points.add([lat, lon, t.millisecondsSinceEpoch / 1000]);
  }

  Duration elapsed([DateTime? now]) => (endedAt ?? now ?? DateTime.now()).difference(startedAt);

  void end([DateTime? now]) => endedAt ??= now ?? DateTime.now();

  Map<String, dynamic> toPayload() => {
        'client_report_id': id,
        'vehicle_type': vehicleType,
        'fare_egp': fareEgp,
        'started_at': startedAt.millisecondsSinceEpoch / 1000,
        'ended_at': (endedAt ?? DateTime.now()).millisecondsSinceEpoch / 1000,
        'distance_m': distanceM.round(),
        'points': _points,
        'planned_step': plannedStep,
      };
}

class RideReportService {
  RideReportService._();

  static const List<String> vehicles = ['microbus', 'tuktuk', 'bus', 'taxi', 'other'];

  /// Walks at least this long offer "I took a vehicle".
  static const double minWalkM = 1500;

  static Future<bool> send(RideReport r, {http.Client? client}) async {
    final c = client ?? http.Client();
    try {
      String? token;
      if (Firebase.apps.isNotEmpty) {
        try {
          token = await FirebaseAuth.instance.currentUser?.getIdToken();
        } catch (_) {}
      }
      final res = await c
          .post(
            Uri.parse('${ApiService.baseUrl}/ride_reports'),
            headers: {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'},
            body: jsonEncode(r.toPayload()),
          )
          .timeout(const Duration(seconds: 15));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      if (client == null) c.close();
    }
  }
}
