import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/LinesScreen.dart';
import 'package:guidy_app/widgets/line_city_pill.dart';

/// Alexandria's lines sit in the same Lines list as Cairo's (APTA 290 next
/// to CTA 290), so they carry a city pill. Cairo and Giza lines stay
/// exactly as they were: no pill.
void main() {
  group('lineCityOf', () {
    test('Alexandria agencies and route ids', () {
      for (final agency in ['ALX_APTA', 'ALX_MICRO', 'ALX_TOMNAYA', 'ALX_BUS_SURVEY', 'ALX_MINIBUS', 'ALX_COOP']) {
        expect(lineCityOf({'agency': agency, 'route_id': '${agency}_1'}), LineCity.alexandria, reason: agency);
      }
      // No agency field (older payloads): the route id decides.
      expect(lineCityOf({'route_id': 'ALX_APTA_13'}), LineCity.alexandria);
    });

    test('intercity microbuses are their own kind', () {
      expect(lineCityOf({'agency': 'ALX_INTERCITY', 'route_id': 'ALX_IC_RAMSES'}), LineCity.intercity);
      expect(lineCityOf({'route_id': 'ALX_IC_MONEEB'}), LineCity.intercity);
    });

    test('Cairo and Giza lines are untouched', () {
      for (final r in [
        {'agency': 'CTA', 'route_id': 'CTA_1145'},
        {'agency': 'NAT', 'route_id': 'NAT_L2'},
        {'agency': 'P_O_14', 'route_id': 'P_O_14_IG076'},
        {'agency': 'GOV_CTA', 'route_id': 'GOV_CTA_12'},
        <String, dynamic>{},
      ]) {
        expect(lineCityOf(r), LineCity.cairo, reason: r.toString());
      }
    });
  });

  group('LineCityPill', () {
    Future<void> pump(WidgetTester tester, Map<String, dynamic> route, String lang) => tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale(lang),
            home: Scaffold(body: Center(child: LineCityPill(route: route))),
          ),
        );

    testWidgets('Alexandria line shows the city, in Arabic and English', (tester) async {
      await pump(tester, {'agency': 'ALX_APTA', 'route_id': 'ALX_APTA_290'}, 'ar');
      expect(find.text('الإسكندرية'), findsOneWidget);
      await pump(tester, {'agency': 'ALX_APTA', 'route_id': 'ALX_APTA_290'}, 'en');
      expect(find.text('Alexandria'), findsOneWidget);
    });

    testWidgets('intercity line shows both cities', (tester) async {
      await pump(tester, {'agency': 'ALX_INTERCITY', 'route_id': 'ALX_IC_RAMSES'}, 'ar');
      expect(find.text('القاهرة ⇄ الإسكندرية'), findsOneWidget);
    });

    testWidgets('Cairo line shows nothing', (tester) async {
      await pump(tester, {'agency': 'CTA', 'route_id': 'CTA_290'}, 'ar');
      expect(find.byType(Text), findsNothing);
    });
  });

  group('Lines card fare', () {
    test('a microbus with its own fare shows it (intercity 140, Alexandria 9.5)', () {
      expect(LinesScreen.fareForRoute({'vehicle_type': 'microbus', 'fare_egp': 140}, false), '140 EGP');
      expect(LinesScreen.fareForRoute({'vehicle_type': 'microbus', 'fare_egp': 9.5}, true), '9.5 ج.م');
    });

    test('an Alexandria microbus shows its distance range up to the line fare', () {
      expect(
          LinesScreen.fareForRoute({'vehicle_type': 'microbus', 'fare_egp': 22, 'fare_from_egp': 5}, false),
          '5 to 22 EGP');
      expect(
          LinesScreen.fareForRoute({'vehicle_type': 'microbus', 'fare_egp': 22.0, 'fare_from_egp': 5.0}, true),
          '5 لـ 22 ج.م');
      // A line whose fare is the first band anyway has nothing to range over.
      expect(LinesScreen.fareForRoute({'vehicle_type': 'microbus', 'fare_egp': 5, 'fare_from_egp': 5}, false),
          '5 EGP');
    });

    test('a Cairo microbus (no single fare) keeps the distance range', () {
      expect(LinesScreen.fareForRoute({'vehicle_type': 'microbus', 'fare_egp': null}, false), '10 to 15 EGP');
    });
  });
}
