import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ad_service.dart';
import 'navigation_session.dart';
import 'trip_pip.dart';

/// Shows a full-screen ad when a rider comes back to Guidy after being away
/// for a while.
///
/// WHY THIS IS AN APP OPEN AD AND NOT AN INTERSTITIAL
///
/// The obvious way to build "show an ad when they come back" is to fire an
/// interstitial on resume. AdMob explicitly forbids that:
///
///   "Do not place interstitial ads on app load and when exiting apps as
///    interstitials should only be placed in between pages of app content."
///
/// Interstitials are for logical breaks *inside* content — finishing a
/// flow, moving between pages. An ad that appears because the rider
/// unlocked their phone is not a break in content, it is an app open, and
/// Google publishes a separate format for exactly this case. Using the
/// wrong one risks the account, not just the placement.
///
/// WHY IT MEASURES BACKGROUND TIME, NOT SCREEN LOCK
///
/// An app cannot observe the phone's lock screen, and it does not run while
/// the screen is off. What it can observe is its own lifecycle: note the
/// time on the way out, compare on the way back. That covers a locked
/// screen, but also switching apps or taking a call — which is what you
/// actually want, since all three mean the rider left and returned.
class AppOpenAdService with WidgetsBindingObserver {
  AppOpenAdService._();
  static final AppOpenAdService instance = AppOpenAdService._();

  /// How long the rider must have been away before returning earns an ad.
  /// A short window here is the difference between a monetised return and
  /// an ad every time someone glances at a notification.
  static const Duration minimumTimeAway = Duration(minutes: 15);

  /// Google expires a cached app open ad after four hours; showing a stale
  /// one fails, so it is reloaded instead.
  static const Duration _adValidity = Duration(hours: 4);

  /// However often the rider comes back, no more than [maxPerDay] app open
  /// ads in any 24 hours, and [minimumGap] between two. Without a cap, a
  /// rider who checks the phone every 20 minutes saw dozens a day, which
  /// Google's guidance and the review both flagged. Kept across restarts.
  static const int maxPerDay = 3;
  static const Duration minimumGap = Duration(hours: 4);
  static const String _shownKey = 'app_open_ad_shown_at';

  /// When the recent ads were shown (the last 24 hours), oldest first.
  final List<DateTime> _shown = [];

  /// When the last app open ad was shown, for other full-screen formats
  /// that should not follow one too closely.
  DateTime? get lastShownAt => _shown.isEmpty ? null : _shown.last;

  /// Whether the cap leaves room for another ad at [now], given when the
  /// recent ones were shown.
  static bool capAllows(List<DateTime> shown, DateTime now) {
    final recent = shown.where((t) => now.difference(t) < const Duration(hours: 24)).toList();
    if (recent.length >= maxPerDay) return false;
    if (recent.isNotEmpty && now.difference(recent.last) < minimumGap) return false;
    return true;
  }

  AppOpenAd? _ad;
  DateTime? _loadedAt;
  DateTime? _leftAt;
  bool _isShowing = false;
  bool _isLoading = false;
  bool _started = false;

  /// Called once from main(). Registers the lifecycle observer and warms
  /// the first ad. Nothing shows on this first launch — `_leftAt` is null
  /// until the rider actually leaves, so a cold start never triggers one.
  void initialize() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _restoreShown();
    _load();
  }

  Future<void> _restoreShown() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    _shown
      ..clear()
      ..addAll((prefs.getStringList(_shownKey) ?? const [])
          .map(DateTime.tryParse)
          .whereType<DateTime>()
          .where((t) => now.difference(t) < const Duration(hours: 24))
          .toList()
        ..sort());
  }

  Future<void> _recordShown(DateTime at) async {
    _shown.add(at);
    _shown.removeWhere((t) => at.difference(t) >= const Duration(hours: 24));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_shownKey, _shown.map((t) => t.toIso8601String()).toList());
  }

  /// Starts the service as soon as ads are allowed: now if consent already
  /// resolved, otherwise when [AdService.adsReady] turns true (a first launch
  /// offline, or a rider who later allows ads in Settings). Safe to call more
  /// than once.
  void initializeWhenReady() {
    if (_started) return;
    if (AdService.adsReady.value) {
      initialize();
      return;
    }
    if (_waitingForReady) return;
    _waitingForReady = true;
    void listener() {
      if (!AdService.adsReady.value) return;
      AdService.adsReady.removeListener(listener);
      _waitingForReady = false;
      initialize();
    }

    AdService.adsReady.addListener(listener);
  }

  bool _waitingForReady = false;

  @visibleForTesting
  bool get started => _started;

  /// How long a show may go without "showed" or "failed" before the service
  /// stops waiting on it.
  @visibleForTesting
  static const Duration showGuard = Duration(seconds: 15);
  Timer? _showGuard;

  void _clearShowing() {
    _showGuard?.cancel();
    _showGuard = null;
    _isShowing = false;
  }

  void dispose() {
    _showGuard?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _ad?.dispose();
    _ad = null;
    _started = false;
  }

  bool get _isAdAvailable =>
      _ad != null && _loadedAt != null && DateTime.now().difference(_loadedAt!) < _adValidity;

  void _load() {
    if (!AdService.adsReady.value) return;
    if (_isLoading || _isAdAvailable) return;
    _isLoading = true;
    try {
      unawaited(AppOpenAd.load(
        adUnitId: AdService.appOpenAdUnitId,
        request: const AdRequest(),
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (ad) {
            _ad = ad;
            _loadedAt = DateTime.now();
            _isLoading = false;
          },
          onAdFailedToLoad: (error) {
            // No fill and network failures are routine. Stay quiet and try
            // again the next time the rider leaves.
            debugPrint('App open ad failed to load: $error');
            _isLoading = false;
          },
        ),
      ).catchError((Object e) {
        debugPrint('App open ad load threw: $e');
        _isLoading = false;
      }));
    } catch (e) {
      debugPrint('App open ad load threw: $e');
      _isLoading = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // Showing the ad itself backgrounds the app. Without this guard the
        // clock would restart behind the ad and the next resume — dismissing
        // it — would look like another return.
        if (!_isShowing) _leftAt = DateTime.now();
      case AppLifecycleState.resumed:
        _maybeShowOnReturn();
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _maybeShowOnReturn() {
    if (_isShowing || !AdService.adsReady.value) return;

    final left = _leftAt;
    if (left == null) return; // cold start, not a return
    final away = DateTime.now().difference(left);
    _leftAt = null;

    // Never over the navigation screen. The long rides where a rider locks
    // the phone for 15+ minutes are exactly the ones where they unlock it
    // to see where to get off.
    if (NavigationSession.isActive || TripPip.active.value) {
      _load();
      return;
    }

    if (away < minimumTimeAway) {
      // Back too soon to monetise. Take the opportunity to top up the cache
      // so the next qualifying return has an ad ready.
      _load();
      return;
    }

    // Already had its share of app open ads; keep the cached one for later.
    if (!capAllows(_shown, DateTime.now())) return;

    if (!_isAdAvailable) {
      _load();
      return;
    }

    final ad = _ad!;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) => _showGuard?.cancel(),
      onAdDismissedFullScreenContent: (ad) {
        _clearShowing();
        ad.dispose();
        _ad = null;
        _loadedAt = null;
        _load();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('App open ad failed to show: $error');
        _clearShowing();
        ad.dispose();
        _ad = null;
        _loadedAt = null;
        _load();
      },
    );
    _ad = null;
    // Set now, not in onAdShowedFullScreenContent: the ad covering the app
    // can pause it before that callback arrives, and the pause would start
    // the away-clock again. A failed show clears it in its own callback.
    _isShowing = true;
    // If neither "showed" nor "failed" ever arrives, stop waiting.
    _showGuard = Timer(showGuard, () {
      debugPrint('App open ad: no show callback, clearing');
      _clearShowing();
      ad.dispose();
      _loadedAt = null;
      _load();
    });
    _recordShown(DateTime.now());
    try {
      ad.show();
    } catch (e) {
      debugPrint('App open ad show threw: $e');
      _clearShowing();
      ad.dispose();
      _loadedAt = null;
      _load();
    }
  }
}
