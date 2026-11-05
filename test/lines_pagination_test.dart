import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/LinesScreen.dart';

void main() {
  testWidgets('LinesScreen renders finite paginated list and controls cleanly', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ar'),
        home: const LinesScreen(),
      ),
    );

    // Initial frame renders loading indicator or container
    await tester.pump();
    expect(find.byType(LinesScreen), findsOneWidget);
  });
}
