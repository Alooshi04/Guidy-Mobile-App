import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/utils/email.dart';

void main() {
  test('accepts real addresses, hyphenated and multi-part domains included', () {
    for (final e in ['a@b.co', 'name@my-company.com', 'x.y+tag@mail.example.com.eg', ' pad@ded.com ']) {
      expect(isValidEmail(e), isTrue, reason: e);
    }
  });

  test('rejects typos', () {
    for (final e in ['', 'plain', 'a@b', '@b.com', 'a@.com', 'a b@c.com', 'a@b.com x', 'a@@b.com']) {
      expect(isValidEmail(e), isFalse, reason: e);
    }
  });
}
