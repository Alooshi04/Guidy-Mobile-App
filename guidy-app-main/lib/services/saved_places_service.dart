import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'cloud_user_data.dart';
import 'places_coords_policy.dart';
import 'places_service.dart';
import 'instruction_formatter.dart';

class SavedPlace {
  final String id;
  final String label; // user-given name, e.g. "Gym"
  final String name;  // resolved address/place name
  final double lat;
  final double lon;

  /// Set only when this place was chosen from a Places search result.
  ///
  /// Its presence is what marks the coordinates as Google Places content,
  /// which may be kept for 30 days (see PlacesCoordsPolicy). A place the
  /// rider picked by tapping the map has no placeId, and its coordinates
  /// are the rider's own input rather than Google's data -- nothing
  /// expires those, and this class does not.
  final String? placeId;

  /// Epoch millis: when [lat]/[lon] were resolved from Places. Null for
  /// map-tap places, where it is meaningless.
  final int? coordsAt;

  SavedPlace({
    required this.id,
    required this.label,
    required this.name,
    required this.lat,
    required this.lon,
    this.placeId,
    this.coordsAt,
  });

  SavedPlace copyWith({double? lat, double? lon, int? coordsAt}) => SavedPlace(
        id: id,
        label: label,
        name: name,
        lat: lat ?? this.lat,
        lon: lon ?? this.lon,
        placeId: placeId,
        coordsAt: coordsAt ?? this.coordsAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'name': name,
        'lat': lat,
        'lon': lon,
        'placeId': placeId,
        'coordsAt': coordsAt,
      };

  factory SavedPlace.fromJson(Map<String, dynamic> json) => SavedPlace(
        id: json['id'],
        label: json['label'],
        name: json['name'],
        lat: (InstructionFormatter.asNum(json['lat']) ?? 0.0).toDouble(),
        lon: (InstructionFormatter.asNum(json['lon']) ?? 0.0).toDouble(),
        placeId: json['placeId'] as String?,
        coordsAt: json['coordsAt'] as int?,
      );
}

class SavedPlacesService {
  static const String _prefsKey = 'guidy_saved_places';

  /// Reads the saved places, refreshing any whose Places coordinates have
  /// aged past the 30-day retention window.
  ///
  /// The refresh happens here, on read, rather than by deleting the
  /// place: a rider's "Home" should not disappear because a month passed.
  /// The placeId may be kept indefinitely, so the coordinates can simply
  /// be fetched again from it -- at most one Place Details call per saved
  /// place per month, which is why storing the id was worth doing.
  ///
  /// A place with no placeId is left alone: those coordinates came from a
  /// map tap, not from Google. Entries written before this field existed
  /// also have no placeId, so they are treated the same way. That is a
  /// judgement call rather than a certainty -- their origin is genuinely
  /// unknowable now -- and it errs toward not silently deleting a rider's
  /// saved places.
  static Future<List<SavedPlace>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return [];

    late final List<SavedPlace> stored;
    try {
      final List<dynamic> decoded = json.decode(raw);
      stored = decoded.map((e) => SavedPlace.fromJson(e)).toList();
    } catch (_) {
      return [];
    }

    final needsWork = stored.any(
        (p) => p.placeId != null && PlacesCoordsPolicy.isExpired(p.coordsAt));
    if (!needsWork) return stored;

    final result = <SavedPlace>[];
    for (final place in stored) {
      if (place.placeId == null || !PlacesCoordsPolicy.isExpired(place.coordsAt)) {
        result.add(place);
        continue;
      }
      final fresh = await _reresolve(place);
      // If the refresh failed, the coordinates still have to go -- the
      // deadline is not conditional on our network. The place is dropped
      // rather than kept with stale coordinates.
      if (fresh != null) result.add(fresh);
    }
    await _save(result);
    return result;
  }

  static Future<SavedPlace?> _reresolve(SavedPlace place) async {
    try {
      final coords = await PlacesService.getPlaceDetails(
          place.placeId!, PlacesService.startSession());
      if (coords == null) return null;
      return place.copyWith(
        lat: coords['lat'],
        lon: coords['lon'],
        coordsAt: PlacesCoordsPolicy.now,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> add(SavedPlace place) async {
    final places = await getAll();
    places.add(place);
    await _save(places);
  }

  static Future<void> remove(String id) async {
    final places = await getAll();
    places.removeWhere((p) => p.id == id);
    await _save(places);
    unawaited(CloudUserData.deleteDocs('saved_places', [id]));
  }

  /// Removes every saved place from THIS DEVICE (not from the cloud).
  /// Called on sign-out; see SavedTripsService.clearLocal.
  static Future<void> clearLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  /// Syncs locally saved places with Firestore for authenticated users.
  static Future<void> syncWithCloud(User user) async {
    if (user.isAnonymous) return;
    try {
      final firestore = FirebaseFirestore.instance;
      final placesCollection = firestore.collection('users').doc(user.uid).collection('saved_places');

      final snapshot = await placesCollection.get();
      final cloudPlaces = <String, SavedPlace>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        cloudPlaces[doc.id] = SavedPlace.fromJson(data);
      }

      final localPlaces = await getAll();
      final localMap = {for (var p in localPlaces) p.id: p};

      final batch = firestore.batch();
      bool hasUploads = false;
      for (final local in localPlaces) {
        if (!cloudPlaces.containsKey(local.id)) {
          final docRef = placesCollection.doc(local.id);
          batch.set(docRef, local.toJson(), SetOptions(merge: true));
          hasUploads = true;
        }
      }
      if (hasUploads) {
        await batch.commit();
      }

      bool hasNewLocal = false;
      for (final entry in cloudPlaces.entries) {
        if (!localMap.containsKey(entry.key)) {
          localPlaces.add(entry.value);
          hasNewLocal = true;
        }
      }
      if (hasNewLocal) {
        await _save(localPlaces);
      }
    } catch (e) {
      debugPrint("Error syncing saved places with cloud: $e");
    }
  }

  static Future<void> _save(List<SavedPlace> places) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, json.encode(places.map((p) => p.toJson()).toList()));
  }
}
