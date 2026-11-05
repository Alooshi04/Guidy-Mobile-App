import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/MainNavigator.dart';
import 'package:guidy_app/screens/MapScreen.dart';
import 'package:guidy_app/services/tour_service.dart';
import 'package:guidy_app/services/trip_pip.dart';
import 'package:guidy_app/theme/app_theme.dart';
import 'package:guidy_app/widgets/app_banner_shell.dart';
import 'package:guidy_app/widgets/guidy_tour.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget home) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: home,
    );

final _trip = {
  'instructions': [
    {'action': 'walk_to_station', 'station': 'Ramses', 'lat': 30.05, 'lon': 31.24, 'distance_m': 200},
    {'action': 'board', 'station': 'Ramses', 'route_id': 'R1', 'route_number': '66', 'vehicle_type': 'minibus', 'lat': 30.05, 'lon': 31.24},
    {'action': 'arrive', 'station': 'Tahrir', 'lat': 30.06, 'lon': 31.25},
  ],
  'option': {'type': 'Recommended', 'time': '30', 'fare_egp': 10},
  'segments': [],
};

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('TourService', () {
    test('a tour is unseen until marked, and replaying makes every tour unseen again', () async {
      expect(await TourService.hasSeen('home'), isFalse);
      await TourService.markSeen('home');
      await TourService.markSeen('trip');
      expect(await TourService.hasSeen('home'), isTrue);
      await TourService.resetAll();
      expect(await TourService.hasSeen('home'), isFalse);
      expect(await TourService.hasSeen('trip'), isFalse);
    });
  });

  group('GuidyTour overlay', () {
    final a = GlobalKey(), b = GlobalKey(), offstage = GlobalKey();

    Widget screen() => Scaffold(
          body: Column(children: [
            SizedBox(key: a, width: 100, height: 40, child: const Text('feature A')),
            const SizedBox(height: 200),
            SizedBox(key: b, width: 100, height: 40, child: const Text('feature B')),
          ]),
        );

    List<TourStep> steps() => [
          const TourStep(title: 'Welcome', body: 'A quick look around.'),
          TourStep(target: a, title: 'Step A', body: 'This is A.'),
          TourStep(target: offstage, title: 'Hidden', body: 'Not on screen, so skipped.'),
          TourStep(target: b, title: 'Step B', body: 'This is B.'),
        ];

    testWidgets('Next walks through the steps on screen, Done closes it', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(screen()));
      final ctx = tester.element(find.byType(Scaffold));
      final result = GuidyTour.show(ctx, steps());
      await tester.pumpAndSettle();

      expect(find.text('Welcome'), findsOneWidget);
      expect(find.text('1 of 3'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Step A'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Hidden'), findsNothing);
      expect(find.text('Step B'), findsOneWidget);
      expect(find.text('3 of 3'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Step B'), findsNothing);
      expect(await result, isTrue);
    });

    testWidgets("the phone's back button closes it as a skip", (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(screen()));
      final result = GuidyTour.show(tester.element(find.byType(Scaffold)), steps());
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Welcome'), findsNothing);
      expect(find.text('feature A'), findsOneWidget);
      expect(await result, isFalse);
    });

    testWidgets('a step whose feature leaves the screen is passed over', (tester) async {
      _phone(tester);
      final showA = ValueNotifier(true);
      await tester.pumpWidget(_app(Scaffold(
        body: ValueListenableBuilder<bool>(
          valueListenable: showA,
          builder: (_, show, _) => Column(children: [
            if (show) SizedBox(key: a, width: 100, height: 40, child: const Text('feature A')),
            const SizedBox(height: 200),
            SizedBox(key: b, width: 100, height: 40, child: const Text('feature B')),
          ]),
        ),
      )));
      final result = GuidyTour.show(tester.element(find.byType(Scaffold)), [
        TourStep(target: a, title: 'Step A', body: 'This is A.'),
        TourStep(target: b, title: 'Step B', body: 'This is B.'),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Step A'), findsOneWidget);

      showA.value = false;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Step B'), findsOneWidget);

      // And when no step is left on screen, the tour ends (as a skip).
      await tester.pumpWidget(_app(const Scaffold(body: SizedBox())));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('guidy_tour_card')), findsNothing);
      expect(await result, isFalse);
    });

    // A floating window is shorter than the card's top and bottom margins
    // put together, which made placing the card throw.
    testWidgets('a screen too short for the card still shows it', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(key: a, width: 100, height: 40, child: const Text('feature A')),
        ),
      )));
      unawaited(GuidyTour.show(tester.element(find.byType(Scaffold)), [
        TourStep(target: a, title: 'Step A', body: 'This is A.'),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('Step A'), findsOneWidget);

      tester.view.physicalSize = const Size(390 * 3, 110 * 3);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      expect(find.text('Step A'), findsOneWidget);
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      await tester.pumpAndSettle();
    });

    testWidgets('the window and card line up with the feature under the top banner', (tester) async {
      // The banner shell sits above the navigator, so the tour's own origin
      // is a banner height below the screen's top.
      _phone(tester);
      appBannerEnabled.value = true;
      addTearDown(() => appBannerEnabled.value = false);
      final low = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        builder: (context, child) => AppBannerShell(
          bannerBuilder: (_) => const SizedBox(height: 60, width: double.infinity),
          child: child!,
        ),
        home: Scaffold(
          body: Column(children: [
            SizedBox(key: a, width: 100, height: 40, child: const Text('feature A')),
            const Spacer(),
            SizedBox(key: low, width: 100, height: 40, child: const Text('feature low')),
            const SizedBox(height: 80),
          ]),
        ),
      ));
      final ctx = tester.element(find.byType(Scaffold));
      unawaited(GuidyTour.show(ctx, [
        TourStep(target: a, title: 'Step A', body: 'This is A.'),
        TourStep(target: low, title: 'Step low', body: 'Near the bottom.'),
      ]));
      await tester.pumpAndSettle();

      // Card below a feature in the top half: 6 px of window, 12 of gap.
      final card = find.byKey(const ValueKey('guidy_tour_card'));
      expect(tester.getTopLeft(card).dy, tester.getBottomLeft(find.byKey(a)).dy + 6 + 12);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      // Card above a feature in the bottom half.
      expect(tester.getBottomLeft(card).dy, tester.getTopLeft(find.byKey(low)).dy - 6 - 12);
    });

    testWidgets('Skip closes it from any step', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(screen()));
      final result = GuidyTour.show(tester.element(find.byType(Scaffold)), steps());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome'), findsNothing);
      expect(await result, isFalse);
    });
  });

  group('The app tour', () {
    setUp(() => GuidyTour.autoStart = true);
    tearDown(() => GuidyTour.autoStart = false);

    testWidgets('shows once on first launch, and Skip means it never comes back on its own', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(const MainNavigator()));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('guidy_tour_card')), findsOneWidget);

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(await TourService.hasSeen(TourService.home), isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_app(const MainNavigator()));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('guidy_tour_card')), findsNothing);
    });

    testWidgets('it waits if another screen is on top (a shared link opened the app)', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(const MainNavigator()));
      final nav = Navigator.of(tester.element(find.byType(MainNavigator)));
      nav.push(MaterialPageRoute(builder: (_) => const Scaffold(body: Text('shared place'))));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('guidy_tour_card')), findsNothing);
      expect(await TourService.hasSeen(TourService.home), isFalse);
    });

    testWidgets('Settings can replay it', (tester) async {
      _phone(tester);
      SharedPreferences.setMockInitialValues({'tour_seen_home': true});
      await tester.pumpWidget(_app(const MainNavigator()));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('guidy_tour_card')), findsNothing);

      MainNavigator.goToTab(4);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('REPLAY TUTORIAL'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('REPLAY TUTORIAL'));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('guidy_tour_card')), findsOneWidget);
      expect(MainNavigator.activeTabNotifier.value, 2);
    });

    testWidgets('the first trip explains the trip screen once', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(MapScreen(pathData: _trip)));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('What to do now'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(await TourService.hasSeen(TourService.trip), isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_app(MapScreen(pathData: _trip)));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('guidy_tour_card')), findsNothing);
    });

    // The trip went to the floating window while the trip tour was still
    // open: the window drops the parts the tour points at, and the tour
    // reading their place on screen threw "Cannot get renderObject of
    // inactive element" -- a red box in the window.
    testWidgets('the trip tour closes as the floating window opens', (tester) async {
      _phone(tester);
      // Wrapped as the app is: the banner shell steps aside for the window.
      appBannerEnabled.value = true;
      addTearDown(() => appBannerEnabled.value = false);
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        theme: AppTheme.light(const Locale('en')),
        builder: (context, child) => AppBannerShell(child: child!),
        home: MapScreen(pathData: _trip),
      ));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('What to do now'), findsOneWidget);

      // Android shrinks the window and says so in the same breath.
      tester.view.physicalSize = const Size(390 * 3, 300 * 3);
      TripPip.active.value = true;
      addTearDown(() => TripPip.active.value = false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('guidy_tour_card')), findsNothing);
      expect(find.byKey(const ValueKey('pip_rundown')), findsOneWidget);
      // Not taken as seen: the rider never got to read it.
      expect(await TourService.hasSeen(TourService.trip), isFalse);

      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      TripPip.active.value = false;
      await tester.pump();
    });
  });
}
