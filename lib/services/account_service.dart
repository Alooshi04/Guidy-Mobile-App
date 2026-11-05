import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import 'current_trip.dart';
import 'saved_places_service.dart';
import 'saved_trips_service.dart';
import 'search_history_service.dart';
import 'trip_history_service.dart';
import 'trip_recorder.dart';

/// Result of an account-deletion attempt.
///
/// `needsReauth` is the important case: Firebase requires a *recent*
/// login before it'll delete an account (security measure -- otherwise a
/// stolen, still-logged-in device could delete someone's account with no
/// further proof of identity). If the person's session isn't recent
/// enough, deletion fails with FirebaseAuthException code
/// 'requires-recent-login', and the caller needs to re-authenticate (see
/// [AccountService.reauthenticateAndDelete]) before trying again.
class AccountDeletionResult {
  final bool success;
  final bool needsReauth;
  final String? error;

  const AccountDeletionResult({this.success = false, this.needsReauth = false, this.error});
}

/// Outcome of sending a verification or password-reset email.
enum AuthEmailResult { sent, invalidEmail, tooManyRequests, network, failed }

enum ChangePasswordResult { success, wrongCurrent, sameAsOld, weakPassword, tooManyRequests, network, failed }

class AccountService {
  /// Attempts to delete the signed-in user directly. This succeeds
  /// immediately for guest/anonymous accounts (nothing to re-challenge)
  /// and for any account whose login is still "recent" by Firebase's own
  /// definition. For anything else, check `result.needsReauth` and follow
  /// up with [reauthenticateAndDelete] using a fresh credential for
  /// whichever provider `user.providerData` reports.
  static Future<AccountDeletionResult> deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const AccountDeletionResult(error: 'not-signed-in');
    }
    try {
      await _cleanupUserData(user.uid);
      await user.delete();
      await clearUserDataOnSignOut();
      return const AccountDeletionResult(success: true);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return const AccountDeletionResult(needsReauth: true);
      }
      return AccountDeletionResult(error: e.message ?? e.code);
    } catch (e) {
      return AccountDeletionResult(error: e.toString());
    }
  }

  /// Re-authenticates with a freshly-obtained credential, then deletes.
  /// Call this after [deleteAccount] returns `needsReauth: true`.
  static Future<AccountDeletionResult> reauthenticateAndDelete(AuthCredential credential) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const AccountDeletionResult(error: 'not-signed-in');
    }
    try {
      await user.reauthenticateWithCredential(credential);
      await _cleanupUserData(user.uid);
      await user.delete();
      await clearUserDataOnSignOut();
      return const AccountDeletionResult(success: true);
    } on FirebaseAuthException catch (e) {
      return AccountDeletionResult(error: e.message ?? e.code);
    } catch (e) {
      return AccountDeletionResult(error: e.toString());
    }
  }

  /// Whether this account has to confirm its email before using the app.
  /// Only email/password accounts: a guest has no email, and Google has
  /// already vouched for a Google account's address (even when the same
  /// account also has a password linked).
  static bool emailVerificationRequired({
    required bool isAnonymous,
    required bool emailVerified,
    required Set<String> providerIds,
  }) =>
      !isAnonymous && !emailVerified && providerIds.contains('password') && !providerIds.contains('google.com');

  static bool needsEmailVerification(User? user) =>
      user != null &&
      emailVerificationRequired(
        isAnonymous: user.isAnonymous,
        emailVerified: user.emailVerified,
        providerIds: user.providerData.map((p) => p.providerId).toSet(),
      );

  /// Firebase writes its verification and reset emails in this language
  /// ('ar' or 'en' -- the app's, not the phone's).
  static Future<void> _setEmailLanguage(String? languageCode) async {
    if (languageCode == null) return;
    try {
      await FirebaseAuth.instance.setLanguageCode(languageCode);
    } catch (_) {}
  }

  /// Sends (or re-sends) the verification link to the signed-in account.
  static Future<AuthEmailResult> sendEmailVerification({String? languageCode}) async {
    final user = currentUser;
    if (user == null) return AuthEmailResult.failed;
    await _setEmailLanguage(languageCode);
    try {
      await user.sendEmailVerification();
      return AuthEmailResult.sent;
    } on FirebaseAuthException catch (e) {
      return _emailResultFor(e);
    } catch (_) {
      return AuthEmailResult.failed;
    }
  }

  /// Reloads the account from Firebase -- `emailVerified` on the cached
  /// user doesn't change when the link is opened elsewhere -- and says
  /// whether the address is now verified.
  static Future<bool> reloadAndCheckEmailVerified() async {
    final user = currentUser;
    if (user == null) return false;
    try {
      await user.reload();
    } catch (_) {
      return false;
    }
    return !needsEmailVerification(FirebaseAuth.instance.currentUser);
  }

  /// Sends a password-reset link. An email with no account reports
  /// [AuthEmailResult.sent] like any other, so the reset form can't be used
  /// to find out which addresses have accounts.
  static Future<AuthEmailResult> sendPasswordReset(String email, {String? languageCode}) async {
    await _setEmailLanguage(languageCode);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      return AuthEmailResult.sent;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') return AuthEmailResult.sent;
      return _emailResultFor(e);
    } catch (_) {
      return AuthEmailResult.failed;
    }
  }

  /// The message for a failed [AuthEmailResult]; null for [AuthEmailResult.sent].
  static String? authEmailErrorText(AppLocalizations l10n, AuthEmailResult result) => switch (result) {
        AuthEmailResult.sent => null,
        AuthEmailResult.invalidEmail => l10n.invalidEmail,
        AuthEmailResult.tooManyRequests => l10n.tooManyRequests,
        AuthEmailResult.network => l10n.checkInternet,
        AuthEmailResult.failed => l10n.authEmailFailed,
      };

  static AuthEmailResult _emailResultFor(FirebaseAuthException e) => switch (e.code) {
        'invalid-email' => AuthEmailResult.invalidEmail,
        'too-many-requests' => AuthEmailResult.tooManyRequests,
        'network-request-failed' => AuthEmailResult.network,
        _ => AuthEmailResult.failed,
      };

  /// Confirms [currentPassword] (Firebase wants a recent login before a
  /// password change anyway), then sets [newPassword]. The caller has
  /// already checked [newPassword] against PasswordPolicy; Firebase's own
  /// policy can still refuse it ([ChangePasswordResult.weakPassword]).
  static Future<ChangePasswordResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = currentUser;
    final email = user?.email;
    if (user == null || email == null) return ChangePasswordResult.failed;
    if (currentPassword == newPassword) return ChangePasswordResult.sameAsOld;
    try {
      await user.reauthenticateWithCredential(EmailAuthProvider.credential(email: email, password: currentPassword));
    } on FirebaseAuthException catch (e) {
      return switch (e.code) {
        'wrong-password' || 'invalid-credential' || 'user-mismatch' => ChangePasswordResult.wrongCurrent,
        'too-many-requests' => ChangePasswordResult.tooManyRequests,
        'network-request-failed' => ChangePasswordResult.network,
        _ => ChangePasswordResult.failed,
      };
    } catch (_) {
      return ChangePasswordResult.failed;
    }
    try {
      await user.updatePassword(newPassword);
      return ChangePasswordResult.success;
    } on FirebaseAuthException catch (e) {
      return switch (e.code) {
        'weak-password' || 'password-does-not-meet-requirements' => ChangePasswordResult.weakPassword,
        'network-request-failed' => ChangePasswordResult.network,
        _ => ChangePasswordResult.failed,
      };
    } catch (_) {
      return ChangePasswordResult.failed;
    }
  }

  static Future<void> _cleanupUserData(String uid) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final userDoc = firestore.collection('users').doc(uid);

      final trips = await userDoc.collection('saved_trips').get();
      for (final doc in trips.docs) {
        await doc.reference.delete();
      }

      final places = await userDoc.collection('saved_places').get();
      for (final doc in places.docs) {
        await doc.reference.delete();
      }

      // Trip history syncs to the account too (TripHistoryService); it was
      // left behind here, so "delete my account" kept every recorded trip.
      final history = await userDoc.collection('trip_history').get();
      for (final doc in history.docs) {
        await doc.reference.delete();
      }

      // Agreements to the legal pages go with the account.
      final consents = await userDoc.collection('legal_consents').get();
      for (final doc in consents.docs) {
        await doc.reference.delete();
      }

      await userDoc.delete();
    } catch (_) {}
    // Trip logs on our server stay (Terms of Service) but are unlinked
    // from this account (TripRecorder.forgetMe).
    await TripRecorder.forgetMe();
  }

  static const String prefKeyDisplayName = 'user_display_name';

  /// Safe accessor for the currently authenticated Firebase user.
  static User? get currentUser {
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// Extracts the conversational first name from any full name string.
  /// E.g.:
  /// - "Youssef Ezzat" -> "Youssef"
  /// - "أحمد محمد" -> "أحمد"
  /// - "Sara" -> "Sara"
  static String? extractFirstName(String? fullName) {
    if (fullName == null || fullName.trim().isEmpty) return null;
    final trimmed = fullName.trim();
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.isNotEmpty && parts.first.isNotEmpty) {
      return parts.first;
    }
    return trimmed;
  }

  /// Saves the user's display name locally in SharedPreferences, and syncs to
  /// Firebase Auth and Firestore if a user is currently logged in.
  static Future<void> saveUserDisplayName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefKeyDisplayName, trimmed);
    } catch (_) {}

    final user = currentUser;
    if (user != null && !user.isAnonymous) {
      try {
        await user.updateDisplayName(trimmed);
        await user.reload();
      } catch (_) {}

      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'displayName': trimmed,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  /// Retrieves the user's display name.
  /// Precedence:
  /// 1. FirebaseAuth currentUser.displayName
  /// 2. SharedPreferences cached name
  /// 3. Firestore doc ('users/{uid}')
  static Future<String?> getUserDisplayName() async {
    final user = currentUser;
    if (user != null && !user.isAnonymous) {
      if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
        final name = user.displayName!.trim();
        _cacheLocalDisplayName(name);
        return name;
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(prefKeyDisplayName);
      if (cached != null && cached.trim().isNotEmpty) {
        return cached.trim();
      }
    } catch (_) {}

    if (user != null && !user.isAnonymous) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data();
          final name = data?['displayName'] as String?;
          if (name != null && name.trim().isNotEmpty) {
            _cacheLocalDisplayName(name.trim());
            return name.trim();
          }
        }
      } catch (_) {}
    }

    return null;
  }

  /// Retrieves the user's first name for greeting and friendly UI displays.
  static Future<String?> getUserFirstName() async {
    final fullName = await getUserDisplayName();
    return extractFirstName(fullName);
  }

  static void _cacheLocalDisplayName(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefKeyDisplayName, name);
    } catch (_) {}
  }

  /// Clears everything personal from THIS DEVICE on sign-out (and after
  /// account deletion).
  ///
  /// This used to remove only the cached display name. Saved trips, saved
  /// places, trip history and recent searches stayed on the phone -- so the
  /// next person to sign in saw them, and the sync on sign-in then uploaded
  /// them into that person's account. Signed-in users keep their copy in
  /// Firestore, so signing back in brings it all back.
  static Future<void> clearUserDataOnSignOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(prefKeyDisplayName);
    } catch (_) {}
    for (final clear in <Future<void> Function()>[
      SavedTripsService.clearLocal,
      SavedPlacesService.clearLocal,
      TripHistoryService.clearLocal,
      SearchHistoryService.clear,
      CurrentTrip.clear,
    ]) {
      try {
        await clear();
      } catch (_) {}
    }
  }

  /// Formats a time-of-day greeting contextualized with the user's name if available.
  /// - Morning (5:00 - 11:59): "Good morning, {name}" / "صباح الخير يا {name}"
  /// - Afternoon (12:00 - 16:59): "Good afternoon, {name}" / "نهارك سعيد يا {name}"
  /// - Evening (17:00 - 20:59): "Good evening, {name}" / "مساء الخير يا {name}"
  /// - Night (21:00 - 4:59): "Good night, {name}" / "سهرة سعيدة يا {name}"
  /// If [name] is null/empty, falls back to generic greetings.
  static String formatGreeting(AppLocalizations l10n, {String? name, int? hourOverride}) {
    final hour = hourOverride ?? DateTime.now().hour;
    final cleanName = extractFirstName(name);

    if (cleanName != null && cleanName.isNotEmpty) {
      if (hour >= 5 && hour < 12) return l10n.goodMorningUser(cleanName);
      if (hour >= 12 && hour < 17) return l10n.goodAfternoonUser(cleanName);
      if (hour >= 17 && hour < 21) return l10n.goodEveningUser(cleanName);
      return l10n.goodNightUser(cleanName);
    }

    if (hour >= 5 && hour < 12) return l10n.goodMorning;
    if (hour >= 12 && hour < 17) return l10n.goodAfternoon;
    if (hour >= 17 && hour < 21) return l10n.goodEvening;
    return l10n.goodNight;
  }
}
