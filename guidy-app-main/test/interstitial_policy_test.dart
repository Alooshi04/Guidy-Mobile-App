import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/services/interstitial_policy.dart';

void main() {
  final now = DateTime(2026, 10, 30, 15, 0);
  bool can({List<DateTime> shown = const [], int trips = 3, DateTime? appOpen, DateTime? at}) =>
      InterstitialPolicy.canShow(
        now: at ?? now,
        shownAt: shown,
        completedTripsBefore: trips,
        lastAppOpenShownAt: appOpen,
      );

  test('allowed when nothing has shown', () => expect(can(), isTrue));
  test('never on the first trip after install', () => expect(can(trips: 0), isFalse));
  test('second trip is allowed', () => expect(can(trips: 1), isTrue));

  test('needs two hours since the last one', () {
    expect(can(shown: [now.subtract(const Duration(hours: 1, minutes: 59))]), isFalse);
    expect(can(shown: [now.subtract(const Duration(hours: 2))]), isTrue);
  });

  test('at most two a day', () {
    final two = [DateTime(2026, 10, 30, 8), DateTime(2026, 10, 30, 11, 30)];
    expect(can(shown: two), isFalse);
    expect(can(shown: [DateTime(2026, 10, 30, 8)]), isTrue);
  });

  test('yesterday does not count toward today', () {
    final shown = [DateTime(2026, 10, 29, 20), DateTime(2026, 10, 29, 22)];
    expect(can(shown: shown, at: DateTime(2026, 10, 30, 0, 30)), isTrue);
    expect(can(shown: shown, at: DateTime(2026, 10, 29, 22, 30)), isFalse); // same day, under 2 h
    expect(can(shown: shown, at: DateTime(2026, 10, 30, 9)), isTrue);
  });

  test('not within five minutes of an app open ad', () {
    expect(can(appOpen: now.subtract(const Duration(minutes: 4))), isFalse);
    expect(can(appOpen: now.subtract(const Duration(minutes: 5))), isTrue);
  });

  test('a clock set back does not lift the cap', () {
    expect(can(shown: [now.add(const Duration(hours: 3))]), isFalse);
  });
}
