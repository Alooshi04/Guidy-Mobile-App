import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/SignInScreen.dart';
import 'package:guidy_app/screens/SignUpScreen.dart';
import 'package:guidy_app/services/legal_consent_service.dart';
import 'package:guidy_app/theme/app_theme.dart';
import 'package:guidy_app/widgets/legal_consent.dart';
import 'package:guidy_app/widgets/social_auth_buttons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Every new account agrees to the Terms, the Privacy Policy and the Data
// Deletion Policy -- email sign-up, Google, or guest -- and anyone who hasn't
// agreed to the current version (existing users, or after a policy update)
// is asked once before using the app. Each agreement is recorded.

class _FakeStore implements LegalConsentStore {
  final Map<String, Map<String, dynamic>> records = {};
  bool failWrites = false;

  @override
  Future<bool> exists(String uid, String version) async => records.containsKey('$uid/$version');

  @override
  Future<void> record(String uid, String version, Map<String, dynamic> data) async {
    if (failWrites) throw Exception('offline');
    records['$uid/$version'] = data;
  }
}

DateTime _effectiveDate(String file) {
  const months = {
    'January': 1, 'February': 2, 'March': 3, 'April': 4, 'May': 5, 'June': 6, 'July': 7,
    'August': 8, 'September': 9, 'October': 10, 'November': 11, 'December': 12,
  };
  final m = RegExp(r'\*\*Effective date:\*\* (\d+) (\w+) (\d{4})')
      .firstMatch(File('website/legal/$file').readAsStringSync())!;
  return DateTime(int.parse(m[3]!), months[m[2]]!, int.parse(m[1]!));
}

DateTime _effectiveDateAr(String file) {
  const months = {
    'يناير': 1, 'فبراير': 2, 'مارس': 3, 'أبريل': 4, 'مايو': 5, 'يونيو': 6, 'يوليو': 7,
    'أغسطس': 8, 'سبتمبر': 9, 'أكتوبر': 10, 'نوفمبر': 11, 'ديسمبر': 12,
  };
  final m = RegExp(r'\*\*تاريخ السريان:\*\* (\d+) (\S+) (\d{4})')
      .firstMatch(File('website/legal/$file').readAsStringSync())!;
  return DateTime(int.parse(m[3]!), months[m[2]]!, int.parse(m[1]!));
}

Widget _app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

/// Shows [home] in the app's own theme, with the brand faces it draws on a
/// phone loaded from the app bundle, so text measures as it does there.
/// (This used to load Roboto from the Flutter SDK's cache, which the CI
/// runner's Flutter does not have, and which the app does not draw with.)
Future<void> _pumpInBrandFonts(WidgetTester tester, Widget home, {Locale locale = const Locale('en')}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  addTearDown(() => GoogleFonts.config.allowRuntimeFetching = true);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(locale),
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ));
  await tester.runAsync(GoogleFonts.pendingFonts);
  await tester.pumpAndSettle();
}

bool _enabled(WidgetTester tester, Finder button) {
  final w = tester.widget(find
      .ancestor(of: button, matching: find.byWidgetPredicate((w) => w is ButtonStyleButton), matchRoot: true)
      .first);
  return (w as ButtonStyleButton).onPressed != null;
}

void main() {
  late _FakeStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(appName: 'Guidy', packageName: 'com.guidy.guidy_app', version: '1.0.3',
        buildNumber: '4', buildSignature: '');
    store = _FakeStore();
    LegalConsentService.store = store;
    LegalConsentService.resetForTesting();
  });

  // Riders agree to all three pages (the checkbox links each one).
  const policies = ['PRIVACY_POLICY', 'TERMS_AND_CONDITIONS', 'DATA_DELETION'];

  group('the version', () {
    test('is the latest effective date of the three policies', () {
      final latest = [for (final p in policies) _effectiveDate('$p.md')]
          .reduce((a, b) => a.isAfter(b) ? a : b);
      final v = latest.toIso8601String().substring(0, 10);
      expect(LegalConsentService.currentVersion, v,
          reason: 'a policy changed: bump currentVersion so everyone is asked again');
    });

    test('each Arabic policy carries its English date', () {
      for (final p in policies) {
        expect(_effectiveDateAr('$p.ar.md'), _effectiveDate('$p.md'), reason: p);
      }
    });
  });

  group('recording', () {
    test('an account that never agreed is asked', () async {
      expect(await LegalConsentService.hasAccepted('u1'), isFalse);
    });

    test('agreeing is recorded on the account and remembered', () async {
      await LegalConsentService.accept('u1', lang: 'ar');
      expect(await LegalConsentService.hasAccepted('u1'), isTrue);
      final r = store.records['u1/${LegalConsentService.currentVersion}']!;
      expect(r['version'], LegalConsentService.currentVersion);
      expect(r['lang'], 'ar');
      expect(r['app_version'], '1.0.3+4');
    });

    test('agreeing offline lets the rider in and uploads the record later', () async {
      store.failWrites = true;
      await LegalConsentService.accept('u1', lang: 'en');
      expect(await LegalConsentService.hasAccepted('u1'), isTrue);
      expect(store.records, isEmpty);

      store.failWrites = false;
      await LegalConsentService.uploadPending('u1');
      expect(store.records.keys, ['u1/${LegalConsentService.currentVersion}']);
    });

    test('a record that is already there stops the retries', () async {
      // Agreed on another phone while this one was offline: the rules
      // refuse a second write of the same record, so don't retry forever.
      store.failWrites = true;
      await LegalConsentService.accept('u1', lang: 'en');
      store.records['u1/${LegalConsentService.currentVersion}'] = {'version': LegalConsentService.currentVersion};
      await LegalConsentService.uploadPending('u1');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('legal_consent_pending_u1'), isNull);
    });

    test('agreeing on the sign-up screen covers the account it creates', () async {
      LegalConsentService.agreeBeforeSignIn(lang: 'en');
      expect(await LegalConsentService.hasAccepted('new-uid'), isTrue);
      expect(store.records.keys, ['new-uid/${LegalConsentService.currentVersion}']);
      // Only once: the next account (another sign-in) is asked again.
      expect(await LegalConsentService.hasAccepted('other-uid'), isFalse);
    });

    test('an agreement made on another phone counts', () async {
      store.records['u1/${LegalConsentService.currentVersion}'] = {'version': LegalConsentService.currentVersion};
      expect(await LegalConsentService.hasAccepted('u1'), isTrue);
    });

    test('agreeing to an older version is not enough', () async {
      store.records['u1/2020-01-01'] = {'version': '2020-01-01'};
      SharedPreferences.setMockInitialValues({'legal_consent_accepted_u1': '2020-01-01'});
      expect(await LegalConsentService.hasAccepted('u1'), isFalse);
    });
  });

  group('the links', () {
    test('open the three legal pages in the app language', () {
      expect(LegalLinks.terms(isAr: false), 'https://guidyapp.com/terms');
      expect(LegalLinks.terms(isAr: true), 'https://guidyapp.com/terms-ar');
      expect(LegalLinks.privacy(isAr: false), 'https://guidyapp.com/privacy');
      expect(LegalLinks.privacy(isAr: true), 'https://guidyapp.com/privacy-ar');
      expect(LegalLinks.dataDeletion(isAr: false), 'https://guidyapp.com/data-deletion');
      expect(LegalLinks.dataDeletion(isAr: true), 'https://guidyapp.com/data-deletion-ar');
    });
  });

  group('sign-up', () {
    testWidgets('email, Google and guest wait for the box', (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      await tester.pumpWidget(_app(const SignUpScreen()));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(tester.element(find.byType(SignUpScreen)));

      final create = find.widgetWithText(ElevatedButton, l10n.createAccount);
      final google = find.text(l10n.continueWithGoogle);
      final guest = find.text(l10n.continueAsGuest);
      for (final b in [create, google, guest]) {
        expect(_enabled(tester, b), isFalse);
      }
      await tester.ensureVisible(find.byType(LegalConsentCheckbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      for (final b in [google, guest]) {
        expect(_enabled(tester, b), isTrue);
      }
      // Ticking it here is the agreement for a Google or guest account too.
      expect(find.byWidgetPredicate((w) => w is SocialAuthButtons && w.agreed), findsOneWidget);
      // Email sign-up also waits for a password that meets PasswordPolicy.
      expect(_enabled(tester, create), isFalse);
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(2), 'Guidy#2026');
      await tester.enterText(fields.at(3), 'Guidy#2026');
      await tester.pump();
      expect(_enabled(tester, create), isTrue);
    });
  });

  // Sign-up has more on it, so it is held to a common 6.5" phone (about
  // 392x872 dp) less its bars and the banner ad. Measured in Roboto, the
  // font Android draws it in: the test font's square glyphs wrap the
  // agreement line onto twice as many lines as a phone does. (No Arabic
  // face is available here, so Arabic is checked on a device.)
  testWidgets('sign-up fits on one phone screen without scrolling', (tester) async {
    tester.view.physicalSize = const Size(392 * 3, 740 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    await _pumpInBrandFonts(tester, const SignUpScreen());

    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
    expect(scroll.position.maxScrollExtent, 0);
  });

  group('sign-in', () {
    // Signing in asks for nothing. A Google or guest sign-in that creates a
    // new account meets LegalConsentGate right after, like anyone who hasn't
    // agreed to the current version.
    testWidgets('has no agreement box, and every way in is ready', (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      await tester.pumpWidget(_app(const SignInScreen()));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(tester.element(find.byType(SignInScreen)));

      expect(find.byType(LegalConsentCheckbox), findsNothing);
      expect(_enabled(tester, find.widgetWithText(ElevatedButton, l10n.signIn)), isTrue);
      expect(_enabled(tester, find.text(l10n.continueWithGoogle)), isTrue);
      expect(_enabled(tester, find.text(l10n.continueAsGuest)), isTrue);
    });

    testWidgets('signing in with Google or as a guest records no agreement up front', (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      await tester.pumpWidget(_app(const SignInScreen()));
      await tester.pumpAndSettle();

      expect(find.byWidgetPredicate((w) => w is SocialAuthButtons && !w.agreed), findsOneWidget);
    });

    // A phone around 360x740 dp, less the status bar, the navigation bar
    // and the banner ad under the screen.
    for (final locale in const [Locale('en'), Locale('ar')]) {
      testWidgets('fits on one phone screen without scrolling (${locale.languageCode})', (tester) async {
        tester.view.physicalSize = const Size(360 * 3, 640 * 3);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(() => tester.view.resetPhysicalSize());
        await tester.pumpWidget(_app(const SignInScreen(), locale: locale));
        await tester.pumpAndSettle();

        final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
        expect(scroll.position.maxScrollExtent, 0);
      });
    }
  });

  group('the one-time agreement', () {
    testWidgets('an account that has not agreed sees it, and gets in after agreeing', (tester) async {
      await tester.pumpWidget(_app(LegalConsentGate(
        uidForTesting: 'u1',
        child: const Text('the app'),
      )));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(tester.element(find.byType(LegalConsentGate)));
      expect(find.text('the app'), findsNothing);
      expect(find.text(l10n.legalConsentTitle), findsOneWidget);

      final agree = find.text(l10n.legalConsentContinue);
      expect(_enabled(tester, agree), isFalse);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(agree);
      await tester.pumpAndSettle();
      expect(find.text('the app'), findsOneWidget);
      expect(store.records.keys, ['u1/${LegalConsentService.currentVersion}']);
    });

    testWidgets('an account that has agreed goes straight in', (tester) async {
      await LegalConsentService.accept('u1', lang: 'en');
      await tester.pumpWidget(_app(LegalConsentGate(uidForTesting: 'u1', child: const Text('the app'))));
      await tester.pumpAndSettle();
      expect(find.text('the app'), findsOneWidget);
    });

    testWidgets('it is in Arabic when the app is', (tester) async {
      await tester.pumpWidget(_app(LegalConsentGate(uidForTesting: 'u1', child: const Text('the app')),
          locale: const Locale('ar')));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(tester.element(find.byType(LegalConsentGate)));
      expect(l10n.localeName, startsWith('ar'));
      expect(find.text(l10n.legalConsentTitle), findsOneWidget);
    });
  });
}
