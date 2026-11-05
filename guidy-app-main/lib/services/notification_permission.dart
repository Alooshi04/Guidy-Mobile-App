import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'commute/commute_notifications.dart';
import 'consent_service.dart';

/// Owner, 2026-10-30: the notification permission (Android 13+) is asked
/// once, on the first launch that reaches the app itself (never over the
/// sign-in, consent or legal screens), and never again on its own. The
/// commute alerts still ask in context when they first have something to
/// send (CommuteStore.takePermissionAsk).
abstract final class NotificationPermission {
  static const String askedKey = 'notifications_asked_on_launch';

  /// Stands in for the system prompt in tests.
  @visibleForTesting
  static Future<void> Function()? debugRequest;

  /// Asks, unless it was asked before. Returns whether it asked.
  static Future<bool> askOnce() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(askedKey) ?? false) return false;
      await prefs.setBool(askedKey, true);
    } catch (_) {
      return false;
    }
    // Not over Google's consent form: one system prompt at a time.
    try {
      await ConsentService.instance.settled.timeout(const Duration(seconds: 30));
    } catch (_) {}
    await (debugRequest ?? CommuteNotifications.requestPermission)();
    return true;
  }
}
