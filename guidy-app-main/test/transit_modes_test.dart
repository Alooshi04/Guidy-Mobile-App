import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/services/transit_modes.dart';

void main() {
  // ────────────────────────────────────────────────────────────────────
  // icon — correct IconData for every mode
  // ────────────────────────────────────────────────────────────────────
  group('TransitModes.icon', () {
    test('metro returns directions_subway', () {
      expect(TransitModes.icon('metro'), equals(Icons.directions_subway));
    });

    test('monorail returns tram (no Icons.monorail in Flutter stable)', () {
      expect(TransitModes.icon('monorail'), equals(Icons.tram));
    });

    test('lrt returns train', () {
      expect(TransitModes.icon('lrt'), equals(Icons.train));
    });

    test('tram returns directions_railway', () {
      expect(TransitModes.icon('tram'), equals(Icons.directions_railway));
    });

    test('apm returns local_airport', () {
      expect(TransitModes.icon('apm'), equals(Icons.local_airport));
    });

    test('minibus returns directions_bus_filled', () {
      expect(TransitModes.icon('minibus'), equals(Icons.directions_bus_filled));
    });

    test('microbus returns airport_shuttle', () {
      expect(TransitModes.icon('microbus'), equals(Icons.airport_shuttle));
    });

    test('brt returns directions_bus_rounded, distinct from a CTA bus', () {
      expect(TransitModes.icon('brt'), equals(Icons.directions_bus_rounded));
      expect(TransitModes.icon('brt'), isNot(equals(TransitModes.icon('bus'))));
      expect(TransitModes.color('brt'), isNot(equals(TransitModes.color('bus'))));
      expect(TransitModes.browsableFilters, contains('brt'));
      expect(TransitModes.isRail('brt'), isTrue);
    });

    test('walk returns directions_walk', () {
      expect(TransitModes.icon('walk'), equals(Icons.directions_walk));
    });

    test('transfer returns swap_horiz', () {
      expect(TransitModes.icon('transfer'), equals(Icons.swap_horiz));
    });

    test('arrive returns flag', () {
      expect(TransitModes.icon('arrive'), equals(Icons.flag));
    });

    test('null defaults to directions_bus', () {
      expect(TransitModes.icon(null), equals(Icons.directions_bus));
    });

    test('unknown string defaults to directions_bus', () {
      expect(TransitModes.icon('flying_carpet'), equals(Icons.directions_bus));
    });
  });

  // ────────────────────────────────────────────────────────────────────
  // color — distinct colors, especially for interchange modes
  // ────────────────────────────────────────────────────────────────────
  group('TransitModes.color', () {
    test('all modes return non-null colors', () {
      for (final mode in ['metro', 'monorail', 'lrt', 'tram', 'apm',
                          'minibus', 'microbus', 'walk', 'bus', null]) {
        expect(TransitModes.color(mode), isNotNull);
      }
    });

    test('metro, monorail, and LRT have DIFFERENT colors (interchange distinguishability)', () {
      final metroColor = TransitModes.color('metro');
      final monorailColor = TransitModes.color('monorail');
      final lrtColor = TransitModes.color('lrt');
      expect(metroColor, isNot(equals(monorailColor)),
          reason: 'Metro and monorail meet at Cairo Stadium — must be visually distinct');
      expect(metroColor, isNot(equals(lrtColor)),
          reason: 'Metro and LRT meet at Adly Mansour — must be visually distinct');
      expect(monorailColor, isNot(equals(lrtColor)),
          reason: 'Monorail and LRT meet at Arts & Culture City — must be visually distinct');
    });
  });

  // ────────────────────────────────────────────────────────────────────
  // isRail
  // ────────────────────────────────────────────────────────────────────
  group('TransitModes.isRail', () {
    test('true for rail modes', () {
      for (final mode in ['metro', 'monorail', 'lrt', 'tram', 'apm']) {
        expect(TransitModes.isRail(mode), isTrue, reason: '$mode should be rail');
      }
    });

    test('false for road and other modes', () {
      for (final mode in ['bus', 'minibus', 'microbus', 'walk']) {
        expect(TransitModes.isRail(mode), isFalse, reason: '$mode should not be rail');
      }
    });

    test('false for null', () {
      expect(TransitModes.isRail(null), isFalse);
    });

    test('false for unknown string', () {
      expect(TransitModes.isRail('gondola'), isFalse);
    });
  });

  // ────────────────────────────────────────────────────────────────────
  // static lists
  // ────────────────────────────────────────────────────────────────────
  group('static lists', () {
    test('rail contains exactly metro, monorail, lrt', () {
      expect(TransitModes.rail, equals(['metro', 'monorail', 'lrt']));
    });

    test('browsableFilters starts with null and has expected modes', () {
      expect(TransitModes.browsableFilters, equals([
        null, 'bus', 'minibus', 'microbus', 'brt', 'metro', 'monorail', 'lrt',
      ]));
    });
  });
}
