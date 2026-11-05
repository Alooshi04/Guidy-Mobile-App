import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/widgets/password_strength_field.dart';

void main() {
  Widget host(TextEditingController controller, {Locale locale = const Locale('en')}) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: Scaffold(
          body: SingleChildScrollView(
            child: PasswordStrengthField(controller: controller, label: 'Password', hint: 'Create a password'),
          ),
        ),
      );

  Icon ruleIcon(WidgetTester tester, String rule) => tester.widget<Icon>(
        find.descendant(of: find.widgetWithText(Row, rule), matching: find.byType(Icon)),
      );

  // The checklist only takes up room when it matters: while the field is in
  // use, or while what's typed still breaks a rule. That keeps sign-up on
  // one screen.
  testWidgets('hides the rules until the field is tapped', (tester) async {
    final c = TextEditingController();
    await tester.pumpWidget(host(c));
    expect(find.text('At least 8 characters'), findsNothing);

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(find.text('At least 8 characters'), findsOneWidget);
  });

  testWidgets('after leaving the field, keeps the rules a weak password breaks, hides them once it passes',
      (tester) async {
    final c = TextEditingController();
    await tester.pumpWidget(host(c));

    await tester.enterText(find.byType(TextField), 'guidy');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(find.text('At least 8 characters'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Guidy#2026');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(find.text('At least 8 characters'), findsNothing);
    expect(find.byKey(const Key('password-strength-meter')), findsOneWidget);
  });

  testWidgets('shows the five rules, all unmet, and no meter while empty', (tester) async {
    final c = TextEditingController();
    await tester.pumpWidget(host(c));
    await tester.tap(find.byType(TextField));
    await tester.pump();

    for (final rule in ['At least 8 characters', 'An uppercase letter (A-Z)', 'A lowercase letter (a-z)', 'A number (0-9)', 'A symbol, like ! @ # ?']) {
      expect(find.text(rule), findsOneWidget, reason: rule);
      expect(ruleIcon(tester, rule).icon, Icons.close_rounded, reason: rule);
    }
    expect(find.byKey(const Key('password-strength-meter')), findsNothing);
    // Only shown once broken.
    expect(find.text('No spaces at the start or end'), findsNothing);
    expect(find.text('Not a commonly used password'), findsNothing);
  });

  testWidgets('ticks rules and rates strength as the user types', (tester) async {
    final c = TextEditingController();
    await tester.pumpWidget(host(c));

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump();
    expect(ruleIcon(tester, 'A lowercase letter (a-z)').icon, Icons.check_rounded);
    expect(ruleIcon(tester, 'At least 8 characters').icon, Icons.close_rounded);
    expect(find.text('Weak'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Guidy#2026');
    await tester.pump();
    for (final rule in ['At least 8 characters', 'An uppercase letter (A-Z)', 'A lowercase letter (a-z)', 'A number (0-9)', 'A symbol, like ! @ # ?']) {
      expect(ruleIcon(tester, rule).icon, Icons.check_rounded, reason: rule);
    }
    expect(find.text('Good'), findsOneWidget);
  });

  testWidgets('flags a common password and edge spaces', (tester) async {
    final c = TextEditingController();
    await tester.pumpWidget(host(c));

    await tester.enterText(find.byType(TextField), 'P@ssw0rd');
    await tester.pump();
    expect(find.text('Not a commonly used password'), findsOneWidget);
    expect(find.text('Weak'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Guidy#2026 ');
    await tester.pump();
    expect(find.text('No spaces at the start or end'), findsOneWidget);
  });

  testWidgets('the eye button toggles obscuring', (tester) async {
    final c = TextEditingController();
    await tester.pumpWidget(host(c));
    expect(tester.widget<TextField>(find.byType(TextField)).obscureText, isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).obscureText, isFalse);
  });

  testWidgets('renders in Arabic', (tester) async {
    final c = TextEditingController(text: 'Guidy#Cairo#2026');
    await tester.pumpWidget(host(c, locale: const Locale('ar')));
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(find.text('8 حروف على الأقل'), findsOneWidget);
    expect(find.text('قوي'), findsOneWidget);
  });
}
