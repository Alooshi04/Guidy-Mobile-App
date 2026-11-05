import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/widgets/trip/trip_arrival_sheet.dart';

void main() {
  testWidgets('shows the trip and reports which button was tapped', (tester) async {
    final taps = <String>[];
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: TripArrivalSheet(
          startName: 'Ramses',
          endName: 'Tahrir',
          durationMinutes: 25,
          fare: 15,
          onDone: () => taps.add('done'),
          onHistory: () => taps.add('history'),
        ),
      ),
    ));
    final l10n = AppLocalizations.of(tester.element(find.byType(TripArrivalSheet)));
    expect(find.text(l10n.youHaveArrived), findsOneWidget);
    expect(find.text('Ramses ➔ Tahrir'), findsOneWidget);
    expect(find.text('15 EGP'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.tap(find.text(l10n.navHistory));
    expect(taps, ['done', 'history']);
  });
}
