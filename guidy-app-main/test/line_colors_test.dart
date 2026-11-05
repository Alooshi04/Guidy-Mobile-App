import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/screens/trip/trip_live_share.dart';
import 'package:guidy_app/services/transit_modes.dart';
import 'package:guidy_app/theme/guidy_ui.dart';

// A ride is the same colour everywhere in the app: metro Line 3 is green on
// the card, the map, the trip and the recap (owner, 2026-10-22).
void main() {
  final l1 = GuidyModeStyle.metroLine('1')!;
  final l3 = GuidyModeStyle.metroLine('3')!;

  Map<String, dynamic> board(String routeId, String vt, {String action = 'board', String? number}) =>
      {'action': action, 'route_id': routeId, 'vehicle_type': vt, 'route_number': ?number};

  group('forRide', () {
    test('each metro line has its own colour, from the route id or its number', () {
      expect(GuidyModeStyle.forRide(board('NAT_L3', 'metro')), l3);
      expect(GuidyModeStyle.forRide(board('NAT_L1', 'metro')), l1);
      expect(GuidyModeStyle.forRide({'vehicle_type': 'metro', 'route_number': '3'}), l3);
    });

    test('other modes use their mode colour', () {
      expect(GuidyModeStyle.forRide(board('ALX_MICRO_018', 'microbus')), GuidyModeStyle.color('microbus'));
      expect(GuidyModeStyle.forRide({'vehicle_type': 'metro'}), GuidyModeStyle.color('metro'));
    });

    test('the monorail is not Line 3 green: they meet at Cairo Stadium', () {
      expect(GuidyModeStyle.color('monorail'), isNot(l3));
    });

    test('TransitModes.color is the same palette', () {
      for (final m in ['bus', 'microbus', 'minibus', 'metro', 'monorail', 'lrt', 'brt']) {
        expect(TransitModes.color(m), GuidyModeStyle.color(m), reason: m);
      }
    });
  });

  group('forStep', () {
    test('a ride and a change onto a line take the line colour', () {
      expect(GuidyModeStyle.forStep(board('NAT_L3', 'metro')), l3);
      expect(GuidyModeStyle.forStep(board('NAT_L3', 'metro', action: 'transfer')), l3);
    });

    test('walks and the arrival keep their own', () {
      expect(GuidyModeStyle.forStep({'action': 'walk_to_station'}), GuidyModeStyle.walkStep);
      expect(GuidyModeStyle.forStep({'action': 'arrive'}), GuidyModeStyle.arriveStep);
    });
  });

  group('segmentColors', () {
    final steps = [
      {'action': 'walk_to_station'},
      board('NAT_L1', 'metro'),
      board('NAT_L3', 'metro', action: 'transfer'),
      {'action': 'walk_to_destination'},
    ];

    test('an older server: the n-th ride segment is the n-th boarding', () {
      final segs = [
        {'is_walk': true},
        {'vehicle_type': 'metro', 'color': '#6DA4C2'},
        {'vehicle_type': 'metro', 'color': '#6DA4C2'},
        {'is_walk': true},
      ];
      expect(GuidyModeStyle.segmentColors(segs, steps), [null, l1, l3, null]);
    });

    test('a newer server names the line on the segment', () {
      final segs = [
        {'vehicle_type': 'metro', 'route_id': 'NAT_L3'},
      ];
      expect(GuidyModeStyle.segmentColors(segs, const []), [l3]);
    });

    test('counts that disagree: each segment keeps its mode colour', () {
      final segs = [
        {'vehicle_type': 'metro'},
      ];
      expect(GuidyModeStyle.segmentColors(segs, steps), [GuidyModeStyle.color('metro')]);
    });
  });

  test('a shared live trip sends the same colours', () {
    final summary = TripLiveShare.summaryOf(
      pathData: {
        'segments': [
          {'vehicle_type': 'metro', 'color': '#6DA4C2', 'points': []},
        ],
      },
      instructions: [board('NAT_L3', 'metro')],
      destName: 'Nasr City',
      startName: null,
      end: null,
      plannedMinutes: 30,
    );
    expect((summary['segments'] as List).single['color'], GuidyModeStyle.hex(l3));
  });
}
