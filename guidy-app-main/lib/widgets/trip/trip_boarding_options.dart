import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/instruction_formatter.dart';
import '../../theme/app_theme.dart';
import '../../utils/minutes_text.dart';
import '../../utils/fare_text.dart';

/// Every route covering this corridor — see raptor_engine.py's
/// _find_equivalent_routes. A live ETA (a rider currently sharing position
/// on that route) always outranks the schedule-derived headway, and the
/// two are styled differently rather than presented as equally certain:
/// live is coloured and marked, schedule-only is muted. At launch there
/// will be no live data at all, so the muted state is the normal one.
///
/// Tapping an alternative switches the vehicle mid-trip, recalculating
/// total journey fare, duration, and updating the instruction card.
class TripBoardingOptions extends StatelessWidget {
  const TripBoardingOptions({super.key, required this.step, required this.onPick});

  /// The step, with its `boarding_options`.
  final Map<String, dynamic> step;
  final void Function(Map<String, dynamic> option) onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final List options = step['boarding_options'] ?? const [];
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 46, bottom: 14, end: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.navAlsoServing.toUpperCase(),
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 7),
          ...options.map<Widget>((opt) {
            final bool isPrimary = opt['is_primary'] == true;
            final etaSec = opt['eta_sec'];
            final bool hasLive = etaSec != null;
            final headway = opt['typical_headway_min'];
            // 0 is a line with no fare of its own (the metro is priced by the leg).
            final optFare = InstructionFormatter.asNum(opt['fare_egp']);

            final String label = InstructionFormatter.optionSummary(l10n, Map<String, dynamic>.from(opt));
            final walkToBoard = InstructionFormatter.asNum(opt['walk_to_board_m'])?.round() ?? 0;
            final boardAt = InstructionFormatter.localized(opt, 'board_stop_name', isAr: isAr);
            final String? walkNote =
                walkToBoard > 0 && boardAt != null ? l10n.navWalkToStop('$walkToBoard', boardAt) : null;

            String detail;
            final etaNum = InstructionFormatter.asNum(etaSec);
            final headwayNum = InstructionFormatter.asNum(headway);
            if (hasLive && etaNum != null) {
              final int mins = (etaNum / 60).ceil();
              detail = mins <= 0 ? l10n.navArrivingNow : l10n.navMinutesAway(l10n.minutes(mins));
            } else if (headwayNum != null && headwayNum.round() > 0) {
              detail = l10n.navEveryMinutes(l10n.minutes(headwayNum));
            } else {
              detail = l10n.navNoLiveData;
            }

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onPick(opt),
                borderRadius: BorderRadius.circular(11),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                  decoration: BoxDecoration(
                    color: isPrimary
                        ? AppColors.primaryTeal.withValues(alpha: context.isDark ? 0.16 : 0.08)
                        : context.fieldFill,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: isPrimary
                          ? AppColors.primaryTeal
                          : (hasLive ? const Color(0xFF2ECC71) : Colors.transparent),
                      width: isPrimary ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(
                    children: [
                      if (hasLive) ...[
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(color: Color(0xFF2ECC71), shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                label,
                                style: TextStyle(
                                  color: isPrimary ? AppColors.primaryTeal : context.textPrimary,
                                  fontSize: 13,
                                  fontWeight: isPrimary ? FontWeight.bold : FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isPrimary) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryTeal,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  l10n.navYourRoute,
                                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (optFare != null && optFare > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00B277).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            '${fareAmount(optFare)} ${isAr ? "ج.م" : "EGP"}',
                            style: const TextStyle(color: Color(0xFF00B277), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        detail,
                        style: TextStyle(
                          color: hasLive ? const Color(0xFF1E9E5A) : context.textSecondary,
                          fontSize: 12,
                          fontWeight: hasLive ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      if (!isPrimary) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.touch_app_outlined, size: 14, color: context.textSecondary.withValues(alpha: 0.6)),
                      ],
                    ],
                  ),
                  // A line boarding a short walk from the leg's own stop.
                  if (walkNote != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        walkNote,
                        style: TextStyle(color: context.textSecondary, fontSize: 11.5),
                      ),
                    ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
