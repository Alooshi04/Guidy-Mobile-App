import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/nav_math.dart';
import 'api_service.dart';
import 'trip_sharing.dart';

/// What riders tell Guidy about walking routes, for the walking-gap review
/// (backend walk_feedback.py). Neither one changes a route by itself.
///
/// * [WalkFeedbackService.report]: "This walk is wrong" on a walking step.
///   Always available; a report is one tap and a reason.
/// * [WalkTraceRecorder]: the path the rider walked, under "Share my
///   trips" ([TripSharing]), on unless they turn it off in Settings.
///
/// Both go through [WalkOutbox]: sent at once, kept on the phone and
/// retried when there is no signal, and never able to block or break a
/// trip.
class WalkOutbox {
  WalkOutbox(this.endpoint, this.queueKey, {this.maxQueued = 20});

  final String endpoint;
  final String queueKey;
  final int maxQueued;

  /// Key in a queued entry for the account that made it. Stripped before
  /// sending: the server never sees it (as in TripRecorder).
  static const String _uidKey = '_uid';

  bool _flushing = false;

  static String? _currentUid() {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  /// Sends [payload], or queues it if that did not work. Never throws.
  Future<void> submit(Map<String, dynamic> payload, {http.Client? client}) async {
    try {
      final uid = _currentUid();
      if (!await _send(payload, uid: uid, client: client)) await _enqueue(payload, uid: uid);
      unawaited(flush(client: client));
    } catch (_) {}
  }

  /// Signed in as the account that made it ([uid]) gives the ID token;
  /// after a sign-out or account switch the entry goes unattributed.
  Future<bool> _send(Map<String, dynamic> payload, {required String? uid, http.Client? client}) async {
    final c = client ?? http.Client();
    try {
      final headers = {...ApiService.jsonHeaders};
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (uid != null && user != null && user.uid == uid) {
          final token = await user.getIdToken();
          if (token != null) headers['Authorization'] = 'Bearer $token';
        }
      } catch (_) {}
      final resp = await c
          .post(Uri.parse('${ApiService.baseUrl}/$endpoint'), headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 15));
      // A 4xx other than rate limiting will not get better by retrying.
      return resp.statusCode < 500 && resp.statusCode != 429;
    } catch (_) {
      return false;
    } finally {
      if (client == null) c.close();
    }
  }

  Future<void> _enqueue(Map<String, dynamic> payload, {required String? uid}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(queueKey) ?? <String>[];
      list.add(jsonEncode({...payload, _uidKey: uid}));
      while (list.length > maxQueued) {
        list.removeAt(0);
      }
      await prefs.setStringList(queueKey, list);
    } catch (_) {}
  }

  /// Sends what could not be sent at the time. Removes only the entries it
  /// dealt with: an entry queued while this runs must survive.
  Future<void> flush({http.Client? client}) async {
    if (_flushing) return;
    _flushing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(queueKey) ?? <String>[];
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
        final uid = p.remove(_uidKey) as String?;
        if (await _send(p, uid: uid, client: client)) done.add(raw);
      }
      final now = prefs.getStringList(queueKey) ?? <String>[];
      await prefs.setStringList(queueKey, [for (final raw in now) if (!done.contains(raw)) raw]);
    } catch (_) {
    } finally {
      _flushing = false;
    }
  }

  /// Forgets everything still waiting to be sent.
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(queueKey);
    } catch (_) {}
  }
}

/// Why a walk is wrong, as the backend knows it.
enum WalkReportReason {
  throughBuildings('through_buildings'),
  tooLong('too_long'),
  noPath('no_path'),
  other('other');

  const WalkReportReason(this.wire);
  final String wire;
}

/// One walking step, the way the app planned it.
class WalkStepInfo {
  const WalkStepInfo({
    required this.tripId,
    required this.stepIndex,
    required this.start,
    required this.end,
    this.plannedDistanceM = 0,
  });

  /// The trip log's id (TripRecorder.id): ties a report or trace to that log.
  final String tripId;
  final int stepIndex;
  final LatLng start;
  final LatLng end;
  final num plannedDistanceM;
}

class WalkFeedbackService {
  WalkFeedbackService._();

  static const String appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '');
  static const int maxNoteLength = 280;

  static final WalkOutbox reports = WalkOutbox('walk_reports', 'pending_walk_reports');
  static final WalkOutbox traces = WalkOutbox('walk_traces', 'pending_walk_traces');

  static List<double> _pt(LatLng p) => [double.parse(p.latitude.toStringAsFixed(6)), double.parse(p.longitude.toStringAsFixed(6))];

  static Map<String, dynamic> reportPayload(WalkStepInfo step, WalkReportReason reason, String note, {String? id}) => {
        'client_report_id': id ?? '${step.tripId}-${step.stepIndex}-${DateTime.now().millisecondsSinceEpoch}',
        'trip_id': step.tripId,
        'step_index': step.stepIndex,
        'reason': reason.wire,
        'note': note.trim().length > maxNoteLength ? note.trim().substring(0, maxNoteLength) : note.trim(),
        'start': _pt(step.start),
        'end': _pt(step.end),
        'distance_m': step.plannedDistanceM.round(),
        'app_version': appVersion,
      };

  /// Queues "this walk is wrong". Returns at once; the send happens in the
  /// background, and if it cannot, on a later launch or trip.
  static void report(WalkStepInfo step, WalkReportReason reason, String note) {
    unawaited(reports.submit(reportPayload(step, reason, note)));
  }

  /// Sends reports and traces that were waiting for signal.
  static Future<void> flushAll() async {
    await reports.flush();
    await traces.flush();
  }
}

/// Records the path walked on each walking step of ONE trip, when the rider
/// shares their trips ([TripSharing.enabled]), and sends each step's path when
/// that step ends.
///
/// It only reads the fixes the trip's GPS already delivers, so it asks the
/// phone for nothing extra. What it keeps:
/// * only while the current step is a walk, and only if the trip is not
///   paused (floating window, app in the background, see [pause]);
/// * a fix at most every [minIntervalS] seconds or [minMoveM] metres;
///   fixes worse than [maxAccuracyM] are dropped;
/// * minus the first and last [trimM] metres of the walk, so nothing near
///   home, work or any door is sent;
/// * simplified, at most [maxPoints] points, 5 decimals (about a metre).
/// A walk too short to have anything left after trimming sends nothing.
class WalkTraceRecorder {
  WalkTraceRecorder({
    required this.tripId,
    WalkOutbox? outbox,
    bool Function()? consent,
  })  : _outbox = outbox ?? WalkFeedbackService.traces,
        _consent = consent ?? (() => TripSharing.enabled.value);

  final String tripId;
  final WalkOutbox _outbox;
  final bool Function() _consent;

  static const double trimM = 50;
  static const double minIntervalS = 8;
  static const double minMoveM = 12;
  static const double maxAccuracyM = 40;
  static const double simplifyM = 3;
  static const int maxPoints = 300;

  int? _step;
  WalkStepInfo? _info;
  final List<List<double>> _points = []; // [lat, lon, unix seconds]
  final Set<int> _done = {};
  bool _paused = false;
  bool _closed = false;

  @visibleForTesting
  int get debugPointCount => _points.length;

  /// One GPS fix of the trip, on [step]. [walk] is the step's walk
  /// description when the step is a walk, else null (nothing is recorded).
  void onFix({
    required double lat,
    required double lon,
    required double accuracy,
    required DateTime time,
    required int step,
    required WalkStepInfo? walk,
  }) {
    if (_closed) return;
    if (_step != step) {
      _finishStep();
      _step = step;
      _info = walk;
    }
    if (walk == null || _paused || _done.contains(step) || !_consent()) return;
    if (accuracy > maxAccuracyM) return;
    final t = time.millisecondsSinceEpoch / 1000.0;
    if (_points.isNotEmpty) {
      final last = _points.last;
      final dt = t - last[2];
      final moved = NavMath.distanceM(LatLng(last[0], last[1]), LatLng(lat, lon));
      if (dt < minIntervalS && moved < minMoveM) return;
      if (moved < 3) return; // standing still
    }
    _points.add([lat, lon, t]);
    if (_points.length > 4 * maxPoints) _decimate(_points);
  }

  /// The trip left the screen (floating window, app in the background): the
  /// walk so far is sent and that step records no more.
  void pause() {
    if (_closed) return;
    _paused = true;
    if (_step != null) _done.add(_step!);
    _finishStep();
  }

  void resume() => _paused = false;

  /// The trip ended (arrived, left, switched route): nothing after this.
  void close() {
    if (_closed) return;
    _finishStep();
    _closed = true;
  }

  void _finishStep() {
    final info = _info;
    final pts = List<List<double>>.of(_points);
    _points.clear();
    _info = null;
    if (info == null || pts.length < 2) return;
    _done.add(info.stepIndex);
    final trimmed = trimEnds(pts, trimM);
    if (trimmed.length < 2) return;
    final thin = simplify(trimmed, simplifyM);
    final out = List<List<double>>.of(thin);
    while (out.length > maxPoints) {
      _decimate(out);
    }
    unawaited(_outbox.submit({
      'client_trace_id': '$tripId-${info.stepIndex}',
      'trip_id': tripId,
      'step_index': info.stepIndex,
      'planned_distance_m': info.plannedDistanceM.round(),
      'start': [info.start.latitude, info.start.longitude],
      'end': [info.end.latitude, info.end.longitude],
      'points': [
        for (final p in out) [_r5(p[0]), _r5(p[1]), p[2].roundToDouble()],
      ],
      'app_version': WalkFeedbackService.appVersion,
    }));
  }

  static double _r5(double v) => (v * 100000).round() / 100000;

  static void _decimate(List<List<double>> pts) {
    final kept = <List<double>>[];
    for (var i = 0; i < pts.length; i++) {
      if (i == 0 || i == pts.length - 1 || i.isEven) kept.add(pts[i]);
    }
    pts
      ..clear()
      ..addAll(kept);
  }

  /// [pts] ([lat, lon, ...]) without the first and last [m] metres of path.
  /// Empty when the path is shorter than 2 * [m] + 1 m.
  static List<List<double>> trimEnds(List<List<double>> pts, double m) {
    if (pts.length < 2) return const [];
    final cum = <double>[0];
    for (var i = 1; i < pts.length; i++) {
      cum.add(cum.last + NavMath.distanceM(LatLng(pts[i - 1][0], pts[i - 1][1]), LatLng(pts[i][0], pts[i][1])));
    }
    final total = cum.last;
    if (total < 2 * m + 1) return const [];
    return [for (var i = 0; i < pts.length; i++) if (cum[i] >= m && cum[i] <= total - m) pts[i]];
  }

  /// Ramer-Douglas-Peucker, tolerance [tolM] metres.
  static List<List<double>> simplify(List<List<double>> pts, double tolM) {
    if (pts.length < 3) return pts;
    final keep = List<bool>.filled(pts.length, false)
      ..[0] = true
      ..[pts.length - 1] = true;
    final stack = <(int, int)>[(0, pts.length - 1)];
    while (stack.isNotEmpty) {
      final (a, b) = stack.removeLast();
      var far = -1.0;
      var at = -1;
      for (var i = a + 1; i < b; i++) {
        final d = _distToSegmentM(pts[i], pts[a], pts[b]);
        if (d > far) {
          far = d;
          at = i;
        }
      }
      if (at != -1 && far > tolM) {
        keep[at] = true;
        stack
          ..add((a, at))
          ..add((at, b));
      }
    }
    return [for (var i = 0; i < pts.length; i++) if (keep[i]) pts[i]];
  }

  static double _distToSegmentM(List<double> p, List<double> a, List<double> b) {
    const mPerDeg = 111320.0;
    final cosLat = math.cos(p[0] * math.pi / 180);
    final ax = (a[1] - p[1]) * mPerDeg * cosLat, ay = (a[0] - p[0]) * mPerDeg;
    final dx = (b[1] - a[1]) * mPerDeg * cosLat, dy = (b[0] - a[0]) * mPerDeg;
    final l2 = dx * dx + dy * dy;
    final t = l2 == 0 ? 0.0 : (-(ax * dx + ay * dy) / l2).clamp(0.0, 1.0);
    final x = ax + t * dx, y = ay + t * dy;
    return math.sqrt(x * x + y * y);
  }
}
