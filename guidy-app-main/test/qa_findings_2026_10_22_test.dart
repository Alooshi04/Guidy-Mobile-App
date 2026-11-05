import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/l10n/app_localizations_en.dart';
import 'package:guidy_app/services/instruction_formatter.dart';
import 'package:guidy_app/services/route_summary.dart';
import 'package:guidy_app/widgets/error_state.dart';

// What the 2026-10-22 emulator pass found on the route screens.
final l10n = AppLocalizationsEn();

Map<String, dynamic> _walk(int m) => {'action': 'walk_to_station', 'distance_m': m};

Map<String, dynamic> _ride(num rideMin) => {
      'action': 'board',
      'route_id': 'r1',
      'route_number': '7',
      'vehicle_type': 'microbus',
      'ride_min': rideMin,
      'fare_egp': 10,
    };

Map<String, dynamic> _option(List<Map<String, dynamic>> steps, {String type = 'Cheapest'}) =>
    {'type': type, 'time': '60', 'fare_total_egp': 10, 'instructions': steps};

void main() {
  group('bus kind on a line chip', () {
    test('AC, double-decker and electric are said; places in brackets are not', () {
      expect(InstructionFormatter.vehicleKind({'route_description_en': 'El-Mandara - K21 (AC)'}, isAr: false), 'AC');
      expect(
          InstructionFormatter.vehicleKind(
              {'route_description_en': 'Anfoshy - Qasar El-Manatazah (double-decker)'}, isAr: false),
          'double-decker');
      expect(InstructionFormatter.vehicleKind({'route_description_ar': 'المندرة - ك21 (كهربائي, مكيف)'}, isAr: true),
          'كهربائي، مكيف');
      expect(InstructionFormatter.vehicleKind({'route_description_en': 'Ramses - Nasr City (Nasr City)'}, isAr: false),
          isNull);
    });

    test('an ordinary bus says nothing', () {
      expect(InstructionFormatter.vehicleKind({'route_description_en': 'Anfoshy - Abu Qir (regular)'}, isAr: false),
          isNull);
      expect(InstructionFormatter.vehicleKind({'route_description_ar': 'المندرة (عادي, غاز)'}, isAr: true), 'غاز');
      expect(InstructionFormatter.vehicleKind({'route_description_en': 'Ramses - Tahrir'}, isAr: false), isNull);
    });
  });

  group('route card tags', () {
    test('a route that stops short of the destination is tagged Partial', () {
      final s = RouteSummary.of(l10n, _option([_walk(100), _ride(40), _walk(3000)], type: 'Partial'));
      expect(s.tag, 'Partial');
    });

    test('walking more than riding, and over 1.5 km, is said on the card', () {
      final s = RouteSummary.of(l10n, _option([_walk(788), _ride(30), _walk(1819)]));
      expect(s.longWalkMinutes, greaterThan(30));
    });

    test('a long ride with a long walk is not flagged', () {
      expect(RouteSummary.of(l10n, _option([_walk(788), _ride(60), _walk(1819)])).longWalkMinutes, isNull);
    });

    test('a short walk is not flagged however short the ride', () {
      expect(RouteSummary.of(l10n, _option([_walk(600), _ride(4), _walk(500)])).longWalkMinutes, isNull);
    });
  });

  group('no route', () {
    test('a trip we do not cover is titled as such, not as an error', () {
      expect(InstructionFormatter.errorTitle(l10n, {'error_code': 'no_coverage'}), l10n.errorTitleNotCovered);
      expect(InstructionFormatter.errorTitle(l10n, {'error_code': 'no_route_found'}), l10n.errorTitleNotCovered);
      expect(InstructionFormatter.errorTitle(l10n, {'error_code': 'outside_service_hours'}), l10n.errorTitleNoService);
      expect(InstructionFormatter.errorTitle(l10n, {'error_code': 'network'}), isNull);
      expect(InstructionFormatter.isNetworkError({'error_code': 'network'}), isTrue);
    });

    testWidgets('the title shows, and a far hub says how far', (tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ErrorState(
            title: l10n.errorTitleNotCovered,
            message: l10n.errorNoRouteFound,
            icon: Icons.wrong_location_rounded,
            onRetry: () {},
            nearestHubs: {
              'from_origin': {'name': 'Miami', 'distance_m': 113},
              'from_destination': {'name': 'Near Baheg', 'distance_m': 8304},
            },
          ),
        ),
      ));
      expect(find.text(l10n.errorTitleNotCovered), findsOneWidget);
      expect(find.text(l10n.somethingWentWrongTitle), findsNothing);
      expect(find.text(l10n.nearestHubsHint('Miami', 'Near Baheg (8.3 km)')), findsOneWidget);
    });
  });
}
