import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/VerifyEmailScreen.dart';
import 'package:guidy_app/services/account_service.dart';

void main() {
  group('AccountService.emailVerificationRequired', () {
    test('an unverified email/password account must verify', () {
      expect(
        AccountService.emailVerificationRequired(isAnonymous: false, emailVerified: false, providerIds: {'password'}),
        isTrue,
      );
    });

    test('verified, guest and Google accounts pass', () {
      expect(AccountService.emailVerificationRequired(isAnonymous: false, emailVerified: true, providerIds: {'password'}),
          isFalse);
      expect(AccountService.emailVerificationRequired(isAnonymous: true, emailVerified: false, providerIds: {}), isFalse);
      expect(AccountService.emailVerificationRequired(isAnonymous: false, emailVerified: false, providerIds: {'google.com'}),
          isFalse);
      // Linked to Google too: Google has vouched for the address.
      expect(
        AccountService.emailVerificationRequired(
            isAnonymous: false, emailVerified: false, providerIds: {'password', 'google.com'}),
        isFalse,
      );
    });
  });

  group('VerifyEmailScreen', () {
    late int resends;
    late bool verifiedOnServer;
    late int verifiedCalls;
    late int signOuts;

    setUp(() {
      resends = 0;
      verifiedOnServer = false;
      verifiedCalls = 0;
      signOuts = 0;
    });

    Widget host({Locale locale = const Locale('en')}) => MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
          home: VerifyEmailScreen(
            email: 'rider@example.com',
            onResend: () async {
              resends++;
              return AuthEmailResult.sent;
            },
            onCheck: () async => verifiedOnServer,
            onVerified: () => verifiedCalls++,
            onSignOut: () async => signOuts++,
          ),
        );

    testWidgets('shows the address and the three actions', (tester) async {
      await tester.pumpWidget(host());
      expect(find.text('Verify your email'), findsOneWidget);
      expect(find.textContaining('rider@example.com'), findsOneWidget);
      expect(find.text("I've verified"), findsOneWidget);
      expect(find.text('Resend email'), findsOneWidget);
      expect(find.text('Use a different account'), findsOneWidget);
    });

    testWidgets("\"I've verified\" before verifying says not yet", (tester) async {
      await tester.pumpWidget(host());
      await tester.tap(find.text("I've verified"));
      await tester.pumpAndSettle();
      expect(verifiedCalls, 0);
      expect(find.text('Not verified yet. Open the link in the email first.'), findsOneWidget);
    });

    testWidgets("\"I've verified\" after verifying lets them in", (tester) async {
      await tester.pumpWidget(host());
      verifiedOnServer = true;
      await tester.tap(find.text("I've verified"));
      await tester.pumpAndSettle();
      expect(verifiedCalls, 1);
    });

    testWidgets('resend sends once, then cools down for 60 seconds', (tester) async {
      await tester.pumpWidget(host());
      await tester.tap(find.text('Resend email'));
      await tester.pump();
      expect(resends, 1);
      expect(find.text('Resend in 60s'), findsOneWidget);

      await tester.tap(find.text('Resend in 60s'));
      await tester.pump();
      expect(resends, 1);

      await tester.pump(const Duration(seconds: 60));
      expect(find.text('Resend email'), findsOneWidget);
      // Let the snackbar finish.
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('use a different account signs out', (tester) async {
      await tester.pumpWidget(host());
      await tester.tap(find.text('Use a different account'));
      await tester.pumpAndSettle();
      expect(signOuts, 1);
    });

    testWidgets('renders in Arabic', (tester) async {
      await tester.pumpWidget(host(locale: const Locale('ar')));
      expect(find.text('أكد إيميلك'), findsOneWidget);
      expect(find.text('أكدت'), findsOneWidget);
    });
  });
}
