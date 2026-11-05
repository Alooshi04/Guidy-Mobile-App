import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/HomeScreen.dart';
import 'package:guidy_app/screens/MapScreen.dart';
import 'package:guidy_app/services/account_service.dart';
import 'package:guidy_app/services/current_trip.dart';
import 'package:guidy_app/services/simple_mode.dart';
import 'package:guidy_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _trip() => {
      'end_name': 'Tahrir',
      'instructions': [
        {'action': 'walk_to_station', 'station': 'Ramses', 'lat': 30.05, 'lon': 31.24, 'distance_m': 200},
        {'action': 'board', 'station': 'Ramses', 'route_id': 'R1', 'route_number': '66', 'vehicle_type': 'minibus', 'lat': 30.05, 'lon': 31.24},
        {'action': 'arrive', 'station': 'Tahrir', 'lat': 30.06, 'lon': 31.25},
      ],
      'option': {'type': 'Recommended', 'time': '30', 'fare_egp': 10},
      'segments': [],
    };

void main() {
  late DateTime clock;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CurrentTrip.debugReset();
    clock = DateTime(2026, 10, 31, 9);
    CurrentTrip.now = () => clock;
    simpleMode.value = false;
  });
  tearDown(CurrentTrip.debugReset);

  group('CurrentTrip service', () {
    test('round-trips through SharedPreferences', () async {
      await CurrentTrip.begin(pathData: _trip(), startName: 'A', endName: 'Tahrir', step: 1, recordHistoryOnArrival: true);
      final saved = (await SharedPreferences.getInstance()).getString('current_trip_v1');
      expect(saved, isNotNull);

      CurrentTrip.debugReset(); // a new launch
      CurrentTrip.now = () => clock.add(const Duration(minutes: 5));
      await CurrentTrip.ensureLoaded();
      final t = CurrentTrip.active.value!;
      expect(t.step, 1);
      expect(t.endName, 'Tahrir');
      expect(t.recordHistoryOnArrival, isTrue);
      expect(t.startedAt, clock);
      expect(t.pathData['instructions'], hasLength(3));
    });

    test('setStep is saved', () async {
      await CurrentTrip.begin(pathData: _trip());
      await CurrentTrip.setStep(2);
      CurrentTrip.debugReset();
      // debugReset puts the real clock back; the restart is the same moment.
      CurrentTrip.now = () => clock;
      await CurrentTrip.ensureLoaded();
      expect(CurrentTrip.active.value!.step, 2);
    });

    test('a new trip replaces the old one', () async {
      await CurrentTrip.begin(pathData: _trip(), endName: 'Old');
      await CurrentTrip.begin(pathData: _trip(), endName: 'New');
      expect(CurrentTrip.active.value!.endName, 'New');
    });

    test('clear removes it from memory and storage', () async {
      await CurrentTrip.begin(pathData: _trip());
      await CurrentTrip.clear();
      expect(CurrentTrip.active.value, isNull);
      expect((await SharedPreferences.getInstance()).getString('current_trip_v1'), isNull);
    });

    test('sign-out clears it', () async {
      await CurrentTrip.begin(pathData: _trip());
      await AccountService.clearUserDataOnSignOut();
      expect(CurrentTrip.active.value, isNull);
    });

    test('times out: past start + duration + 2 h', () async {
      await CurrentTrip.begin(pathData: _trip()); // 30 min plan
      clock = clock.add(const Duration(hours: 2, minutes: 29));
      await CurrentTrip.touch();
      CurrentTrip.expireIfStale();
      expect(CurrentTrip.active.value, isNotNull);
      clock = clock.add(const Duration(minutes: 2));
      CurrentTrip.expireIfStale();
      expect(CurrentTrip.active.value, isNull);
    });

    test('times out: 6 h without activity, even on a long plan', () async {
      final long = _trip()..['option'] = {'time': '600'};
      await CurrentTrip.begin(pathData: long);
      clock = clock.add(const Duration(hours: 6, minutes: 1));
      CurrentTrip.expireIfStale();
      expect(CurrentTrip.active.value, isNull);
    });

    test('a stale saved trip is dropped on launch', () async {
      await CurrentTrip.begin(pathData: _trip());
      CurrentTrip.debugReset();
      CurrentTrip.now = () => clock.add(const Duration(hours: 5));
      await CurrentTrip.ensureLoaded();
      expect(CurrentTrip.active.value, isNull);
    });

    test('garbage in storage is ignored', () async {
      SharedPreferences.setMockInitialValues({'current_trip_v1': '{nope'});
      await CurrentTrip.ensureLoaded();
      expect(CurrentTrip.active.value, isNull);
    });
  });

  group('Home card', () {
    Future<void> pumpHome(WidgetTester tester, {Locale locale = const Locale('en'), bool dark = false}) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        theme: AppTheme.light(locale),
        darkTheme: AppTheme.dark(locale),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HomeScreen(),
      ));
      await tester.pumpAndSettle();
    }

    final card = find.byKey(const ValueKey('current_trip_card'));

    testWidgets('absent without a trip', (tester) async {
      await pumpHome(tester);
      expect(card, findsNothing);
    });

    for (final (locale, dark) in [(const Locale('en'), false), (const Locale('ar'), true)]) {
      testWidgets('${locale.languageCode} ${dark ? 'dark' : 'light'}: shows destination and step, then clears', (tester) async {
        await CurrentTrip.begin(pathData: _trip(), endName: 'Tahrir', step: 1);
        await pumpHome(tester, locale: locale, dark: dark);
        expect(card, findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(find.descendant(of: card, matching: find.textContaining('Tahrir')), findsOneWidget);
        final l10n = lookupAppLocalizations(locale);
        expect(find.descendant(of: card, matching: find.text(l10n.currentTripLabel)), findsOneWidget);

        // Arrival, End trip and timeout all come down to clear().
        await CurrentTrip.clear();
        await tester.pump();
        expect(card, findsNothing);
      });
    }

    testWidgets('disappears on timeout', (tester) async {
      await CurrentTrip.begin(pathData: _trip(), endName: 'Tahrir');
      await pumpHome(tester);
      expect(card, findsOneWidget);
      clock = clock.add(const Duration(hours: 3));
      CurrentTrip.expireIfStale();
      await tester.pump();
      expect(card, findsNothing);
    });

    testWidgets('tapping resumes the trip on the saved step', (tester) async {
      await CurrentTrip.begin(pathData: _trip(), endName: 'Tahrir', step: 1);
      await pumpHome(tester);
      await tester.tap(card);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      final map = tester.widget<MapScreen>(find.byType(MapScreen));
      expect(map.initialStep, 1);
      expect(map.startedAt, clock);
      expect(CurrentTrip.active.value!.step, 1);
      expect(CurrentTrip.active.value!.startedAt, clock, reason: 'a resume keeps the trip clock');
    });
  });

  group('trip screen', () {
    testWidgets('opening a trip records it; End trip clears it', (tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MapScreen(pathData: _trip()))),
              child: const Text('home'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('home'));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      expect(CurrentTrip.active.value, isNotNull);

      // Back keeps it: Home shows it.
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.pop();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      expect(CurrentTrip.active.value, isNotNull);

      await tester.tap(find.text('home'));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.scrollUntilVisible(find.byKey(const ValueKey('trip_end_button')), 200,
          scrollable: find.descendant(of: find.byKey(const ValueKey('trip-sheet-steps')), matching: find.byType(Scrollable)));
      await tester.tap(find.byKey(const ValueKey('trip_end_button')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const ValueKey('simple_confirm_yes')));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      expect(CurrentTrip.active.value, isNull);
    });
  });
}
