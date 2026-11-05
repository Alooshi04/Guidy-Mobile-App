import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/widgets/trip/trip_boarding_options.dart';

void main() {
  testWidgets('live ETA, schedule-only frequency, fare; tapping picks the option', (tester) async {
    final picked = <Map<String, dynamic>>[];
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: TripBoardingOptions(
          step: {
            'boarding_options': [
              {'is_primary': true, 'vehicle_type': 'minibus', 'route_number': '66', 'eta_sec': 0, 'fare_egp': 10},
              {'vehicle_type': 'bus', 'route_number': '35', 'typical_headway_min': 12},
              {'vehicle_type': 'microbus'},
            ],
          },
          onPick: picked.add,
        ),
      ),
    ));
    final l10n = AppLocalizations.of(tester.element(find.byType(TripBoardingOptions)));
    expect(find.text(l10n.navYourRoute), findsOneWidget);
    expect(find.text(l10n.navArrivingNow), findsOneWidget);
    expect(find.text(l10n.navNoLiveData), findsOneWidget);
    expect(find.text('10 EGP'), findsOneWidget);

    await tester.tap(find.byType(InkWell).at(1));
    expect(picked.single['route_number'], '35');
  });

  testWidgets('fares keep piastres; a line with no fare of its own (the metro) shows none', (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: TripBoardingOptions(
          step: {
            'boarding_options': [
              {'is_primary': true, 'vehicle_type': 'minibus', 'route_number': '66', 'fare_egp': 5.5},
              {'vehicle_type': 'metro', 'route_number': '1', 'fare_egp': 0},
            ],
          },
          onPick: (_) {},
        ),
      ),
    ));
    expect(find.text('5.5 EGP'), findsOneWidget);
    expect(find.text('0 EGP'), findsNothing);
  });
}
