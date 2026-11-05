import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ad_service.dart';
import 'app_open_ad_service.dart';
import 'interstitial_policy.dart';
import 'navigation_session.dart';
import 'trip_pip.dart';

/// One interstitial when a rider finishes a trip.
///
/// WHEN: only from the arrival sheet, after "you have arrived" has been read
/// and the rider taps Done or History; never during navigation and never in
/// the floating window. Caps live in [InterstitialPolicy]; the times are kept
/// in SharedPreferences so they survive restarts. Never on the first trip
/// after install. The ad is loaded when a trip starts so it is ready on
/// arrival; if it is not, nothing shows.
class InterstitialAdService {
  InterstitialAdService({DateTime Function()? clock, DateTime? Function()? lastAppOpenShownAt})
      : _clock = clock ?? DateTime.now,
        _lastAppOpenShownAt = lastAppOpenShownAt ?? (() => AppOpenAdService.instance.lastShownAt);

  static final InterstitialAdService instance = InterstitialAdService();

  static const String _shownKey = 'interstitial_shown_ms';
  static const String _tripsKey = 'interstitial_completed_trips';

  /// Google drops a loaded interstitial after an hour.
  static const Duration _adValidity = Duration(minutes: 55);

  final DateTime Function() _clock;
  final DateTime? Function() _lastAppOpenShownAt;

  InterstitialAd? _ad;
  DateTime? _loadedAt;
  bool _loading = false;
  bool _showing = false;

  /// Set when the arrival is recorded, consumed by [showAfterTrip]: one per trip.
  bool _tripEligible = false;

  /// The pending [recordArrival], so a quick tap on Done waits for it.
  Future<void>? _arrival;

  /// Whether the trip just recorded may carry an ad (before the loaded-ad and
  /// navigation checks in [showAfterTrip]).
  @visibleForTesting
  bool get tripEligible => _tripEligible;

  bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS) && AdService.adsEnabled;

  /// A trip started: warm an ad so it is ready on arrival.
  void preload() {
    if (!_supported || !AdService.adsReady.value) return;
    final unit = AdService.interstitialAdUnitId;
    if (unit == null || _loading || _showing || _isFresh) return;
    _loading = true;
    InterstitialAd.load(
      adUnitId: unit,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loadedAt = _clock();
          _loading = false;
        },
        onAdFailedToLoad: (error) {
          debugPrint('Interstitial failed to load: $error');
          _loading = false;
        },
      ),
    );
  }

  bool get _isFresh => _ad != null && _loadedAt != null && _clock().difference(_loadedAt!) < _adValidity;

  /// The rider arrived. Counts the trip and decides whether this one may
  /// carry an ad. Call once per trip.
  Future<void> recordArrival() => _arrival = _recordArrival();

  Future<void> _recordArrival() async {
    final prefs = await SharedPreferences.getInstance();
    final before = prefs.getInt(_tripsKey) ?? 0;
    await prefs.setInt(_tripsKey, before + 1);
    _tripEligible = InterstitialPolicy.canShow(
      now: _clock(),
      shownAt: _storedTimes(prefs),
      completedTripsBefore: before,
      lastAppOpenShownAt: _lastAppOpenShownAt(),
    );
  }

  /// Shows the ad if this trip earned one and one is loaded; otherwise does
  /// nothing. Never throws.
  Future<void> showAfterTrip() async {
    await _arrival;
    if (!_tripEligible) return;
    _tripEligible = false;
    if (_showing || !_supported || !AdService.adsReady.value) return;
    if (!_isFresh) return;

    // Done pops the map; it leaves navigation only once the pop transition
    // has finished and MapScreen is disposed. Never over navigation, so wait
    // for that, and give up if it does not end.
    for (var i = 0; i < 20 && NavigationSession.isActive; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (NavigationSession.isActive || TripPip.active.value) return;
    final ad = _isFresh ? _ad : null;
    if (ad == null) return;

    // Re-check: the app open ad may have shown while the sheet was open.
    final prefs = await SharedPreferences.getInstance();
    final now = _clock();
    if (!InterstitialPolicy.canShow(
      now: now,
      shownAt: _storedTimes(prefs),
      completedTripsBefore: 1,
      lastAppOpenShownAt: _lastAppOpenShownAt(),
    )) {
      return;
    }

    _ad = null;
    _loadedAt = null;
    _showing = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        _showing = false;
        ad.dispose();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Interstitial failed to show: $error');
        _showing = false;
        ad.dispose();
      },
    );
    // Only the last two days matter for the caps.
    final cutoff = now.subtract(const Duration(days: 2));
    final kept = [
      for (final t in _storedTimes(prefs))
        if (t.isAfter(cutoff)) t.millisecondsSinceEpoch,
      now.millisecondsSinceEpoch,
    ];
    await prefs.setStringList(_shownKey, [for (final t in kept) '$t']);
    try {
      await ad.show();
    } catch (e) {
      debugPrint('Interstitial show error: $e');
      _showing = false;
      ad.dispose();
    }
  }

  List<DateTime> _storedTimes(SharedPreferences prefs) => [
        for (final s in prefs.getStringList(_shownKey) ?? const <String>[])
          if (int.tryParse(s) != null) DateTime.fromMillisecondsSinceEpoch(int.parse(s)),
      ];
}
