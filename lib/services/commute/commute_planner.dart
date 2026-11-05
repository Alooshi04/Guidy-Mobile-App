import 'dart:math' as math;

/// How often a line runs between two times of day (minutes after midnight),
/// from the backend's `headway_bands` (GTFS frequencies.txt).
class HeadwayBand {
  final int fromMin;
  final int toMin;
  final double every;

  const HeadwayBand({required this.fromMin, required this.toMin, required this.every});

  Map<String, dynamic> toJson() => {'from_min': fromMin, 'to_min': toMin, 'every_min': every};

  static HeadwayBand? fromJson(Object? j) {
    if (j is! Map) return null;
    final from = j['from_min'], to = j['to_min'], every = j['every_min'];
    if (from is! num || to is! num || every is! num || every <= 0) return null;
    return HeadwayBand(fromMin: from.toInt(), toMin: to.toInt(), every: every.toDouble());
  }
}

/// When a line runs at all (minutes after midnight; past 1440 for service
/// after midnight), from the backend's `service_windows`.
class ServiceWindow {
  final int fromMin;
  final int toMin;

  const ServiceWindow({required this.fromMin, required this.toMin});

  Map<String, dynamic> toJson() => {'from_min': fromMin, 'to_min': toMin};

  static ServiceWindow? fromJson(Object? j) {
    if (j is! Map) return null;
    final from = j['from_min'], to = j['to_min'];
    if (from is! num || to is! num || to <= from) return null;
    return ServiceWindow(fromMin: from.toInt(), toMin: to.toInt());
  }
}

/// One line of the rider's saved Home <-> Work route.
class CommuteLine {
  final String routeId;

  /// How the line is named in a notification ("Microbus 24", "Metro M1").
  final String label;
  final List<HeadwayBand> bands;
  final List<ServiceWindow> windows;

  const CommuteLine({required this.routeId, required this.label, this.bands = const [], this.windows = const []});

  Map<String, dynamic> toJson() => {
        'route_id': routeId,
        'label': label,
        'bands': [for (final b in bands) b.toJson()],
        'windows': [for (final w in windows) w.toJson()],
      };

  static CommuteLine? fromJson(Object? j) {
    if (j is! Map || j['route_id'] == null) return null;
    return CommuteLine(
      routeId: j['route_id'].toString(),
      label: (j['label'] ?? '').toString(),
      bands: [for (final b in (j['bands'] as List? ?? const [])) ?HeadwayBand.fromJson(b)],
      windows: [for (final w in (j['windows'] as List? ?? const [])) ?ServiceWindow.fromJson(w)],
    );
  }
}

enum CommuteNoticeKind {
  /// One of the rider's lines stops for the day soon.
  lastService,

  /// A line runs much more often now than at other times of day.
  easierNow,

  /// No line has frequencies: the window before the traffic rush.
  beatRush,
}

/// One notification of a day, at [minuteOfDay] (may pass 1440 for a line
/// that runs past midnight).
class CommuteNotice {
  final CommuteNoticeKind kind;
  final int minuteOfDay;

  /// The line it is about; null for [CommuteNoticeKind.beatRush].
  final String? line;

  /// Until when: the line's last service, the end of its frequent stretch,
  /// or the start of the rush.
  final int untilMin;

  /// [CommuteNoticeKind.easierNow]: every how many minutes now, and at its
  /// slowest the same part of the day.
  final double? every;
  final double? slowEvery;

  /// Morning (to work) or not (home).
  bool get morning => minuteOfDay < 12 * 60;

  const CommuteNotice({
    required this.kind,
    required this.minuteOfDay,
    required this.untilMin,
    this.line,
    this.every,
    this.slowEvery,
  });
}

/// Picks a day's commute notifications. Pure: no clock, no I/O, so the
/// whole policy is tested on its own (commute_planner_test.dart).
abstract final class CommutePlanner {
  static const int maxPerDay = 3;

  /// The warning comes this long before a line's last service.
  static const int lastServiceLeadMin = 45;

  /// Notifications this close together are one too many.
  static const int minGapMin = 60;

  /// Parts of the day a commute happens in: to work, and home.
  static const _periods = [(from: 5 * 60, to: 11 * 60), (from: 13 * 60, to: 21 * 60)];

  /// Cairo's traffic (raptor_engine.traffic_congestion_multiplier): a
  /// morning rush from 07:30 and an evening one from 17:30, after a midday
  /// peak that eases at 16:30.
  static const _rushHints = [
    (at: 7 * 60, until: 7 * 60 + 30),
    (at: 16 * 60 + 30, until: 17 * 60 + 30),
  ];

  /// A line's frequency is worth a notification when its frequent stretch
  /// saves at least this much waiting, and runs at most this share of its
  /// slowest headway in the same part of the day.
  static const double _minSavingMin = 3;
  static const double _maxShareOfSlowest = 0.75;

  static List<CommuteNotice> forDay(
    int weekday,
    List<CommuteLine> lines, {
    bool easier = true,
    bool lastService = true,
  }) {
    // Friday is the weekend: no commute to talk about.
    if (lines.isEmpty || weekday == DateTime.friday) return const [];

    final candidates = <CommuteNotice>[
      if (lastService) ?_lastService(lines),
      if (easier) ..._easier(lines),
    ];
    final picked = <CommuteNotice>[];
    for (final n in candidates) {
      if (picked.length >= maxPerDay) break;
      if (picked.any((p) => (p.minuteOfDay - n.minuteOfDay).abs() < minGapMin)) continue;
      picked.add(n);
    }
    return picked;
  }

  /// The line that stops first, unless every line runs all day.
  static CommuteNotice? _lastService(List<CommuteLine> lines) {
    CommuteLine? first;
    var firstEnd = 0;
    for (final l in lines) {
      if (l.windows.isEmpty) continue;
      final covered = l.windows.fold<int>(0, (t, w) => t + (w.toMin - w.fromMin));
      if (covered >= 23 * 60) continue;
      final end = l.windows.map((w) => w.toMin).reduce(math.max);
      if (first == null || end < firstEnd) {
        first = l;
        firstEnd = end;
      }
    }
    if (first == null) return null;
    return CommuteNotice(
      kind: CommuteNoticeKind.lastService,
      minuteOfDay: firstEnd - lastServiceLeadMin,
      line: first.label,
      untilMin: firstEnd,
    );
  }

  static List<CommuteNotice> _easier(List<CommuteLine> lines) {
    if (lines.every((l) => l.bands.isEmpty)) {
      return [
        for (final r in _rushHints) CommuteNotice(kind: CommuteNoticeKind.beatRush, minuteOfDay: r.at, untilMin: r.until),
      ];
    }
    return [
      for (final p in _periods) ?_bestStretch(lines, p.from, p.to),
    ];
  }

  /// The line whose frequency changes most over [from, to), at the start
  /// of its most frequent stretch there.
  static CommuteNotice? _bestStretch(List<CommuteLine> lines, int from, int to) {
    CommuteNotice? best;
    var bestSaving = 0.0;
    for (final l in lines) {
      final inPeriod = l.bands.where((b) => b.toMin > from && b.fromMin < to).toList();
      if (inPeriod.length < 2) continue;
      final fast = inPeriod.reduce((a, b) => b.every < a.every ? b : a);
      final slow = inPeriod.map((b) => b.every).reduce(math.max);
      final saving = slow - fast.every;
      if (saving < _minSavingMin || fast.every > slow * _maxShareOfSlowest) continue;
      if (saving > bestSaving) {
        bestSaving = saving;
        best = CommuteNotice(
          kind: CommuteNoticeKind.easierNow,
          minuteOfDay: math.max(fast.fromMin, from),
          line: l.label,
          untilMin: fast.toMin,
          every: fast.every,
          slowEvery: slow,
        );
      }
    }
    return best;
  }
}
