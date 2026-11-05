import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guidy_app/screens/SettingsScreen.dart';
import 'package:guidy_app/services/theme_controller.dart';
import 'package:guidy_app/services/locale_controller.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/services/simple_mode.dart';
import 'package:guidy_app/services/commute/commute_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // The version shown is the installed build's, not a fixed string.
    PackageInfo.setMockInitialValues(
      appName: 'Guidy',
      packageName: 'app.guidy',
      version: '1.0.11',
      buildNumber: '14',
      buildSignature: '',
    );
  });

  Widget buildSettingsScreen({VoidCallback? onGoHome, Locale locale = const Locale('en')}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: SettingsScreen(onGoHome: onGoHome),
    );
  }

  group('SettingsScreen Widget Tests', () {
    testWidgets('renders all section headers and core items cleanly', (tester) async {
      tester.view.physicalSize = const Size(400 * 2.0, 1200 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildSettingsScreen());
      await tester.pumpAndSettle();

      // Verify app bar title
      expect(find.text('Settings'), findsOneWidget);

      // Section labels
      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(find.text('PREFERENCES'), findsOneWidget);
      expect(find.text('SUPPORT'), findsOneWidget);

      // Core actions (the redesign shows row labels in capitals)
      expect(find.text('DARK MODE'), findsOneWidget);
      expect(find.text('LANGUAGE'), findsOneWidget);
      expect(find.text('CONTACT US'), findsOneWidget);
      expect(find.text('RATE GUIDY'), findsOneWidget);
      expect(find.text('PRIVACY POLICY'), findsOneWidget);
      expect(find.text('LOG OUT'), findsOneWidget);
      // No signed-in user here, which the screen shows as a guest.
      expect(find.text('DELETE GUEST DATA'), findsOneWidget);

      // Scroll down to version badge at the bottom
      await tester.scrollUntilVisible(find.text('v1.0.11 (14)'), 100);
      expect(find.text('v1.0.11 (14)'), findsOneWidget);
    });

    testWidgets('a guest is asked about deleting guest data, not an account', (tester) async {
      tester.view.physicalSize = const Size(400 * 2.0, 1200 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildSettingsScreen());
      await tester.pumpAndSettle();

      expect(find.text('DELETE ACCOUNT'), findsNothing);
      await tester.tap(find.text('DELETE GUEST DATA'));
      await tester.pumpAndSettle();

      expect(find.text('Delete your guest data?'), findsOneWidget);
      expect(find.text('Delete your account?'), findsNothing);
    });

    testWidgets('shows back button when onGoHome is provided and triggers callback', (tester) async {
      var homeClicked = false;
      await tester.pumpWidget(buildSettingsScreen(onGoHome: () => homeClicked = true));
      await tester.pumpAndSettle();

      final backButton = find.byIcon(Icons.arrow_back);
      expect(backButton, findsOneWidget);

      await tester.tap(backButton);
      await tester.pumpAndSettle();

      expect(homeClicked, isTrue);
    });

    testWidgets('does not show back button when onGoHome is null', (tester) async {
      await tester.pumpWidget(buildSettingsScreen(onGoHome: null));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });

    testWidgets('Dark Mode toggle interacts with themeController', (tester) async {
      themeController.value = ThemeMode.system;
      await tester.pumpWidget(buildSettingsScreen());
      await tester.pumpAndSettle();

      // Dark mode, Simple mode and commute notifications (with its two
      // kinds) and walking paths -- dark mode is first.
      expect(find.byType(Switch), findsNWidgets(6));
      final switchFinder = find.byType(Switch).first;

      // Tap switch -> flips to dark
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();
      expect(themeController.value, equals(ThemeMode.dark));

      // Tap switch -> flips to light
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();
      expect(themeController.value, equals(ThemeMode.light));
    });

    testWidgets('commute notifications are on by default, and each kind can be turned off', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(buildSettingsScreen());
      await tester.pumpAndSettle();
      bool on(String key) =>
          tester.widget<SwitchListTile>(find.byKey(ValueKey(key))).value;
      expect(on('commute-notifs'), isTrue);
      expect(on('commute-notifs-easier'), isTrue);
      expect(on('commute-notifs-last'), isTrue);

      await tester.ensureVisible(find.byKey(const ValueKey('commute-notifs-easier')));
      await tester.tap(find.byKey(const ValueKey('commute-notifs-easier')));
      await tester.pumpAndSettle();
      expect(CommuteStore.settings.value.easier, isFalse);
      expect((await SharedPreferences.getInstance()).getBool('commute_notifs_easier'), isFalse);

      // All off hides the kinds.
      await tester.tap(find.byKey(const ValueKey('commute-notifs')));
      await tester.pumpAndSettle();
      expect(CommuteStore.settings.value.enabled, isFalse);
      expect(find.byKey(const ValueKey('commute-notifs-last')), findsNothing);
      await CommuteStore.saveSettings(const CommuteSettings());
    });

    for (final locale in [const Locale('en'), const Locale('ar')]) {
      testWidgets('commute notifications: one short line, and an info button that explains (${locale.languageCode})',
          (tester) async {
        tester.view.physicalSize = const Size(360 * 2.0, 1200 * 2.0);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        await tester.pumpWidget(buildSettingsScreen(locale: locale));
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(tester.element(find.byType(SettingsScreen)));

        expect(l10n.commuteNotifsSubtitle.split(RegExp(r'\s+')).length, lessThanOrEqualTo(8),
            reason: 'the line under the switch is at most about eight words');
        expect(find.textContaining(l10n.commuteNotifsSubtitle), findsOneWidget);

        await tester.scrollUntilVisible(find.byKey(const ValueKey('commute-notifs-info')), 300);
        await tester.tap(find.byKey(const ValueKey('commute-notifs-info')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('commute-notifs-info-dialog')), findsOneWidget);
        expect(find.text(l10n.commuteInfoTitle), findsWidgets);
        expect(find.textContaining(l10n.commuteInfoBody.substring(0, 30)), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text(l10n.whatsNewOk));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('commute-notifs-info-dialog')), findsNothing);
      });
    }

    testWidgets('Simple mode switch works, and trip sharing is not optional', (tester) async {
      simpleMode.value = false;
      await tester.pumpWidget(buildSettingsScreen());
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch).at(1));
      await tester.pumpAndSettle();
      expect(simpleMode.value, isTrue);
      simpleMode.value = false;
      await tester.pumpAndSettle();

      expect(find.text('Help fix bus routes'), findsNothing);
    });

    testWidgets('Language item displays current language name', (tester) async {
      await tester.pumpWidget(buildSettingsScreen());
      await tester.pumpAndSettle();

      // In English locale, should show English or Arabic depending on controller
      final langLabel = localeController.isArabic ? 'العربية' : 'English';
      expect(find.text(langLabel), findsOneWidget);
    });

    testWidgets('renders cleanly in Arabic locale without overflow', (tester) async {
      tester.view.physicalSize = const Size(390 * 2.5, 844 * 2.5);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildSettingsScreen(locale: const Locale('ar')));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
