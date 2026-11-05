import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/services/step_copy.dart';

Future<AppLocalizations> l10nFor(String code) => AppLocalizations.delegate.load(Locale(code));

final trip = <Map<String, dynamic>>[
  {'action': 'walk_to_station', 'distance_m': 704, 'station': '8th District', 'station_en': '8th District'},
  {
    'action': 'board', 'vehicle_type': 'minibus', 'route_number': '66', 'route_id': 'R66',
    'station': '8th District', 'station_en': '8th District', 'towards': 'Ramses', 'towards_en': 'Ramses',
    'alight_station': 'Kids Land', 'alight_station_en': 'Kids Land', 'ride_m': 4200, 'ride_min': 12, 'stops_count': 5,
  },
  {'action': 'walk_to_transfer', 'distance_m': 200, 'station': 'Kids Land', 'station_en': 'Kids Land'},
  {
    'action': 'transfer', 'vehicle_type': 'microbus', 'route_id': 'R9', 'station': 'Abbas', 'station_en': 'Abbas',
    'alight_station': 'Helwan', 'alight_station_en': 'Helwan', 'ride_m': 9000, 'ride_min': 25, 'stops_count': 1,
  },
  {'action': 'arrive', 'station': 'Helwan', 'station_en': 'Helwan'},
  {'action': 'walk_to_destination', 'distance_m': 300, 'station': null},
];

void main() {
  test('walk to the station: where, how far, how long', () async {
    final c = StepCopy.of(await l10nFor('en'), trip, 0);
    expect(c.title, 'Walk to 8th District');
    expect(c.lines, ['704 m, about 10 min']);
    expect(c.countdown, 0, reason: 'the live line takes its place');
    expect(c.fare, isNull);
  });

  test('a ride says where to board, where to get off, stops and time; not the direction', () async {
    final c = StepCopy.of(await l10nFor('en'), trip, 1);
    expect(c.title, 'Take minibus 66');
    expect(c.lines, ['Board at 8th District', 'Ride to Kids Land, 5 stops, 12 min']);
    expect(c.countdown, 1);
  });

  test("a ride's fare goes next to its line; none for a line priced by the leg", () async {
    final en = await l10nFor('en');
    final ar = await l10nFor('ar');
    final paid = [
      {...trip[1], 'fare_egp': 10},
    ];
    expect(StepCopy.of(en, paid, 0).fare, '10 EGP');
    expect(StepCopy.of(ar, paid, 0).fare, ar.fareEgp('10'));
    expect(StepCopy.of(en, [{...trip[1], 'fare_egp': 7.5}], 0).fare, '7.5 EGP', reason: 'decimal');
    expect(StepCopy.of(en, [{...trip[1], 'fare_egp': 0}], 0).fare, isNull, reason: 'the metro');
  });

  test('getting off and walking to the next ride is one instruction', () async {
    final c = StepCopy.of(await l10nFor('en'), trip, 2);
    expect(c.title, 'Get off at Kids Land');
    expect(c.lines, ['then walk 200 m to Abbas, about 3 min']);
  });

  test('the last get-off says only where: the walk after it is its own step', () async {
    final c = StepCopy.of(await l10nFor('en'), trip, 4);
    expect(c.title, 'Get off at Helwan');
    expect(c.lines, isEmpty);
    final ar = StepCopy.of(await l10nFor('ar'), trip, 4);
    expect(ar.lines, isEmpty, reason: 'no "وبعدين امشي ... لحد المكان اللي رايحه"');
  });

  test('Arabic stop counts and Arabic commas', () async {
    final c = StepCopy.of(await l10nFor('ar'), trip, 3);
    expect(c.lines.last, contains('محطة واحدة'));
    expect(c.lines.last, contains('، '));
  });

  test('Arabic walk line reads as words', () async {
    final c = StepCopy.of(await l10nFor('ar'), trip, 0);
    expect(c.lines, ['704 متر، حوالي 10 دقائق']);
  });

  test('live: a ride counts down to the get-off at the ride pace', () async {
    // 4200 m in 12 min = 350 m/min; 1400 m left = 4 min.
    expect(StepCopy.live(await l10nFor('en'), trip, 1, 1400), 'Get off at Kids Land in about 4 min');
    expect(StepCopy.live(await l10nFor('ar'), trip, 1, 1400), 'هتنزل في Kids Land بعد حوالي 4 دقائق');
  });

  test('live: a walk counts down at walking pace, without repeating the place', () async {
    expect(StepCopy.live(await l10nFor('en'), trip, 0, 450), '450 m left, about 6 min');
    expect(StepCopy.live(await l10nFor('ar'), trip, 0, 670), 'فاضل 670 متر، حوالي 9 دقائق');
  });

  test('live: a get-off walk names where it goes, its title does not', () async {
    expect(StepCopy.live(await l10nFor('en'), trip, 2, 150), '150 m to Abbas, about 2 min');
  });

  test('live: under a minute reads "about a minute", never "0 m" or a bare tilde', () async {
    final ar = await l10nFor('ar');
    expect(StepCopy.live(ar, trip, 0, 40), 'فاضل 40 متر، حوالي دقيقة');
    expect(StepCopy.live(ar, trip, 0, 3), 'هتوصل 8th District...');
    expect(StepCopy.live(await l10nFor('en'), trip, 0, 0), 'Arriving at 8th District...');
  });

  test('no step line has a middle dot or a tilde', () async {
    for (final code in ['en', 'ar']) {
      final l10n = await l10nFor(code);
      for (var i = 0; i < trip.length; i++) {
        final c = StepCopy.of(l10n, trip, i);
        for (final text in [c.title, ...c.lines, StepCopy.live(l10n, trip, i, 500) ?? '']) {
          expect(text, isNot(contains('·')), reason: '$code step $i: $text');
          expect(text, isNot(contains('~')), reason: '$code step $i: $text');
        }
      }
    }
  });
}
