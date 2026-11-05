import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/services/route_choice.dart';

void main() {
  walkTests();
  test('the planned line leads a ride\'s lines, the rest keep their order', () {
    final option = <String, dynamic>{
      'instructions': [
        {'action': 'walk_to_station'},
        {
          'action': 'board',
          'boarding_options': [
            {'route_id': 'B1036', 'is_primary': false},
            {'route_id': 'MB100', 'is_primary': true},
            {'route_id': 'B7', 'is_primary': false},
          ],
        },
      ],
    };
    RouteChoice.plannedLineFirst(option);
    final ids = [for (final o in (option['instructions'][1]['boarding_options'] as List)) o['route_id']];
    expect(ids, ['MB100', 'B1036', 'B7']);
  });

  test('a ride already led by its planned line, or with no options, is untouched', () {
    final option = <String, dynamic>{
      'instructions': [
        {'action': 'board'},
        {
          'action': 'board',
          'boarding_options': [
            {'route_id': 'a', 'is_primary': true},
            {'route_id': 'b'},
          ],
        },
      ],
    };
    RouteChoice.plannedLineFirst(option);
    expect(option['instructions'][0].containsKey('boarding_options'), isFalse);
    expect([for (final o in (option['instructions'][1]['boarding_options'] as List)) o['route_id']], ['a', 'b']);
  });
}

void walkTests() {
  test('picking a line that boards elsewhere moves the walk before it', () {
    final option = <String, dynamic>{
      'instructions': [
        {'action': 'walk_to_station', 'station': 'Road', 'distance_m': 300},
        {
          'action': 'board',
          'station': 'Road',
          'fare_egp': 5,
          'boarding_options': [
            {'route_id': 'a', 'is_primary': true},
            {'route_id': 'b', 'board_stop_name': 'Museum', 'board_lat': 1.0, 'board_lon': 2.0, 'walk_to_board_m': 80},
          ],
        },
      ],
    };
    final r = RouteChoice.apply(option, {1: 1});
    final walk = (r['instructions'] as List)[0] as Map;
    expect(walk['station'], 'Museum');
    expect(walk['distance_m'], 380);
    expect((option['instructions'] as List)[0]['station'], 'Road'); // the original is untouched
  });
}
