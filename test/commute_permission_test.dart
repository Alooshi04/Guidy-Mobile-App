import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/SettingsScreen.dart';
import 'package:guidy_app/services/commute/commute_notifications.dart';
import 'package:guidy_app/services/commute/commute_planner.dart';
import 'package:guidy_app/services/commute/commute_store.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Owner, 2026-10-22: on the latest build no commute notification ever
/// arrived. Alerts are on by default, so nobody switches them on in
/// Settings, and planning from "my location" rarely lands within 400 m of
/// the saved Home: the two places that asked for the notification
/// permission never ran, while the app-start refresh scheduled a week of
/// notifications that Android 13+ drops without the permission.
///
/// These drive the real plugin and record what it would send to Android.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  late List<String> calls;
  var blocked = false;

  setUp(() {
    calls = [];
    blocked = false;
    CommuteNotifications.debugSupported = true;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    FlutterLocalNotificationsPlatform.instance = AndroidFlutterLocalNotificationsPlugin();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'initialize':
        case 'requestNotificationsPermission':
          return true;
        case 'pendingNotificationRequests':
          return <Map<String, Object?>>[];
        case 'areNotificationsEnabled':
          return !blocked;
        default:
          return null;
      }
    });
    SharedPreferences.setMockInitialValues({
      'Home': 'Home|30.0444|31.2357',
      'Work': 'Work|30.0626|31.3300',
    });
  });

  tearDown(() {
    CommuteNotifications.debugSupported = null;
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  Future<void> saveCommuteLines() async {
    final prefs = await SharedPreferences.getInstance();
    final hw = CommuteNotifications.homeWorkFrom(prefs)!;
    await CommuteStore.saveLines([const CommuteLine(routeId: 'B910', label: 'Bus 910')],
        homeWorkKey: CommuteNotifications.keyOf(hw));
  }

  test('at app start, the rider is asked for permission before the week is scheduled', () async {
    await saveCommuteLines();

    await CommuteNotifications.refresh();

    expect(calls, contains('zonedSchedule'), reason: 'the week is scheduled');
    expect(calls, contains('requestNotificationsPermission'),
        reason: 'without it Android 13+ drops every scheduled notification');
    expect(calls.indexOf('requestNotificationsPermission'), lessThan(calls.indexOf('zonedSchedule')));
  });

  test('the rider is asked only once', () async {
    await saveCommuteLines();

    await CommuteNotifications.refresh();
    await CommuteNotifications.refresh();

    expect(calls.where((m) => m == 'requestNotificationsPermission'), hasLength(1));
  });

  test('blocked notifications are reported, so Settings can say so', () async {
    blocked = true;
    expect(await CommuteNotifications.notificationsAllowed(), isFalse);
    blocked = false;
    expect(await CommuteNotifications.notificationsAllowed(), isTrue);
  });

  group('Settings', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = null; // the variant sets it
      PackageInfo.setMockInitialValues(
          appName: 'Guidy', packageName: 'app.guidy', version: '1.1.0', buildNumber: '23', buildSignature: '');
    });

    Future<void> openSettings(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400 * 2.0, 2400 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const SettingsScreen(),
      ));
      await tester.pumpAndSettle();
    }

    // The variant sets and resets the platform, as testWidgets requires.
    final android = TargetPlatformVariant.only(TargetPlatform.android);

    testWidgets('says when the phone blocks the alerts', (tester) async {
      blocked = true;
      await openSettings(tester);
      expect(find.byKey(const ValueKey('commute-notifs-blocked')), findsOneWidget);
      expect(find.text('Turn on in phone settings'), findsOneWidget);
    }, variant: android);

    testWidgets('says nothing when they are allowed', (tester) async {
      blocked = false;
      await openSettings(tester);
      expect(find.byKey(const ValueKey('commute-notifs-blocked')), findsNothing);
    }, variant: android);
  });

  test('nothing to notify about, nothing asked', () async {
    // No commute lines yet (and no Home/Work search succeeds offline).
    SharedPreferences.setMockInitialValues({});

    await CommuteNotifications.refresh();

    expect(calls, isNot(contains('requestNotificationsPermission')));
    expect(calls, isNot(contains('zonedSchedule')));
  });
}
