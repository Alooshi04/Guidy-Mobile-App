import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/services/interstitial_ad_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DateTime now;
  DateTime? appOpen;
  InterstitialAdService service() => InterstitialAdService(clock: () => now, lastAppOpenShownAt: () => appOpen);

  setUp(() {
    now = DateTime(2026, 10, 30, 15);
    appOpen = null;
    SharedPreferences.setMockInitialValues({});
  });

  test('the first trip after install never earns an ad, the second does', () async {
    final s = service();
    await s.recordArrival();
    expect(s.tripEligible, isFalse);
    await s.recordArrival();
    expect(s.tripEligible, isTrue);
  });

  test('the trip count survives a restart', () async {
    await service().recordArrival();
    final afterRestart = service();
    await afterRestart.recordArrival();
    expect(afterRestart.tripEligible, isTrue);
  });

  test('an app open ad a few minutes ago blocks it', () async {
    SharedPreferences.setMockInitialValues({'interstitial_completed_trips': 3});
    appOpen = now.subtract(const Duration(minutes: 2));
    final s = service();
    await s.recordArrival();
    expect(s.tripEligible, isFalse);
  });

  test('stored ad times apply the 2 h gap and the daily cap', () async {
    String ms(DateTime t) => '${t.millisecondsSinceEpoch}';
    SharedPreferences.setMockInitialValues({
      'interstitial_completed_trips': 5,
      'interstitial_shown_ms': [ms(DateTime(2026, 10, 30, 14))],
    });
    var s = service();
    await s.recordArrival();
    expect(s.tripEligible, isFalse, reason: 'one hour since the last');

    SharedPreferences.setMockInitialValues({
      'interstitial_completed_trips': 5,
      'interstitial_shown_ms': [ms(DateTime(2026, 10, 30, 8)), ms(DateTime(2026, 10, 30, 11))],
    });
    s = service();
    await s.recordArrival();
    expect(s.tripEligible, isFalse, reason: 'two already today');

    now = DateTime(2026, 10, 31, 9);
    s = service();
    await s.recordArrival();
    expect(s.tripEligible, isTrue, reason: 'a new day');
  });

  test('showAfterTrip uses up the trip\'s chance', () async {
    SharedPreferences.setMockInitialValues({'interstitial_completed_trips': 3});
    final s = service();
    await s.recordArrival();
    expect(s.tripEligible, isTrue);
    await s.showAfterTrip(); // no ad loaded in tests: nothing shows
    expect(s.tripEligible, isFalse);
  });
}
