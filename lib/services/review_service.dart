import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Prompts for a store review after the person has completed a few real
/// trips -- not on first open, and never more than once (the OS itself
/// also rate-limits how often the native dialog can show, but we avoid
/// even asking to show it repeatedly).
class ReviewService {
  static const String _tripCountKey = 'guidy_completed_trip_count';
  static const String _hasPromptedKey = 'guidy_has_prompted_review';
  static const int _tripsBeforePrompt = 3;

  static Future<void> onTripCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyPrompted = prefs.getBool(_hasPromptedKey) ?? false;
    if (alreadyPrompted) return;

    final count = (prefs.getInt(_tripCountKey) ?? 0) + 1;
    await prefs.setInt(_tripCountKey, count);

    if (count >= _tripsBeforePrompt) {
      await prefs.setBool(_hasPromptedKey, true);
      final inAppReview = InAppReview.instance;
      if (await inAppReview.isAvailable()) {
        await inAppReview.requestReview();
      }
    }
  }

  /// Used by the "Rate Guidy" tile in Settings -- always opens the store
  /// listing directly, regardless of trip count, since the person asked
  /// for it explicitly.
  static Future<void> openStoreListing() async {
    final inAppReview = InAppReview.instance;
    await inAppReview.openStoreListing();
  }
}
