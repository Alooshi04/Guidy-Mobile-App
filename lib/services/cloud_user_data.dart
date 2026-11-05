import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Deletes the signed-in user's own documents under `users/{uid}/<collection>`.
///
/// The sync code (SavedTripsService / SavedPlacesService / TripHistoryService
/// `syncWithCloud`) merges in both directions but never learned about
/// deletions: a trip removed on the phone was still in Firestore, so the next
/// sync pulled it straight back. Every local removal now also removes the
/// cloud copy through here.
///
/// Best-effort by design, like the syncs themselves: no Firebase (unit
/// tests), no user, a guest account, or no network all just return. Firestore
/// queues the delete offline and sends it when the connection returns.
class CloudUserData {
  static CollectionReference<Map<String, dynamic>>? _collection(String name) {
    if (Firebase.apps.isEmpty) return null;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return null;
    return FirebaseFirestore.instance.collection('users').doc(user.uid).collection(name);
  }

  static Future<void> deleteDocs(String collection, Iterable<String> ids) async {
    try {
      final coll = _collection(collection);
      if (coll == null) return;
      final list = ids.toList();
      for (var i = 0; i < list.length; i += 400) {
        final batch = FirebaseFirestore.instance.batch();
        for (final id in list.skip(i).take(400)) {
          batch.delete(coll.doc(id));
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('[CloudUserData] delete from $collection failed: $e');
    }
  }

  /// Merges [data] into one of the user's documents (e.g. marking a trip
  /// completed). The two-way sync only uploads documents the cloud doesn't
  /// have yet, so a later change to an existing one has to be sent here.
  static Future<void> merge(String collection, String id, Map<String, dynamic> data) async {
    try {
      final coll = _collection(collection);
      if (coll == null) return;
      await coll.doc(id).set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[CloudUserData] merge into $collection/$id failed: $e');
    }
  }

  static Future<void> deleteAll(String collection) async {
    try {
      final coll = _collection(collection);
      if (coll == null) return;
      final snapshot = await coll.get();
      await deleteDocs(collection, snapshot.docs.map((d) => d.id));
    } catch (e) {
      debugPrint('[CloudUserData] clear $collection failed: $e');
    }
  }
}
