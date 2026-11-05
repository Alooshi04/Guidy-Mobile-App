import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/MapScreen.dart';
import 'package:guidy_app/services/notification_permission.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Owner, 2026-10-30, after a phone test: End trip at the bottom of the
/// trip sheet, notifications asked once on first launch, "Notifications"
/// in Settings, the Simple mode hint's Arabic, and no native ad validator.

Map<String, dynamic> _trip() => {
      'instructions': [
        {'action': 'walk_to_station', 'station': 'Ramses', 'lat': 30.05, 'lon': 31.24, 'distance_m': 200},
        {'action': 'board', 'station': 'Ramses', 'route_id': 'R1', 'route_number': '66', 'vehicle_type': 'minibus', 'lat': 30.05, 'lon': 31.24},
        {'action': 'arrive', 'station': 'Tahrir', 'lat': 30.06, 'lon': 31.25},
      ],
      'option': {'type': 'Recommended', 'time': '30', 'fare_egp': 10},
      'segments': [],
    };

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('End trip in the trip sheet', () {
    Future<void> open(WidgetTester tester) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.padding = const FakeViewPadding(bottom: 48 * 3);
      tester.view.viewPadding = const FakeViewPadding(bottom: 48 * 3);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MapScreen(pathData: _trip()))),
                child: const Text('home'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('home'));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
    }

    Future<void> scrollToEnd(WidgetTester tester) async {
      await tester.scrollUntilVisible(find.byKey(const ValueKey('trip_end_button')), 200,
          scrollable: find.descendant(of: find.byKey(const ValueKey('trip-sheet-steps')), matching: find.byType(Scrollable)));
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('is the last thing under the steps, labelled, above the navigation bar', (tester) async {
      await open(tester);
      await scrollToEnd(tester);
      final button = find.byKey(const ValueKey('trip_end_button'));
      expect(find.descendant(of: button, matching: find.text('End trip')), findsOneWidget);
      final steps = tester.getRect(find.byKey(const ValueKey('trip-sheet-steps')));
      final rect = tester.getRect(button);
      expect(steps.bottom - rect.bottom, greaterThanOrEqualTo(48), reason: 'clear of the navigation bar');
      // Nothing scrolls in under it.
      final scroll = tester.state<ScrollableState>(
          find.descendant(of: find.byKey(const ValueKey('trip-sheet-steps')), matching: find.byType(Scrollable)));
      expect(scroll.position.pixels, scroll.position.maxScrollExtent);
    });

    testWidgets('asks first, then ends the trip', (tester) async {
      await open(tester);
      await scrollToEnd(tester);
      await tester.tap(find.byKey(const ValueKey('trip_end_button')));
      await tester.pump(const Duration(milliseconds: 400));
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.simpleEndTripTitle), findsOneWidget);

      // No keeps the trip.
      await tester.tap(find.byKey(const ValueKey('simple_confirm_no')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(MapScreen), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('trip_end_button')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const ValueKey('simple_confirm_yes')));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(MapScreen), findsNothing);
      expect(find.text('home'), findsOneWidget);
    });
  });

  group('notification permission on first launch', () {
    late int asked;
    setUp(() {
      asked = 0;
      NotificationPermission.debugRequest = () async => asked++;
    });
    tearDown(() => NotificationPermission.debugRequest = null);

    test('is asked once and remembered', () async {
      expect(await NotificationPermission.askOnce(), isTrue);
      expect(await NotificationPermission.askOnce(), isFalse);
      expect(asked, 1);
      expect((await SharedPreferences.getInstance()).getBool(NotificationPermission.askedKey), isTrue);
    });

    test('is not asked when it was asked before', () async {
      SharedPreferences.setMockInitialValues({NotificationPermission.askedKey: true});
      expect(await NotificationPermission.askOnce(), isFalse);
      expect(asked, 0);
    });
  });

  test('labels', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final ar = lookupAppLocalizations(const Locale('ar'));
    expect(en.commuteNotifsLabel, 'Notifications');
    expect(ar.commuteNotifsLabel, 'الإشعارات');
    expect(en.simpleEndTrip, 'End trip');
    expect(ar.simpleSettingsOnHint, 'اقفله عشان تشوف كل المميزات تاني.');
  });

  test('the native ad validator is off', () {
    expect(File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
        matches(RegExp(r'com\.google\.android\.gms\.ads\.flag\.NATIVE_AD_DEBUGGER_ENABLED"\s*android:value="false"')));
    expect(File('ios/Runner/Info.plist').readAsStringSync(),
        matches(RegExp(r'<key>GADNativeAdValidatorEnabled</key>\s*<false/>')));
  });
}
