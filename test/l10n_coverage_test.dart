import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Localization ARB Parity & Integrity Tests', () {
    late Map<String, dynamic> enJson;
    late Map<String, dynamic> arJson;
    late Set<String> enKeys;
    late Set<String> arKeys;

    setUpAll(() {
      final enFile = File('lib/l10n/app_en.arb');
      final arFile = File('lib/l10n/app_ar.arb');

      expect(enFile.existsSync(), isTrue, reason: 'app_en.arb must exist');
      expect(arFile.existsSync(), isTrue, reason: 'app_ar.arb must exist');

      enJson = jsonDecode(enFile.readAsStringSync()) as Map<String, dynamic>;
      arJson = jsonDecode(arFile.readAsStringSync()) as Map<String, dynamic>;

      enKeys = enJson.keys.where((k) => !k.startsWith('@')).toSet();
      arKeys = arJson.keys.where((k) => !k.startsWith('@')).toSet();
    });

    test('Both ARB files declare their @@locale properly', () {
      expect(enJson['@@locale'], equals('en'));
      expect(arJson['@@locale'], equals('ar'));
    });

    test('Both files have identical translation keys (no missing translations)', () {
      final missingInAr = enKeys.difference(arKeys);
      final missingInEn = arKeys.difference(enKeys);

      expect(
        missingInAr,
        isEmpty,
        reason: 'Keys present in English but missing in Arabic: $missingInAr',
      );
      expect(
        missingInEn,
        isEmpty,
        reason: 'Keys present in Arabic but missing in English: $missingInEn',
      );
      expect(enKeys.length, equals(arKeys.length));
      expect(enKeys.length, greaterThan(400));
    });

    test('No translation values are empty or whitespace only', () {
      for (final key in enKeys) {
        final enVal = enJson[key];
        expect(enVal, isA<String>(), reason: 'EN key $key must have a String value');
        expect((enVal as String).trim(), isNotEmpty, reason: 'EN key $key must not be empty');

        final arVal = arJson[key];
        expect(arVal, isA<String>(), reason: 'AR key $key must have a String value');
        expect((arVal as String).trim(), isNotEmpty, reason: 'AR key $key must not be empty');
      }
    });

    test('Placeholders in English strings match placeholders in Arabic strings', () {
      final placeholderRegex = RegExp(r'\{([a-zA-Z0-9_]+)\}');

      for (final key in enKeys) {
        final enStr = enJson[key] as String;
        final arStr = arJson[key] as String;

        final enPlaceholders = placeholderRegex
            .allMatches(enStr)
            .map((m) => m.group(1)!)
            .toSet();
        final arPlaceholders = placeholderRegex
            .allMatches(arStr)
            .map((m) => m.group(1)!)
            .toSet();

        expect(
          arPlaceholders,
          equals(enPlaceholders),
          reason: 'Placeholders mismatch for key "$key": EN=$enPlaceholders vs AR=$arPlaceholders',
        );
      }
    });

    test('Arabic translations contain Arabic characters for core UI labels', () {
      final arabicCharRegex = RegExp(r'[\u0600-\u06FF]');
      final sampleKeys = [
        'appTagline',
        'goodMorning',
        'logOut',
        'settingsTitle',
        'searchPlaceholder',
        'cancel',
      ];

      for (final key in sampleKeys) {
        if (arKeys.contains(key)) {
          final arStr = arJson[key] as String;
          expect(
            arabicCharRegex.hasMatch(arStr),
            isTrue,
            reason: 'Arabic key "$key" should contain Arabic characters: "$arStr"',
          );
        }
      }
    });
  });
}
