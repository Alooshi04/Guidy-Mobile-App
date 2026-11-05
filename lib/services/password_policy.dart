/// The rules a new email-account password must meet, and a rough
/// strength rating for the meter under the password field.
///
/// Mirrors the Firebase Auth password policy set in the console
/// (Authentication -> Settings -> Password policy): min length 8, upper,
/// lower, numeric and special characters. The console policy is what
/// actually stops a weak password reaching Firebase from outside the app;
/// this copy is so the app can say which rule is missing before sending.
/// [PasswordRule.notCommon] and [PasswordRule.noEdgeSpaces] are app-only.
library;

enum PasswordRule { minLength, upper, lower, digit, symbol, noEdgeSpaces, notCommon }

enum PasswordStrength { none, weak, fair, good, strong }

class PasswordCheck {
  final Set<PasswordRule> failed;
  const PasswordCheck(this.failed);
  bool get isValid => failed.isEmpty;
  bool passes(PasswordRule rule) => !failed.contains(rule);
}

class PasswordPolicy {
  static const int minLength = 8;

  /// Long enough that a valid password is rated strong rather than good.
  static const int strongLength = 12;

  static final RegExp _upper = RegExp(r'[A-Z]');
  static final RegExp _lower = RegExp(r'[a-z]');
  static final RegExp _digit = RegExp(r'[0-9]');
  // Anything that isn't an ASCII letter, a digit or whitespace -- so
  // punctuation, but also Arabic letters, which have no case to count
  // towards upper/lower.
  static final RegExp _symbol = RegExp(r'[^A-Za-z0-9\s]');

  /// Lowercased. Well-known passwords that satisfy (or nearly satisfy) the
  /// character rules -- the ones a length/character check alone lets through.
  static const Set<String> _common = {
    '12345678', '123456789', '1234567890', '87654321', '11111111', '00000000',
    'password', 'password1', 'password12', 'password123', 'password1!', 'password@1',
    'password@123', 'p@ssw0rd', 'p@ssword', 'p@ssw0rd1', 'p@ssw0rd123', 'passw0rd',
    'passw0rd!', 'qwerty123', 'qwerty12', 'qwerty123!', 'qwertyuiop', 'qwerty@123',
    'abc12345', 'abc123456', 'abcd1234', 'abcd@1234', 'aa123456', 'iloveyou',
    'iloveyou1', 'welcome1', 'welcome123', 'welcome@123', 'admin123', 'admin@123',
    'letmein1', 'sunshine1', 'football1', 'monkey123', 'dragon123', 'princess1',
    '1q2w3e4r', '1qaz2wsx', 'zaq12wsx', 'asdf1234', 'egypt123', 'egypt@123',
    'cairo123', 'cairo@123', 'guidy123', 'guidy@123',
  };

  static PasswordCheck check(String password) {
    final failed = <PasswordRule>{};
    if (password.length < minLength) failed.add(PasswordRule.minLength);
    if (!_upper.hasMatch(password)) failed.add(PasswordRule.upper);
    if (!_lower.hasMatch(password)) failed.add(PasswordRule.lower);
    if (!_digit.hasMatch(password)) failed.add(PasswordRule.digit);
    if (!_symbol.hasMatch(password)) failed.add(PasswordRule.symbol);
    if (password.isNotEmpty && password.trim() != password) failed.add(PasswordRule.noEdgeSpaces);
    if (isCommon(password)) failed.add(PasswordRule.notCommon);
    return PasswordCheck(failed);
  }

  static bool isCommon(String password) => _common.contains(password.toLowerCase());

  static PasswordStrength strength(String password) {
    if (password.isEmpty) return PasswordStrength.none;
    if (isCommon(password)) return PasswordStrength.weak;
    if (check(password).isValid) {
      return password.length >= strongLength ? PasswordStrength.strong : PasswordStrength.good;
    }
    final classes = [_upper, _lower, _digit, _symbol].where((r) => r.hasMatch(password)).length;
    return password.length >= minLength && classes >= 2 ? PasswordStrength.fair : PasswordStrength.weak;
  }
}
