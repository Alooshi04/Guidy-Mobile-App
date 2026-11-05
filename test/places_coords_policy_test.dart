import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/services/places_coords_policy.dart';

void main() {
  group('PlacesCoordsPolicy', () {
    // ── maxAge ─────────────────────────────────────────────────────────
    test('maxAge is 30 days', () {
      expect(PlacesCoordsPolicy.maxAge, equals(const Duration(days: 30)));
    });

    // ── now ─────────────────────────────────────────────────────────────
    test('now returns a value close to current epoch millis', () {
      final before = DateTime.now().millisecondsSinceEpoch;
      final result = PlacesCoordsPolicy.now;
      final after = DateTime.now().millisecondsSinceEpoch;
      expect(result, greaterThanOrEqualTo(before));
      expect(result, lessThanOrEqualTo(after));
    });

    // ── isExpired ──────────────────────────────────────────────────────
    group('isExpired', () {
      test('null returns true (pre-policy entries with unknown age)', () {
        expect(PlacesCoordsPolicy.isExpired(null), isTrue);
      });

      test('non-int returns true', () {
        expect(PlacesCoordsPolicy.isExpired('not_an_int'), isTrue);
        expect(PlacesCoordsPolicy.isExpired(3.14), isTrue);
        expect(PlacesCoordsPolicy.isExpired(true), isTrue);
      });

      test('just-created timestamp is NOT expired', () {
        final now = DateTime.now().millisecondsSinceEpoch;
        expect(PlacesCoordsPolicy.isExpired(now), isFalse);
      });

      test('29-day-old timestamp is NOT expired', () {
        final ts = DateTime.now()
            .subtract(const Duration(days: 29))
            .millisecondsSinceEpoch;
        expect(PlacesCoordsPolicy.isExpired(ts), isFalse);
      });

      test('31-day-old timestamp IS expired', () {
        final ts = DateTime.now()
            .subtract(const Duration(days: 31))
            .millisecondsSinceEpoch;
        expect(PlacesCoordsPolicy.isExpired(ts), isTrue);
      });

      test('exactly 30 days ago IS expired (boundary: >= maxAge)', () {
        final ts = DateTime.now()
            .subtract(const Duration(days: 30))
            .millisecondsSinceEpoch;
        expect(PlacesCoordsPolicy.isExpired(ts), isTrue);
      });

      test('1-second-old timestamp is NOT expired', () {
        final ts = DateTime.now()
            .subtract(const Duration(seconds: 1))
            .millisecondsSinceEpoch;
        expect(PlacesCoordsPolicy.isExpired(ts), isFalse);
      });
    });
  });
}
