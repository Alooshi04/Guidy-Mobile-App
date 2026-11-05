import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/widgets/error_state.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ));

  testWidgets('a connection failure shows the no-signal icon by default', (tester) async {
    await pump(tester, ErrorState(message: 'offline', onRetry: () {}));
    expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
  });

  testWidgets('a trip we do not cover is not drawn as a connection problem', (tester) async {
    await pump(tester, ErrorState(message: 'no route', icon: Icons.wrong_location_rounded, onRetry: () {}));
    expect(find.byIcon(Icons.wrong_location_rounded), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off_rounded), findsNothing);
  });
}
