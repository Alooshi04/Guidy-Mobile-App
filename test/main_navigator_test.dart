import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guidy_app/screens/MainNavigator.dart';
import 'package:guidy_app/screens/HomeScreen.dart';
import 'package:guidy_app/screens/SettingsScreen.dart';
import 'package:guidy_app/screens/LinesScreen.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/widgets/app_banner_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Static, so it would carry the last test's tab into this one.
    MainNavigator.activeTabNotifier.value = 2;
  });

  Widget buildNavigator({Locale locale = const Locale('en')}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: const MainNavigator(),
    );
  }

  group('Top banner', () {
    testWidgets('shows only while the app itself is on screen, not over sign-in or loading', (tester) async {
      // AdMob placement policy: no ads on login, loading or consent screens.
      tester.view.physicalSize = const Size(400 * 2.0, 800 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(() => appBannerEnabled.value = false);
      final signedIn = ValueNotifier<bool>(false);
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: ValueListenableBuilder<bool>(
          valueListenable: signedIn,
          builder: (_, inApp, __) => inApp ? const MainNavigator() : const Scaffold(body: Text('Sign in')),
        ),
      ));
      await tester.pump();
      expect(appBannerEnabled.value, isFalse);

      signedIn.value = true;
      await tester.pumpAndSettle();
      expect(appBannerEnabled.value, isTrue);

      // Signing out goes back to the sign-in screen.
      signedIn.value = false;
      await tester.pumpAndSettle();
      expect(appBannerEnabled.value, isFalse);
    });
  });

  group('MainNavigator & HomeScreen Widget Tests', () {
    testWidgets('renders NavigationBar with all 5 destinations and defaults to Home', (tester) async {
      tester.view.physicalSize = const Size(400 * 2.0, 800 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildNavigator());
      await tester.pumpAndSettle();

      // Verify 5 NavigationBar destinations exist
      final navDestinations = find.byType(NavigationDestination);
      expect(navDestinations, findsNWidgets(5));

      // Navigation labels in English using widgetWithText
      expect(find.widgetWithText(NavigationDestination, 'Lines'), findsOneWidget);
      expect(find.widgetWithText(NavigationDestination, 'Metro'), findsOneWidget);
      expect(find.widgetWithText(NavigationDestination, 'Home'), findsOneWidget);
      expect(find.widgetWithText(NavigationDestination, 'Trips'), findsOneWidget);
      expect(find.widgetWithText(NavigationDestination, 'Settings'), findsOneWidget);

      // Default index is 2 (HomeScreen)
      final indexedStack = tester.widget<IndexedStack>(find.byType(IndexedStack));
      expect(indexedStack.index, equals(2));
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('switching tabs via NavigationBar changes the active IndexedStack index', (tester) async {
      tester.view.physicalSize = const Size(400 * 2.0, 800 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildNavigator());
      await tester.pumpAndSettle();

      // Tap Settings (index 4)
      await tester.tap(find.widgetWithText(NavigationDestination, 'Settings'));
      await tester.pumpAndSettle();

      var indexedStack = tester.widget<IndexedStack>(find.byType(IndexedStack));
      expect(indexedStack.index, equals(4));
      expect(find.byType(SettingsScreen), findsOneWidget);

      // Tap Lines (index 0)
      await tester.tap(find.widgetWithText(NavigationDestination, 'Lines'));
      await tester.pumpAndSettle();

      indexedStack = tester.widget<IndexedStack>(find.byType(IndexedStack));
      expect(indexedStack.index, equals(0));
      expect(find.byType(LinesScreen), findsOneWidget);

      // Tap Home (index 2) to return
      await tester.tap(find.widgetWithText(NavigationDestination, 'Home'));
      await tester.pumpAndSettle();

      indexedStack = tester.widget<IndexedStack>(find.byType(IndexedStack));
      expect(indexedStack.index, equals(2));
    });

    testWidgets('onGoHome in Settings returns to Home tab (index 2)', (tester) async {
      tester.view.physicalSize = const Size(400 * 2.0, 800 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildNavigator());
      await tester.pumpAndSettle();

      // Switch to Settings tab
      await tester.tap(find.widgetWithText(NavigationDestination, 'Settings'));
      await tester.pumpAndSettle();

      expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, equals(4));

      // Tap back button on Settings screen
      final backBtn = find.byIcon(Icons.arrow_back);
      expect(backBtn, findsOneWidget);
      await tester.tap(backBtn);
      await tester.pumpAndSettle();

      // Should return to Home tab
      expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, equals(2));
    });

    testWidgets('renders cleanly in Arabic locale without layout overflow', (tester) async {
      tester.view.physicalSize = const Size(390 * 2.5, 844 * 2.5);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildNavigator(locale: const Locale('ar')));
      await tester.pumpAndSettle();

      expect(find.byType(MainNavigator), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final locale in const [Locale('en'), Locale('ar')]) {
      testWidgets('Home search bar is full width and tall in ${locale.languageCode} at 2x text', (tester) async {
        tester.view.physicalSize = const Size(390 * 2.0, 844 * 2.0);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2.0)),
            child: child!,
          ),
          home: const MainNavigator(),
        ));
        await tester.pumpAndSettle();

        final bar = find.ancestor(of: find.byIcon(Icons.search), matching: find.byType(InkWell)).first;
        final size = tester.getSize(bar);
        expect(size.width, 390 - 32 - 4, reason: 'full width, inside the 2 dp blue-amber edge');
        expect(size.height, greaterThanOrEqualTo(64));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Settings has no language switch in its header; the other tabs do', (tester) async {
      tester.view.physicalSize = const Size(400 * 2.0, 800 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildNavigator());
      await tester.pumpAndSettle();
      final toggle = find.byKey(const ValueKey('guidy-language-toggle'));

      await tester.tap(find.widgetWithText(NavigationDestination, 'Settings'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(SettingsScreen), matching: toggle), findsNothing);

      await tester.tap(find.widgetWithText(NavigationDestination, 'Lines'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(LinesScreen), matching: toggle), findsOneWidget);
    });

    testWidgets('Settings opens scrolled to the top every time', (tester) async {
      tester.view.physicalSize = const Size(400 * 2.0, 800 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildNavigator());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(NavigationDestination, 'Settings'));
      await tester.pumpAndSettle();

      final settingsList = find.descendant(of: find.byType(SettingsScreen), matching: find.byType(Scrollable)).first;
      await tester.drag(settingsList, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(tester.state<ScrollableState>(settingsList).position.pixels, greaterThan(0));

      await tester.tap(find.widgetWithText(NavigationDestination, 'Home'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(NavigationDestination, 'Settings'));
      await tester.pumpAndSettle();
      expect(tester.state<ScrollableState>(settingsList).position.pixels, 0);
    });

    testWidgets('Home comes back at the top after another tab was chosen', (tester) async {
      tester.view.physicalSize = const Size(400 * 2.0, 600 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildNavigator());
      await tester.pumpAndSettle();

      final homeList = find.descendant(of: find.byType(HomeScreen), matching: find.byType(Scrollable)).first;
      await tester.drag(homeList, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.state<ScrollableState>(homeList).position.pixels, greaterThan(0));

      await tester.tap(find.widgetWithText(NavigationDestination, 'Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(NavigationDestination, 'Home'));
      await tester.pumpAndSettle();
      expect(tester.state<ScrollableState>(homeList).position.pixels, 0);
    });
  });
}
