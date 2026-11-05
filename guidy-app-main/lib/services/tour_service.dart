import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which feature tours the rider has already seen (or skipped). Each runs
/// once by itself; Settings > Replay tutorial makes them all new again.
class TourService {
  TourService._();

  /// The app tour: Home and the tabs, on first launch.
  static const String home = 'home';

  /// The trip screen tour, the first time a trip starts.
  static const String trip = 'trip';

  static const List<String> _all = [home, trip];

  static String _key(String id) => 'tour_seen_$id';

  static Future<bool> hasSeen(String id) async =>
      (await SharedPreferences.getInstance()).getBool(_key(id)) ?? false;

  static Future<void> markSeen(String id) async =>
      (await SharedPreferences.getInstance()).setBool(_key(id), true);

  /// Bumped by Settings > Replay tutorial; MainNavigator listens and runs
  /// the app tour again.
  static final ValueNotifier<int> replayRequests = ValueNotifier(0);

  /// Every tour new again, and the app tour now.
  static Future<void> replay() async {
    await resetAll();
    replayRequests.value++;
  }

  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final id in _all) {
      await prefs.remove(_key(id));
    }
  }
}
