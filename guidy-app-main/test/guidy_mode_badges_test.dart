import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/theme/guidy_ui.dart';

void main() {
  group('metro line badge', () {
    test('comes from the route id, so Arabic line names still give M1/M2/M3', () {
      expect(GuidyModeStyle.metroLineNumber({'route_id': 'NAT_L3', 'number': 'الخط الثالث'}), '3');
      expect(GuidyModeStyle.metroLineNumber({'route_id': 'NAT_L1', 'number': 'Line 1'}), '1');
    });

    test('falls back to the digits in the number', () {
      expect(GuidyModeStyle.metroLineNumber({'route_id': 'X', 'number': 'Line 2'}), '2');
      expect(GuidyModeStyle.metroLineNumber({'route_id': 'X', 'number': 'الخط الأول'}), isNull);
    });

    test('each line has its own colour', () {
      expect(GuidyModeStyle.metroLine('1'), isNot(GuidyModeStyle.metroLine('2')));
      expect(GuidyModeStyle.metroLine('2'), isNot(GuidyModeStyle.metroLine('3')));
      expect(GuidyModeStyle.metroLine(null), isNull);
    });
  });

  group('number under a mode icon', () {
    test('keeps real line numbers', () {
      expect(GuidyModeStyle.badgeNumber('211'), '211');
      expect(GuidyModeStyle.badgeNumber('M11'), 'M11');
    });

    test('drops names that would not fit the tile', () {
      expect(GuidyModeStyle.badgeNumber('الأتوبيس الترددي'), '');
      expect(GuidyModeStyle.badgeNumber('BRT'), '');
      expect(GuidyModeStyle.badgeNumber(null), '');
    });
  });
}
