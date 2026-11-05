import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../screens/trip/trip_progress.dart';
import '../../services/instruction_formatter.dart';
import '../../services/step_copy.dart';
import '../../services/transit_modes.dart';
import '../../theme/app_theme.dart';
import '../../theme/guidy_ui.dart';
import '../../utils/minutes_text.dart';
import '../../utils/trip_eta.dart';

/// The one card in the floating window: the step now, and what is left.
class TripPipRundown extends StatelessWidget {
  const TripPipRundown({super.key, required this.instructions, required this.step, required this.remaining});

  final List<dynamic> instructions;
  final int step;
  final ValueListenable<Remaining?> remaining;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final iconKey = InstructionFormatter.iconKey(instructions[step] as Map<String, dynamic>);
    final copy = StepCopy.of(l10n, instructions, step);
    return Container(
      key: const ValueKey('pip_rundown'),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: context.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 6)],
      ),
      child: Row(
        children: [
          Icon(TransitModes.icon(iconKey), size: 18, color: GuidyModeStyle.forStep(instructions[step] as Map<String, dynamic>, dark: context.isDark)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.brandBlue,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                ValueListenableBuilder<Remaining?>(
                  valueListenable: remaining,
                  builder: (context, left, _) {
                    if (left == null) return const SizedBox.shrink();
                    return Text(
                      StepCopy.join(l10n, [
                        l10n.minutes(math.max(1, left.minutes.ceil())),
                        TripEta.distanceLabel(left.meters, isArabic: isArabic),
                      ]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.textSecondary, fontSize: 10.5),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
