import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

/// iOS App Tracking Transparency (ATT). Apple requires this prompt before
/// an app can use IDFA-based ad tracking -- google_mobile_ads uses IDFA by
/// default, so without this, Apple will reject the app on submission.
///
/// No-op on Android (the permission doesn't exist there) and in debug mode
/// on the simulator, where the system dialog doesn't reliably appear.
///
/// Call this once, on iOS only, *before* MobileAds.instance.initialize()
/// -- see main.dart -- so the ad SDK already knows the tracking decision
/// by the time it requests its first ad. Whatever the person chooses,
/// initialization continues normally: declining tracking means AdMob
/// falls back to non-personalized ads, not no ads.
class TrackingService {
  static Future<void> requestAuthorization() async {
    if (!Platform.isIOS) return;

    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;

      // Already answered (a previous launch, or restored from backup) --
      // nothing to prompt for.
      if (status != TrackingStatus.notDetermined) {
        debugPrint('[ATT] Already resolved: $status');
        return;
      }

      // iOS won't show two native permission dialogs at once -- if one is
      // still animating away (e.g. the consent form that runs just before
      // this in main.dart), the second call gets silently dropped. This delay
      // is the same one the plugin's own docs recommend.
      await Future.delayed(const Duration(milliseconds: 300));

      final result = await AppTrackingTransparency.requestTrackingAuthorization();
      debugPrint('[ATT] Result: $result');
    } catch (e) {
      // Never let a tracking-permission failure block app startup.
      debugPrint('[ATT] Request failed (continuing without tracking): $e');
    }
  }
}
