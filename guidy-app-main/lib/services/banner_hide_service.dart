import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The top banner is hidden for 24 hours after the rider watches a rewarded
/// ad (Settings > "Remove banner for 24 hours"). Persisted, so it survives a
/// restart; the banner comes back by itself when the time is up.
class BannerHideService {
  BannerHideService({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static final BannerHideService instance = BannerHideService();

  static const Duration hideFor = Duration(hours: 24);
  static const String _key = 'banner_hidden_until_ms';

  final DateTime Function() _clock;
  Timer? _timer;
  DateTime? _until;

  /// True while the banner must stay hidden.
  final ValueNotifier<bool> hidden = ValueNotifier<bool>(false);

  /// When the banner returns, or null if it is showing.
  DateTime? get hiddenUntil => hidden.value ? _until : null;

  /// Reads the stored time. Called once at launch.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_key);
    _apply(ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms));
  }

  /// The rider earned the reward: hide the banner for 24 hours from now.
  Future<void> hideForDay() async {
    final until = _clock().add(hideFor);
    _apply(until);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, until.millisecondsSinceEpoch);
  }

  /// Re-checks the clock (call on app resume, a timer may not have fired).
  void refresh() => _apply(_until);

  void _apply(DateTime? until) {
    _timer?.cancel();
    _timer = null;
    final now = _clock();
    // A stored time further off than 24 h means the clock was moved: ignore it.
    if (until != null && until.isAfter(now) && until.difference(now) <= hideFor) {
      _until = until;
      hidden.value = true;
      _timer = Timer(until.difference(now), refresh);
    } else {
      _until = null;
      hidden.value = false;
    }
  }

  @visibleForTesting
  void dispose() => _timer?.cancel();
}
