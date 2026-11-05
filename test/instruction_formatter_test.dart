import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/services/instruction_formatter.dart';


void main() {
  // ──────────────────────────────────────────────────────────────────────
  // asNum — pure logic, no localization needed
  // ──────────────────────────────────────────────────────────────────────
  group('asNum', () {
    test('null returns null', () {
      expect(InstructionFormatter.asNum(null), isNull);
    });

    test('int returns int', () {
      expect(InstructionFormatter.asNum(42), equals(42));
    });

    test('double returns double', () {
      expect(InstructionFormatter.asNum(3.14), equals(3.14));
    });

    test('valid numeric string returns num', () {
      expect(InstructionFormatter.asNum('20'), equals(20));
      expect(InstructionFormatter.asNum(' 3.5 '), equals(3.5));
    });

    test('invalid string returns null', () {
      expect(InstructionFormatter.asNum('abc'), isNull);
      expect(InstructionFormatter.asNum(''), isNull);
    });

    test('non-string non-num returns null', () {
      expect(InstructionFormatter.asNum(true), isNull);
    });
  });

  // ──────────────────────────────────────────────────────────────────────
  // Tests that need AppLocalizations
  // ──────────────────────────────────────────────────────────────────────
  group('InstructionFormatter with localization', () {
    late AppLocalizations l10n;

    setUp(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('en'));
    });

    // ── iconKey ──────────────────────────────────────────────────────────
    group('iconKey', () {
      test('walk actions return "walk"', () {
        for (final action in [
          'walk_to_station',
          'walk_to_transfer',
          'continue_walk',
          'walk_to_destination',
        ]) {
          expect(InstructionFormatter.iconKey({'action': action}), 'walk');
        }
      });

      test('transfer returns "transfer"', () {
        expect(InstructionFormatter.iconKey({'action': 'transfer'}), 'transfer');
      });

      test('arrive returns "arrive"', () {
        expect(InstructionFormatter.iconKey({'action': 'arrive'}), 'arrive');
      });

      test('board returns vehicle_type', () {
        expect(
          InstructionFormatter.iconKey({'action': 'board', 'vehicle_type': 'metro'}),
          'metro',
        );
      });

      test('board with null vehicle_type defaults to bus', () {
        expect(InstructionFormatter.iconKey({'action': 'board'}), 'bus');
      });
    });

    // ── routeTierLabel ──────────────────────────────────────────────────
    group('routeTierLabel', () {
      test('maps all known tiers', () {
        final knownTiers = [
          'Recommended', 'Fastest', 'Regular', 'Cheapest',
          'Alternative', 'Walk', 'Partial',
        ];
        for (final tier in knownTiers) {
          final label = InstructionFormatter.routeTierLabel(l10n, tier);
          expect(label, isNotEmpty, reason: '$tier should produce a non-empty label');
          // Known tiers should NOT return the raw tier string unchanged
          // (they should be localized)
        }
      });

      test('unknown tier returns raw string', () {
        expect(InstructionFormatter.routeTierLabel(l10n, 'SomeFutureTier'), 'SomeFutureTier');
      });
    });

    // ── fareText ────────────────────────────────────────────────────────
    group('fareText', () {
      test('numeric fare_total_egp formats as EGP', () {
        final text = InstructionFormatter.fareText(l10n, {'fare_total_egp': 15});
        expect(text, contains('15'));
      });

      test('zero fare shows free', () {
        final text = InstructionFormatter.fareText(l10n, {'fare_total_egp': 0});
        expect(text, equals(l10n.fareFree));
      });

      test('string fare is parsed', () {
        final text = InstructionFormatter.fareText(l10n, {'fare_total_egp': '20'});
        expect(text, contains('20'));
      });

      test('walk option is free', () {
        final text = InstructionFormatter.fareText(l10n, {'vehicle_type': 'walk'});
        expect(text, equals(l10n.fareFree));
      });

      test('fallback to price string', () {
        final text = InstructionFormatter.fareText(l10n, {'price': '10 EGP'});
        expect(text, equals('10 EGP'));
      });

      test('null everything returns dash', () {
        final text = InstructionFormatter.fareText(l10n, {});
        expect(text, equals('-'));
      });

      test('fare_egp is used as fallback key', () {
        final text = InstructionFormatter.fareText(l10n, {'fare_egp': 8});
        expect(text, contains('8'));
      });
    });

    // ── title ───────────────────────────────────────────────────────────
    group('title', () {
      test('known actions return non-empty strings', () {
        final actions = [
          'walk_to_station', 'walk_to_transfer', 'continue_walk',
          'board', 'transfer', 'arrive', 'walk_to_destination',
        ];
        for (final a in actions) {
          final t = InstructionFormatter.title(l10n, {'action': a, 'vehicle_type': 'bus'});
          expect(t, isNotEmpty, reason: 'title for "$a" should not be empty');
        }
      });

      test('unknown action returns empty string', () {
        expect(InstructionFormatter.title(l10n, {'action': 'unknown'}), isEmpty);
      });
    });

    // ── subtitle ────────────────────────────────────────────────────────
    group('subtitle', () {
      test('walk_to_station includes station name', () {
        final sub = InstructionFormatter.subtitle(l10n, {
          'action': 'walk_to_station',
          'station': 'Sadat',
          'distance_m': 200,
        });
        expect(sub, contains('Sadat'));
      });

      test('board returns route label', () {
        final sub = InstructionFormatter.subtitle(l10n, {
          'action': 'board',
          'vehicle_type': 'bus',
          'route_number': '27',
        });
        expect(sub, contains('27'));
      });

      test('arrive includes station', () {
        final sub = InstructionFormatter.subtitle(l10n, {
          'action': 'arrive',
          'station': 'Tahrir',
        });
        expect(sub, contains('Tahrir'));
      });

      test('unknown action returns empty string', () {
        expect(InstructionFormatter.subtitle(l10n, {'action': 'xyz'}), isEmpty);
      });
    });

    // ── optionSummary ───────────────────────────────────────────────────
    group('optionSummary', () {
      test('walk option returns walk label', () {
        final summary = InstructionFormatter.optionSummary(l10n, {'vehicle_type': 'walk'});
        expect(summary, equals(InstructionFormatter.vehicleTypeLabel(l10n, 'walk')));
      });

      test('with route_number includes number', () {
        final summary = InstructionFormatter.optionSummary(l10n, {
          'vehicle_type': 'bus',
          'route_number': '302',
        });
        expect(summary, contains('302'));
      });

      test('with description only', () {
        final summary = InstructionFormatter.optionSummary(l10n, {
          'vehicle_type': 'microbus',
          'route_description': 'Nahda City',
        });
        expect(summary, contains('Nahda City'));
      });

      test('null vehicle_type returns walk label', () {
        final summary = InstructionFormatter.optionSummary(l10n, {});
        expect(summary, equals(InstructionFormatter.vehicleTypeLabel(l10n, 'walk')));
      });
    });

    // ── errorMessage ────────────────────────────────────────────────────
    group('errorMessage', () {
      test('maps known error codes', () {
        expect(InstructionFormatter.errorMessage(l10n, {'error_code': 'network'}),
            equals(l10n.serverUnreachable));
        expect(InstructionFormatter.errorMessage(l10n, {'error_code': 'outside_coverage'}),
            equals(l10n.errorOutsideCoverage));
        expect(InstructionFormatter.errorMessage(l10n, {'error_code': 'outside_service_hours'}),
            equals(l10n.errorNoServiceThisHour));
        expect(InstructionFormatter.errorMessage(l10n, {'error_code': 'no_coverage'}),
            equals(l10n.errorNoRouteFound));
        expect(InstructionFormatter.errorMessage(l10n, {'error_code': 'no_route_found'}),
            equals(l10n.errorNoRouteFound));
      });

      test('unknown code with error string returns the string', () {
        expect(InstructionFormatter.errorMessage(l10n, {'error': 'Something broke'}),
            equals('Something broke'));
      });

      test('unknown code with no error string returns generic message', () {
        expect(InstructionFormatter.errorMessage(l10n, {}),
            equals(l10n.routeCalculationFailed));
      });
    });
  });

  // ──────────────────────────────────────────────────────────────────────
  // Route numbers and operator brands -- real short_name shapes from
  // gtfs_data/routes.txt and translations.txt.
  // ──────────────────────────────────────────────────────────────────────
  group('cleanRouteNumber', () {
    test('strips vehicle/operator prefixes, keeps branch letters and codes', () {
      final cases = {
        'CTA 910': '910',
        'CTA 26t': '26t',
        'CTA 173ss': '173ss',
        'APTA 44': '44',
        'apta 733': '733',
        'APTA 24t': '24t',
        'Minibus 305': '305',
        'مينى باص 305': '305',
        'ميني باص Q3': 'Q3',
        'أتوبيس 1088': '1088',
        'Green G1': 'G1',
        'جرين G1': 'G1',
        'MM M11': 'M11',
        'M11': 'M11',
        'Line 1': '1',
        'Minibus Ms4': 'Ms4',
        'MD-1': 'MD-1',
        'AN1': 'AN1',
      };
      cases.forEach((raw, expected) {
        expect(InstructionFormatter.cleanRouteNumber(raw), expected, reason: raw);
      });
    });

    test('a bare vehicle word is not a number', () {
      for (final raw in [
        'APTA', 'Microbus', 'Minibus', 'Tomnaya', 'Box', 'LRT', 'Monorail', 'APM',
        'ميكروباص', 'مينى باص', 'ثمناية', 'بوكس', '', '  ',
      ]) {
        expect(InstructionFormatter.cleanRouteNumber(raw), isNull, reason: raw);
      }
      expect(InstructionFormatter.cleanRouteNumber(null), isNull);
    });
  });

  group('brandOf / lineLabel', () {
    late AppLocalizations en;
    late AppLocalizations ar;

    setUp(() async {
      en = await AppLocalizations.delegate.load(const Locale('en'));
      ar = await AppLocalizations.delegate.load(const Locale('ar'));
    });

    test('Mwasalat Misr is decided by agency, not by a leading M', () {
      expect(InstructionFormatter.lineLabel(en, {
        'vehicle_type': 'bus', 'route_number': '111', 'agency': 'MM', 'route_id': 'MM_111',
      }), 'Mwasalat Misr 111');
      // Madinaty bus MD-1 starts with M but is not Mwasalat Misr.
      expect(InstructionFormatter.lineLabel(en, {
        'vehicle_type': 'bus', 'route_number': 'MD-1', 'agency': 'NC_TMG', 'route_id': 'NC_R_MD_INT1',
      }), 'Bus MD-1');
      // LTRA minibus Ms4 is a minibus.
      expect(InstructionFormatter.lineLabel(en, {
        'vehicle_type': 'minibus', 'route_number': 'Ms4', 'agency': 'LTRA_M', 'route_id': 'MSR_Ms4',
      }), 'Minibus Ms4');
    });

    test('Green Bus by agency; lookup payloads use the display agency name', () {
      expect(InstructionFormatter.lineLabel(en, {
        'vehicle_type': 'bus', 'route_number': 'G1', 'agency': 'GRN', 'route_id': 'GRN_G1',
      }), 'Green Bus G1');
      expect(InstructionFormatter.brandOf({
        'vehicle_type': 'bus', 'route_number': 'Green G2', 'agency': 'Green Bus',
      }), TransitBrand.greenBus);
      expect(InstructionFormatter.brandOf({
        'vehicle_type': 'bus', 'route_number': '618', 'agency': 'Mwasalat Misr',
      }), TransitBrand.mwasalatMisr);
    });

    test('a minibus is never branded, whatever its code', () {
      expect(InstructionFormatter.brandOf({
        'vehicle_type': 'minibus', 'route_number': 'M5', 'agency': '',
      }), TransitBrand.none);
    });

    test('legacy payload without agency falls back to exact code shapes only', () {
      expect(InstructionFormatter.brandOf({'vehicle_type': 'bus', 'route_number': 'M11'}),
          TransitBrand.mwasalatMisr);
      expect(InstructionFormatter.brandOf({'vehicle_type': 'bus', 'route_number': 'MD-1'}),
          TransitBrand.none);
      expect(InstructionFormatter.brandOf({'vehicle_type': 'bus', 'route_number': 'G2'}),
          TransitBrand.greenBus);
    });

    test('CTA buses and minibuses get their number, prefix removed', () {
      expect(InstructionFormatter.lineLabel(en, {
        'vehicle_type': 'bus', 'route_number': 'CTA 910', 'agency': 'CTA', 'route_id': 'CTA_910',
      }), 'Bus 910');
      expect(InstructionFormatter.lineLabel(ar, {
        'vehicle_type': 'minibus', 'route_number': 'مينى باص 305', 'agency': 'CTA_M',
      }), 'ميني باص رقم 305');
    });

    test('metro lines are named the way riders say them', () {
      final line2 = {'vehicle_type': 'metro', 'route_number': '2', 'route_id': 'NAT_L2'};
      expect(InstructionFormatter.lineLabel(ar, line2), 'الخط التاني');
      expect(InstructionFormatter.lineLabel(en, line2), 'Metro Line 2');
      expect(InstructionFormatter.lineLabel(ar, {
        'vehicle_type': 'metro', 'route_number': 'Line 3', 'route_id': 'NAT_L3',
      }), 'الخط التالت');
      expect(InstructionFormatter.lineLabel(ar, {
        'vehicle_type': 'metro', 'route_number': '1',
      }), 'الخط الأول');
    });

    test('unnumbered microbus: vehicle label, never the route_id', () {
      final step = {
        'vehicle_type': 'microbus',
        'route_number': null,
        'route_id': '-pzqD_9pESIJi9DBe5yJq',
        'agency': 'P_O_14',
      };
      expect(InstructionFormatter.lineLabel(en, step), 'Microbus');
      expect(InstructionFormatter.lineLabel(en, {...step, 'route_number': 'Microbus'}), 'Microbus');
    });

    test('BRT has no route number; its label is the mode', () async {
      final ar = await AppLocalizations.delegate.load(const Locale('ar'));
      final leg = {'vehicle_type': 'brt', 'route_number': null, 'route_id': 'BRT_RING_P1', 'agency': 'BRT'};
      expect(InstructionFormatter.lineLabel(en, leg), 'BRT');
      expect(InstructionFormatter.lineLabel(ar, {...leg, 'route_number': 'الأتوبيس الترددي'}), 'الأتوبيس الترددي');
      expect(InstructionFormatter.cleanRouteNumber('BRT'), isNull);
    });

    test('optionSummary keeps the brand when a full boarding option is passed', () {
      expect(InstructionFormatter.optionSummary(en, {
        'vehicle_type': 'bus', 'route_number': 'M21', 'agency': 'MM', 'route_id': 'MM_M21',
        'route_description': 'Cairo University - Laylat Al Qadr',
      }), 'Mwasalat Misr M21');
      expect(InstructionFormatter.optionSummary(en, {
        'vehicle_type': 'microbus', 'route_number': null, 'route_id': 'P_O_14_IG076',
        'route_description': 'Moassasa - Nahda City',
      }), 'Microbus Moassasa - Nahda City');
    });
  });
}
