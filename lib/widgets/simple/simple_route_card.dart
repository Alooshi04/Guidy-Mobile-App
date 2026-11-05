import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/instruction_formatter.dart';
import '../../services/route_summary.dart';
import '../../services/transit_modes.dart';
import '../../theme/app_theme.dart';
import '../../theme/guidy_ui.dart';
import '../../utils/fare_text.dart';
import '../../utils/minutes_text.dart';
import '../../utils/ride_words.dart';
import '../route_options/route_card.dart' show RouteTag;
import 'simple_ui.dart';

/// One way to go, in plain words, with a single "Start this trip" button:
/// "Option 1, Easiest", "No changes", then each part ("Walk 5 min", "Ride
/// the minibus 45") and the total time and fare.
class SimpleRouteCard extends StatelessWidget {
  const SimpleRouteCard({
    super.key,
    required this.summary,
    required this.number,
    required this.easiest,
    required this.onStart,
    this.closedNote,
  });

  final RouteSummary summary;
  final int number;
  final bool easiest;
  final String? closedNote;
  final VoidCallback onStart;

  int get _changes => (summary.legs.where((l) => !l.isWalk).length - 1).clamp(0, 99);

  static String legText(AppLocalizations l10n, RouteLeg leg) {
    if (leg.isWalk) return l10n.simpleWalkFor(l10n.minutes(leg.walkMinutes));
    return RideWords.action(l10n, leg.step);
  }

  /// The trip's total time and fare, both big and bold: "116 min   20 EGP".
  Widget _timeAndFare(BuildContext context, AppLocalizations l10n, String money) {
    return Wrap(
      key: const ValueKey('simple-time-fare'),
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 18,
      runSpacing: 2,
      children: [
        Text(l10n.minutes(summary.minutes),
            key: const ValueKey('simple-total-time'),
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: context.textPrimary)),
        Text(money,
            key: const ValueKey('simple-total-fare'),
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: GuidyUi.greenText(context))),
      ],
    );
  }

  /// Fastest / Cheapest / Recommended, named and coloured as on the normal
  /// Route Options cards.
  Widget _tierChips(BuildContext context, AppLocalizations l10n) {
    return Wrap(
      key: const ValueKey('simple-tiers'),
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tier in summary.tiers)
          Builder(builder: (context) {
            final fg = RouteTag.colorFor(context, tier);
            return Container(
              key: ValueKey('simple-tier-$tier'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: fg.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: fg, width: 1.5),
              ),
              child: Text(InstructionFormatter.routeTierLabel(l10n, tier),
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: fg)),
            );
          }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fare = summary.fare;
    final money = fare == null || fare == 0 ? l10n.fareFree : l10n.fareEgp(fareAmount(fare));
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceCard,
        borderRadius: BorderRadius.circular(GuidyUi.radius),
        border: Border.all(color: context.isDark ? Colors.white54 : const Color(0xFF0B1B2B), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l10n.simpleOption(number),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.textPrimary)),
              ),
              if (easiest)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: SimpleUi.primaryFill(context), borderRadius: BorderRadius.circular(20)),
                  child: Text(l10n.simpleEasiest,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: SimpleUi.onPrimary(context))),
                ),
            ],
          ),
          if (summary.tiers.isNotEmpty) ...[
            const SizedBox(height: 10),
            _tierChips(context, l10n),
          ],
          const SizedBox(height: 8),
          Text(l10n.simpleChanges(_changes),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.textPrimary)),
          const SizedBox(height: 4),
          _timeAndFare(context, l10n, money),
          const SizedBox(height: 12),
          for (final leg in summary.legs)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(leg.isWalk ? Icons.directions_walk_rounded : TransitModes.icon(leg.vehicleType),
                      size: 28, color: context.textPrimary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(legText(l10n, leg),
                        style: TextStyle(fontSize: 19, color: context.textPrimary, height: 1.25)),
                  ),
                ],
              ),
            ),
          if (closedNote != null) ...[
            const SizedBox(height: 8),
            Text(closedNote!, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.errorRed)),
          ],
          const SizedBox(height: 14),
          SimpleButton(
            key: ValueKey('simple_start_$number'),
            icon: Icons.play_arrow_rounded,
            label: l10n.simpleStartTrip,
            primary: true,
            onPressed: onStart,
          ),
        ],
      ),
    );
  }
}
