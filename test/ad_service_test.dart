import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/services/ad_service.dart';

void main() {
  const testUnit = 'ca-app-pub-3940256099942544/6300978111';
  const realUnit = 'ca-app-pub-1111111111111111/2222222222';

  group('AdService.pickUnit', () {
    test('a build not explicitly marked for real ads serves the test unit even when a real one was passed', () {
      // Any script that hands the real unit IDs to the compiler (the Mac
      // installers pass every secret) used to ship live ads by accident.
      expect(AdService.pickUnit(realAds: false, configured: realUnit, testUnit: testUnit), testUnit);
    });

    test('a real-ads build serves the configured unit', () {
      expect(AdService.pickUnit(realAds: true, configured: realUnit, testUnit: testUnit), realUnit);
    });

    test('a real-ads build without a configured unit falls back to the test unit', () {
      expect(AdService.pickUnit(realAds: true, configured: '', testUnit: testUnit), testUnit);
    });
  });

  group('AdService.optionalUnit', () {
    const testNative = 'ca-app-pub-3940256099942544/2247696110';

    test('a build not marked for real ads serves the test unit', () {
      expect(AdService.optionalUnit(realAds: false, configured: realUnit, testUnit: testNative), testNative);
    });

    test('a real-ads build serves the configured unit', () {
      expect(AdService.optionalUnit(realAds: true, configured: realUnit, testUnit: testNative), realUnit);
    });

    test('a real-ads build without a unit serves none, never the test unit', () {
      // Riders must not see Google's test ads because a unit was missing.
      expect(AdService.optionalUnit(realAds: true, configured: '', testUnit: testNative), isNull);
    });
  });
}
