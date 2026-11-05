import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/services/commute/commute_notifications.dart';
import 'package:guidy_app/services/commute/commute_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  tzdata.initializeTimeZones();
  final en = lookupAppLocalizations(const Locale('en'));
  final ar = lookupAppLocalizations(const Locale('ar'));

  group('copy', () {
    test('clock times in each language', () {
      expect(CommuteCopy.clock(1380, arabic: false), '11:00 PM');
      expect(CommuteCopy.clock(330, arabic: false), '5:30 AM');
      expect(CommuteCopy.clock(1440, arabic: false), '12:00 AM');
      expect(CommuteCopy.clock(1380, arabic: true), '11:00 م');
    });

    test('last service names the line and when it stops', () {
      const n = CommuteNotice(kind: CommuteNoticeKind.lastService, minuteOfDay: 1335, untilMin: 1380, line: 'Bus 910');
      expect(CommuteCopy.of(en, n).title, 'Bus 910 stops at 11:00 PM');
      expect(CommuteCopy.of(ar, n).title, contains('Bus 910'));
    });

    test('easier now says how often, until when, and otherwise', () {
      const n = CommuteNotice(
          kind: CommuteNoticeKind.easierNow, minuteOfDay: 360, untilMin: 600, line: 'Bus 910', every: 10, slowEvery: 25);
      final c = CommuteCopy.of(en, n);
      expect(c.title, en.commuteEasierTitleMorning);
      expect(c.body, 'Bus 910 runs every 10 min until 10:00 AM. Other times it\'s every 25 min.');
    });

    test('the evening rush hint is about heading home', () {
      const n = CommuteNotice(kind: CommuteNoticeKind.beatRush, minuteOfDay: 990, untilMin: 1050);
      expect(CommuteCopy.of(en, n).title, en.commuteRushTitleEvening);
      expect(CommuteCopy.of(en, n).body, contains('5:30 PM'));
    });
  });

  group('Home and Work', () {
    setUp(() => SharedPreferences.setMockInitialValues({
          'Home': 'Shubra|30.1100|31.2450',
          'Work': 'Smart Village|30.0710|31.0170',
        }));

    test('read from the saved slots', () async {
      final hw = CommuteNotifications.homeWorkFrom(await SharedPreferences.getInstance())!;
      expect(hw.homeLat, 30.11);
      expect(hw.workLon, 31.017);
    });

    test('a trip between them, either way, is the commute; others are not', () async {
      final hw = CommuteNotifications.homeWorkFrom(await SharedPreferences.getInstance())!;
      expect(CommuteNotifications.isCommute(hw, 30.1102, 31.2452, 30.0712, 31.0168), isTrue);
      expect(CommuteNotifications.isCommute(hw, 30.0712, 31.0168, 30.1102, 31.2452), isTrue);
      expect(CommuteNotifications.isCommute(hw, 30.1102, 31.2452, 30.0444, 31.2357), isFalse);
    });

    test('no Work saved, no commute', () async {
      SharedPreferences.setMockInitialValues({'Home': 'Shubra|30.11|31.245'});
      expect(CommuteNotifications.homeWorkFrom(await SharedPreferences.getInstance()), isNull);
    });
  });

  group('lines of the commute', () {
    final option = {
      'instructions': [
        {'action': 'walk_to_station'},
        {'action': 'board', 'route_id': 'M1', 'direction_id': '0', 'route_number': '1', 'vehicle_type': 'metro'},
        {'action': 'transfer', 'route_id': 'B910', 'direction_id': '1', 'route_number': '910', 'vehicle_type': 'bus'},
        {'action': 'arrive'},
      ],
    };

    test('each vehicle leg once, with the direction ridden', () {
      final legs = CommuteNotifications.legsOf(en, option);
      expect(legs.map((l) => l.routeId), ['M1', 'B910']);
      expect(legs.map((l) => l.directionId), ['0', '1']);
      expect(legs.last.label, contains('910'));
    });

    test('a line takes the bands of the direction ridden and the line\'s hours', () {
      final leg = CommuteNotifications.legsOf(en, option).last;
      final line = CommuteNotifications.lineFrom(leg, {
        'service_windows': [
          {'from_min': 360, 'to_min': 1380}
        ],
        'directions': [
          {
            'direction_id': '0',
            'headway_bands': [
              {'from_min': 360, 'to_min': 600, 'every_min': 40}
            ]
          },
          {
            'direction_id': '1',
            'headway_bands': [
              {'from_min': 360, 'to_min': 600, 'every_min': 10},
              {'from_min': 600, 'to_min': 1380, 'every_min': 25},
            ]
          },
        ],
      });
      expect(line.bands.map((b) => b.every), [10, 25]);
      expect(line.windows.single.toMin, 1380);
    });
  });

  group('when', () {
    final cairo = tz.getLocation('Africa/Cairo');

    test('the next such weekday at that time', () {
      final now = tz.TZDateTime(cairo, 2026, 10, 14, 20); // a Wednesday evening
      final at = CommuteNotifications.nextAt(now, DateTime.thursday, 7 * 60);
      expect(at, tz.TZDateTime(cairo, 2026, 10, 15, 7));
    });

    test('today, if it is still to come', () {
      final now = tz.TZDateTime(cairo, 2026, 10, 14, 6);
      expect(CommuteNotifications.nextAt(now, DateTime.wednesday, 7 * 60), tz.TZDateTime(cairo, 2026, 10, 14, 7));
    });

    test('past midnight falls on the next day', () {
      final now = tz.TZDateTime(cairo, 2026, 10, 14, 6);
      // Wednesday's line stops at 00:30 Thursday: warned at 23:45 Wednesday,
      // and a 24:15 minute-of-day lands at 00:15 Thursday.
      expect(CommuteNotifications.nextAt(now, DateTime.wednesday, 24 * 60 + 15), tz.TZDateTime(cairo, 2026, 10, 15, 0, 15));
    });
  });
}
