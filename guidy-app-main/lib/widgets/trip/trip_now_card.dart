import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/instruction_formatter.dart';
import '../../services/ride_report_service.dart';
import '../../services/step_copy.dart';
import '../../services/transit_modes.dart';
import '../../theme/app_theme.dart';
import '../../theme/guidy_ui.dart';
import '../../utils/minutes_text.dart';

/// The top of the trip sheet: the step now with its fare (a ride) and one
/// live line of what is left of it, the "I took a vehicle" recording, and
/// why there is no position when there isn't one.
class TripNowCard extends StatelessWidget {
  static final ButtonStyle _stepNavStyle =
      TextButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    minimumSize: const Size(0, 34),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
  );

  const TripNowCard({
    super.key,
    required this.instructions,
    required this.step,
    required this.distanceToNextStop,
    required this.locationProblem,
    required this.rideReport,
    required this.offersRideReport,
    required this.onStartRideReport,
    required this.onStopRideReport,
    this.onReportWalk,
    this.walkReported = false,
    this.tourKey,
    this.onPrevious,
    this.onNext,
  });

  final List<dynamic> instructions;
  final int step;
  /// The live line for the step (nextStopLine): it takes the place of the
  /// step's planned distance ([StepCopy.countdown]). Empty: not yet.
  final ValueListenable<String> distanceToNextStop;
  final ValueListenable<String?> locationProblem;

  /// The ride being recorded, if any.
  final RideReport? rideReport;

  /// The step is a walk long enough to offer "I took a vehicle".
  final bool offersRideReport;
  final VoidCallback onStartRideReport;
  final VoidCallback onStopRideReport;

  /// "This walk is wrong"; null when the step is not a walk.
  final VoidCallback? onReportWalk;
  final bool walkReported;

  /// The first-trip tour points at the card.
  final Key? tourKey;

  /// Back to the step before / on to the next one by hand; null hides it.
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final iconKey = InstructionFormatter.iconKey(instructions[step] as Map<String, dynamic>);
    final color = GuidyModeStyle.forStep(instructions[step] as Map<String, dynamic>, dark: context.isDark);
    final copy = StepCopy.of(l10n, instructions, step);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 38,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 12),
            decoration: BoxDecoration(
              color: context.textSecondary.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
        Container(
          key: tourKey,
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: context.isDark
                  ? [AppColors.brandBlue.withValues(alpha: 0.22), AppColors.brandBlue.withValues(alpha: 0.08)]
                  : [const Color(0xFFDDF1FC), const Color(0xFFF4FAFF)],
              begin: AlignmentDirectional.centerStart,
              end: AlignmentDirectional.centerEnd,
            ),
            borderRadius: BorderRadius.circular(GuidyUi.radius),
            boxShadow: GuidyUi.cardShadow(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: color.withValues(alpha: context.isDark ? 0.3 : 0.16), shape: BoxShape.circle),
                    child: Icon(TransitModes.icon(iconKey), color: color, size: 24),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                          margin: const EdgeInsets.only(bottom: 3),
                          decoration: BoxDecoration(color: AppColors.brandBlue, borderRadius: BorderRadius.circular(8)),
                          child: Text(
                            l10n.navNowLabel,
                            style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                        // A ride's fare sits right next to its line ("Take
                        // minibus 66  10 EGP"), not as a trip total below.
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              child: Text(
                                copy.title,
                                style: const TextStyle(
                                  color: AppColors.brandBlue,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            if (copy.fare != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                copy.fare!,
                                key: const ValueKey('nav_step_fare'),
                                style: TextStyle(
                                  color: GuidyUi.greenText(context),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ],
                        ),
                        // One distance line, live: the planned one ("678 m,
                        // about 10 min") until the first fix, then what is left
                        // ("670 m left, about 9 min") in its place. The separate
                        // "left to X" row and the trip's time/distance/fare pills
                        // are gone: they repeated on every step and covered the
                        // map (beta feedback, 2026-11).
                        ValueListenableBuilder<String>(
                          valueListenable: distanceToNextStop,
                          builder: (context, live, _) {
                            final lines = List<String>.of(copy.lines);
                            final at = live.isEmpty ? null : (copy.countdown ?? lines.length);
                            if (at != null && at < lines.length) {
                              lines[at] = live;
                            } else if (at != null) {
                              lines.add(live);
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (var i = 0; i < lines.length; i++) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    lines[i],
                                    key: i == at ? const ValueKey('nav_live_line') : null,
                                    maxLines: i == at ? 2 : null,
                                    overflow: i == at ? TextOverflow.ellipsis : null,
                                    style: i == at
                                        ? TextStyle(color: context.textPrimary, fontSize: 13.5, height: 1.3, fontWeight: FontWeight.w600)
                                        : TextStyle(color: context.textSecondary, fontSize: 13.5, height: 1.3),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (rideReport != null)
                Padding(
                  padding: const EdgeInsets.only(top: 11),
                  child: Row(
                    children: [
                      const Icon(Icons.fiber_manual_record, size: 12, color: Colors.redAccent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          l10n.rideReportRecording(
                            rideReport!.distanceM >= 1000
                                ? l10n.distanceKm((rideReport!.distanceM / 1000).toStringAsFixed(1))
                                : '${rideReport!.distanceM.round()} ${isArabic ? 'متر' : 'm'}',
                            l10n.minutes(rideReport!.elapsed().inMinutes),
                          ),
                          style: TextStyle(color: context.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton(onPressed: onStopRideReport, child: Text(l10n.rideReportStop)),
                    ],
                  ),
                )
              else if (offersRideReport)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: onStartRideReport,
                    icon: const Icon(Icons.airport_shuttle_rounded, size: 18),
                    label: Text(l10n.rideReportButton),
                  ),
                ),
              if (onReportWalk != null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    key: const ValueKey('walk_report_button'),
                    onPressed: walkReported ? null : onReportWalk,
                    icon: Icon(walkReported ? Icons.check_rounded : Icons.report_gmailerrorred_rounded, size: 18),
                    label: Text(walkReported ? l10n.walkReportedLabel : l10n.walkReportButton),
                  ),
                ),
              if (onPrevious != null || onNext != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    key: const ValueKey('trip_step_nav'),
                    children: [
                      if (onPrevious != null)
                        Flexible(
                          child: TextButton.icon(
                            key: const ValueKey('trip_prev_step'),
                            onPressed: onPrevious,
                            icon: const Icon(Icons.arrow_back_rounded, size: 18),
                            style: _stepNavStyle,
                            label: FittedBox(fit: BoxFit.scaleDown, child: Text(l10n.navPrevStep, maxLines: 1)),
                          ),
                        ),
                      const Spacer(),
                      if (onNext != null)
                        Flexible(
                          child: TextButton.icon(
                            key: const ValueKey('trip_next_step'),
                            onPressed: onNext,
                            iconAlignment: IconAlignment.end,
                            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                            style: _stepNavStyle,
                            label: FittedBox(fit: BoxFit.scaleDown, child: Text(l10n.navNextStep, maxLines: 1)),
                          ),
                        ),
                    ],
                  ),
                ),
              ValueListenableBuilder<String?>(
                valueListenable: locationProblem,
                builder: (context, problem, _) {
                  if (problem == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 11),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 14, color: context.textSecondary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            problem,
                            style: TextStyle(color: context.textSecondary, fontSize: 12, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
