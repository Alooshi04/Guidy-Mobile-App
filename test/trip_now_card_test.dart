import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/widgets/trip/trip_now_card.dart';

// The live trip's step card after the beta reviewer's "less text" notes
// (2026-11): one distance line under the step, live once there is a fix;
// no "left to X" row and no trip time/distance/fare pills on every step; a
// ride's fare next to its line.
const _trip = [
  {'action': 'walk_to_station', 'station': '8th District', 'distance_m': 678},
  {
    'action': 'board', 'vehicle_type': 'minibus', 'route_number': '66', 'station': '8th District',
    'towards': 'Ramses', 'alight_station': 'Kids Land', 'ride_m': 4200, 'ride_min': 12, 'stops_count': 5,
    'fare_egp': 10, 'wait_min': 6,
  },
  {'action': 'arrive', 'station': 'Kids Land'},
];

Widget _app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

TripNowCard _card(int step, ValueNotifier<String> live, {VoidCallback? onReportWalk}) => TripNowCard(
      instructions: _trip,
      step: step,
      distanceToNextStop: live,
      locationProblem: ValueNotifier<String?>(null),
      rideReport: null,
      offersRideReport: false,
      onStartRideReport: () {},
      onStopRideReport: () {},
      onReportWalk: onReportWalk,
      onPrevious: step > 0 ? () {} : null,
      onNext: () {},
    );

void main() {
  testWidgets('a walk: one distance line, planned until there is a fix, then live in its place', (tester) async {
    final live = ValueNotifier('');
    await tester.pumpWidget(_app(_card(0, live, onReportWalk: () {})));
    expect(find.text('Walk to 8th District'), findsOneWidget);
    expect(find.text('678 m, about 10 min'), findsOneWidget);

    live.value = '670 m left, about 9 min';
    await tester.pump();
    expect(find.text('678 m, about 10 min'), findsNothing, reason: 'not a static and a live copy');
    expect(find.byKey(const ValueKey('nav_live_line')), findsOneWidget);
    expect(find.text('670 m left, about 9 min'), findsOneWidget);

    // Gone from every step: the remaining-distance row and both trip pills.
    expect(find.byKey(const ValueKey('nav_next_stop_line')), findsNothing);
    expect(find.byKey(const ValueKey('nav_remaining_chip')), findsNothing);
    expect(find.byIcon(Icons.payments_outlined), findsNothing);
    expect(find.byIcon(Icons.schedule_rounded), findsNothing);

    // Kept: report the walk, previous/next step.
    final l10n = AppLocalizations.of(tester.element(find.byType(TripNowCard)));
    expect(find.text(l10n.walkReportButton), findsOneWidget);
    expect(find.byKey(const ValueKey('trip_next_step')), findsOneWidget);
  });

  testWidgets('a ride: its fare next to the line, no direction or wait, the countdown in place of the ride line',
      (tester) async {
    final live = ValueNotifier('');
    await tester.pumpWidget(_app(_card(1, live)));
    expect(find.text('Take minibus 66'), findsOneWidget);
    expect(find.byKey(const ValueKey('nav_step_fare')), findsOneWidget);
    expect(find.text('10 EGP'), findsOneWidget);
    final title = tester.getRect(find.text('Take minibus 66'));
    final fare = tester.getRect(find.text('10 EGP'));
    expect(fare.left, greaterThan(title.right - 1), reason: 'right after the line number');
    expect(find.textContaining('Ramses'), findsNothing);
    expect(find.textContaining('Wait'), findsNothing);
    expect(find.text('Board at 8th District'), findsOneWidget);
    expect(find.text('Ride to Kids Land, 5 stops, 12 min'), findsOneWidget);

    live.value = 'Get off at Kids Land in about 4 min';
    await tester.pump();
    expect(find.text('Ride to Kids Land, 5 stops, 12 min'), findsNothing);
    expect(find.text('Get off at Kids Land in about 4 min'), findsOneWidget);
    expect(find.text('Board at 8th District'), findsOneWidget);
  });

  testWidgets('Arabic: the fare sits after the line, right to left, and nothing overflows', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_app(_card(1, ValueNotifier('')), locale: const Locale('ar')));
    expect(tester.takeException(), isNull);
    final title = tester.getRect(find.text('اركب ميني باص رقم 66'));
    final fare = tester.getRect(find.text(lookupAppLocalizations(const Locale('ar')).fareEgp('10')));
    expect(fare.right, lessThan(title.left + 1));
    expect(find.text('خليك راكب لحد Kids Land، 5 محطات، 12 دقيقة'), findsOneWidget);
  });

  testWidgets('the get-off step has no "then walk to your destination" line', (tester) async {
    await tester.pumpWidget(_app(_card(2, ValueNotifier(''))));
    expect(find.text('Get off at Kids Land'), findsOneWidget);
    expect(find.textContaining('then walk'), findsNothing);
  });
}
