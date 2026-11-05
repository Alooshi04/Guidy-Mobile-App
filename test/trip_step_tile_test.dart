import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/utils/minutes_text.dart';
import 'package:guidy_app/widgets/trip/trip_step_tile.dart';

const _steps = [
  {'action': 'walk_to_station', 'station': 'Ramses', 'distance_m': 200},
  {'action': 'board', 'station': 'Ramses', 'vehicle_type': 'minibus', 'route_number': '66', 'fare_egp': 10, 'wait_min': 4},
  {'action': 'arrive', 'station': 'Tahrir'},
];

Future<void> pump(WidgetTester tester, Widget tile) => tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: tile),
    ));

void main() {
  testWidgets('the current step is marked, with its fare next to the line and no wait', (tester) async {
    await pump(
      tester,
      TripStepTile(instructions: _steps, index: 1, isNow: true, isOpen: false, tappable: false, onToggle: () {}),
    );
    final l10n = AppLocalizations.of(tester.element(find.byType(TripStepTile)));
    expect(find.text(l10n.navNowLabel.toUpperCase()), findsOneWidget);
    expect(find.text(l10n.fareEgp('10')), findsOneWidget);
    // Right beside "Take minibus 66", on the same line (beta feedback, 2026-11).
    final title = tester.getRect(find.text('Take minibus 66'));
    final fare = tester.getRect(find.byKey(const ValueKey('step_fare_1')));
    expect(fare.left, greaterThan(title.right - 1));
    expect((fare.center.dy - title.center.dy).abs(), lessThan(4));
    expect(find.byIcon(Icons.hourglass_empty), findsNothing);
    expect(find.textContaining(l10n.stepWaitHint(l10n.minutes(4))), findsNothing);
  });

  testWidgets('a ride in the list drops the direction, keeps stops and minutes', (tester) async {
    await pump(
      tester,
      TripStepTile(
        instructions: const [
          {
            'action': 'board', 'station': 'Ramses', 'vehicle_type': 'minibus', 'route_number': '66', 'fare_egp': 10,
            'wait_min': 3, 'towards': 'Rod El Farag Axis', 'alight_station': 'Safaa Hegazy', 'stops_count': 14, 'ride_min': 29,
          },
          {'action': 'arrive', 'station': 'Safaa Hegazy'},
          {'action': 'walk_to_destination', 'distance_m': 1265},
        ],
        index: 0,
        isNow: false,
        isOpen: false,
        tappable: false,
        onToggle: () {},
      ),
    );
    expect(find.text('Ride to Safaa Hegazy, 14 stops, 29 min'), findsOneWidget);
    expect(find.textContaining('Rod El Farag'), findsNothing);
    expect(find.textContaining('Wait'), findsNothing);
  });

  testWidgets('the get-off step does not repeat the walk that follows it', (tester) async {
    const steps = [
      {'action': 'arrive', 'station': 'Safaa Hegazy'},
      {'action': 'walk_to_destination', 'distance_m': 1265},
    ];
    await pump(
      tester,
      TripStepTile(instructions: steps, index: 0, isNow: false, isOpen: false, tappable: false, onToggle: () {}),
    );
    expect(find.text('Get off at Safaa Hegazy'), findsOneWidget);
    expect(find.textContaining('then walk'), findsNothing);
  });

  testWidgets('a step with choices unfolds on tap and shows them when open', (tester) async {
    var toggled = 0;
    await pump(
      tester,
      TripStepTile(
        instructions: _steps,
        index: 1,
        isNow: false,
        isOpen: true,
        tappable: true,
        onToggle: () => toggled++,
        alternatives: const Text('other vehicles'),
      ),
    );
    expect(find.text('other vehicles'), findsOneWidget);
    expect(find.byIcon(Icons.expand_less), findsOneWidget);
    await tester.tap(find.byType(InkWell));
    expect(toggled, 1);
  });

  testWidgets('a step without choices does not react to taps', (tester) async {
    var toggled = 0;
    await pump(
      tester,
      TripStepTile(instructions: _steps, index: 0, isNow: false, isOpen: false, tappable: false, onToggle: () => toggled++),
    );
    await tester.tap(find.byType(InkWell));
    expect(toggled, 0);
    expect(find.byIcon(Icons.expand_more), findsNothing);
  });

  testWidgets('a fare keeps its piastres; a zero fare (the metro) is not shown', (tester) async {
    Future<void> tile(num fare) => pump(
          tester,
          TripStepTile(
            instructions: [
              _steps[0],
              {..._steps[1], 'fare_egp': fare},
              _steps[2],
            ],
            index: 1,
            isNow: false,
            isOpen: false,
            tappable: false,
            onToggle: () {},
          ),
        );
    await tile(5.5);
    final l10n = AppLocalizations.of(tester.element(find.byType(TripStepTile)));
    expect(find.text(l10n.fareEgp('5.5')), findsOneWidget);
    await tile(0);
    expect(find.byKey(const ValueKey('step_fare_1')), findsNothing);
  });
}
