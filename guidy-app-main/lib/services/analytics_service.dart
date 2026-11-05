import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Wraps FirebaseAnalytics with named events for Guidy's key actions,
/// so call sites read "AnalyticsService.logRouteCalculated(...)" instead
/// of hand-rolling event names/parameters in every screen.
class AnalyticsService {
  static FirebaseAnalytics? get _analytics {
    try {
      return Firebase.apps.isNotEmpty ? FirebaseAnalytics.instance : null;
    } catch (_) {
      return null;
    }
  }

  static NavigatorObserver? _observer;

  static NavigatorObserver get observer => _observer ??= _createObserver();

  static NavigatorObserver _createObserver() {
    try {
      final analytics = _analytics;
      if (analytics != null) {
        return FirebaseAnalyticsObserver(analytics: analytics);
      }
    } catch (e) {
      // ignore
    }
    return NavigatorObserver();
  }

  static Future<void> logSignIn(String method) async {
    try {
      await _analytics?.logLogin(loginMethod: method);
    } catch (e) {
      // ignore -- analytics is best-effort, never fatal to the app.
    }
  }

  static Future<void> logSignUp(String method) async {
    try {
      await _analytics?.logSignUp(signUpMethod: method);
    } catch (e) {
      // ignore -- analytics is best-effort, never fatal to the app.
    }
  }

  static Future<void> logRouteCalculated({required bool success}) async {
    // Firebase Analytics event parameters must be String or num -- a raw
    // bool fails _assertParameterTypesAreCorrect with an uncaught zone
    // error (this call is fire-and-forget at every call site, so that
    // error never surfaces where it's actually caused; it just spams the
    // console as an unrelated-looking crash). Encode as 0/1 instead.
    // Also swallow any analytics failure here -- logging a route
    // calculation should never be able to break the actual route flow.
    try {
      await _analytics?.logEvent(
        name: 'route_calculated',
        parameters: {'success': success ? 1 : 0},
      );
    } catch (e) {
      // ignore -- analytics is best-effort, never fatal to the app.
    }
  }

  static Future<void> logSavedPlaceAdded() async {
    try {
      await _analytics?.logEvent(name: 'saved_place_added');
    } catch (e) {
      // ignore -- analytics is best-effort, never fatal to the app.
    }
  }

  static Future<void> logLanguageChanged(String languageCode) async {
    try {
      await _analytics?.logEvent(name: 'language_changed', parameters: {'language': languageCode});
    } catch (e) {
      // ignore -- analytics is best-effort, never fatal to the app.
    }
  }

  static Future<void> logDarkModeToggled(bool isDark) async {
    // Same bool-parameter issue as logRouteCalculated above -- Firebase
    // Analytics rejects non-String/num parameter values.
    try {
      await _analytics?.logEvent(name: 'dark_mode_toggled', parameters: {'is_dark': isDark ? 1 : 0});
    } catch (e) {
      // ignore -- analytics is best-effort, never fatal to the app.
    }
  }

  static Future<void> logTripCompleted() async {
    try {
      await _analytics?.logEvent(name: 'trip_completed');
      await logBreadcrumb('Trip completed');
    } catch (e) {
      // ignore -- analytics is best-effort, never fatal to the app.
    }
  }

  static FirebaseCrashlytics? get _crashlytics {
    try {
      return Firebase.apps.isNotEmpty ? FirebaseCrashlytics.instance : null;
    } catch (_) {
      return null;
    }
  }

  /// Sets a custom key in Crashlytics reports (e.g. 'active_screen', 'is_navigating').
  static Future<void> setCrashlyticsKey(String key, Object value) async {
    try {
      if (value is String) {
        await _crashlytics?.setCustomKey(key, value);
      } else if (value is bool) {
        await _crashlytics?.setCustomKey(key, value);
      } else if (value is int) {
        await _crashlytics?.setCustomKey(key, value);
      } else if (value is double) {
        await _crashlytics?.setCustomKey(key, value);
      } else {
        await _crashlytics?.setCustomKey(key, value.toString());
      }
    } catch (_) {}
  }

  /// Appends a diagnostic breadcrumb log message in Crashlytics.
  static Future<void> logBreadcrumb(String message) async {
    try {
      await _crashlytics?.log(message);
    } catch (_) {}
  }

}
