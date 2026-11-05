import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'saved_places_service.dart';
import 'account_service.dart';

/// Result of a social sign-in attempt. `cancelled` is distinguished from a
/// real failure because the person closing the Google picker
/// shouldn't show an error message.
class SocialAuthResult {
  final UserCredential? credential;
  final bool cancelled;
  final String? errorMessage;

  const SocialAuthResult({this.credential, this.cancelled = false, this.errorMessage});
}

class SocialAuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  static Future<SocialAuthResult> signInWithGoogle() async {
    try {
      // Sign out first to ensure the Google account chooser modal appears every time,
      // letting users select a different account or switch emails.
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return const SocialAuthResult(cancelled: true);
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      if (userCredential.user != null) {
        final name = userCredential.user!.displayName ?? googleUser.displayName;
        if (name != null && name.trim().isNotEmpty) {
          await AccountService.saveUserDisplayName(name);
        }
        SavedPlacesService.syncWithCloud(userCredential.user!);
      }
      return SocialAuthResult(credential: userCredential);
    } on FirebaseAuthException catch (e) {
      return SocialAuthResult(errorMessage: e.message);
    } catch (e) {
      return SocialAuthResult(errorMessage: e.toString());
    }
  }

  /// Guest sign-in: creates a temporary, anonymous Firebase user with no
  /// email or provider attached, so someone can use the app right away
  /// without creating an account. Requires the "Anonymous" sign-in
  /// provider to be enabled in the Firebase console (Authentication ->
  /// Sign-in method) -- it's off by default on a new Firebase project.
  static Future<SocialAuthResult> signInAsGuest() async {
    try {
      final userCredential = await FirebaseAuth.instance.signInAnonymously();
      return SocialAuthResult(credential: userCredential);
    } on FirebaseAuthException catch (e) {
      return SocialAuthResult(errorMessage: e.message);
    } catch (e) {
      return SocialAuthResult(errorMessage: e.toString());
    }
  }

  /// Gets a fresh Google credential *without* signing it into Firebase --
  /// used to re-authenticate an already-signed-in user (e.g. right before
  /// account deletion, which Firebase requires a recent login for) via
  /// `user.reauthenticateWithCredential(...)`, as opposed to
  /// [signInWithGoogle] which is for a fresh sign-in via
  /// `signInWithCredential`. Returns null if the person cancels the picker.
  static Future<AuthCredential?> getGoogleCredential() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;
    final googleAuth = await googleUser.authentication;
    return GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
  }
}
