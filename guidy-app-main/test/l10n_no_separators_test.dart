import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The beta reviewer circled every middle dot in the app ("same AI text")
// and asked for them all to go (2026-11). The "~" for "about" went with
// them: words read better ("about 10 min", "حوالي 10 دقايق"). This keeps
// both out of every user-facing string, in both languages.
const _middleDot = '·';

void main() {
  for (final lang in ['en', 'ar']) {
    test('no user-facing $lang string has a middle dot or a tilde', () {
      final arb = jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map<String, dynamic>;
      final bad = <String, String>{
        for (final e in arb.entries)
          if (!e.key.startsWith('@') && e.value is String && (e.value as String).contains(RegExp('[$_middleDot~]')))
            e.key: e.value as String,
      };
      expect(bad, isEmpty, reason: 'Use a comma, "and", a line break, or "about"/"حوالي" instead: $bad');
    });
  }
}
