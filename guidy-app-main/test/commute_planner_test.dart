import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/services/commute/commute_planner.dart';

// Commute notifications (owner, 2026-10-14): the lines of the saved
// Home <-> Work route; "easier now" from how often they run at each time of
// day, falling back to the rush-hour profile; a warning before they stop
// for the day; never more than three a day. Planned on the phone.

CommuteLine _line(
  String label, {
  List<HeadwayBand> bands = const [],
  List<ServiceWindow> windows = const [],
}) =>
    CommuteLine(routeId: label, label: label, bands: bands, windows: windows);

HeadwayBand _band(int fromH, int toH, double every) => HeadwayBand(fromMin: fromH * 60, toMin: toH * 60, every: every);

void main() {
  const sunday = DateTime.sunday;

  test('no lines, no notifications', () {
    expect(CommutePlanner.forDay(sunday, const []), isEmpty);
  });

  test('nothing on Friday, the weekend', () {
    final lines = [_line('Microbus 24', windows: const [ServiceWindow(fromMin: 360, toMin: 1380)])];
    expect(CommutePlanner.forDay(DateTime.friday, lines), isEmpty);
    expect(CommutePlanner.forDay(sunday, lines), isNotEmpty);
  });

  group('last service', () {
    test('warns 45 minutes before the first of the lines stops for the day', () {
      final lines = [
        _line('Bus 910', windows: const [ServiceWindow(fromMin: 360, toMin: 1380)]), // to 23:00
        _line('LRT', windows: const [ServiceWindow(fromMin: 330, toMin: 1410)]), // to 23:30
      ];
      final last = CommutePlanner.forDay(sunday, lines).where((n) => n.kind == CommuteNoticeKind.lastService).toList();
      expect(last, hasLength(1));
      expect(last.single.minuteOfDay, 1380 - 45);
      expect(last.single.line, 'Bus 910');
      expect(last.single.untilMin, 1380);
    });

    test('a line running past midnight is warned about before its own end', () {
      final lines = [_line('Metro M1', windows: const [ServiceWindow(fromMin: 315, toMin: 1440)])];
      final last = CommutePlanner.forDay(sunday, lines).singleWhere((n) => n.kind == CommuteNoticeKind.lastService);
      expect(last.minuteOfDay, 1440 - 45);
    });

    test('a line that never stops gets no warning', () {
      final lines = [_line('Microbus', windows: const [ServiceWindow(fromMin: 0, toMin: 1440)])];
      expect(CommutePlanner.forDay(sunday, lines).where((n) => n.kind == CommuteNoticeKind.lastService), isEmpty);
    });

    test('lines without hours get no warning', () {
      expect(
          CommutePlanner.forDay(sunday, [_line('Bus 1')]).where((n) => n.kind == CommuteNoticeKind.lastService),
          isEmpty);
    });
  });

  group('easier now, from how often the lines run', () {
    test('points at the morning stretch when the line runs most often', () {
      final lines = [
        _line('Bus 910', bands: [_band(6, 10, 10), _band(10, 15, 25), _band(15, 19, 12), _band(19, 23, 30)]),
      ];
      final easier = CommutePlanner.forDay(sunday, lines).where((n) => n.kind == CommuteNoticeKind.easierNow).toList();
      final morning = easier.firstWhere((n) => n.minuteOfDay < 12 * 60);
      expect(morning.minuteOfDay, 6 * 60); // as the frequent stretch starts
      expect(morning.line, 'Bus 910');
      expect(morning.every, 10);
      expect(morning.untilMin, 10 * 60);
      expect(morning.slowEvery, 25);
      final evening = easier.firstWhere((n) => n.minuteOfDay >= 12 * 60);
      expect(evening.minuteOfDay, 15 * 60);
      expect(evening.every, 12);
      expect(evening.untilMin, 19 * 60);
    });

    test('a frequency that hardly changes is not worth a notification', () {
      final lines = [_line('Bus 2', bands: [_band(6, 12, 10), _band(12, 23, 11)])];
      final n = CommutePlanner.forDay(sunday, lines);
      expect(n.where((n) => n.kind == CommuteNoticeKind.easierNow), isEmpty);
    });

    test('the line whose frequency changes most is the one named', () {
      final lines = [
        _line('Bus 1', bands: [_band(6, 10, 10), _band(10, 23, 14)]),
        _line('Minibus 7', bands: [_band(6, 10, 5), _band(10, 23, 20)]),
      ];
      final morning = CommutePlanner.forDay(sunday, lines)
          .firstWhere((n) => n.kind == CommuteNoticeKind.easierNow && n.minuteOfDay < 12 * 60);
      expect(morning.line, 'Minibus 7');
    });
  });

  group('easier now, from the rush hours, when no line has frequencies', () {
    test('before the morning rush and in the afternoon lull', () {
      final n = CommutePlanner.forDay(sunday, [_line('Microbus')]);
      final rush = n.where((n) => n.kind == CommuteNoticeKind.beatRush).toList();
      expect(rush.map((n) => n.minuteOfDay), [7 * 60, 16 * 60 + 30]);
      expect(rush.first.untilMin, 7 * 60 + 30);
      expect(rush.last.untilMin, 17 * 60 + 30);
    });
  });

  test('never more than three a day, the last-service warning first', () {
    final lines = [
      _line('Bus 910',
          bands: [_band(6, 10, 10), _band(10, 15, 25), _band(15, 19, 12), _band(19, 23, 30)],
          windows: const [ServiceWindow(fromMin: 360, toMin: 1380)]),
    ];
    final n = CommutePlanner.forDay(sunday, lines);
    expect(n.length, lessThanOrEqualTo(CommutePlanner.maxPerDay));
    expect(n.first.kind, CommuteNoticeKind.lastService);
  });

  test('a kind the rider turned off is left out', () {
    final lines = [
      _line('Bus 910', bands: [_band(6, 10, 10), _band(10, 23, 25)], windows: const [ServiceWindow(fromMin: 360, toMin: 1380)]),
    ];
    final onlyLast = CommutePlanner.forDay(sunday, lines, easier: false);
    expect(onlyLast.map((n) => n.kind), [CommuteNoticeKind.lastService]);
    final noLast = CommutePlanner.forDay(sunday, lines, lastService: false);
    expect(noLast.map((n) => n.kind), everyElement(isNot(CommuteNoticeKind.lastService)));
  });

  test('notifications are not at the same time as one another', () {
    final lines = [
      // Frequent from 22:30 and the service ends at 23:15: the warning wins.
      _line('Bus 9', bands: [_band(13, 22, 30), HeadwayBand(fromMin: 1350, toMin: 1395, every: 5)],
          windows: const [ServiceWindow(fromMin: 780, toMin: 1395)]),
    ];
    final times = CommutePlanner.forDay(sunday, lines).map((n) => n.minuteOfDay).toList()..sort();
    for (var i = 1; i < times.length; i++) {
      expect(times[i] - times[i - 1], greaterThanOrEqualTo(60));
    }
  });
}
