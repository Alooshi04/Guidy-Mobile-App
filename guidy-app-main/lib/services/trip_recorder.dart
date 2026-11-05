import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'trip_sharing.dart';

/// Records every navigated trip in detail and sends it to the backend when
/// the trip ends, finished or not: the route the rider was given, when each
/// step was reached, any vehicle or route switch, and the GPS trace.
///
/// The backend (crowd_routes.py) uses these to correct lines: when enough
/// riders show a vehicle now takes a different street between two stops,
/// that becomes the line's path. Signed-in riders send their Firebase ID
/// token so each rider counts once; the uid itself is never stored there.
///
/// On unless the rider turns off "Share my trips" ([TripSharing], as the
/// Terms and the Privacy Policy say); off, nothing is kept or sent.
/// Deleting an account unlinks its logs on the server (they are kept,
/// without anything tying them to the person -- see crowd_routes.py).
class TripRecorder {
  static const String _queueKey = 'pending_trip_logs';
  static const int _maxQueued = 8;
  static const int _maxPoints = 4500;

  final String id;
  final DateTime startedAt = DateTime.now();
  final Map<String, dynamic> _start;
  final Map<String, dynamic> _end;
  final Map<String, dynamic> _option;
  final List<List<num>> _points = [];
  final List<Map<String, dynamic>> _events = [];
  bool _finished = false;
  int _lastStep = -1;

  @visibleForTesting
  int get debugPointCount => _points.length;

  TripRecorder({required Map<String, dynamic> pathData, String? startName, String? endName})
      : id = '${DateTime.now().millisecondsSinceEpoch}',
        _start = {
          'lat': pathData['start_lat'],
          'lon': pathData['start_lon'],
          'name': startName ?? pathData['start_name'],
        },
        _end = {
          'lat': pathData['end_lat'],
          'lon': pathData['end_lon'],
          'name': endName ?? pathData['end_name'],
        },
        _option = _summary(pathData);

  static Map<String, dynamic> _summary(Map<String, dynamic> pathData) {
    final opt = pathData['option'];
    final o = opt is Map ? opt : const {};
    return {
      'type': o['type'],
      'time': o['time'],
      'fare_egp': o['fare_total_egp'] ?? o['fare_egp'],
      'profile': pathData['profile'],
      'chosen_index': pathData['chosen_index'],
    };
  }

  static double _now() => DateTime.now().millisecondsSinceEpoch / 1000.0;

  /// One GPS fix. Kept every 4 s, or sooner after 20 m of movement; fixes
  /// worse than 60 m accuracy are dropped.
  void onFix(Position p, int step) {
    if (_finished || !TripSharing.enabled.value) return;
    if (p.accuracy > 60) return;
    final t = p.timestamp.millisecondsSinceEpoch / 1000.0;
    if (_points.isNotEmpty && step == _lastStep) {
      final last = _points.last;
      final dt = t - last[2];
      final moved = Geolocator.distanceBetween(last[0].toDouble(), last[1].toDouble(), p.latitude, p.longitude);
      if (dt < 4 && !(moved >= 20 && dt >= 1)) return;
    }
    _lastStep = step;
    _points.add([p.latitude, p.longitude, t, p.accuracy.roundToDouble(), step]);
    if (_points.length > _maxPoints) _thin(_points);
  }

  /// Halves the trace, keeping the first and last point of every step.
  static void _thin(List<List<num>> pts) {
    final kept = <List<num>>[];
    for (var i = 0; i < pts.length; i++) {
      final stepChange = i == 0 || i == pts.length - 1 || pts[i][4] != pts[i - 1][4] || pts[i][4] != pts[i + 1][4];
      if (stepChange || i.isEven) kept.add(pts[i]);
    }
    pts
      ..clear()
      ..addAll(kept);
  }

  void onStep(int step, Object? instruction) {
    if (_finished) return;
    final m = instruction is Map ? instruction : const {};
    _events.add({'type': 'step', 't': _now(), 'step': step, 'action': m['action'], 'route_id': m['route_id']});
  }

  void onEvent(String type, [Map<String, dynamic> extra = const {}]) {
    if (_finished) return;
    _events.add({'type': type, 't': _now(), ...extra});
  }

  static Map<String, dynamic> _step(Object? s) {
    final m = s is Map ? s : const {};
    String? boardStop;
    final opts = m['boarding_options'];
    if (opts is List) {
      for (final o in opts) {
        if (o is Map && o['is_primary'] == true && o['route_id'] == m['route_id']) {
          boardStop = o['board_stop_id']?.toString();
        }
      }
    }
    return {
      'action': m['action'],
      'route_id': m['route_id'],
      'direction_id': m['direction_id']?.toString(),
      'board_stop_id': boardStop,
      'route_number': m['route_number']?.toString(),
      'vehicle_type': m['vehicle_type'],
      'station': m['station'],
      'lat': m['lat'],
      'lon': m['lon'],
    };
  }

  /// Ends the recording and sends it. [instructions] are the steps as they
  /// stand at the end, so a vehicle swapped mid-trip is what gets sent.
  Future<void> finish({required bool completed, required String reason, required List instructions}) async {
    if (_finished) return;
    _finished = true;
    // Turned off during the trip: nothing of it is sent.
    if (!TripSharing.enabled.value) return;
    // A trip opened and closed with nothing recorded tells us nothing.
    if (_points.length < 2 && !completed) return;
    final payload = <String, dynamic>{
      'client_trip_id': id,
      'started_at': startedAt.millisecondsSinceEpoch / 1000.0,
      'ended_at': _now(),
      'completed': completed,
      'end_reason': reason,
      'app_version': const String.fromEnvironment('APP_VERSION', defaultValue: ''),
      'start': _start,
      'end': _end,
      'option': _option,
      'instructions': [for (final s in instructions.take(80)) _step(s)],
      'events': _events.take(300).toList(),
      'points': _points,
    };
    final uid = _currentUid();
    final sent = await _send(payload, uid: uid);
    if (!sent) await _enqueue(payload, uid: uid);
    unawaited(flushQueue());
  }

  /// Key in a queued trip for the account that rode it. Stripped before
  /// sending: the server never sees it.
  static const String _uidKey = '_uid';

  static String? _currentUid() {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  /// Sends with the signed-in account's ID token only when that account is
  /// the one that rode the trip ([uid]). A trip queued offline and sent
  /// after a sign-out, an account switch or an account deletion goes
  /// without one: unattributed, rather than counted for someone else.
  static Future<bool> _send(Map<String, dynamic> payload, {required String? uid}) async {
    try {
      final headers = {...ApiService.jsonHeaders};
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (uid != null && user != null && user.uid == uid) {
          final token = await user.getIdToken();
          if (token != null) headers['Authorization'] = 'Bearer $token';
        }
      } catch (_) {}
      final resp = await http
          .post(Uri.parse('${ApiService.baseUrl}/trips/log'), headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 15));
      // 4xx other than rate limiting will not get better by retrying.
      return resp.statusCode < 500 && resp.statusCode != 429;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _enqueue(Map<String, dynamic> payload, {required String? uid}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_queueKey) ?? <String>[];
      final pts = (payload['points'] as List).cast<List<num>>();
      while (pts.length > 1500) {
        _thin(pts);
      }
      list.add(jsonEncode({...payload, _uidKey: uid}));
      while (list.length > _maxQueued) {
        list.removeAt(0);
      }
      await prefs.setStringList(_queueKey, list);
    } catch (_) {}
  }

  /// On account deletion: the server keeps this account's trip logs but
  /// removes what ties them to the account (crowd_routes.py forget_rider).
  /// Must run while the account still exists: it needs its ID token.
  static Future<void> forgetMe() async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) return;
      await http.post(Uri.parse('${ApiService.baseUrl}/trips/forget_me'),
          headers: {...ApiService.clientHeaders, 'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  /// "Share my trips" turned off: trips not sent yet never will be.
  static Future<void> dropQueued() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_queueKey);
    } catch (_) {}
  }

  static bool _flushing = false;

  /// Sends trips that could not be sent at the time (no signal).
  ///
  /// Removes only the entries it dealt with. Sending can take a while (up
  /// to 15 s a trip without signal), and a trip that ends meanwhile is
  /// queued behind this loop's back: writing back a list built from the
  /// first read would erase it.
  static Future<void> flushQueue() async {
    if (_flushing || !TripSharing.enabled.value) return;
    _flushing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_queueKey) ?? <String>[];
      if (list.isEmpty) return;
      final done = <String>{};
      for (final raw in list) {
        Map<String, dynamic> p;
        try {
          p = jsonDecode(raw) as Map<String, dynamic>;
        } catch (_) {
          done.add(raw); // unreadable: drop it
          continue;
        }
        // Queued by a version that didn't record the account: send it as
        // that version would have, with whoever is signed in now.
        final uid = p.containsKey(_uidKey) ? p.remove(_uidKey) as String? : _currentUid();
        if (await _send(p, uid: uid)) done.add(raw);
      }
      // No await between reading the queue and writing it: nothing can be
      // queued in between.
      final now = prefs.getStringList(_queueKey) ?? <String>[];
      await prefs.setStringList(_queueKey, [for (final raw in now) if (!done.contains(raw)) raw]);
    } catch (_) {
    } finally {
      _flushing = false;
    }
  }
}
