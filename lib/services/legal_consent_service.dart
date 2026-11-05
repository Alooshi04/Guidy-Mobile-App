import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where agreements are recorded: users/{uid}/legal_consents/{version}.
/// firestore.rules lets a rider add their own records and never change
/// them, so they stand as a log of who agreed to what, and when.
abstract class LegalConsentStore {
  Future<bool> exists(String uid, String version);
  Future<void> record(String uid, String version, Map<String, dynamic> data);
}

class FirestoreLegalConsentStore implements LegalConsentStore {
  DocumentReference<Map<String, dynamic>> _doc(String uid, String version) => FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('legal_consents')
      .doc(version);

  @override
  Future<bool> exists(String uid, String version) async => (await _doc(uid, version).get()).exists;

  @override
  Future<void> record(String uid, String version, Map<String, dynamic> data) =>
      _doc(uid, version).set({...data, 'accepted_at': FieldValue.serverTimestamp()});
}

/// Agreement to the Terms and Conditions, the Privacy Policy and the Data
/// Deletion Policy. Every new account agrees when it is created (email,
/// Google or guest), and anyone who hasn't agreed to [currentVersion] --
/// existing accounts, or everyone after a policy update -- is asked once
/// (LegalConsentGate).
class LegalConsentService {
  LegalConsentService._();

  /// The latest effective date of the Terms and the Privacy Policy
  /// (legal_consent_test checks it against the markdown). Bump it with
  /// either, and everyone is asked to agree again.
  static const String currentVersion = '2026-10-22';

  static LegalConsentStore store = FirestoreLegalConsentStore();

  static String _acceptedKey(String uid) => 'legal_consent_accepted_$uid';
  static String _pendingKey(String uid) => 'legal_consent_pending_$uid';

  /// Ticked on the sign-in or sign-up screen, before the account exists.
  static String? _agreedLang;

  @visibleForTesting
  static void resetForTesting() => _agreedLang = null;

  /// The box was ticked before signing in or up; the account that results
  /// is recorded as agreeing (see [hasAccepted]).
  static void agreeBeforeSignIn({required String lang}) => _agreedLang = lang;

  /// Sign-in was cancelled or failed: the agreement must not carry over to
  /// whichever account signs in next.
  static void forgetAgreementBeforeSignIn() => _agreedLang = null;

  /// Whether [uid] has agreed to [currentVersion]: remembered on this phone,
  /// just agreed on the sign-up screen, or recorded from another phone.
  static Future<bool> hasAccepted(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_acceptedKey(uid)) == currentVersion) {
      await uploadPending(uid);
      return true;
    }
    final lang = _agreedLang;
    if (lang != null) {
      _agreedLang = null;
      await accept(uid, lang: lang);
      return true;
    }
    try {
      if (await store.exists(uid, currentVersion)) {
        await prefs.setString(_acceptedKey(uid), currentVersion);
        return true;
      }
    } catch (e) {
      debugPrint('[LegalConsent] could not check the record: $e');
    }
    return false;
  }

  /// Records that [uid] agrees to [currentVersion]. Remembered on the phone
  /// at once, so an agreement made offline lets the rider in; the record is
  /// uploaded now or, failing that, by [uploadPending] later.
  static Future<void> accept(String uid, {required String lang}) async {
    final prefs = await SharedPreferences.getInstance();
    var appVersion = '';
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {}
    final data = {'version': currentVersion, 'lang': lang, 'app_version': appVersion};
    await prefs.setString(_acceptedKey(uid), currentVersion);
    await prefs.setString(_pendingKey(uid), jsonEncode(data));
    await uploadPending(uid);
  }

  /// Uploads a record agreed while offline, if there is one.
  static Future<void> uploadPending(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingKey(uid));
    if (raw == null) return;
    try {
      final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      await store.record(uid, data['version'] as String, data);
      await prefs.remove(_pendingKey(uid));
    } catch (e) {
      // Already recorded (e.g. agreed on another phone): the rules refuse
      // rewriting a record, so stop trying.
      try {
        final version = (jsonDecode(raw) as Map)['version'] as String;
        if (await store.exists(uid, version)) {
          await prefs.remove(_pendingKey(uid));
          return;
        }
      } catch (_) {}
      debugPrint('[LegalConsent] record not uploaded yet: $e');
    }
  }
}
