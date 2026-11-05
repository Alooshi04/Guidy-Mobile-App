import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Ad unit IDs, with Google's public TEST units unless the build is
/// explicitly marked for real ads.
///
/// Real units need TWO things at compile time: the unit ID itself
/// (`--dart-define=ADMOB_..._AD_UNIT_ID_...`) and `--dart-define=GUIDY_REAL_ADS=true`.
/// Only `build_release.ps1 -RealAds` and `run_app.ps1 -RealAds` pass the
/// second. Before it existed, the unit IDs alone switched ads on, and the
/// Mac/iOS scripts pass every value in secrets.properties -- so a build made
/// that way served live ads to its own developer, which is how an AdMob
/// account gets flagged for invalid traffic.
class AdService {
  /// True only for a build made with `-RealAds`.
  static const bool realAds = bool.fromEnvironment('GUIDY_REAL_ADS');

  /// True for a build made with `-NoAds`: no consent flow, no ads SDK, no
  /// banner, no app open ad. For a store build made while the AdMob account
  /// has no approval, when a request for a real unit could not be filled.
  static const bool noAds = bool.fromEnvironment('GUIDY_NO_ADS');

  static bool get adsEnabled => !noAds;

  /// A debug build never requests a live unit, whatever it was compiled with:
  /// a developer's own phone tapping live ads is invalid traffic.
  static bool get useRealUnits => realAds && !kDebugMode;

  /// Flips true once the user's consent allows ad requests (Google's UMP
  /// says so) and the ads SDK is initialised. Nothing requests an ad before.
  static final ValueNotifier<bool> adsReady = ValueNotifier<bool>(false);

  static const String _testBannerAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testBannerIOS = 'ca-app-pub-3940256099942544/2934735716';

  static const String _bannerAndroid = String.fromEnvironment('ADMOB_BANNER_AD_UNIT_ID_ANDROID');
  static const String _bannerIOS = String.fromEnvironment('ADMOB_BANNER_AD_UNIT_ID_IOS');

  static String get bannerAdUnitId => Platform.isAndroid
      ? pickUnit(realAds: useRealUnits, configured: _bannerAndroid, testUnit: _testBannerAndroid)
      : pickUnit(realAds: useRealUnits, configured: _bannerIOS, testUnit: _testBannerIOS);

  // --- App open -----------------------------------------------------------
  // Shown when a rider returns after being away (see app_open_ad_service.dart).
  static const String _testAppOpenAndroid = 'ca-app-pub-3940256099942544/9257395921';
  static const String _testAppOpenIOS = 'ca-app-pub-3940256099942544/5575463023';

  static const String _appOpenAndroid = String.fromEnvironment('ADMOB_APP_OPEN_AD_UNIT_ID_ANDROID');
  static const String _appOpenIOS = String.fromEnvironment('ADMOB_APP_OPEN_AD_UNIT_ID_IOS');

  static String get appOpenAdUnitId => Platform.isAndroid
      ? pickUnit(realAds: useRealUnits, configured: _appOpenAndroid, testUnit: _testAppOpenAndroid)
      : pickUnit(realAds: useRealUnits, configured: _appOpenIOS, testUnit: _testAppOpenIOS);

  // --- Native --------------------------------------------------------------
  // In-content cards at the foot of Home, Metro and Route details (see
  // native_ad_card.dart). Google's native template test units.
  static const String _testNativeAndroid = 'ca-app-pub-3940256099942544/2247696110';
  static const String _testNativeIOS = 'ca-app-pub-3940256099942544/3986624511';

  static const String _nativeAndroid = String.fromEnvironment('ADMOB_NATIVE_AD_UNIT_ID_ANDROID');
  static const String _nativeIOS = String.fromEnvironment('ADMOB_NATIVE_AD_UNIT_ID_IOS');

  /// Null when a real-ads build has no native unit: the cards stay hidden
  /// rather than serving Google's test ads to riders.
  static String? get nativeAdUnitId => Platform.isAndroid
      ? optionalUnit(realAds: useRealUnits, configured: _nativeAndroid, testUnit: _testNativeAndroid)
      : optionalUnit(realAds: useRealUnits, configured: _nativeIOS, testUnit: _testNativeIOS);

  // --- Interstitial ---------------------------------------------------------
  // One full-screen ad when a trip ends (see interstitial_ad_service.dart).
  static const String _testInterstitialAndroid = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testInterstitialIOS = 'ca-app-pub-3940256099942544/4411468910';

  static const String _interstitialAndroid = String.fromEnvironment('ADMOB_INTERSTITIAL_AD_UNIT_ID_ANDROID');
  static const String _interstitialIOS = String.fromEnvironment('ADMOB_INTERSTITIAL_AD_UNIT_ID_IOS');

  /// Null when a real-ads build has no interstitial unit: none is shown.
  static String? get interstitialAdUnitId => Platform.isAndroid
      ? optionalUnit(realAds: useRealUnits, configured: _interstitialAndroid, testUnit: _testInterstitialAndroid)
      : optionalUnit(realAds: useRealUnits, configured: _interstitialIOS, testUnit: _testInterstitialIOS);

  // --- Rewarded -------------------------------------------------------------
  // "Watch an ad to hide the banner for 24 hours" (see rewarded_ad_service.dart).
  static const String _testRewardedAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const String _testRewardedIOS = 'ca-app-pub-3940256099942544/1712485313';

  static const String _rewardedAndroid = String.fromEnvironment('ADMOB_REWARDED_AD_UNIT_ID_ANDROID');
  static const String _rewardedIOS = String.fromEnvironment('ADMOB_REWARDED_AD_UNIT_ID_IOS');

  /// Null when a real-ads build has no rewarded unit: the Settings option is
  /// hidden rather than serving test ads.
  static String? get rewardedAdUnitId => Platform.isAndroid
      ? optionalUnit(realAds: useRealUnits, configured: _rewardedAndroid, testUnit: _testRewardedAndroid)
      : optionalUnit(realAds: useRealUnits, configured: _rewardedIOS, testUnit: _testRewardedIOS);

  /// Like [pickUnit], but a real-ads build without a configured unit gets
  /// none, for a format that may ship before its unit exists.
  static String? optionalUnit({required bool realAds, required String configured, required String testUnit}) {
    if (!realAds) return testUnit;
    return configured.isNotEmpty ? configured : null;
  }

  /// The unit to request: the configured one only in a real-ads build.
  static String pickUnit({required bool realAds, required String configured, required String testUnit}) =>
      realAds && configured.isNotEmpty ? configured : testUnit;

  /// True if this build serves Google's public test ads.
  static bool get isUsingTestAds => bannerAdUnitId == _testBannerAndroid || bannerAdUnitId == _testBannerIOS;
}
