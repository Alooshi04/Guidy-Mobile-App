import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/services/step_copy.dart';

// A leg boarded or left on the street (backend hail.py) says so mid-trip:
// wave it down there, ask the driver to stop there.
void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  final steps = <Map<String, dynamic>>[
    {'action': 'walk_to_station', 'station': 'On the road to Wadi Hof Metro', 'distance_m': 27},
    {'action': 'board', 'hail': true, 'station': 'On the road to Wadi Hof Metro', 'route_number': '24',
     'vehicle_type': 'microbus'},
    {'action': 'arrive', 'hail': true, 'station': 'On the road after Icon'},
  ];

  test('the walk to a hailed boarding goes to the street', () {
    expect(StepCopy.of(l10n, steps, 0).title, l10n.stepWalkToStreet);
  });

  test('a hailed boarding says to wave it down', () {
    expect(StepCopy.of(l10n, steps, 1).lines.first, startsWith(l10n.plannerHailAt('On the road to Wadi Hof Metro')));
  });

  test('a hailed stop says to ask the driver', () {
    expect(StepCopy.of(l10n, steps, 2).title, l10n.plannerAskToStopAt('On the road after Icon'));
  });

  test('a stop boarding is worded as before', () {
    final atStop = [
      {'action': 'board', 'station': 'Al Tabba', 'route_number': '24', 'vehicle_type': 'microbus'},
    ];
    expect(StepCopy.of(l10n, atStop, 0).lines.first, startsWith(l10n.stepBoardAt('Al Tabba')));
  });
}
