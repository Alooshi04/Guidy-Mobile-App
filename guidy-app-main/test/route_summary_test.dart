import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations_ar.dart';
import 'package:guidy_app/l10n/app_localizations_en.dart';
import 'package:guidy_app/services/route_summary.dart';

// The route card and the route detail page read a route through
// RouteSummary: its legs in order, each walk's distance, each ride's
// planned line and every line that covers it, and the fare.
final l10n = AppLocalizationsEn();

Map<String, dynamic> _line(String? number, {String vt = 'bus', bool primary = false, num every = 5, num fare = 7.5}) => {
      'route_id': 'r-$number-$vt',
      'route_number': number,
      'vehicle_type': vt,
      'is_primary': primary,
      'typical_headway_min': every,
      'fare_egp': fare,
      'walk_to_board_m': 0,
    };

Map<String, dynamic> _ride({
  required List<Map<String, dynamic>> lines,
  String vt = 'bus',
  String station = 'Sidi Gaber',
  num fare = 7.5,
  String action = 'board',
}) {
  final primary = lines.firstWhere((l) => l['is_primary'] == true, orElse: () => lines.first);
  return {
    'action': action,
    'hail': true,
    'station': station,
    'route_id': primary['route_id'],
    'route_number': primary['route_number'],
    'vehicle_type': vt,
    'fare_egp': fare,
    'stops_count': 30,
    'ride_min': 41,
    'wait_min': 8,
    'alight_station': 'Mahattet Masr',
    'boarding_options': lines,
  };
}

Map<String, dynamic> _option(List<Map<String, dynamic>> steps, {String type = 'Recommended', num fare = 12.5, num time = 75}) =>
    {'type': type, 'time': '$time', 'fare_total_egp': fare, 'fare_egp': fare, 'instructions': steps};

void main() {
  test('a ride lists every line that covers it, in the order sent', () {
    final s = RouteSummary.of(l10n, _option([
      _ride(lines: [_line('871', primary: true), _line('45'), _line('290'), _line('221'), _line('45')]),
    ]));
    expect(s.legs.single.lineLabels, ['871', '45', '290', '221']);
  });

  // Seen on Victoria -> Mahattet Masr: microbuses (no numbers) and buses
  // cover the same ride. The chip must not pass bus numbers off as the
  // microbus, so the numberless lines are named by their mode.
  test('lines without a number are named by their mode, once', () {
    final s = RouteSummary.of(l10n, _option([
      _ride(vt: 'microbus', lines: [
        _line(null, vt: 'microbus', primary: true),
        _line(null, vt: 'microbus'),
        _line('738'),
        _line('244'),
      ]),
    ]));
    expect(s.legs.single.lineLabels, [l10n.vehicleMicrobus, '738', '244']);
  });

  test('walks sit between the rides; back-to-back walks are one, a few steps are none', () {
    final s = RouteSummary.of(l10n, _option([
      {'action': 'walk_to_station', 'station': 'Sidi Gaber', 'distance_m': 350},
      _ride(lines: [_line('871', primary: true)]),
      {'action': 'walk_to_transfer', 'station': 'Mahattet Masr', 'distance_m': 8},
      _ride(vt: 'microbus', action: 'transfer', lines: [_line(null, vt: 'microbus', primary: true)]),
      {'action': 'arrive', 'station': 'Agami'},
      {'action': 'walk_to_destination', 'distance_m': 120},
      {'action': 'continue_walk', 'distance_m': 80},
    ]));
    expect([for (final l in s.legs) l.isWalk ? 'walk ${l.meters}' : 'ride ${l.lineLabels.first}'],
        ['walk 350', 'ride 871', 'ride ${l10n.vehicleMicrobus}', 'walk 200']);
  });

  // "Show how many metres I'll walk and the recommended minibus number"
  // (beta reviewer, 2026-11).
  test('a ride is named by the line it was planned with, not the first one sent', () {
    final s = RouteSummary.of(l10n, _option([
      _ride(lines: [_line('45', every: 3), _line('871', primary: true, every: 5)]),
      _ride(vt: 'minibus', action: 'transfer', lines: [_line('66', vt: 'minibus', primary: true), _line('70', vt: 'minibus')]),
    ], fare: 12.5));
    expect([for (final l in s.legs) l.line], ['Bus 871', 'Minibus 66']);
    expect(s.fareText(l10n), '12.5 EGP');
  });

  test('a numberless microbus is named by its mode, a metro line as riders say it', () {
    final s = RouteSummary.of(l10n, _option([
      _ride(vt: 'microbus', lines: [_line(null, vt: 'microbus', primary: true), _line('738')]),
      _ride(vt: 'metro', action: 'transfer', lines: [
        {..._line('3', vt: 'metro', primary: true), 'route_id': 'NAT_L3'},
      ])
        ..['route_id'] = 'NAT_L3',
    ]));
    expect([for (final l in s.legs) l.line], [l10n.vehicleMicrobus, 'M3']);
  });

  test('a walk says how far: metres, then kilometres from one', () {
    final s = RouteSummary.of(l10n, _option([
      {'action': 'walk_to_station', 'distance_m': 376},
      _ride(lines: [_line('871', primary: true)]),
      {'action': 'walk_to_destination', 'distance_m': 1240},
    ]));
    expect([for (final l in s.legs.where((l) => l.isWalk)) l.walkText(l10n)], ['376 m', '1.2 km']);
    final ar = AppLocalizationsAr();
    expect(RouteSummary.of(ar, _option([{'action': 'walk_to_station', 'distance_m': 376}])).legs.single.walkText(ar),
        '376 م');
  });

  test('a short paid ride says what it buys without a middle dot', () {
    final s = RouteSummary.of(l10n, {
      ..._option([_ride(lines: [_line('871', primary: true)])]),
      'short_ride': {'saves_min': 15, 'extra_egp': 20},
    });
    expect(s.shortRide, '15 min faster for 20 EGP more');
  });

  test('a walk-only route is free', () {
    final s = RouteSummary.of(l10n, _option([
      {'action': 'walk_to_destination', 'distance_m': 900},
    ], type: 'Walk', fare: 0));
    expect(s.legs.single.walkText(l10n), '900 m');
    expect(s.fareText(l10n), l10n.fareFree);
  });

  // Build 19 stacked Recommended + Cheapest + Fastest on one card.
  test('a route carries at most one tag, and a plain alternative none', () {
    final rec = RouteSummary.of(l10n, {
      ..._option([], type: 'Recommended'),
      'also_qualifies_as': ['Cheapest', 'Fastest'],
    });
    expect(rec.tag, 'Recommended');
    expect(RouteSummary.of(l10n, _option([], type: 'Alternative')).tag, isNull);
    expect(RouteSummary.of(l10n, _option([], type: 'Cheapest')).tag, 'Cheapest');
  });

  test('a metro line is said the way riders say it', () {
    final s = RouteSummary.of(l10n, _option([
      _ride(vt: 'metro', lines: [_line('2', vt: 'metro', primary: true)]),
    ]));
    expect(s.legs.single.lineLabels, ['M2']);
    expect(s.legs.single.line, 'M2');
  });

  test('a leg the backend says to ask the driver about is named by its mode only', () {
    final s = RouteSummary.of(l10n, _option([
      _ride(vt: 'microbus', lines: [_line(null, vt: 'microbus', primary: true), _line('738'), _line('244')])
        ..['ask_driver_en'] = 'Cine Plex'
        ..['ask_driver_ar'] = 'سيني بلكس',
    ]));
    expect(s.legs.single.lineLabels, [l10n.vehicleMicrobus]);
    expect(s.legs.single.line, l10n.vehicleMicrobus);
  });
}
