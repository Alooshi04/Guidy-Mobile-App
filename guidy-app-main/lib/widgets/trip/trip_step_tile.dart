import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/instruction_formatter.dart';
import '../../services/step_copy.dart';
import '../../services/transit_modes.dart';
import '../../theme/app_theme.dart';
import '../../theme/guidy_ui.dart';

/// One step in the trip sheet's list: its mode on a rail, what to do with
/// a ride's fare next to its line, and -- when the step offers other
/// vehicles and is unfolded -- [alternatives] under it. No wait or
/// direction: the stops and minutes say enough (beta feedback, 2026-11).
class TripStepTile extends StatelessWidget {
  const TripStepTile({
    super.key,
    required this.instructions,
    required this.index,
    required this.isNow,
    required this.isOpen,
    required this.tappable,
    required this.onToggle,
    this.alternatives,
    this.onReportWalk,
    this.walkReported = false,
  });

  final List<dynamic> instructions;
  final int index;

  /// The step the rider is on.
  final bool isNow;

  /// Unfolded to show [alternatives].
  final bool isOpen;

  /// The step has other vehicles to choose from, so it can unfold.
  final bool tappable;
  final VoidCallback onToggle;
  final Widget? alternatives;

  /// "This walk is wrong" for a walking step the rider is not on yet or
  /// has passed; the step the rider is on has it on the Now card.
  final VoidCallback? onReportWalk;
  final bool walkReported;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final step = instructions[index] as Map<String, dynamic>;
    final iconKey = InstructionFormatter.iconKey(step);
    final color = GuidyModeStyle.forStep(step, dark: context.isDark);
    final bool isLast = index == instructions.length - 1;
    final copy = StepCopy.of(l10n, instructions, index);

    return Ink(
      color: isNow ? AppColors.brandBlue.withValues(alpha: context.isDark ? 0.10 : 0.05) : null,
      child: InkWell(
        onTap: tappable ? onToggle : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // rail: dot + connector, so the list reads as one journey
                  SizedBox(
                    width: 34,
                    child: Column(
                      children: [
                        const SizedBox(height: 14),
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: context.isDark ? 0.22 : 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(color: color, width: isNow ? 2 : 0),
                          ),
                          child: Icon(TransitModes.icon(iconKey), color: color, size: 16),
                        ),
                        if (!isLast) Container(width: 2, height: isOpen ? 18 : 26, color: context.fieldFill),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 14, bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  copy.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: iconKey == 'walk' ? AppColors.brandBlue : color,
                                  ),
                                ),
                              ),
                              if (copy.fare != null) ...[
                                const SizedBox(width: 7),
                                Text(
                                  copy.fare!,
                                  key: ValueKey('step_fare_$index'),
                                  style: TextStyle(
                                    color: GuidyUi.greenText(context),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                              if (isNow) ...[
                                const SizedBox(width: 7),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.brandBlue,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    l10n.navNowLabel.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          for (final line in copy.lines)
                            Text(line, style: TextStyle(color: context.textSecondary, fontSize: 12.5)),
                          if (onReportWalk != null)
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: TextButton.icon(
                                key: ValueKey('walk_report_step_$index'),
                                onPressed: walkReported ? null : onReportWalk,
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                ),
                                icon: Icon(walkReported ? Icons.check_rounded : Icons.report_gmailerrorred_rounded, size: 16),
                                label: Text(
                                  walkReported ? l10n.walkReportedLabel : l10n.walkReportButton,
                                  style: const TextStyle(fontSize: 12.5),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (tappable)
                    Padding(
                      padding: const EdgeInsets.only(top: 18),
                      child: Icon(
                        isOpen ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                        color: context.textSecondary,
                      ),
                    ),
                ],
              ),
              if (isOpen && alternatives != null) alternatives!,
            ],
          ),
        ),
      ),
    );
  }
}
