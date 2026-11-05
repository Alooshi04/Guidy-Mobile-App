import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../l10n/app_localizations.dart';
import '../services/ad_service.dart';
import '../theme/app_theme.dart';

/// Real AdMob banner (standard 320x50), refreshed on a timer.
///
/// REFRESH INTERVAL
///
/// AdMob's custom refresh range is **30–150 seconds**. Anything faster is
/// not offered in the console and, done in code, is the textbook pattern
/// behind an "invalid traffic" serving limit — Google counts impressions
/// the rider had no chance to see. 30 seconds is therefore the floor, and
/// [_refreshInterval] is clamped to it rather than trusted.
///
/// IMPORTANT — pick ONE refresh mechanism. If automatic refresh is also
/// enabled for this ad unit in the AdMob console, the unit refreshes twice
/// per cycle: once server-side and once from this timer. That is worse than
/// either alone. Using this widget's timer means **turning automatic
/// refresh off** for the banner unit in the console.
///
/// The timer stops whenever the app is not in the foreground. A banner that
/// keeps cycling in the background bills impressions nobody saw, which is
/// the same invalid-traffic problem arriving by a quieter route.
class BannerAdPlaceholder extends StatefulWidget {
  final double? bottomMargin;

  /// When no ad ever loads, keep the slot's height (empty) instead of
  /// collapsing it. A slot that collapses a few seconds after launch moves
  /// the whole screen below it, and a tap aimed at one control lands on
  /// another.
  final bool maintainSlotOnFailure;

  /// Told whenever the slot collapses (no ad could be loaded) or comes back,
  /// so the screen below can take back the space.
  final ValueChanged<bool>? onCollapsedChanged;

  /// False while the shell keeps the banner offstage (keyboard open, floating
  /// trip window). No timer runs and no request goes out until it is true
  /// again: an impression nobody can see is invalid traffic.
  final bool visible;

  const BannerAdPlaceholder({
    super.key,
    this.visible = true,
    this.bottomMargin,
    this.maintainSlotOnFailure = false,
    this.onCollapsedChanged,
  });

  /// Wait before the next request after [failures] misses in a row: the
  /// normal refresh interval, doubling to a five minute ceiling. A phone with
  /// no fill (account not approved, no network) asks a handful of times an
  /// hour, not every 30 seconds.
  static Duration retryDelay(int failures) {
    if (failures <= 0) return refreshInterval;
    final seconds = refreshInterval.inSeconds * (1 << (failures > 4 ? 4 : failures));
    return Duration(seconds: seconds > 300 ? 300 : seconds);
  }

  /// A refresh may be queued only while the banner can be seen and no
  /// request (or first request) is outstanding.
  @visibleForTesting
  static bool canSchedule({required bool visible, required bool inFlight, required bool initialPending}) =>
      visible && !inFlight && !initialPending;

  /// Requested refresh interval. Clamped to AdMob's 30-second minimum.
  static const Duration refreshInterval = Duration(seconds: 30);

  @override
  State<BannerAdPlaceholder> createState() => _BannerAdPlaceholderState();
}

class _BannerAdPlaceholderState extends State<BannerAdPlaceholder>
    with WidgetsBindingObserver {
  static const Duration _admobMinimumRefresh = Duration(seconds: 30);

  /// Breathing room below the ad, before the screen's own controls.
  /// AdMob names close proximity to interactive elements as "one of the
  /// biggest causes of accidental clicks" -- which is what gets an account
  /// flagged, not the placement itself. 16 rather than 8: every screen's
  /// back button, search field or map control starts right below it.
  static const double _separationBelow = 16;

  Duration get _refreshInterval =>
      BannerAdPlaceholder.refreshInterval < _admobMinimumRefresh
          ? _admobMinimumRefresh
          : BannerAdPlaceholder.refreshInterval;

  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _failed = false;
  bool _waitingForConsent = false;
  int _failures = 0;
  bool? _reportedCollapsed;
  Timer? _refreshTimer;

  /// A request is on its way. A resume or an un-hide must not start another.
  bool _inFlight = false;

  /// Consent was ready but the banner was hidden, so the first request waits.
  bool _initialPending = false;

  @override
  void initState() {
    super.initState();
    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    if (isMobile && AdService.adsEnabled) {
      WidgetsBinding.instance.addObserver(this);
      if (AdService.adsReady.value) {
        _startInitial();
      } else {
        // No request until Google's consent flow says ads are allowed.
        _waitingForConsent = true;
        AdService.adsReady.addListener(_onAdsReady);
      }
    } else {
      _failed = true;
    }
    _reportCollapsed();
  }

  void _onAdsReady() {
    if (!mounted || !AdService.adsReady.value || !_waitingForConsent) return;
    _waitingForConsent = false;
    AdService.adsReady.removeListener(_onAdsReady);
    _startInitial();
  }

  void _startInitial() {
    if (!widget.visible) {
      _initialPending = true;
      return;
    }
    _initialPending = false;
    _loadAd(initial: true);
  }

  @override
  void didUpdateWidget(BannerAdPlaceholder old) {
    super.didUpdateWidget(old);
    if (old.visible == widget.visible || _waitingForConsent) return;
    if (!widget.visible) {
      _refreshTimer?.cancel();
    } else if (_initialPending) {
      _startInitial();
    } else {
      _scheduleRefresh();
    }
  }

  bool get _collapsed => _failed || _waitingForConsent;

  /// Reported after the frame: the slot's size feeds a widget above this one.
  void _reportCollapsed() {
    final cb = widget.onCollapsedChanged;
    if (cb == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _reportedCollapsed == _collapsed) return;
      _reportedCollapsed = _collapsed;
      cb(_collapsed);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_waitingForConsent) return;
    if (state == AppLifecycleState.resumed) {
      _scheduleRefresh();
    } else {
      _refreshTimer?.cancel();
    }
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    if (!BannerAdPlaceholder.canSchedule(visible: widget.visible, inFlight: _inFlight, initialPending: _initialPending)) return;
    final base = _refreshInterval;
    final wait = BannerAdPlaceholder.retryDelay(_failures);
    _refreshTimer = Timer(wait < base ? base : wait, _refreshAd);
  }

  void _loadAd({bool initial = false}) {
    _inFlight = true;
    final ad = BannerAd(
      adUnitId: AdService.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _inFlight = false;
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = ad as BannerAd;
            _isLoaded = true;
            _failed = false;
            _failures = 0;
          });
          _reportCollapsed();
          _scheduleRefresh();
        },
        onAdFailedToLoad: (ad, error) {
          _inFlight = false;
          ad.dispose();
          if (!mounted) return;
          _failures++;
          if (initial) {
            setState(() => _failed = true);
            _reportCollapsed();
          }
          // A failed refresh keeps the ad already on screen. Either way the
          // next try backs off, so no fill is not a request loop.
          _scheduleRefresh();
        },
      ),
    );
    ad.load();
  }

  /// Loads a replacement before retiring the current one. Disposing the ad
  /// that an [AdWidget] is still rendering tears down the platform view
  /// underneath it, so the swap only happens once the new ad is ready.
  void _refreshAd() {
    if (!mounted || !widget.visible) return;
    if (!AdService.adsReady.value) {
      // Consent withdrawn from Settings: stop requesting, drop the ad.
      _bannerAd?.dispose();
      setState(() {
        _bannerAd = null;
        _isLoaded = false;
        _failed = false;
        _waitingForConsent = true;
      });
      AdService.adsReady.addListener(_onAdsReady);
      _reportCollapsed();
      return;
    }
    final BannerAd? outgoing = _bannerAd;
    _inFlight = true;

    final next = BannerAd(
      adUnitId: AdService.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _inFlight = false;
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = ad as BannerAd;
            _isLoaded = true;
            _failed = false;
            _failures = 0;
          });
          _reportCollapsed();
          outgoing?.dispose();
          _scheduleRefresh();
        },
        onAdFailedToLoad: (ad, error) {
          _inFlight = false;
          ad.dispose();
          if (!mounted) return;
          _failures++;
          _scheduleRefresh();
        },
      ),
    );
    next.load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AdService.adsReady.removeListener(_onAdsReady);
    _refreshTimer?.cancel();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    if (!isMobile) return const SizedBox.shrink();

    final double effectiveBottomMargin = widget.bottomMargin ?? _separationBelow;

    if (_waitingForConsent) return const SizedBox.shrink();

    if (_failed) {
      if (!widget.maintainSlotOnFailure) return const SizedBox.shrink();
      // Same height as the loading placeholder and the loaded banner, so the
      // layout never moves whichever way the first request turns out.
      return SafeArea(
        top: true,
        bottom: false,
        child: SizedBox(width: double.infinity, height: 50 + effectiveBottomMargin),
      );
    }

    if (!_isLoaded || _bannerAd == null) {
      return AdPlaceholderStrip(bottomMargin: effectiveBottomMargin);
    }

    return SafeArea(
      top: true,
      bottom: false,
      child: Container(
        width: double.infinity,
        height: _bannerAd!.size.height.toDouble(),
        margin: EdgeInsets.only(bottom: effectiveBottomMargin),
        alignment: Alignment.center,
        color: context.surfaceCard,
        child: SizedBox(
          width: _bannerAd!.size.width.toDouble(),
          height: _bannerAd!.size.height.toDouble(),
          child: AdWidget(ad: _bannerAd!),
        ),
      ),
    );
  }
}

/// The 50 px strip shown while no ad has loaded: the app's card colour in
/// either theme (it was always white, a bright bar in dark mode).
class AdPlaceholderStrip extends StatelessWidget {
  const AdPlaceholderStrip({super.key, required this.bottomMargin});

  final double bottomMargin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final edge = context.isDark ? Colors.white12 : Colors.black12;
    return SafeArea(
      top: true,
      bottom: false,
      child: Container(
        key: const ValueKey('ad_placeholder_strip'),
        width: double.infinity,
        height: 50,
        margin: EdgeInsets.only(bottom: bottomMargin),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.surfaceCard,
          border: Border(top: BorderSide(color: edge), bottom: BorderSide(color: edge)),
        ),
        child: Text(
          l10n.adPlaceholderLabel,
          style: TextStyle(color: context.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
