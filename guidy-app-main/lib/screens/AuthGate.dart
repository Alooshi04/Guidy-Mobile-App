import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'MainNavigator.dart';
import 'SignInScreen.dart';
import 'VerifyEmailScreen.dart';
import '../theme/app_theme.dart';

import '../services/saved_places_service.dart';
import '../widgets/legal_consent.dart';
import '../services/trip_history_service.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  static String? _lastSyncedUid;

  @override
  Widget build(BuildContext context) {
    if (Firebase.apps.isEmpty) {
      // Graceful fallback if Firebase is uninitialized (e.g. desktop preview or offline tests)
      return const MainNavigator();
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show a loading spinner while Firebase checks the user's token
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: context.surfaceCard,
            body: const Center(
              child: CircularProgressIndicator(color: AppColors.primaryTeal),
            ),
          );
        }
        
        // If the user is successfully logged in, take them to the main app layout
        if (snapshot.hasData) {
          final user = snapshot.data;
          // Once per signed-in user, not on every rebuild of this
          // StreamBuilder -- each sync is three Firestore reads and a write.
          if (user != null && !user.isAnonymous && _lastSyncedUid != user.uid) {
            _lastSyncedUid = user.uid;
            SavedPlacesService.syncWithCloud(user);
            TripHistoryService.syncWithCloud(user);
          }

          // Not before an email account has verified its address, nor
          // before the account has agreed to the current legal pages.
          return const EmailVerificationGate(child: LegalConsentGate(child: MainNavigator()));
        }
        
        // Otherwise, send them to the login screen
        _lastSyncedUid = null;
        return const SignInScreen();
      },
    );
  }
}