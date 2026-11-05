import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

// Updated import paths to point to your screens folder
import 'screens/AuthGate.dart';
import 'screens/SignUpScreen.dart';
import 'services/api_service.dart';
import 'services/banner_hide_service.dart';
import 'services/locale_controller.dart';
import 'services/theme_controller.dart';
import 'services/analytics_service.dart';
import 'services/ad_service.dart';
import 'services/consent_service.dart';
import 'services/telemetry_consent.dart';
import 'services/tracking_service.dart';
import 'services/deep_link_service.dart';
import 'services/app_open_ad_service.dart';
import 'theme/app_theme.dart';
import 'widgets/animated_splash.dart';
import 'l10n/app_localizations.dart';
import 'firebase_options.dart';
import 'widgets/app_banner_shell.dart';
import 'widgets/system_bars_style.dart';
import 'services/simple_mode.dart';
import 'services/trip_sharing.dart';
import 'services/trip_recorder.dart';
import 'services/commute/commute_notifications.dart';
import 'services/current_trip.dart';
import 'services/trip_notification.dart';
import 'widgets/trip/current_trip_card.dart';

/// Lets DeepLinkService push a screen from outside the widget tree (the
/// incoming-link listener isn't itself a widget with a BuildContext).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Named routes. The sign-in screens leave with
/// pushReplacementNamed('/home') and the email-verification screen's sign-out
/// goes to '/signin', and both replace whatever screen was underneath. So
/// both are AuthGate itself: it's the only widget listening to sign-in state,
/// and if it gets replaced, Log Out signs Firebase out but the app stays on
/// screen. AuthGate already wraps the app in the email-verification and
/// legal-consent gates.
final Map<String, WidgetBuilder> appRoutes = {
  '/home': (context) => const AuthGate(),
  '/signin': (context) => const AuthGate(),
  '/signup': (context) => const SignUpScreen(),
};

void main() {
  // Everything -- including WidgetsFlutterBinding.ensureInitialized() and
  // runApp -- runs inside the SAME zone created by runZonedGuarded. Doing
  // the binding init before/outside this call (as this used to) trips
  // Flutter's "Zone mismatch" assertion on every launch: the binding
  // is initialized in the root zone while runApp then runs in a
  // different (guarded) zone, which is exactly the inconsistency
  // BindingBase.debugCheckZone warns about. It's non-fatal in debug mode,
  // but it's still a real bug -- zone-specific state (like this error
  // handler) can silently attach to the wrong zone depending on timing.
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      final bool isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

      // Initialize Firebase Safely
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (e) {
        debugPrint(
          "Firebase initialized natively or caught an options error: $e",
        );
      }

      final bool isFirebaseReady = Firebase.apps.isNotEmpty;

      // Crashlytics: route all uncaught Flutter framework errors there. Only
      // active on real mobile devices/builds with initialized Firebase.
      if (!kDebugMode && isFirebaseReady && isMobile) {
        FlutterError.onError =
            FirebaseCrashlytics.instance.recordFlutterFatalError;
        PlatformDispatcher.instance.onError = (error, stack) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
          return true;
        };
      }

      // Load saved preferences before the first frame so the app doesn't flash
      // in the wrong language/theme. Theme defaults to following the device's
      // system setting until the person overrides it in Settings.
      await localeController.loadSavedLocale();
      await themeController.loadSavedTheme();
      await simpleMode.load();
      await TripSharing.load();
      await BannerHideService.instance.load();
      // The 24 h hide timer can fire late after the phone slept.
      AppLifecycleListener(onResume: BannerHideService.instance.refresh);
      unawaited(ApiService.init());
      registerBrandFontLicenses();

      runApp(const GuidyApp());

      // Permission prompts and the ads SDK start AFTER the first frame. They
      // used to be awaited before runApp, so a cold start showed a blank
      // screen for as long as they took, and a brand-new user was asked for
      // notification permission before seeing a single screen of the app.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_startDeferredServices(isMobile: isMobile));
        // Trips that ended without signal are sent now.
        unawaited(TripRecorder.flushQueue());
      });

      // After runApp so navigatorKey.currentState is available by the time a
      // link actually arrives (cold-start links are still handled correctly
      // -- DeepLinkService checks getInitialLink() too, it just can't act on
      // it until the navigator exists).
      DeepLinkService.initialize(navigatorKey);
      unawaited(_wireTripNotification());
    },
    (error, stack) {
      if (!kDebugMode && Firebase.apps.isNotEmpty) {
        try {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        } catch (_) {
          debugPrint('Uncaught error: $error\n$stack');
        }
      } else {
        debugPrint('Uncaught zone error: $error\n$stack');
      }
    },
  );
}

/// Order matters: Google's consent form (EEA/UK), then iOS App Tracking
/// Transparency (it cannot show two system dialogs at once), then the ads
/// SDK -- all inside ConsentService.gather.
Future<void> _startDeferredServices({required bool isMobile}) async {
  if (!isMobile) return;

  // A week of commute notifications, planned on the phone from the saved
  // Home <-> Work route's lines. Not held up behind the consent form.
  unawaited(CommuteNotifications.refresh());

  if (!AdService.adsEnabled) {
    await TelemetryConsent.applyWithoutConsentForm();
    return;
  }

  // No push-notification service is started: nothing sends pushes yet, so
  // asking riders for that permission would do nothing. Add one back once
  // the backend stores tokens and something is actually sent.
  // Consent first (Google's UMP: EEA/UK users are asked), then iOS tracking,
  // then the ads SDK. Nothing requests an ad unless UMP allows it.
  await ConsentService.instance
      .gather(beforeAdsInit: TrackingService.requestAuthorization);

  // Full-screen ad when a rider returns after being away a while. Started
  // now if ads are allowed, otherwise the moment consent resolves later.
  try {
    AppOpenAdService.instance.initializeWhenReady();
  } catch (e) {
    debugPrint('AppOpenAdService initialization error: $e');
  }
}

/// Holds the launch animation for its full length, then opens the app.
/// (There used to be a three-card intro carousel here on first launch.)
class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  // Created once, in initState: GuidyApp rebuilds on every locale or theme
  // change, and a future built in build() would replay the splash each time.
  late final Future<void> _splash = Future<void>.delayed(AnimatedSplash.duration);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _splash,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const AnimatedSplash();
        // No banner yet: MainNavigator turns it on. AdMob does not allow ads
        // on the sign-in, loading, verification and consent screens.
        return const AuthGate();
      },
    );
  }
}

class GuidyApp extends StatelessWidget {
  const GuidyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: localeController,
      builder: (context, locale, _) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: themeController,
          builder: (context, mode, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: simpleMode,
              builder: (context, simple, _) => MaterialApp(
                navigatorKey: navigatorKey,
                title: 'Guidy Transit',
                debugShowCheckedModeBanner: false,
                locale: locale,
                supportedLocales: const [Locale('en'), Locale('ar', 'EG')],
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                theme: AppTheme.light(locale, simple: simple),
                darkTheme: AppTheme.dark(locale, simple: simple),
                // Follows the device's system setting until the person flips
                // the Dark Mode switch in Settings, which sets an explicit
                // override (see ThemeController).
                themeMode: mode,
                navigatorObservers: [AnalyticsService.observer],
                // StartupGate holds the splash, then AuthGate makes the
                // signed-in-vs-not routing decision.
                home: const StartupGate(),
                builder: (context, child) {
                  Widget page = SystemBarsStyle(
                    child: AppBannerShell(
                      child: child ?? const SizedBox.shrink(),
                    ),
                  );
                  if (simple) {
                    // Simple mode: at least 30% larger text everywhere, more
                    // if the phone's own setting already asks for it.
                    final mq = MediaQuery.of(context);
                    final scale = mq.textScaler.scale(1.0);
                    page = MediaQuery(
                      data: mq.copyWith(
                        textScaler: TextScaler.linear(
                          scale < SimpleModeController.textScale
                              ? SimpleModeController.textScale
                              : scale,
                        ),
                      ),
                      child: page,
                    );
                  }
                  return page;
                },
                routes: appRoutes,
              ),
            );
          },
        );
      },
    );
  }
}

/// The trip's phone notification: shown for a trip saved by an earlier run,
/// and tapping it (also the one that launched the app) opens the live trip.
Future<void> _wireTripNotification() async {
  void open() {
    final nav = navigatorKey.currentState;
    final trip = CurrentTrip.active.value;
    if (nav != null && trip != null && !CurrentTrip.isStale(trip)) CurrentTripCard.resume(nav, trip);
  }

  CommuteNotifications.onTap = (payload) {
    if (payload == TripNotification.payload) open();
  };
  await TripNotification.restore();
  try {
    if (!CommuteNotifications.supported) return;
    await CommuteNotifications.init();
    final launch = await CommuteNotifications.plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true && launch?.notificationResponse?.payload == TripNotification.payload) {
      open();
    }
  } catch (_) {}
}
