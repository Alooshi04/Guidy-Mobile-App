import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import 'trip_recorder.dart';
import 'walk_feedback_service.dart';

/// "Share my trips" (owner, 2026-10-22): the one switch for what Guidy
/// records of a trip the rider follows. That's the vehicle route and GPS
/// trace sent at the end of the trip ([TripRecorder]) and the path walked
/// on each walking step ([WalkTraceRecorder]). Off until the rider answers the
/// one-time ask ([askIfNeeded], before the first trip starts). Off records nothing and drops whatever is
/// still waiting to be sent.
///
/// A "This walk is wrong" report is not covered by it: the rider sends each
/// one on purpose.
class TripSharing {
  TripSharing._();

  static const String _key = 'trip_sharing';
  static const String _askedKey = 'trip_sharing_asked';

  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(false);

  /// True once the rider answered the ask, or set the Settings switch.
  static bool asked = false;

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled.value = prefs.getBool(_key) ?? false;
      // Someone who already used the Settings switch has answered.
      asked = prefs.getBool(_askedKey) ?? prefs.containsKey(_key);
    } catch (_) {}
  }

  static Future<void> set(bool on) async {
    enabled.value = on;
    asked = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, on);
      await prefs.setBool(_askedKey, true);
    } catch (_) {}
    if (!on) {
      await WalkFeedbackService.traces.clear();
      await TripRecorder.dropQueued();
    }
  }

  /// Asks once, before a trip's navigation opens (never over the live map).
  /// Remembered either way; Settings still flips it later.
  static Future<void> askIfNeeded(BuildContext context) async {
    if (asked) return;
    final l10n = AppLocalizations.of(context);
    final share = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('trip-share-ask'),
        title: Text(l10n.tripShareAskTitle),
        content: Text(l10n.tripShareAskBody, style: const TextStyle(height: 1.4)),
        actions: [
          TextButton(
            key: const ValueKey('trip-share-ask-no'),
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.tripShareAskNo),
          ),
          FilledButton(
            key: const ValueKey('trip-share-ask-yes'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.tripShareAskYes),
          ),
        ],
      ),
    );
    await set(share ?? false);
  }
}
