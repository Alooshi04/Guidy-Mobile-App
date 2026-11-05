import 'dart:math' as math;

import '../l10n/app_localizations.dart';
import '../utils/fare_text.dart';
import '../utils/minutes_text.dart';
import '../utils/ride_words.dart';
import 'instruction_formatter.dart';

/// What a trip step says, as one instruction per card: where to walk to, or
/// which vehicle to ride, where to board and where to get off -- with how
/// long each takes. Replaces the card-plus-"intermission" pairs that
/// repeated each instruction and never said where to get off.
class StepCopy {
  const StepCopy({required this.title, this.lines = const [], this.fare, this.countdown});

  final String title;
  final List<String> lines;

  /// The ride's own fare ("10 EGP"), shown right next to the line in
  /// [title]; null for a walk, and for a line with no fare of its own (the
  /// metro is priced by the leg).
  final String? fare;

  /// Which of [lines] the live countdown ([live]) replaces on the step the
  /// rider is on, so the card never shows a planned and a live copy of the
  /// same distance. Null: none does, and the countdown follows the lines.
  final int? countdown;

  /// The engine's walking pace: 1.25 m/s.
  static const double walkMetersPerMin = 75;

  static int walkMinutes(num meters) => math.max(1, (meters / walkMetersPerMin).ceil());

  static bool _isAr(AppLocalizations l10n) => l10n.localeName.startsWith('ar');

  /// Parts of one line, in words: "Ride to X, 5 stops, 12 min" /
  /// "خليك راكب لحد X، 5 محطات، 12 دقيقة". The reviewer read the old middle dot
  /// between them as machine text (beta feedback, 2026-11).
  static String join(AppLocalizations l10n, Iterable<String> parts) => parts.join(_isAr(l10n) ? '، ' : ', ');

  /// A ride step's own fare, worded; null when it has none.
  static String? fareOf(AppLocalizations l10n, Map<dynamic, dynamic> step) {
    // 0 is a line with no fare of its own (the metro is priced by the leg).
    final fare = InstructionFormatter.asNum(step['fare_egp']);
    return fare != null && fare > 0 ? l10n.fareEgp(fareAmount(fare)) : null;
  }

  static Map<String, dynamic>? _at(List steps, int i) =>
      i >= 0 && i < steps.length && steps[i] is Map ? Map<String, dynamic>.from(steps[i] as Map) : null;

  static String _name(AppLocalizations l10n, Map<String, dynamic>? m, [String key = 'station']) =>
      m == null ? '' : (InstructionFormatter.localized(m, key, isAr: _isAr(l10n)) ?? '');

  static int _meters(Map<String, dynamic> m) => InstructionFormatter.asNum(m['distance_m'])?.round() ?? 0;

  static StepCopy of(AppLocalizations l10n, List steps, int index) {
    final s = _at(steps, index) ?? const <String, dynamic>{};
    final next = _at(steps, index + 1);
    final d = _meters(s);
    String walkMeta(int m) => l10n.stepWalkMeta('$m', l10n.minutes(walkMinutes(m)));

    switch (s['action']) {
      case 'walk_to_station':
      case 'continue_walk':
        final to = _name(l10n, s['action'] == 'continue_walk' ? next : s);
        // To the street, where the next vehicle is waved down (backend hail.py).
        final toStreet = next != null && next['hail'] == true && (next['action'] == 'board' || next['action'] == 'transfer');
        return StepCopy(
          title: toStreet
              ? l10n.stepWalkToStreet
              : (to.isNotEmpty ? l10n.stepWalkTo(to) : InstructionFormatter.title(l10n, s)),
          lines: [if (d > 0) walkMeta(d)],
          countdown: d > 0 ? 0 : null,
        );
      case 'board':
      case 'transfer':
        final board = _name(l10n, s);
        final alight = _name(l10n, s, 'alight_station');
        final rideMin = InstructionFormatter.asNum(s['ride_min']);
        final stops = InstructionFormatter.asNum(s['stops_count'])?.round();
        // Where to, how many stops, how long. Not the direction or the wait:
        // the line and where to get off already say which way, and the wait
        // is a guess the rider can't act on (beta feedback, 2026-11).
        final rideLine = join(l10n, [
          if (alight.isNotEmpty) l10n.stepRideTo(alight),
          if (stops != null && stops > 0) l10n.stepStops(stops),
          if (rideMin != null) l10n.minutes(rideMin),
        ]);
        return StepCopy(
          title: RideWords.action(l10n, s),
          fare: fareOf(l10n, s),
          lines: [
            // Boarded on the street, not at a stop (backend hail.py).
            if (board.isNotEmpty) s['hail'] == true ? l10n.plannerHailAt(board) : l10n.stepBoardAt(board),
            if (rideLine.isNotEmpty) rideLine,
            ...InstructionFormatter.legWalkNotes(l10n, s),
          ],
          countdown: rideLine.isEmpty ? null : (board.isNotEmpty ? 1 : 0),
        );
      case 'walk_to_transfer':
        final to = _name(l10n, next);
        final at = _name(l10n, s);
        return StepCopy(
          title: at.isNotEmpty ? l10n.stepGetOffAt(at) : InstructionFormatter.title(l10n, s),
          lines: [
            if (d > 0 && to.isNotEmpty) l10n.stepThenWalkTo('$d', to, l10n.minutes(walkMinutes(d))),
            if (d > 0 && to.isEmpty) walkMeta(d),
          ],
          countdown: d > 0 ? 0 : null,
        );
      case 'arrive':
        final at = _name(l10n, s);
        // No "then walk N m to your destination": the walk that follows is
        // its own step and says exactly that (beta feedback, 2026-11).
        return StepCopy(
          title: at.isEmpty
              ? InstructionFormatter.title(l10n, s)
              : (s['hail'] == true ? l10n.plannerAskToStopAt(at) : l10n.stepGetOffAt(at)),
        );
      case 'walk_to_destination':
        return StepCopy(
          title: l10n.stepWalkToDestination,
          lines: [if (d > 0) walkMeta(d)],
          countdown: d > 0 ? 0 : null,
        );
      default:
        final sub = InstructionFormatter.subtitle(l10n, s);
        return StepCopy(title: InstructionFormatter.title(l10n, s), lines: [if (sub.isNotEmpty) sub]);
    }
  }

  /// The live line for the step the rider is on, given the metres left to
  /// the end of it; null when the step has nothing to count down. It takes
  /// the place of the step's planned line ([countdown]).
  static String? live(AppLocalizations l10n, List steps, int index, double metersLeft) {
    final s = _at(steps, index);
    if (s == null) return null;
    final left = metersLeft.round();
    switch (s['action']) {
      case 'board':
      case 'transfer':
        final rideM = InstructionFormatter.asNum(s['ride_m']);
        final rideMin = InstructionFormatter.asNum(s['ride_min']);
        final alight = _name(l10n, s, 'alight_station');
        if (rideM == null || rideMin == null || rideM <= 0 || rideMin <= 0 || alight.isEmpty) return null;
        final mins = math.max(1, (left / (rideM / rideMin)).ceil());
        return l10n.liveGetOffIn(alight, l10n.minutes(mins));
      case 'walk_to_station':
      case 'continue_walk':
      case 'walk_to_transfer':
      case 'walk_to_destination':
      case 'arrive':
        final next = _at(steps, index + 1);
        final to = _name(l10n, s['action'] == 'walk_to_station' ? s : next);
        // Nearly there: "Arriving at X...", never "0 m to X".
        if (left < 20) return to.isEmpty ? null : l10n.arrivingAt(to);
        final shown = (left / 10).round() * 10;
        final mins = l10n.minutes(walkMinutes(left));
        // A walk's title already names where it ends ("Walk to X"); only a
        // get-off's ("Get off at X") needs the place the walk goes to.
        final namesEnd = s['action'] == 'walk_to_transfer' || s['action'] == 'arrive';
        if (!namesEnd) return l10n.liveWalkMetersLeft('$shown', mins);
        return to.isEmpty ? null : l10n.liveWalkLeft('$shown', to, mins);
      default:
        return null;
    }
  }
}
