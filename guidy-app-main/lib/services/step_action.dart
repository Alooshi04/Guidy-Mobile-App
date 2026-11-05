import 'dart:math' as math;

import '../l10n/app_localizations.dart';
import '../utils/fare_text.dart';
import '../utils/minutes_text.dart';
import '../utils/ride_words.dart';
import 'instruction_formatter.dart';
import 'step_copy.dart';

/// One line the rider can take for a ride step ("Bus 45"), from the
/// step's `boarding_options`.
class StepLine {
  const StepLine({required this.label, required this.option, required this.isPlanned, this.note});

  final String label;

  /// What sets this line apart, if anything: "about 3 min away" from a
  /// live position, or its fare when that differs from the planned line's.
  final String? note;

  /// The boarding option itself, to switch the trip to it.
  final Map<String, dynamic> option;

  /// The line the trip is planned on.
  final bool isPlanned;
}

/// What one live trip step says on its card: a short bold action
/// ([header], "Wave down any of these"), the place it is about ([title]),
/// and for a ride every line that covers it ([lines]) and where to get
/// off ([ride]).
class StepAction {
  const StepAction({
    required this.header,
    required this.title,
    this.lines = const [],
    this.ride,
    this.notes = const [],
    this.askDriver,
    this.linesLabel,
  });

  /// "Ask the driver: going to Cine Plex?", for a road ride: the one name
  /// true for every line in [lines], which then sit behind [linesLabel]
  /// ("Which microbuses?"). Null when the backend sent no name (rail, or an
  /// older backend): the lines are then listed as before.
  final String? askDriver;
  final String? linesLabel;

  /// The walks a ride's leg adds, when its line boards or lets off a short
  /// walk from the planned stops ("Walk 180 m to Ragab Sons first").
  final List<String> notes;

  final String header;
  final String title;
  final List<StepLine> lines;

  /// "Get off at X, 30 stops, 49 min", for a ride.
  final String? ride;

  static Map<String, dynamic>? _at(List steps, int i) =>
      i >= 0 && i < steps.length && steps[i] is Map ? Map<String, dynamic>.from(steps[i] as Map) : null;

  /// [destination] names the trip's end, for the last walk.
  static StepAction of(AppLocalizations l10n, List steps, int index, {String? destination}) {
    final isAr = l10n.localeName.startsWith('ar');
    final s = _at(steps, index) ?? const <String, dynamic>{};
    final next = _at(steps, index + 1);
    String name(Map<String, dynamic>? m, [String key = 'station']) =>
        m == null ? '' : (InstructionFormatter.localized(m, key, isAr: isAr) ?? '');
    final meters = InstructionFormatter.asNum(s['distance_m'])?.round() ?? 0;
    final walkFor = l10n.minutes(StepCopy.walkMinutes(math.max(1, meters)));

    switch (s['action']) {
      case 'board':
      case 'transfer':
        final alight = name(s, 'alight_station');
        final stops = InstructionFormatter.asNum(s['stops_count'])?.round();
        final rideMin = InstructionFormatter.asNum(s['ride_min']);
        final ride = StepCopy.join(l10n, [
          if (alight.isNotEmpty) l10n.stepGetOffAt(alight),
          if (stops != null && stops > 0) l10n.stepStops(stops),
          if (rideMin != null) l10n.minutes(rideMin),
        ]);
        final lines = _lines(l10n, s);
        final hail = s['hail'] == true;
        final many = lines.length > 1;
        final place = name(s, 'ask_driver');
        final ask = place.isEmpty ? null : l10n.stepAskDriver(place);
        final vt = s['vehicle_type']?.toString();
        return StepAction(
          header: ask != null
              ? (hail ? l10n.actWaveDownRide : l10n.actWaitForRide)
              : hail
                  ? (many ? l10n.actWaveDownAny : l10n.actWaveDown(RideWords.thing(l10n, s)))
                  : (many ? l10n.actWaitForAny : l10n.actTakeAt(RideWords.action(l10n, s))),
          askDriver: ask,
          linesLabel: ask == null
              ? null
              : (vt == 'bus' ? l10n.stepWhichBuses : l10n.stepWhichMicrobuses),
          title: name(s),
          lines: lines,
          ride: ride.isEmpty ? null : ride,
          notes: InstructionFormatter.legWalkNotes(l10n, s),
        );
      case 'arrive':
        return StepAction(
          header: s['hail'] == true ? l10n.actAskDriverStopAt : l10n.actGetOffAt,
          title: name(s),
        );
      case 'walk_to_transfer':
        return StepAction(header: l10n.actGetOffWalkTo(walkFor), title: name(next));
      case 'walk_to_destination':
        return StepAction(
          header: l10n.actWalkTo(walkFor),
          title: destination != null && destination.isNotEmpty ? destination : l10n.actYourDestination,
        );
      case 'continue_walk':
        return StepAction(header: l10n.actWalkTo(walkFor), title: name(next));
      default:
        return StepAction(header: l10n.actWalkTo(walkFor), title: name(s));
    }
  }

  static List<StepLine> _lines(AppLocalizations l10n, Map<String, dynamic> s) {
    final opts = s['boarding_options'];
    // No alternatives listed: the step's own line is the only one.
    if (opts is! List || opts.isEmpty) {
      return [StepLine(label: InstructionFormatter.optionSummary(l10n, s), option: s, isPlanned: true)];
    }
    final plannedFare = InstructionFormatter.asNum(s['fare_egp']);
    return [
      for (final o in opts.whereType<Map>())
        StepLine(
          label: InstructionFormatter.optionSummary(l10n, Map<String, dynamic>.from(o)),
          option: Map<String, dynamic>.from(o),
          isPlanned: o['is_primary'] == true,
          note: _note(l10n, o, plannedFare),
        ),
    ];
  }

  static String? _note(AppLocalizations l10n, Map o, num? plannedFare) {
    final eta = InstructionFormatter.asNum(o['eta_sec']);
    final walk = InstructionFormatter.asNum(o['walk_to_board_m'])?.round() ?? 0;
    final boardAt = InstructionFormatter.localized(o, 'board_stop_name', isAr: l10n.localeName.startsWith('ar'));
    final fare = InstructionFormatter.asNum(o['fare_egp']);
    final kind = InstructionFormatter.vehicleKind(o, isAr: l10n.localeName.startsWith('ar'));
    final parts = [
      // "Bus 20, 25 EGP" beside "Bus 221, 5.5 EGP" looked like a
      // mistake until it said double-decker (QA 2026-10-22).
      ?kind,
      if (eta != null) l10n.navMinutesAway(l10n.minutes(math.max(1, (eta / 60).ceil()))),
      if (walk > 0 && boardAt != null) l10n.navWalkToStop('$walk', boardAt),
      // 0 is a line with no fare of its own (the metro is priced by the leg).
      if (fare != null && fare > 0 && plannedFare != null && fare != plannedFare) l10n.fareEgp(fareAmount(fare)),
    ];
    return parts.isEmpty ? null : StepCopy.join(l10n, parts);
  }
}
