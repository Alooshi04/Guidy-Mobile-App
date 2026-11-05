import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/services/account_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AccountService.extractFirstName', () {
    test('extracts first name from full English name', () {
      expect(AccountService.extractFirstName('Youssef Ezzat'), equals('Youssef'));
      expect(AccountService.extractFirstName('John Michael Doe'), equals('John'));
      expect(AccountService.extractFirstName('Sarah'), equals('Sarah'));
    });

    test('extracts first name from Arabic name', () {
      expect(AccountService.extractFirstName('أحمد محمد'), equals('أحمد'));
      expect(AccountService.extractFirstName('يوسف عزت عبد المنعم'), equals('يوسف'));
      expect(AccountService.extractFirstName('مريم'), equals('مريم'));
    });

    test('handles leading, trailing, and redundant whitespace', () {
      expect(AccountService.extractFirstName('   Omar   Khaled  '), equals('Omar'));
      expect(AccountService.extractFirstName(''), isNull);
      expect(AccountService.extractFirstName('    '), isNull);
      expect(AccountService.extractFirstName(null), isNull);
    });
  });

  group('AccountService display name caching and sign-out', () {
    test('saveUserDisplayName persists to SharedPreferences and getUserDisplayName retrieves it', () async {
      SharedPreferences.setMockInitialValues({});
      await AccountService.saveUserDisplayName('Nour El Din');

      final storedName = await AccountService.getUserDisplayName();
      expect(storedName, equals('Nour El Din'));

      final firstName = await AccountService.getUserFirstName();
      expect(firstName, equals('Nour'));
    });

    test('clearUserDataOnSignOut removes cached display name', () async {
      SharedPreferences.setMockInitialValues({
        AccountService.prefKeyDisplayName: 'Karim',
      });

      expect(await AccountService.getUserDisplayName(), equals('Karim'));
      await AccountService.clearUserDataOnSignOut();
      expect(await AccountService.getUserDisplayName(), isNull);
    });
  });

  group('AccountService.formatGreeting', () {
    late AppLocalizations l10nEn;
    late AppLocalizations l10nAr;

    setUpAll(() async {
      l10nEn = await AppLocalizations.delegate.load(const Locale('en'));
      l10nAr = await AppLocalizations.delegate.load(const Locale('ar'));
    });

    test('formats English greetings with user first name based on hour', () {
      // Morning (5 <= hour < 12)
      expect(
        AccountService.formatGreeting(l10nEn, name: 'Youssef Ezzat', hourOverride: 8),
        equals('Good morning, Youssef'),
      );
      // Afternoon (12 <= hour < 17)
      expect(
        AccountService.formatGreeting(l10nEn, name: 'Youssef', hourOverride: 14),
        equals('Good afternoon, Youssef'),
      );
      // Evening (17 <= hour < 21)
      expect(
        AccountService.formatGreeting(l10nEn, name: 'Youssef', hourOverride: 19),
        equals('Good evening, Youssef'),
      );
      // Night (hour >= 21 or hour < 5)
      expect(
        AccountService.formatGreeting(l10nEn, name: 'Youssef', hourOverride: 23),
        equals('Good night, Youssef'),
      );
      expect(
        AccountService.formatGreeting(l10nEn, name: 'Youssef', hourOverride: 2),
        equals('Good night, Youssef'),
      );
    });

    test('formats Arabic greetings with user first name based on hour', () {
      // Morning
      expect(
        AccountService.formatGreeting(l10nAr, name: 'أحمد محمد', hourOverride: 9),
        equals('صباح الخير يا أحمد'),
      );
      // Afternoon
      expect(
        AccountService.formatGreeting(l10nAr, name: 'أحمد', hourOverride: 13),
        equals('نهارك سعيد يا أحمد'),
      );
      // Evening
      expect(
        AccountService.formatGreeting(l10nAr, name: 'أحمد', hourOverride: 18),
        equals('مساء الخير يا أحمد'),
      );
      // Night
      expect(
        AccountService.formatGreeting(l10nAr, name: 'أحمد', hourOverride: 22),
        equals('مساء الخير يا أحمد'),
      );
    });

    test('falls back to generic greetings when name is null or whitespace', () {
      // English generic fallback
      expect(
        AccountService.formatGreeting(l10nEn, name: null, hourOverride: 8),
        equals('Good Morning'),
      );
      expect(
        AccountService.formatGreeting(l10nEn, name: '   ', hourOverride: 14),
        equals('Good Afternoon'),
      );

      // Arabic generic fallback
      expect(
        AccountService.formatGreeting(l10nAr, name: null, hourOverride: 18),
        equals('مساء الخير'),
      );
      expect(
        AccountService.formatGreeting(l10nAr, name: '', hourOverride: 23),
        equals('مساء الخير'),
      );
    });
  });
}
