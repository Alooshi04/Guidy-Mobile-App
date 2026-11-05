import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/services/password_policy.dart';

void main() {
  group('PasswordPolicy.check', () {
    test('a password meeting every rule passes', () {
      final r = PasswordPolicy.check('Guidy#2026');
      expect(r.isValid, isTrue);
      expect(r.failed, isEmpty);
    });

    test('each rule is reported on its own', () {
      expect(PasswordPolicy.check('Gu#1abc').failed, {PasswordRule.minLength});
      expect(PasswordPolicy.check('guidy#2026').failed, {PasswordRule.upper});
      expect(PasswordPolicy.check('GUIDY#2026').failed, {PasswordRule.lower});
      expect(PasswordPolicy.check('Guidy#Cairo').failed, {PasswordRule.digit});
      expect(PasswordPolicy.check('Guidy2026x').failed, {PasswordRule.symbol});
    });

    test('leading or trailing spaces fail; inner spaces are fine', () {
      expect(PasswordPolicy.check(' Guidy#2026').failed, {PasswordRule.noEdgeSpaces});
      expect(PasswordPolicy.check('Guidy#2026 ').failed, {PasswordRule.noEdgeSpaces});
      expect(PasswordPolicy.check('Guidy# 2026').isValid, isTrue);
    });

    test('a space counts as neither a symbol nor anything else', () {
      expect(PasswordPolicy.check('Guidy 2026').failed, {PasswordRule.symbol});
    });

    test('the empty password fails every character rule', () {
      expect(PasswordPolicy.check('').failed, {
        PasswordRule.minLength,
        PasswordRule.upper,
        PasswordRule.lower,
        PasswordRule.digit,
        PasswordRule.symbol,
      });
    });

    test('non-ASCII letters count as symbols, not as upper/lower', () {
      // Arabic letters have no case; they mustn't satisfy upper or lower.
      final r = PasswordPolicy.check('مرحبا2026aA');
      expect(r.failed, isEmpty);
    });
  });

  group('PasswordPolicy.strength', () {
    test('empty is none', () {
      expect(PasswordPolicy.strength(''), PasswordStrength.none);
    });

    test('commonly used passwords are weak whatever they contain', () {
      expect(PasswordPolicy.strength('123456789'), PasswordStrength.weak);
      expect(PasswordPolicy.strength('Password1!'), PasswordStrength.weak);
      expect(PasswordPolicy.strength('P@ssw0rd'), PasswordStrength.weak);
    });

    test('commonly used passwords make the policy fail', () {
      final r = PasswordPolicy.check('P@ssw0rd');
      expect(r.failed, {PasswordRule.notCommon});
      expect(r.isValid, isFalse);
    });

    test('grows with rules met and length', () {
      expect(PasswordPolicy.strength('abc'), PasswordStrength.weak);
      expect(PasswordPolicy.strength('abcdefgh1'), PasswordStrength.fair);
      expect(PasswordPolicy.strength('Guidy#2026'), PasswordStrength.good);
      expect(PasswordPolicy.strength('Guidy#Cairo#2026'), PasswordStrength.strong);
    });

    test('a valid password is never rated below good', () {
      for (final p in ['Aa1!aaaa', 'Zz9?zzzz', 'Guidy#26']) {
        expect(PasswordPolicy.check(p).isValid, isTrue, reason: p);
        expect(PasswordPolicy.strength(p).index, greaterThanOrEqualTo(PasswordStrength.good.index), reason: p);
      }
    });

    test('an invalid password is never rated above fair', () {
      for (final p in ['abcdefghijklmnopqrst', 'ABCDEFGHIJKLMNOP1234', 'Guidy20262026']) {
        expect(PasswordPolicy.check(p).isValid, isFalse, reason: p);
        expect(PasswordPolicy.strength(p).index, lessThanOrEqualTo(PasswordStrength.fair.index), reason: p);
      }
    });
  });
}
