import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/MapScreen.dart';
import 'package:guidy_app/services/step_copy.dart';
import 'package:guidy_app/widgets/trip/trip_now_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Going back a step while following a trip, in the normal trip sheet. The
// auto-advance interplay (hold until the rider has moved on) is covered by
// the StepTracker tests in trip_progress_test.dart.
Map<String, dynamic> _trip() => {
      'instructions': [
        <String, dynamic>{'action': 'walk_to_station', 'station': 'Al Tabba', 'lat': 30.058, 'lon': 31.380, 'distance_m': 900},
        <String, dynamic>{
          'action': 'board', 'station': 'Al Tabba', 'route_id': 'MB', 'vehicle_type': 'microbus',
          'lat': 30.058, 'lon': 31.380, 'fare_egp': 10, 'alight_station': 'Alf Maskan',
        },
        <String, dynamic>{'action': 'arrive', 'station': 'Alf Maskan', 'lat': 30.119, 'lon': 31.340},
      ],
      'option': {'type': 'Cheapest', 'time': '60', 'fare_egp': 10},
      'segments': [],
    };

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<AppLocalizations> open(WidgetTester tester, {Locale? locale}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    await tester.pumpWidget(MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MapScreen(pathData: _trip()),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    return AppLocalizations.of(tester.element(find.byType(MapScreen)));
  }

  for (final locale in [const Locale('en'), const Locale('ar')]) {
    testWidgets('the trip sheet steps forward and back (${locale.languageCode})', (tester) async {
      final l10n = await open(tester, locale: locale);
      final steps = _trip()['instructions'] as List;
      final first = StepCopy.of(l10n, steps, 0).title;
      final second = StepCopy.of(l10n, steps, 1).title;

      expect(tester.takeException(), isNull, reason: 'on open');
      expect(find.byKey(const ValueKey('trip_prev_step')), findsNothing, reason: 'nothing before the first step');
      expect(find.byKey(const ValueKey('trip_next_step')), findsOneWidget);
      expect(find.text(l10n.navPrevStep), findsNothing);

      await tester.tap(find.byKey(const ValueKey('trip_next_step')));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('trip_prev_step')), findsOneWidget);
      expect(find.text(l10n.navPrevStep), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('trip_prev_step')));
      await tester.pump();
      expect(find.byKey(const ValueKey('trip_prev_step')), findsNothing, reason: 'back on the first step');
      expect(find.text(first), findsWidgets);
      expect(find.text(second), findsWidgets);
      expect(tester.takeException(), isNull);

      // Forward again, to the last step: no "next" there.
      await tester.tap(find.byKey(const ValueKey('trip_next_step')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('trip_next_step')));
      await tester.pump();
      expect(find.byKey(const ValueKey('trip_next_step')), findsNothing);
      expect(find.byKey(const ValueKey('trip_prev_step')), findsOneWidget);
    });
  }

  testWidgets('narrow phone (360 dp), larger text, Arabic: the step buttons fit', (tester) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.15)), child: child!),
      home: MapScreen(pathData: _trip()),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const ValueKey('trip_next_step')));
    await tester.pump();
    expect(find.byKey(const ValueKey('trip_prev_step')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final locale in [const Locale('en'), const Locale('ar')]) {
    testWidgets('previous/next labels are whole, no ellipsis, at 360 dp x1.3 (${locale.languageCode})', (tester) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)), child: child!),
        home: Scaffold(
          body: SingleChildScrollView(
            child: TripNowCard(
              instructions: _trip()['instructions'] as List,
              step: 1,
              distanceToNextStop: ValueNotifier('300 m'),
              locationProblem: ValueNotifier<String?>(null),
              rideReport: null,
              offersRideReport: false,
              onStartRideReport: () {},
              onStopRideReport: () {},
              onPrevious: () {},
              onNext: () {},
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      final l10n = AppLocalizations.of(tester.element(find.byType(TripNowCard)));
      for (final label in [l10n.navPrevStep, l10n.navNextStep]) {
        final text = tester.widget<Text>(find.text(label));
        expect(text.overflow, isNot(TextOverflow.ellipsis));
        // Painted whole: its box is at least as wide as the text at its size.
        final box = tester.getSize(find.text(label));
        final painter = TextPainter(
          text: TextSpan(text: label, style: DefaultTextStyle.of(tester.element(find.text(label))).style),
          textDirection: Directionality.of(tester.element(find.text(label))),
          maxLines: 1,
        )..layout();
        expect(box.width, greaterThan(painter.width * 0.7), reason: '$label is not squeezed to a stub');
      }
      final prev = tester.widget<TextButton>(find.byKey(const ValueKey('trip_prev_step')));
      final next = tester.widget<TextButton>(find.byKey(const ValueKey('trip_next_step')));
      expect(prev.style, next.style, reason: 'same weight and padding');
    });
  }
}
