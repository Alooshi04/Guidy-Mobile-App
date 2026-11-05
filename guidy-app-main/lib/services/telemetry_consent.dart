import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// The Firebase calls [TelemetryConsent] makes, split out so tests can fake them.
abstract class TelemetrySink {
  Future<void> setAnalytics(bool on);
  Future<void> setCrashlytics(bool on);
}

class FirebaseTelemetrySink implements TelemetrySink {
  const FirebaseTelemetrySink();

  @override
  Future<void> setAnalytics(bool on) async {
    if (Firebase.apps.isEmpty) return;
    final a = FirebaseAnalytics.instance;
    await a.setAnalyticsCollectionEnabled(on);
    await a.setConsent(
      analyticsStorageConsentGranted: on,
      adStorageConsentGranted: on,
      adUserDataConsentGranted: on,
      adPersonalizationSignalsConsentGranted: on,
    );
  }

  @override
  Future<void> setCrashlytics(bool on) async {
    if (Firebase.apps.isEmpty) return;
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(on);
  }
}

/// Firebase Analytics and Crashlytics are OFF at install (manifest /
/// Info.plist defaults) and are switched on here only once consent is
/// resolved: when Google's UMP says the user may be shown ads
/// (`canRequestAds`: consent given, or not required where they live).
/// A user who refuses, or whose consent is withdrawn in "Ad privacy
/// settings", keeps collection off.
///
/// Builds made with `-NoAds` have no UMP, so no consent is ever collected:
/// collection stays off there unless built with
/// `--dart-define=GUIDY_TELEMETRY=true` (internal testing builds).
class TelemetryConsent {
  TelemetryConsent._();

  static const bool noAdsOptIn = bool.fromEnvironment('GUIDY_TELEMETRY');

  static TelemetrySink sink = const FirebaseTelemetrySink();

  /// Last value applied (null: not decided yet this launch).
  static bool? applied;

  static Future<void> apply(bool on) async {
    applied = on;
    try {
      await sink.setAnalytics(on);
      await sink.setCrashlytics(on && !kDebugMode);
    } catch (e) {
      debugPrint('Telemetry consent error: $e');
    }
  }

  /// For builds with no consent form.
  static Future<void> applyWithoutConsentForm() => apply(noAdsOptIn);
}
