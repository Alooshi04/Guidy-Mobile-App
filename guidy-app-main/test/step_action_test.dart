import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/services/step_action.dart';

// What each live trip step says on its card: one bold action ("Wave down
// any of these"), the place it's about, and the lines you can take.
void main() {
  late AppLocalizations en;

  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  final hailTrip = <Map<String, dynamic>>[
    {'action': 'walk_to_station', 'station': 'On the road to Wadi Hof Metro', 'distance_m': 339},
    {
      'action': 'board',
      'hail': true,
      'station': 'On the road to Wadi Hof Metro',
      'alight_station': 'Al Montazah Train Station',
      'route_number': '871',
      'vehicle_type': 'bus',
      'stops_count': 30,
      'ride_min': 49,
      'wait_min': 10,
      'fare_egp': 5.5,
      'boarding_options': [
        {'route_id': 'a', 'route_number': '871', 'vehicle_type': 'bus', 'is_primary': true, 'fare_egp': 5.5},
        {'route_id': 'b', 'route_number': '45', 'vehicle_type': 'bus', 'fare_egp': 20},
      ],
    },
    {'action': 'arrive', 'hail': true, 'station': 'Al Montazah Train Station'},
    {'action': 'walk_to_destination', 'distance_m': 942},
  ];

  test('a walk to a hailed boarding says how long and where', () {
    final a = StepAction.of(en, hailTrip, 0);
    expect(a.header, 'Walk 5 min to');
    expect(a.title, 'On the road to Wadi Hof Metro');
  });

  test('a hailed boarding with several lines says to wave any of them down', () {
    final a = StepAction.of(en, hailTrip, 1);
    expect(a.header, 'Wave down any of these');
    expect(a.title, 'On the road to Wadi Hof Metro');
    expect(a.lines.map((l) => l.label), ['Bus 871', 'Bus 45']);
    expect(a.lines.first.isPlanned, isTrue);
    expect(a.ride, 'Get off at Al Montazah Train Station, 30 stops, 49 min');
  });

  test('a single line at a stop says to take it there', () {
    final atStop = [
      {'action': 'board', 'station': 'Al Tabba', 'route_number': '24', 'vehicle_type': 'microbus'},
    ];
    final a = StepAction.of(en, atStop, 0);
    expect(a.header, 'Take microbus 24 at');
    expect(a.title, 'Al Tabba');
    expect(a.lines.map((l) => l.label), ['Microbus 24']);
    expect(a.lines.single.isPlanned, isTrue);
  });

  test('several lines at a stop say to wait for any of them', () {
    final atStop = [
      {
        'action': 'board',
        'station': 'Sidi Gaber',
        'route_number': '1',
        'vehicle_type': 'bus',
        'boarding_options': [
          {'route_id': 'a', 'route_number': '1', 'vehicle_type': 'bus', 'is_primary': true},
          {'route_id': 'b', 'route_number': '2', 'vehicle_type': 'bus'},
        ],
      },
    ];
    expect(StepAction.of(en, atStop, 0).header, 'Wait for one of these');
  });

  test('a single hailed line says to wave it down', () {
    final hail = [
      {'action': 'board', 'hail': true, 'station': 'Corniche', 'route_number': '24', 'vehicle_type': 'microbus'},
    ];
    expect(StepAction.of(en, hail, 0).header, 'Wave down microbus 24 on');
  });

  test('a hailed stop says to ask the driver', () {
    final a = StepAction.of(en, hailTrip, 2);
    expect(a.header, 'Ask the driver to stop at');
    expect(a.title, 'Al Montazah Train Station');
  });

  test('a stop says to get off there', () {
    final a = StepAction.of(en, [
      {'action': 'arrive', 'station': 'Raml Station'},
    ], 0);
    expect(a.header, 'Get off at');
    expect(a.title, 'Raml Station');
  });

  test('the last walk goes to the destination by name', () {
    final a = StepAction.of(en, hailTrip, 3, destination: 'Montaza Palace');
    expect(a.header, 'Walk 13 min to');
    expect(a.title, 'Montaza Palace');
  });

  test('a change says to get off and walk to the next stop', () {
    final a = StepAction.of(en, [
      {'action': 'walk_to_transfer', 'station': 'Sidi Gaber', 'distance_m': 150},
      {'action': 'board', 'station': 'Sidi Gaber Metro', 'route_number': '2', 'vehicle_type': 'bus'},
    ], 0);
    expect(a.header, 'Get off, then walk 2 min to');
    expect(a.title, 'Sidi Gaber Metro');
  });

  test('a line that costs more than the planned one says its fare', () {
    final lines = StepAction.of(en, hailTrip, 1).lines;
    expect(lines.first.note, isNull);
    expect(lines.last.note, '20 EGP');
  });

  // The backend prices the metro by stops on the leg, so its line comes
  // with fare 0: that's "no per-line fare", not a free ride.
  test('a metro line priced by the leg does not say 0 EGP', () {
    final a = StepAction.of(en, [
      {
        'action': 'board',
        'station': 'Sadat',
        'route_number': '1',
        'vehicle_type': 'metro',
        'fare_egp': 10,
        'boarding_options': [
          {'route_id': 'M1', 'route_number': '1', 'vehicle_type': 'metro', 'is_primary': true, 'fare_egp': 0},
        ],
      },
    ], 0);
    expect(a.lines.single.note, isNull);
  });

  test('a line with a live position says how far away it is', () {
    final a = StepAction.of(en, [
      {
        'action': 'board',
        'station': 'Raml',
        'boarding_options': [
          {'route_id': 'a', 'route_number': '1', 'vehicle_type': 'bus', 'is_primary': true},
          {'route_id': 'b', 'route_number': '2', 'vehicle_type': 'bus', 'eta_sec': 170},
        ],
      },
    ], 0);
    expect(a.lines.last.note, 'about 3 min away');
  });

  test('a line boarding a short walk away says where it boards', () {
    final a = StepAction.of(en, [
      {
        'action': 'board',
        'station': 'Al Tabba',
        'fare_egp': 10,
        'boarding_options': [
          {'route_id': 'MB', 'vehicle_type': 'microbus', 'is_primary': true, 'fare_egp': 10, 'walk_to_board_m': 0},
          {
            'route_id': 'M140', 'route_number': '140', 'vehicle_type': 'minibus', 'fare_egp': 10,
            'board_stop_name': 'Ragab Sons', 'walk_to_board_m': 180,
          },
        ],
      },
    ], 0);
    expect(a.lines.last.note, '180 m walk to Ragab Sons');
  });

  test("a leg moved to a stop a short walk away says the walks on and off", () {
    final a = StepAction.of(en, [
      {
        'action': 'board',
        'station': 'Ragab Sons',
        'route_number': '140',
        'vehicle_type': 'minibus',
        'walk_to_board_m': 180,
        'board_stop_name': 'Ragab Sons',
        'walk_from_alight_m': 250,
        'alight_stop_name': 'Shams Club',
      },
    ], 0);
    expect(a.notes, ['Walk 180 m to Ragab Sons first', 'Get off at Shams Club, then walk 250 m']);
  });

  test('Arabic: the header and places read in Arabic', () async {
    final ar = await AppLocalizations.delegate.load(const Locale('ar'));
    final a = StepAction.of(ar, [
      {
        'action': 'board',
        'hail': true,
        'station': 'Corniche',
        'station_ar': 'الكورنيش',
        'boarding_options': [
          {'route_id': 'a', 'route_number': '1', 'vehicle_type': 'bus', 'is_primary': true},
          {'route_id': 'b', 'route_number': '2', 'vehicle_type': 'bus'},
        ],
      },
    ], 0);
    expect(a.header, 'شاور لأي واحدة من دول');
    expect(a.title, 'الكورنيش');
  });

  group('ask the driver (owner, 2026-10-16)', () {
    Map<String, dynamic> trip({String vt = 'microbus', bool hail = true}) => {
          'action': 'board',
          'hail': hail,
          'station': 'Sidi Gaber',
          'alight_station': 'Near Cine Plex',
          'ask_driver_en': 'Cine Plex',
          'ask_driver_ar': 'سيني بلكس',
          'vehicle_type': vt,
          'boarding_options': [
            {'route_id': 'a', 'vehicle_type': vt, 'is_primary': true},
            {'route_id': 'b', 'vehicle_type': vt},
          ],
        };

    test('a road leg tells the rider what to ask instead of leading with the lines', () {
      final a = StepAction.of(en, [trip()], 0);
      expect(a.askDriver, 'Ask the driver: going to Cine Plex?');
      expect(a.header, 'Wave down a ride');
      expect(a.linesLabel, 'Which microbuses?');
      expect(a.lines, hasLength(2));
    });

    test('buses say buses, and not hailed says to wait', () {
      final a = StepAction.of(en, [trip(vt: 'bus', hail: false)], 0);
      expect(a.header, 'Wait for a ride');
      expect(a.linesLabel, 'Which buses?');
    });

    test('Arabic', () async {
      final ar = await AppLocalizations.delegate.load(const Locale('ar'));
      expect(StepAction.of(ar, [trip()], 0).askDriver, 'اسأل السواق: رايح سيني بلكس؟');
    });

    test('without the backend field the leg keeps its old wording', () {
      final t = trip()..remove('ask_driver_en');
      final a = StepAction.of(en, [t], 0);
      expect(a.askDriver, isNull);
      expect(a.header, 'Wave down any of these');
    });
  });
}
