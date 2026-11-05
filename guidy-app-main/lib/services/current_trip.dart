import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A trip the rider has started and not finished: what Home shows as the
/// "current trip" card, and what is reopened on tap or after a restart.
///
/// This is not a second trip model. It keeps the same inputs MapScreen takes
/// (the route's `pathData`, the alternatives, the names) plus the step the
/// rider had reached, and hands them straight back to a new MapScreen.
class CurrentTripData {
  CurrentTripData({
    required this.pathData,
    required this.alternatives,
    this.startName,
    this.endName,
    this.historyEntryId,
    this.recordHistoryOnArrival = false,
    this.step = 0,
    required this.startedAt,
    required this.lastActiveAt,
  });

  final Map<String, dynamic> pathData;
  final List<Map<String, dynamic>> alternatives;
  final String? startName;
  final String? endName;
  final String? historyEntryId;
  final bool recordHistoryOnArrival;
  int step;
  final DateTime startedAt;
  DateTime lastActiveAt;

  /// The plan's own estimate, in minutes (30 when it gives none).
  int get expectedMinutes {
    final opt = pathData['option'];
    final t = (opt is Map ? opt['time'] : null) ?? pathData['duration_minutes'];
    final n = t is num ? t : num.tryParse('$t');
    return n == null || n <= 0 ? 30 : n.round();
  }

  Map<String, dynamic> toJson() => {
        'path': pathData,
        'alts': alternatives,
        'start_name': startName,
        'end_name': endName,
        'history_id': historyEntryId,
        'on_arrival': recordHistoryOnArrival,
        'step': step,
        'started': startedAt.millisecondsSinceEpoch,
        'active': lastActiveAt.millisecondsSinceEpoch,
      };

  static CurrentTripData? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final path = raw['path'];
    final started = raw['started'];
    final active = raw['active'];
    if (path is! Map || started is! int || active is! int) return null;
    final alts = raw['alts'];
    return CurrentTripData(
      pathData: Map<String, dynamic>.from(path),
      alternatives: [
        if (alts is List)
          for (final a in alts)
            if (a is Map) Map<String, dynamic>.from(a),
      ],
      startName: raw['start_name'] as String?,
      endName: raw['end_name'] as String?,
      historyEntryId: raw['history_id'] as String?,
      recordHistoryOnArrival: raw['on_arrival'] == true,
      step: raw['step'] is int ? raw['step'] as int : 0,
      startedAt: DateTime.fromMillisecondsSinceEpoch(started),
      lastActiveAt: DateTime.fromMillisecondsSinceEpoch(active),
    );
  }
}

/// The one trip in progress, kept in memory and in SharedPreferences.
///
/// Set when a trip screen opens, moved on with each step, and cleared on
/// arrival, on End trip, on sign-out, and when it goes stale ([isStale]).
/// Leaving the trip screen any other way (back, another tab, closing the
/// app) keeps it. Only ever one: [begin] replaces whatever was there.
class CurrentTrip {
  CurrentTrip._();

  static const String _key = 'current_trip_v1';

  /// Slack on top of the plan's own duration before a trip is given up on:
  /// buses run late, riders stop for tea.
  static const Duration grace = Duration(hours: 2);

  /// A trip with no sign of life for this long is over, whatever the plan
  /// says. The shorter of the two limits wins, so a 20 minute walk is gone
  /// after 2h20 and nothing outlives 6 hours of silence.
  static const Duration maxIdle = Duration(hours: 6);

  /// The clock, replaceable in tests.
  static DateTime Function() now = DateTime.now;

  /// The trip to show, or null. Home listens to this.
  static final ValueNotifier<CurrentTripData?> active = ValueNotifier(null);

  static bool _loaded = false;

  /// Whether [t] has run out: past start + expected duration + [grace], or
  /// idle for more than [maxIdle].
  static bool isStale(CurrentTripData t, [DateTime? at]) {
    final n = at ?? now();
    final due = t.startedAt.add(Duration(minutes: t.expectedMinutes)).add(grace);
    return n.isAfter(due) || n.difference(t.lastActiveAt) > maxIdle;
  }

  /// Reads the saved trip once per launch (later calls only re-check it for
  /// staleness). Safe to call from any screen.
  static Future<void> ensureLoaded() async {
    if (!_loaded) {
      _loaded = true;
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_key);
        // A trip begun while this was reading wins.
        if (raw != null && active.value == null) {
          final t = CurrentTripData.fromJson(jsonDecode(raw));
          if (t != null) active.value = t;
        }
      } catch (_) {
        // Unreadable: treated as no trip.
        await _wipe();
      }
    }
    expireIfStale();
  }

  /// Clears the trip if it has run out. Call when Home comes back to view.
  static void expireIfStale() {
    final t = active.value;
    if (t != null && isStale(t)) clear();
  }

  /// A trip screen opened. [startedAt] is kept when the same trip is
  /// reopened (a resume), so it doesn't restart its clock.
  static Future<void> begin({
    required Map<String, dynamic> pathData,
    List<Map<String, dynamic>> alternatives = const [],
    String? startName,
    String? endName,
    String? historyEntryId,
    bool recordHistoryOnArrival = false,
    int step = 0,
    DateTime? startedAt,
  }) {
    final n = now();
    active.value = CurrentTripData(
      pathData: pathData,
      alternatives: alternatives,
      startName: startName,
      endName: endName,
      historyEntryId: historyEntryId,
      recordHistoryOnArrival: recordHistoryOnArrival,
      step: step,
      startedAt: startedAt ?? n,
      lastActiveAt: n,
    );
    return _save();
  }

  /// The rider reached [step] (or went back to it).
  static Future<void> setStep(int step) {
    final t = active.value;
    if (t == null) return Future.value();
    t.step = step;
    t.lastActiveAt = now();
    active.value = _copy(t);
    return _save();
  }

  /// The trip screen is still in use (called periodically while open).
  static Future<void> touch() {
    final t = active.value;
    if (t == null) return Future.value();
    t.lastActiveAt = now();
    return _save();
  }

  /// Arrived, ended, signed out, or timed out.
  static Future<void> clear() async {
    active.value = null;
    await _wipe();
  }

  /// A new object so listeners see a change (the data itself is mutable).
  static CurrentTripData _copy(CurrentTripData t) => CurrentTripData(
        pathData: t.pathData,
        alternatives: t.alternatives,
        startName: t.startName,
        endName: t.endName,
        historyEntryId: t.historyEntryId,
        recordHistoryOnArrival: t.recordHistoryOnArrival,
        step: t.step,
        startedAt: t.startedAt,
        lastActiveAt: t.lastActiveAt,
      );

  static Future<void> _save() async {
    final t = active.value;
    if (t == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(t.toJson()));
    } catch (_) {
      // Not storable: the trip still works, it just won't survive a restart.
    }
  }

  static Future<void> _wipe() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }

  @visibleForTesting
  static void debugReset() {
    _loaded = false;
    active.value = null;
    now = DateTime.now;
  }
}
