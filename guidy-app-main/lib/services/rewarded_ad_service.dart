import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_service.dart';
import 'banner_hide_service.dart';

enum RewardedResult { rewarded, notWatched, unavailable }

/// "Watch a short ad to hide the banner for 24 hours". Loaded only when the
/// rider asks, so nothing is requested for people who never use it.
class RewardedAdService {
  RewardedAdService._();
  static final RewardedAdService instance = RewardedAdService._();

  bool _busy = false;

  /// False where the option should not appear: ads off, unsupported platform,
  /// or a real-ads build without a rewarded unit.
  static bool get isOffered =>
      !kIsWeb &&
      (Platform.isAndroid || Platform.isIOS) &&
      AdService.adsEnabled &&
      AdService.rewardedAdUnitId != null;

  /// Loads and shows the ad. [RewardedResult.rewarded] only when the rider
  /// earned it; the banner is then hidden for 24 hours.
  Future<RewardedResult> watchToHideBanner() async {
    final unit = AdService.rewardedAdUnitId;
    if (_busy || unit == null || !AdService.adsReady.value) return RewardedResult.unavailable;
    _busy = true;
    final done = Completer<RewardedResult>();
    var earned = false;
    RewardedAd.load(
      adUnitId: unit,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              if (!done.isCompleted) done.complete(earned ? RewardedResult.rewarded : RewardedResult.notWatched);
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('Rewarded ad failed to show: $error');
              ad.dispose();
              if (!done.isCompleted) done.complete(RewardedResult.unavailable);
            },
          );
          ad.show(onUserEarnedReward: (_, _) {
            earned = true;
            unawaited(BannerHideService.instance.hideForDay());
          });
        },
        onAdFailedToLoad: (error) {
          debugPrint('Rewarded ad failed to load: $error');
          if (!done.isCompleted) done.complete(RewardedResult.unavailable);
        },
      ),
    );
    try {
      return await done.future.timeout(const Duration(minutes: 5), onTimeout: () => RewardedResult.unavailable);
    } finally {
      _busy = false;
    }
  }
}
