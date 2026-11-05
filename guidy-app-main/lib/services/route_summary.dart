import '../l10n/app_localizations.dart';
import '../theme/guidy_ui.dart';
import '../utils/fare_text.dart';
import '../utils/minutes_text.dart';
import 'instruction_formatter.dart';
import 'step_copy.dart';
import 'transit_modes.dart';

/// One part of a route: a walk, or a ride on any of the lines that cover it.
class RouteLeg {
  const RouteLeg.walk({required this.meters})
      : step = const {},
        stepIndex = -1,
        lineLabels = const [],
        line = '';

  const RouteLeg.ride({required this.step, required this.stepIndex, required this.lineLabels, required this.line})
      : meters = 0;

  /// Where the ride's instruction sits in the route's instructions.
  final int stepIndex;

  bool get isWalk => step.isEmpty;

  /// "bus", "microbus", "metro" ...; "walk" for a walk.
  String get vehicleType => isWalk ? 'walk' : (step['vehicle_type']?.toString() ?? 'bus');

  /// Minutes on foot, for a walk.
  int get walkMinutes => StepCopy.walkMinutes(meters);

  /// How far a walk is, as the card says it: "376 m" / "376 م", and
  /// "1.2 km" from a kilometre on.
  String walkText(AppLocalizations l10n) =>
      meters >= 1000 ? l10n.distanceKm((meters / 1000).toStringAsFixed(1)) : l10n.routeWalkMeters('$meters');

  /// Minutes on board, for a ride.
  num? get rideMinutes => InstructionFormatter.asNum(step['ride_min']);

  /// Minutes waiting for the ride to come.
  num get waitMinutes => InstructionFormatter.asNum(step['wait_min']) ?? 0;

  int? get stops => InstructionFormatter.asNum(step['stops_count'])?.round();

  /// The ride's fare (decimal).
  num? get fare => InstructionFormatter.asNum(step['fare_egp']);

  /// How far a walk is.
  final int meters;

  /// The ride's instruction, as the route sends it.
  final Map<String, dynamic> step;

  /// Every line that covers the ride ("871", "45" ...), in the order the
  /// backend sends them (most frequent first), each once.
  final List<String> lineLabels;

  /// The one line the route was planned with (or the one the rider
  /// picked), as the card names it: "Minibus 66", "M3", or the mode alone
  /// for a line with no number. Empty for a walk.
  final String line;
}

/// A route option as the route card and the route detail page show it.
class RouteSummary {
  const RouteSummary._({
    required this.legs,
    required this.fare,
    required this.minutes,
    this.tag,
    this.tiers = const [],
    this.shortRide,
  });

  /// For a paid ride a short walk would replace: what it buys
  /// ("15 min faster, +20 EGP"). Shown in place of the tag.
  final String? shortRide;

  /// Door to door.
  final int minutes;

  /// The one tag the card shows ("Recommended", "Cheapest" ...), or null
  /// for a plain alternative. Other tiers the route also qualifies for
  /// aren't stacked next to it.
  final String? tag;

  /// Every one of Recommended / Fastest / Cheapest this route is (its own
  /// type and the ones it also qualifies as), in that order. Simple Mode
  /// shows them all; the compact card shows [tag] only.
  final List<String> tiers;

  // 'Partial' too: a route that stops short of the destination read as an
  // ordinary one on the compact card (QA 2026-10-22).
  static const _tierOrder = ['Recommended', 'Fastest', 'Cheapest'];

  static List<String> _tiersOf(Map<String, dynamic> option) {
    final have = <String>{
      if (option['type'] != null) option['type'].toString(),
      for (final t in (option['also_qualifies_as'] as List? ?? const [])) t.toString(),
    };
    return [for (final t in _tierOrder) if (have.contains(t)) t];
  }

  static const _tags = {'Recommended', 'Fastest', 'Cheapest', 'Available now', 'Walk', 'Partial'};

  /// Walking this far is worth saying on the card when it is more than
  /// the riding.
  static const _longWalkM = 1500;

  /// Minutes on foot when a transit route walks more than it rides and at
  /// least [_longWalkM] ("Cheapest" from Tahrir to Nasr City: 35 min of
  /// walking around 30 on board), else null. The card says so rather than
  /// hiding the route: Cheapest is the rider's call (QA 2026-10-22).
  int? get longWalkMinutes {
    final rides = legs.where((l) => !l.isWalk).toList();
    if (rides.isEmpty) return null;
    final walkM = legs.where((l) => l.isWalk).fold<int>(0, (s, l) => s + l.meters);
    if (walkM < _longWalkM) return null;
    final walkMin = StepCopy.walkMinutes(walkM);
    final rideMin = rides.fold<num>(0, (s, l) => s + (l.rideMinutes ?? 0));
    return walkMin > rideMin ? walkMin : null;
  }

  /// The whole trip's fare (decimal: 12.5 stays 12.5).
  final num? fare;

  final List<RouteLeg> legs;

  static const _walks = {'walk_to_station', 'walk_to_transfer', 'continue_walk', 'walk_to_destination'};

  /// Shorter walks aren't worth a step (the old step list skipped them too).
  static const _minWalkM = 15;

  static RouteSummary of(AppLocalizations l10n, Map<String, dynamic> option) {
    final legs = <RouteLeg>[];
    // Walks in a row (to a stop, then on) are one walk; a few steps are none.
    var walk = 0;
    void endWalk() {
      if (walk >= _minWalkM) legs.add(RouteLeg.walk(meters: walk));
      walk = 0;
    }

    final steps = option['instructions'] as List? ?? const [];
    for (var i = 0; i < steps.length; i++) {
      final raw = steps[i];
      if (raw is! Map) continue;
      final s = Map<String, dynamic>.from(raw);
      if (_walks.contains(s['action'])) {
        walk += InstructionFormatter.asNum(s['distance_m'])?.round() ?? 0;
      } else if (s['action'] == 'board' || s['action'] == 'transfer') {
        endWalk();
        legs.add(RouteLeg.ride(step: s, stepIndex: i, lineLabels: _lineLabels(l10n, s), line: rideLine(l10n, s)));
      }
    }
    endWalk();
    return RouteSummary._(
      legs: legs,
      fare: InstructionFormatter.asNum(option['fare_total_egp'] ?? option['fare_egp']),
      minutes: (InstructionFormatter.asNum(option['time']) ?? 0).round(),
      tag: _tags.contains(option['type']) ? option['type'] as String : null,
      tiers: _tiersOf(option),
      shortRide: switch (option['short_ride']) {
        final Map r => l10n.routeShortRide(
            l10n.minutes(InstructionFormatter.asNum(r['saves_min'])),
            fareAmount(InstructionFormatter.asNum(r['extra_egp']) ?? 0),
          ),
        _ => null,
      },
    );
  }

  static List<String> _lineLabels(AppLocalizations l10n, Map<String, dynamic> step) {
    // A road ride the rider asks the driver about: the mode, not the
    // lines (they are behind "Which microbuses?" on the ride itself).
    if (step['ask_driver_en'] != null || step['ask_driver_ar'] != null) {
      return [TransitModes.label(l10n, step['vehicle_type']?.toString())];
    }
    final opts = [
      for (final o in (step['boarding_options'] as List? ?? const []))
        if (o is Map) o,
    ];
    if (opts.isEmpty) opts.add(step);
    return <String>{for (final o in opts) lineLabel(l10n, o)}.toList();
  }

  /// The ride's own line, the one marked with a star on the detail page:
  /// "Minibus 66" / "ميني باص 66", "Green Bus G1", "M3". A line with no
  /// number, or a road ride the rider asks the driver about, is named by
  /// its mode. The reviewer had to open the route to find the minibus
  /// number (2026-11); a list of every covering line didn't fit the chip.
  /// Also names the lines a rider picks to build a route of their own.
  static String rideLine(AppLocalizations l10n, Map<dynamic, dynamic> step) {
    final vt = step['vehicle_type']?.toString();
    if (step['ask_driver_en'] != null || step['ask_driver_ar'] != null) return TransitModes.label(l10n, vt);
    final n = InstructionFormatter.cleanRouteNumber(step['route_number']?.toString());
    if (vt == 'metro') {
      final line = GuidyModeStyle.metroLineNumber(step);
      if (line != null) return 'M$line';
    }
    if (n == null) return InstructionFormatter.vehicleLabelFor(l10n, step);
    return l10n.routeCardLine(InstructionFormatter.vehicleLabelFor(l10n, step), n);
  }

  /// A line as riders say it: "M2" for metro line 2, the bare number for
  /// a bus, and the mode for a line without a number (microbuses).
  static String lineLabel(AppLocalizations l10n, Map o) {
    final vt = o['vehicle_type']?.toString();
    final n = InstructionFormatter.cleanRouteNumber(o['route_number']?.toString());
    if (n == null) return TransitModes.label(l10n, vt);
    return vt == 'metro' && RegExp(r'^\d+$').hasMatch(n) ? 'M$n' : n;
  }

  /// The whole trip's fare as riders read it: "22 EGP" / "22 جنيه", or Free.
  String fareText(AppLocalizations l10n) {
    final f = fare;
    return f == null || f == 0 ? l10n.fareFree : l10n.fareEgp(fareAmount(f));
  }
}
