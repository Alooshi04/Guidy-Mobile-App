import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/instruction_formatter.dart';
import '../../services/step_copy.dart';
import '../../theme/app_theme.dart';
import '../../theme/guidy_ui.dart';
import '../../utils/minutes_text.dart';
import '../../utils/ride_words.dart';
import 'simple_ui.dart';

/// What one trip step says, in plain words: "Walk to X", or "Ride the
/// minibus to Y" with what to tell the driver.
class SimpleStepText {
  const SimpleStepText({required this.title, this.tellDriver, this.details = const []});

  final String title;

  /// "Tell the driver: “Cine Plex”", for a road ride flagged down.
  final String? tellDriver;

  /// Minor lines (how far, how long), after the title.
  final List<String> details;

  static SimpleStepText of(AppLocalizations l10n, List steps, int index, {String? destination}) {
    final isAr = l10n.localeName.startsWith('ar');
    final s = index >= 0 && index < steps.length && steps[index] is Map
        ? Map<String, dynamic>.from(steps[index] as Map)
        : const <String, dynamic>{};
    final next = index + 1 < steps.length && steps[index + 1] is Map ? Map<String, dynamic>.from(steps[index + 1] as Map) : null;
    String name(Map<String, dynamic>? m, [String key = 'station']) =>
        m == null ? '' : (InstructionFormatter.localized(m, key, isAr: isAr) ?? '');
    final copy = StepCopy.of(l10n, steps, index);
    final action = s['action'];

    switch (action) {
      case 'board':
      case 'transfer':
        final asks = name(s, 'ask_driver');
        final ride = RideWords.action(l10n, s);
        final alight = name(s, 'alight_station');
        final rideMin = InstructionFormatter.asNum(s['ride_min']);
        return SimpleStepText(
          title: alight.isEmpty ? ride : l10n.simpleRideTo(ride, alight),
          tellDriver: asks.isEmpty ? null : l10n.simpleTellDriver(asks),
          details: [
            if (copy.lines.isNotEmpty) copy.lines.first,
            if (rideMin != null) l10n.minutes(rideMin),
          ],
        );
      case 'arrive':
        final at = name(s);
        return SimpleStepText(
          title: at.isEmpty ? copy.title : l10n.simpleGetOffAt(at),
          details: copy.lines,
        );
      case 'walk_to_destination':
        return SimpleStepText(
          title: destination != null && destination.isNotEmpty ? l10n.simpleWalkTo(destination) : copy.title,
          details: copy.lines,
        );
      case 'walk_to_station':
      case 'continue_walk':
      case 'walk_to_transfer':
        final place = name(action == 'walk_to_station' ? s : next);
        // To the street, where the next vehicle is waved down: the step's
        // own wording ("Walk to the street") has no place name to give.
        final toStreet = action != 'walk_to_transfer' &&
            next != null &&
            next['hail'] == true &&
            (next['action'] == 'board' || next['action'] == 'transfer');
        return SimpleStepText(
          title: place.isEmpty || toStreet ? copy.title : l10n.simpleWalkTo(place),
          details: copy.lines,
        );
      default:
        return SimpleStepText(title: copy.title, details: copy.lines);
    }
  }
}

/// The trip screen in simple mode: only the step the rider is on, big, with
/// "Next step" (when there is one), "Previous step" (when there is one) and
/// "End trip". It sits at the bottom of
/// the map and does not move.
class SimpleStepPanel extends StatelessWidget {
  const SimpleStepPanel({
    super.key,
    required this.instructions,
    required this.index,
    required this.onNext,
    required this.onEnd,
    this.onPrevious,
    this.destination,
    this.alarmStation,
    this.onReportWalk,
    this.walkReported = false,
  });

  final List instructions;
  final int index;
  final String? destination;

  /// Set when the next stop is close: "Get off at X" on top of everything.
  final String? alarmStation;

  /// Moves to the following step; null on the last one.
  final VoidCallback? onNext;
  final VoidCallback onEnd;

  /// Back to the step before; null on the first step.
  final VoidCallback? onPrevious;

  /// "This walk is wrong", on a walking step; null on any other.
  final VoidCallback? onReportWalk;
  final bool walkReported;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = SimpleStepText.of(l10n, instructions, index, destination: destination);
    return Container(
      key: const ValueKey('simple_step_panel'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(GuidyUi.radius)),
        border: Border(top: BorderSide(color: context.isDark ? Colors.white54 : const Color(0xFF0B1B2B), width: 2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: context.isDark ? 0.5 : 0.18), blurRadius: 12)],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.simpleStepOf(index + 1, instructions.length),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.textSecondary)),
            const SizedBox(height: 4),
            if (alarmStation != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active_rounded, color: AppColors.errorRed, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(l10n.simpleGetOffAt(alarmStation!),
                          key: const ValueKey('simple_alarm'),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.errorRed)),
                    ),
                  ],
                ),
              ),
            Text(text.title,
                key: const ValueKey('simple_step_title'),
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: context.textPrimary, height: 1.2)),
            if (text.tellDriver != null) ...[
              const SizedBox(height: 10),
              Container(
                key: const ValueKey('simple_tell_driver'),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.brandAmber.withValues(alpha: context.isDark ? 0.18 : 0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.record_voice_over_rounded, size: 28, color: context.textPrimary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(text.tellDriver!,
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: context.textPrimary, height: 1.25)),
                    ),
                  ],
                ),
              ),
            ],
            for (final d in text.details)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(d, style: TextStyle(fontSize: 18, color: context.textSecondary, height: 1.3)),
              ),
            if (onReportWalk != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: SimpleTextAction(
                  key: const ValueKey('simple_report_walk'),
                  icon: walkReported ? Icons.check_rounded : Icons.report_gmailerrorred_rounded,
                  label: walkReported ? l10n.walkReportedLabel : l10n.walkReportButton,
                  onPressed: walkReported ? null : onReportWalk,
                ),
              ),
            const SizedBox(height: 14),
            if (onNext != null) ...[
              SimpleButton(
                key: const ValueKey('simple_next_step'),
                icon: Icons.arrow_forward_rounded,
                label: l10n.simpleNextStep,
                primary: true,
                onPressed: onNext,
              ),
              const SizedBox(height: 10),
            ],
            if (onPrevious != null) ...[
              SimpleButton(
                key: const ValueKey('simple_prev_step'),
                icon: Icons.arrow_back_rounded,
                label: l10n.navPrevStep,
                primary: false,
                onPressed: onPrevious,
              ),
              const SizedBox(height: 10),
            ],
            SimpleButton(
              key: const ValueKey('simple_end_trip'),
              icon: Icons.close_rounded,
              label: l10n.simpleEndTrip,
              primary: onNext == null,
              onPressed: onEnd,
            ),
          ],
        ),
      ),
    );
  }
}
