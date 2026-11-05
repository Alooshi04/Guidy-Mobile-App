import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/screens/trip/vehicle_switch.dart';

Map<String, dynamic> step() => {
      'action': 'board',
      'route_id': 'MB66',
      'route_number': '66',
      'vehicle_type': 'minibus',
      'fare_egp': 10,
      'wait_min': 4,
      'boarding_options': [
        {'route_id': 'MB66', 'is_primary': true},
        {'route_id': 'B35', 'route_number': '35', 'vehicle_type': 'bus', 'fare_egp': 8, 'eta_sec': 300},
        {'route_id': 'MC', 'vehicle_type': 'microbus', 'typical_headway_min': 5},
      ],
    };

void main() {
  test('switching takes the new line alight name to ask the driver about', () {
    final st = step()..['ask_driver_en'] = 'Old'..['ask_driver_ar'] = 'قديم';
    applyVehicleSwitch(st, {'route_id': 'B35', 'vehicle_type': 'bus', 'ask_driver_en': 'New', 'ask_driver_ar': 'جديد'});
    expect(st['ask_driver_en'], 'New');
    expect(st['ask_driver_ar'], 'جديد');
  });

  test('switching takes the new line, its fare and its live wait', () {
    final s = step();
    final opt = (s['boarding_options'] as List)[1] as Map<String, dynamic>;
    final change = applyVehicleSwitch(s, opt);
    expect(s['route_id'], 'B35');
    expect(s['route_number'], '35');
    expect(s['vehicle_type'], 'bus');
    expect(s['fare_egp'], 8);
    expect(s['wait_min'], 5); // 300 s
    expect(change.fareDelta, -2);
    expect(change.waitDelta, 1);
    expect(change.moved, isFalse);
    expect([for (final o in s['boarding_options'] as List) o['is_primary']], [false, true, false]);
  });

  test('without a live ETA the wait is half the headway; no fare keeps the old one', () {
    final s = step();
    final change = applyVehicleSwitch(s, (s['boarding_options'] as List)[2] as Map<String, dynamic>);
    expect(s['wait_min'], 3); // ceil(5 / 2)
    expect(change.waitDelta, -1);
    expect(change.fareDelta, 0);
  });

  test('no ETA and no headway: the wait is left alone', () {
    final s = step();
    final change = applyVehicleSwitch(s, {'route_id': 'X'});
    expect(change.waitDelta, isNull);
    expect(s['wait_min'], 4);
  });

  test('switching between lines with piastre fares keeps the piastres', () {
    final step = <String, dynamic>{'action': 'board', 'route_id': 'a', 'fare_egp': 5.5};
    final change = applyVehicleSwitch(step, {'route_id': 'b', 'fare_egp': 7.25});
    expect(change.fareDelta, 1.75);
    expect(step['fare_egp'], 7.25);
  });

  group('the walk before the ride follows the switch', () {
    Map<String, dynamic> ride() => {
          'action': 'board',
          'station': 'On the road',
          'route_id': 'a',
          'boarding_options': [
            {
              'route_id': 'a',
              'is_primary': true,
              'board_stop_name': 'On the road',
              'board_lat': 31.0,
              'board_lon': 29.0,
              'walk_to_board_m': 0,
            },
            {
              'route_id': 'b',
              'board_stop_name': 'Mosaic Museum',
              'board_stop_name_ar': 'متحف الفسيفساء',
              'board_lat': 31.001,
              'board_lon': 29.001,
              'walk_to_board_m': 76,
            },
          ],
        };
    Map<String, dynamic> walk() =>
        {'action': 'walk_to_station', 'station': 'On the road', 'distance_m': 339, 'lat': 31.0, 'lon': 29.0};

    test('it names the new stop, adds the extra walk, and moves to its position', () {
      final r = ride(), w = walk();
      applyVehicleSwitch(r, (r['boarding_options'] as List)[1] as Map<String, dynamic>, walkBefore: w);
      expect(w['station'], 'Mosaic Museum');
      expect(w['station_ar'], 'متحف الفسيفساء');
      expect(w['distance_m'], 339 + 76);
      expect(w['lat'], 31.001);
    });

    test('taking the planned line back restores the walk', () {
      final r = ride(), w = walk();
      final opts = r['boarding_options'] as List;
      applyVehicleSwitch(r, opts[1] as Map<String, dynamic>, walkBefore: w);
      applyVehicleSwitch(r, opts[0] as Map<String, dynamic>, walkBefore: w);
      expect(w['station'], 'On the road');
      expect(w['distance_m'], 339);
      expect(w['lat'], 31.0);
    });

    test('a line boarding at the same stop leaves the walk alone', () {
      final r = ride(), w = walk();
      applyVehicleSwitch(r, {'route_id': 'c'}, walkBefore: w);
      expect(w['station'], 'On the road');
      expect(w['distance_m'], 339);
    });
  });
}
