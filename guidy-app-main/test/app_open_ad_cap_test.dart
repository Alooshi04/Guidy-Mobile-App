import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/services/app_open_ad_service.dart';

void main() {
  final now = DateTime(2026, 10, 30, 18);
  bool allows(List<Duration> agos) => AppOpenAdService.capAllows(agos.map(now.subtract).toList()..sort(), now);

  group('AppOpenAdService.capAllows', () {
    test('the first ad of the day is allowed', () {
      expect(allows([]), isTrue);
    });

    test('not within 4 hours of the last one', () {
      expect(allows([const Duration(hours: 3, minutes: 59)]), isFalse);
      expect(allows([const Duration(hours: 4)]), isTrue);
    });

    test('at most 3 in any 24 hours', () {
      expect(allows([const Duration(hours: 16), const Duration(hours: 10), const Duration(hours: 5)]), isFalse);
      expect(allows([const Duration(hours: 10), const Duration(hours: 5)]), isTrue);
    });

    test('ads older than 24 hours no longer count', () {
      expect(allows([const Duration(hours: 30), const Duration(hours: 25), const Duration(hours: 24)]), isTrue);
    });
  });
}
