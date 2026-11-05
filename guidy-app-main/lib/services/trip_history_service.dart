import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'cloud_user_data.dart';
import '../utils/polyline_utils.dart';
import 'instruction_formatter.dart';
import 'location_localizer.dart';
import 'maps_link_parser.dart';

num? _asNum(dynamic val) => InstructionFormatter.asNum(val);

/// Represents a recorded commuter trip in the user's history with calculated
/// savings in money, time, and carbon emissions.
class TripHistoryEntry {
  final String id;
  final String startName;
  final String endName;
  final String? startNameAr;
  final String? startNameEn;
  final String? endNameAr;
  final String? endNameEn;
  final double? startLat;
  final double? startLon;
  final double? endLat;
  final double? endLon;
  final DateTime timestamp;
  final List<String> transitModes;
  final String? primaryMode;
  final String? routeNumber;
  final int transitFareEgp;
  final int transitDurationMin;
  final int transitDistanceMeters;
  final double rideHailFareEgp;
  final double moneySavedEgp;
  final int timeSavedMin;
  final double co2SavedKg;
  final Map<String, dynamic> pathData;
  final Map<String, dynamic>? option;
  final String chosenProfile; // 'Fastest', 'Cheapest', 'Alternative', etc.
  final bool isCompleted;

  TripHistoryEntry({
    required this.id,
    required this.startName,
    required this.endName,
    this.startNameAr,
    this.startNameEn,
    this.endNameAr,
    this.endNameEn,
    this.startLat,
    this.startLon,
    this.endLat,
    this.endLon,
    DateTime? timestamp,
    List<String>? transitModes,
    this.primaryMode,
    this.routeNumber,
    required this.transitFareEgp,
    required this.transitDurationMin,
    required this.transitDistanceMeters,
    required this.rideHailFareEgp,
    required this.moneySavedEgp,
    required this.timeSavedMin,
    required this.co2SavedKg,
    required this.pathData,
    this.option,
    String? chosenProfile,
    this.isCompleted = true,
  })  : timestamp = timestamp ?? DateTime.now(),
        transitModes = transitModes ?? const [],
        chosenProfile = chosenProfile ??
            option?['type']?.toString() ??
            pathData['type']?.toString() ??
            pathData['option']?['type']?.toString() ??
            'Recommended';

  Map<String, dynamic> toJson() => {
        'id': id,
        'start_name': startName,
        'end_name': endName,
        'start_name_ar': startNameAr,
        'start_name_en': startNameEn,
        'end_name_ar': endNameAr,
        'end_name_en': endNameEn,
        'start_lat': startLat,
        'start_lon': startLon,
        'end_lat': endLat,
        'end_lon': endLon,
        'timestamp': timestamp.toIso8601String(),
        'transit_modes': transitModes,
        'primary_mode': primaryMode,
        'route_number': routeNumber,
        'transit_fare_egp': transitFareEgp,
        'transit_duration_min': transitDurationMin,
        'transit_distance_meters': transitDistanceMeters,
        'ride_hail_fare_egp': rideHailFareEgp,
        'money_saved_egp': moneySavedEgp,
        'time_saved_min': timeSavedMin,
        'co2_saved_kg': co2SavedKg,
        // Compacted: see PolylineUtils.compactForStorage.
        'path_data': PolylineUtils.compactForStorage(pathData),
        'option': PolylineUtils.compactForStorage(option),
        'chosen_profile': chosenProfile,
        'is_completed': isCompleted,
      };

  factory TripHistoryEntry.fromJson(Map<String, dynamic> json) {
    final modes = (json['transit_modes'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final pathData = json['path_data'] is Map ? Map<String, dynamic>.from(json['path_data']) : <String, dynamic>{};
    final option = json['option'] is Map ? Map<String, dynamic>.from(json['option']) : null;
    double moneySaved = _asNum(json['money_saved_egp'])?.toDouble() ?? 0.0;
    int timeSaved = _asNum(json['time_saved_min'])?.toInt() ?? 0;
    // Trips saved by older versions carry made-up savings; when the
    // routes that were on offer are still stored, work them out again.
    if (pathData['options'] is List || pathData['compared_options'] is List) {
      final saved = TripHistoryService.computeSavings(
        duration: _asNum(json['transit_duration_min'])?.toInt() ?? 30,
        fare: _asNum(json['transit_fare_egp'])?.toInt() ?? 10,
        option: option,
        pathData: pathData,
      );
      moneySaved = saved.egp;
      timeSaved = saved.minutes;
    }
    return TripHistoryEntry(
      id: (json['id'] ?? '').toString(),
      startName: (json['start_name'] ?? '').toString(),
      endName: (json['end_name'] ?? '').toString(),
      startNameAr: json['start_name_ar']?.toString(),
      startNameEn: json['start_name_en']?.toString(),
      endNameAr: json['end_name_ar']?.toString(),
      endNameEn: json['end_name_en']?.toString(),
      startLat: _asNum(json['start_lat'])?.toDouble(),
      startLon: _asNum(json['start_lon'])?.toDouble(),
      endLat: _asNum(json['end_lat'])?.toDouble(),
      endLon: _asNum(json['end_lon'])?.toDouble(),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      transitModes: modes,
      primaryMode: json['primary_mode']?.toString(),
      routeNumber: json['route_number']?.toString(),
      transitFareEgp: _asNum(json['transit_fare_egp'])?.toInt() ?? 10,
      transitDurationMin: _asNum(json['transit_duration_min'])?.toInt() ?? 30,
      transitDistanceMeters: _asNum(json['transit_distance_meters'])?.toInt() ?? 10000,
      rideHailFareEgp: _asNum(json['ride_hail_fare_egp'])?.toDouble() ?? 80.0,
      moneySavedEgp: moneySaved,
      timeSavedMin: timeSaved,
      co2SavedKg: _asNum(json['co2_saved_kg'])?.toDouble() ?? 1.15,
      pathData: pathData,
      option: option,
      chosenProfile: json['chosen_profile']?.toString() ??
          (json['option'] is Map ? json['option']['type']?.toString() : null) ??
          'Recommended',
      isCompleted: json['is_completed'] as bool? ?? true,
    );
  }
}

/// Aggregate metrics for cumulative user transit savings.
class TripHistoryStats {
  final double totalMoneySavedEgp;
  final int totalTimeSavedMinutes;
  final double fastestTimeSavedMin;
  final double cheapestMoneySavedEgp;
  final int fastestTripsCount;
  final int cheapestTripsCount;
  final int totalTrips;
  final double totalDistanceKm;
  final double totalCo2SavedKg;

  const TripHistoryStats({
    required this.totalMoneySavedEgp,
    required this.totalTimeSavedMinutes,
    this.fastestTimeSavedMin = 0,
    this.cheapestMoneySavedEgp = 0,
    this.fastestTripsCount = 0,
    this.cheapestTripsCount = 0,
    required this.totalTrips,
    required this.totalDistanceKm,
    required this.totalCo2SavedKg,
  });

  static const empty = TripHistoryStats(
    totalMoneySavedEgp: 0,
    totalTimeSavedMinutes: 0,
    fastestTimeSavedMin: 0,
    cheapestMoneySavedEgp: 0,
    fastestTripsCount: 0,
    cheapestTripsCount: 0,
    totalTrips: 0,
    totalDistanceKm: 0,
    totalCo2SavedKg: 0,
  );
}

/// Service managing persistent storage and analytics for user trips.
class TripHistoryService {
  static const String _storageKey = 'guidy_trip_history_v1';
  static DateTime? _lastLoggedAt;
  static String? _lastLoggedRouteKey;
  static int _lastIdMs = 0;

  /// The time in milliseconds, moved on past the last id handed out: two
  /// trips recorded within one millisecond used to share an id, and with it
  /// a card key in the history list and a trip_history document.
  static String _nextId(DateTime now) {
    _lastIdMs = math.max(now.millisecondsSinceEpoch, _lastIdMs + 1);
    return _lastIdMs.toString();
  }

  /// Notifier that increments whenever history changes (new trip, delete, clear).
  /// Screens listen to this to instantly update their UI.
  static final ValueNotifier<int> changeNotifier = ValueNotifier<int>(0);

  /// Retrieves all recorded trips sorted newest first.
  // The parsed history, kept for as long as the stored text is unchanged.
  // Each trip carries its full route data, so parsing all of them is heavy,
  // and Home and Trips both read the history on every tab change.
  static String? _parsedFrom;
  static List<TripHistoryEntry> _parsed = const [];

  static Future<List<TripHistoryEntry>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      _parsedFrom = null;
      _parsed = const [];
      return [];
    }
    // A fresh list each time: callers remove from it and reorder it.
    if (raw == _parsedFrom) return List.of(_parsed);

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final list = decoded
          .whereType<Map>()
          .map((m) => TripHistoryEntry.fromJson(Map<String, dynamic>.from(m)))
          // Only trips the rider actually finished count as history.
          // Older builds recorded a trip the moment navigation started.
          .where((e) => e.isCompleted)
          .toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      _parsedFrom = raw;
      _parsed = List.unmodifiable(list);
      return list;
    } catch (e) {
      debugPrint("Error reading trip history: $e");
      return [];
    }
  }

  /// What choosing this route actually saved, compared with the other
  /// routes the rider was offered for the same trip.
  ///
  /// Minutes: against the next-slower alternative (so picking the fastest
  /// of three routes counts the gap to the second-fastest, not to the
  /// slowest). Money: against the next more expensive alternative. Nothing
  /// to compare with means nothing saved -- earlier versions invented
  /// 12 min / 8 EGP (or 15 min, 10 EGP) for those trips, clamped every
  /// figure to at least 3 min / 2 EGP, and compared against the slowest
  /// and priciest option separately, which is how a single trip could
  /// claim 49 minutes and 10 EGP at once.
  static ({int minutes, double egp}) computeSavings({
    required int duration,
    required int fare,
    Map<String, dynamic>? option,
    required Map<String, dynamic> pathData,
  }) {
    final raw = (pathData['compared_options'] as List?) ??
        (pathData['options'] as List?) ??
        (pathData['all_options'] as List?);
    if (raw == null) return (minutes: 0, egp: 0.0);
    final chosenIndex = _asNum(pathData['chosen_index'])?.toInt();
    final others = <Map>[];
    var skippedSelf = false;
    for (var i = 0; i < raw.length; i++) {
      final o = raw[i];
      if (o is! Map) continue;
      if (chosenIndex != null) {
        if (i == chosenIndex) continue;
      } else if (!skippedSelf &&
          (identical(o, option) ||
              (_asNum(o['time'])?.toInt() == duration &&
                  _asNum(o['fare_total_egp'] ?? o['fare_egp'])?.toInt() == fare &&
                  o['type']?.toString() == option?['type']?.toString()))) {
        skippedSelf = true;
        continue;
      }
      if (o['type']?.toString() == 'Walk' || o['type']?.toString() == 'Partial') continue;
      others.add(o);
    }
    int? nextSlower;
    double? nextPricier;
    for (final o in others) {
      final t = _asNum(o['time'])?.toInt();
      if (t != null && t > duration && (nextSlower == null || t < nextSlower)) nextSlower = t;
      final f = _asNum(o['fare_total_egp'] ?? o['fare_egp'])?.toDouble();
      if (f != null && f > fare && (nextPricier == null || f < nextPricier)) nextPricier = f;
    }
    return (
      minutes: nextSlower == null ? 0 : nextSlower - duration,
      egp: nextPricier == null ? 0.0 : nextPricier - fare,
    );
  }

  /// Records a new trip to history.
  /// Prevents double-logging if invoked repeatedly within 10 seconds for the same corridor.
  static Future<TripHistoryEntry?> recordTrip({
    required String startName,
    required String endName,
    double? startLat,
    double? startLon,
    double? endLat,
    double? endLon,
    required Map<String, dynamic> pathData,
    Map<String, dynamic>? option,
    String? chosenProfile,
    bool isCompleted = true,
  }) async {
    final now = DateTime.now();
    final routeKey = '$startName->$endName';

    // Duplicate debouncer: ignore if the exact same start-end was logged within 2s
    if (_lastLoggedRouteKey == routeKey &&
        _lastLoggedAt != null &&
        now.difference(_lastLoggedAt!).inSeconds < 2) {
      return null;
    }

    _lastLoggedAt = now;
    _lastLoggedRouteKey = routeKey;

    // Extract metrics from option / pathData
    final duration = _asNum(option?['time'])?.toInt() ?? 35;
    final fare = _asNum(option?['fare_total_egp'])?.toInt() ??
        _asNum(option?['fare_egp'])?.toInt() ??
        12;
    final distance = _asNum(option?['distance_m'])?.toInt() ?? 12000;

    // Extract transit modes
    final List<String> modes = [];
    final instructions = (option?['instructions'] as List?) ?? (pathData['instructions'] as List?) ?? [];
    for (final step in instructions) {
      if (step is Map && step['icon'] != null) {
        final icon = step['icon'].toString().toLowerCase();
        if (icon != 'walk' && icon != 'transfer' && icon != 'arrive' && !modes.contains(icon)) {
          modes.add(icon);
        }
      }
    }
    if (modes.isEmpty && option?['vehicle_type'] != null) {
      modes.add(option!['vehicle_type'].toString().toLowerCase());
    }
    if (modes.isEmpty) {
      modes.add('bus');
    }

    final primaryMode = option?['vehicle_type']?.toString() ?? modes.first;
    final routeNumber = option?['route_number']?.toString() ?? option?['name']?.toString();

    final resolvedProfile = chosenProfile ??
        option?['type']?.toString() ??
        pathData['type']?.toString() ??
        pathData['option']?['type']?.toString() ??
        'Recommended';

    final savings = computeSavings(
      duration: duration,
      fare: fare,
      option: option,
      pathData: pathData,
    );
    final int timeSaved = savings.minutes;
    final double moneySaved = savings.egp;

    // Calculate ride hail comparison fare: 20 EGP base + 7.5 EGP/km + 1.0 EGP/min
    final distanceKm = distance / 1000.0;
    final rideHailFare = (20.0 + (distanceKm * 7.5) + (duration * 1.0)).clamp(35.0, 500.0);
    final calculatedRideHail = (rideHailFare * 10).round() / 10.0;

    final co2Saved = ((distance / 1000.0) * 0.115 * 10).round() / 10.0;

    String effectiveStartName = startName;
    String? startNameAr;
    String? startNameEn;

    final lowerStart = startName.trim().toLowerCase();
    final isCurrentLoc = lowerStart == 'my current location' ||
        lowerStart == 'current location' ||
        startName.trim() == 'موقعي الحالي' ||
        startName.trim() == 'الموقع الحالي' ||
        LocationLocalizer.isBareNumber(startName);

    if (isCurrentLoc && startLat != null && startLon != null) {
      try {
        final resolved = await MapsLinkParser.resolveLocationBilingual(startLat, startLon);
        if (resolved['en']?.isNotEmpty == true || resolved['ar']?.isNotEmpty == true) {
          startNameAr = resolved['ar'];
          startNameEn = resolved['en'];
          effectiveStartName = (startNameEn?.isNotEmpty == true) ? startNameEn! : (startNameAr ?? startName);
        }
      } catch (e) {
        debugPrint("Error resolving start location for history: $e");
      }
    }

    if (startNameAr == null || startNameEn == null) {
      final bilingualStart = LocationLocalizer.bilingual(effectiveStartName, lat: startLat, lon: startLon);
      startNameAr ??= bilingualStart['ar'];
      startNameEn ??= bilingualStart['en'];
    }

    final bilingualEnd = LocationLocalizer.bilingual(endName, lat: endLat, lon: endLon);
    final endNameAr = bilingualEnd['ar'];
    final endNameEn = bilingualEnd['en'];

    final entry = TripHistoryEntry(
      id: _nextId(now),
      startName: effectiveStartName,
      endName: endName,
      startNameAr: startNameAr,
      startNameEn: startNameEn,
      endNameAr: endNameAr,
      endNameEn: endNameEn,
      startLat: startLat,
      startLon: startLon,
      endLat: endLat,
      endLon: endLon,
      timestamp: now,
      transitModes: modes,
      primaryMode: primaryMode,
      routeNumber: routeNumber,
      transitFareEgp: fare,
      transitDurationMin: duration,
      transitDistanceMeters: distance,
      rideHailFareEgp: calculatedRideHail,
      moneySavedEgp: moneySaved,
      timeSavedMin: timeSaved,
      co2SavedKg: co2Saved,
      pathData: pathData,
      option: option,
      chosenProfile: resolvedProfile,
      isCompleted: isCompleted,
    );

    final history = await getHistory();
    history.insert(0, entry);

    // Limit history to 100 trips to keep storage compact
    final trimmed = history.take(100).toList();
    await _persistHistory(trimmed);

    // Sync in background if authenticated
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.isAnonymous) {
        syncWithCloud(user);
      }
    } catch (_) {
      // Firebase not initialized in unit tests or offline
    }

    return entry;
  }

  /// Deletes a trip by its ID.
  static Future<bool> deleteTrip(String id) async {
    final history = await getHistory();
    final beforeCount = history.length;
    history.removeWhere((e) => e.id == id);
    if (history.length != beforeCount) {
      await _persistHistory(history);
      unawaited(CloudUserData.deleteDocs('trip_history', [id]));
      return true;
    }
    return false;
  }

  /// Marks a trip recorded at "Start navigation" as finished, when the rider
  /// actually arrives. Bumps [changeNotifier] so History, Home and the
  /// savings figures refresh the moment the trip ends -- previously nothing
  /// at all happened at arrival, so what a rider saw after finishing a trip
  /// was whatever had been computed when they started it.
  static Future<bool> markCompleted(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return false;
    try {
      final list = jsonDecode(raw);
      if (list is! List) return false;
      var found = false;
      final completedAt = DateTime.now().toIso8601String();
      for (final m in list) {
        if (m is Map && m['id'] == id) {
          m['is_completed'] = true;
          m['completed_at'] = completedAt;
          found = true;
        }
      }
      if (!found) return false;
      await prefs.setString(_storageKey, jsonEncode(list));
      changeNotifier.value++;
      unawaited(CloudUserData.merge('trip_history', id, {'is_completed': true, 'completed_at': completedAt}));
      return true;
    } catch (e) {
      debugPrint('Error marking trip $id completed: $e');
      return false;
    }
  }

  /// Clears all trip history.
  static Future<void> clearHistory() async {
    await clearLocal();
    unawaited(CloudUserData.deleteAll('trip_history'));
  }

  /// Removes the history from THIS DEVICE only (sign-out). Unlike
  /// [clearHistory] it leaves the account's cloud copy alone, so signing
  /// back in restores it.
  static Future<void> clearLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    _parsedFrom = null;
    _parsed = const [];
    changeNotifier.value++;
  }

  @visibleForTesting
  static void resetCacheForTesting() {
    _parsedFrom = null;
    _parsed = const [];
  }

  /// Calculates aggregated totals for all or filtered entries.
  static TripHistoryStats getStats(List<TripHistoryEntry> entries) {
    if (entries.isEmpty) return TripHistoryStats.empty;

    int totalTimeSaved = 0;
    double totalMoneySaved = 0;
    int fastestCount = 0;
    int cheapestCount = 0;
    double totalDistance = 0;
    double totalCo2 = 0;

    for (final e in entries) {
      totalDistance += (e.transitDistanceMeters / 1000.0);
      totalCo2 += e.co2SavedKg;

      // Both figures are real comparisons now (see computeSavings), so
      // they count whichever card the rider picked.
      if (e.timeSavedMin > 0) {
        totalTimeSaved += e.timeSavedMin;
        fastestCount++;
      }
      if (e.moneySavedEgp > 0) {
        totalMoneySaved += e.moneySavedEgp;
        cheapestCount++;
      }
    }

    return TripHistoryStats(
      totalMoneySavedEgp: (totalMoneySaved * 10).round() / 10.0,
      totalTimeSavedMinutes: totalTimeSaved,
      fastestTimeSavedMin: totalTimeSaved.toDouble(),
      cheapestMoneySavedEgp: (totalMoneySaved * 10).round() / 10.0,
      fastestTripsCount: fastestCount,
      cheapestTripsCount: cheapestCount,
      totalTrips: entries.length,
      totalDistanceKm: (totalDistance * 10).round() / 10.0,
      totalCo2SavedKg: (totalCo2 * 10).round() / 10.0,
    );
  }

  /// Cloud sync with Firestore users/{uid}/trip_history
  static Future<void> syncWithCloud(User user) async {
    if (user.isAnonymous) return;
    try {
      final firestore = FirebaseFirestore.instance;
      final coll = firestore.collection('users').doc(user.uid).collection('trip_history');

      final snapshot = await coll.limit(50).get();
      final cloudEntries = <String, TripHistoryEntry>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        cloudEntries[doc.id] = TripHistoryEntry.fromJson(data);
      }

      final localEntries = await getHistory();
      final localMap = {for (var t in localEntries) t.id: t};

      // Upload local to cloud
      final batch = firestore.batch();
      bool hasUploads = false;
      for (final local in localEntries) {
        if (!cloudEntries.containsKey(local.id)) {
          final docRef = coll.doc(local.id);
          batch.set(docRef, local.toJson(), SetOptions(merge: true));
          hasUploads = true;
        }
      }
      if (hasUploads) {
        await batch.commit();
      }

      // Merge cloud into local
      bool hasNew = false;
      for (final entry in cloudEntries.entries) {
        if (!localMap.containsKey(entry.key)) {
          localEntries.add(entry.value);
          hasNew = true;
        }
      }
      if (hasNew) {
        localEntries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        await _persistHistory(localEntries);
      }
    } catch (e) {
      debugPrint("Error syncing trip history with cloud: $e");
    }
  }

  static Future<void> _persistHistory(List<TripHistoryEntry> history) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(history.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
    changeNotifier.value++;
  }
}
