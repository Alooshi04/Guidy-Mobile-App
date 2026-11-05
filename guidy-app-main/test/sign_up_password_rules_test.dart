import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/SignUpScreen.dart';
import 'package:guidy_app/widgets/password_strength_field.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpSignUp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: const SignUpScreen(),
    ));
    await tester.pump();
  }

  ElevatedButton createButton(WidgetTester tester) =>
      tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Create Account'));

  Finder passwordField() =>
      find.descendant(of: find.byType(PasswordStrengthField), matching: find.byType(TextField));
  Finder confirmField() => find.byType(TextField).last;

  testWidgets('Create Account stays off until the password passes every rule and matches', (tester) async {
    await pumpSignUp(tester);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    await tester.enterText(passwordField(), '123456789');
    await tester.enterText(confirmField(), '123456789');
    await tester.pump();
    expect(createButton(tester).onPressed, isNull, reason: 'weak password');

    await tester.enterText(passwordField(), 'Guidy#2026');
    await tester.enterText(confirmField(), 'Guidy#2025');
    await tester.pump();
    expect(createButton(tester).onPressed, isNull, reason: 'mismatch');
    expect(find.text('Passwords do not match'), findsOneWidget);

    await tester.enterText(confirmField(), 'Guidy#2026');
    await tester.pump();
    expect(createButton(tester).onPressed, isNotNull);
    expect(find.text('Passwords do not match'), findsNothing);
  });

  testWidgets('the strength checklist is shown under the password once it is tapped', (tester) async {
    await pumpSignUp(tester);
    expect(find.byType(PasswordStrengthField), findsOneWidget);
    await tester.tap(passwordField());
    await tester.pump();
    expect(find.text('At least 8 characters'), findsOneWidget);
  });
}
