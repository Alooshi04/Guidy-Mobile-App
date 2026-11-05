import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A small cache for the backend's *reference* data: the lines list, one
/// line's stops, the metro station list.
///
/// WHY
/// That data comes from a GTFS feed baked into the backend image. It
/// changes when the backend is redeployed -- not between two requests a
/// minute apart. Yet every open of the Lines browser and every open of
/// the Metro tab re-fetched it in full, and every tap into a line
/// re-fetched that line's stops even if you had just backed out of it.
///
/// Two wins for one change: the requests disappear, and those screens
/// start working with no signal at all -- which on the Cairo metro is
/// most of the journey, and is exactly when a rider wants to check which
/// stop is next.
///
/// WHAT IS DELIBERATELY NOT CACHED
/// /api/route and /api/metro/plan. Those depend on the time of day and on
/// live vehicle positions reported by other riders. A cached trip plan is
/// not a cheap trip plan, it is a wrong one.
class ReferenceCache {
  ReferenceCache._();

  static const String _prefix = 'guidy_refcache_v3_';

  /// How long a cached copy is served without asking the server. A day is
  /// chosen against how often the feed actually changes (on deploy), not
  /// against how fresh it could theoretically be.
  static const Duration maxAge = Duration(hours: 24);

  /// Memory tier. Survives navigation, not app restart. Everything cached
  /// lands here; only entries written with `persist: true` also go to
  /// disk.
  static final Map<String, _Entry> _memory = {};

  /// A fresh value, or null. Checks memory first so repeated navigation
  /// inside one session never touches disk either.
  static Future<Object?> read(String key) async {
    final entry = await _load(key);
    if (entry == null) return null;
    return entry.isFresh ? entry.data : null;
  }

  /// Any value regardless of age, or null. For the offline path: a
  /// week-old stop list beats an error screen, and the rider can tell the
  /// difference between the two far better than we can.
  static Future<Object?> readStale(String key) async {
    final entry = await _load(key);
    return entry?.data;
  }

  /// [persist] false keeps an entry in memory only. Used for per-line
  /// detail, where the number of distinct keys is unbounded -- a rider
  /// browsing many lines should not slowly fill SharedPreferences, which
  /// is a small key/value store and not a database.
  static Future<void> write(String key, Object data, {bool persist = true}) async {
    final entry = _Entry(data, DateTime.now());
    _memory[key] = entry;
    if (!persist) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefix + key, jsonEncode(entry.toJson()));
    } catch (_) {
      // A cache that cannot write is still a cache that can serve from
      // memory. Never let this break the call it was meant to speed up.
    }
  }

  static Future<_Entry?> _load(String key) async {
    final hit = _memory[key];
    if (hit != null) return hit;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefix + key);
      if (raw == null) return null;
      final entry = _Entry.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      _memory[key] = entry;
      return entry;
    } catch (_) {
      return null;
    }
  }

  /// Drops everything. Exposed for a future "refresh" affordance and for
  /// tests; nothing calls it yet.
  static Future<void> clear() async {
    _memory.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final k in prefs.getKeys().where((k) => k.startsWith(_prefix))) {
        await prefs.remove(k);
      }
    } catch (_) {
      // Best-effort, exactly like the write path above.
    }
  }
}

class _Entry {
  const _Entry(this.data, this.storedAt);

  final Object data;
  final DateTime storedAt;

  bool get isFresh => DateTime.now().difference(storedAt) < ReferenceCache.maxAge;

  Map<String, dynamic> toJson() =>
      {'at': storedAt.millisecondsSinceEpoch, 'data': data};

  factory _Entry.fromJson(Map<String, dynamic> json) => _Entry(
        json['data'] as Object,
        DateTime.fromMillisecondsSinceEpoch(json['at'] as int),
      );
}
