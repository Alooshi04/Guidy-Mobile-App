import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../screens/MapScreen.dart';
import '../../screens/trip/trip_plan.dart';
import '../../services/current_trip.dart';
import '../../services/instruction_formatter.dart';
import '../../services/step_copy.dart';
import '../../services/transit_modes.dart';
import '../../theme/app_theme.dart';
import '../../theme/guidy_ui.dart';
import '../../utils/minutes_text.dart';

/// Home's "trip in progress" card: shown while a trip has been started and
/// not finished, ended or timed out (see [CurrentTrip]). Tapping it reopens
/// the live trip screen on the step the rider was at.
class CurrentTripCard extends StatefulWidget {
  const CurrentTripCard({super.key});

  /// Space kept clear above and below, from the banner and the native ad.
  static const double gap = 24;

  /// Reopens the live trip on the step it was at (also from the trip's
  /// phone notification, which has no widget context).
  static void resume(NavigatorState nav, CurrentTripData t) {
    nav.push(
      MaterialPageRoute(
        builder: (_) => MapScreen(
          pathData: t.pathData,
          alternatives: t.alternatives,
          startName: t.startName,
          endName: t.endName,
          historyEntryId: t.historyEntryId,
          recordHistoryOnArrival: t.recordHistoryOnArrival,
          initialStep: t.step,
          startedAt: t.startedAt,
        ),
      ),
    );
  }

  @override
  State<CurrentTripCard> createState() => _CurrentTripCardState();
}

class _CurrentTripCardState extends State<CurrentTripCard> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CurrentTrip.ensureLoaded();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) CurrentTrip.expireIfStale();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CurrentTripData?>(
      valueListenable: CurrentTrip.active,
      builder: (context, t, _) {
        if (t == null || CurrentTrip.isStale(t)) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: CurrentTripCard.gap / 2),
          child: _body(context, t),
        );
      },
    );
  }

  Widget _body(BuildContext context, CurrentTripData t) {
    final l10n = AppLocalizations.of(context);
    final isAr = l10n.localeName.startsWith('ar');
    final plan = TripPlan.fromPathData(t.pathData, defaultColor: AppColors.brandBlue, dark: context.isDark);
    final steps = plan.instructions;
    final step = steps.isEmpty ? -1 : t.step.clamp(0, steps.length - 1);
    final stepMap = step < 0 || steps[step] is! Map ? null : Map<String, dynamic>.from(steps[step] as Map);

    final dest = (t.endName ?? t.pathData['end_name'])?.toString() ?? '';
    final title = dest.isEmpty ? l10n.currentTripLabel : l10n.currentTripTitle(dest);
    final stepText = step < 0 ? '' : StepCopy.of(l10n, steps, step).title;
    final iconKey = stepMap == null ? null : InstructionFormatter.iconKey(stepMap);
    final elapsed = CurrentTrip.now().difference(t.startedAt).inMinutes;
    final left = t.expectedMinutes - elapsed;
    final accent = AppColors.brandBlue;

    return GuidyCard(
      key: const ValueKey('current_trip_card'),
      onTap: () => CurrentTripCard.resume(Navigator.of(context), t),
      borderColor: accent.withValues(alpha: 0.55),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withValues(alpha: context.isDark ? 0.2 : 0.12)),
            child: Icon(TransitModes.icon(iconKey), color: accent, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        l10n.currentTripLabel,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (left > 0) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          l10n.currentTripLeft(l10n.minutes(math.max(1, left))),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: context.textSecondary, fontSize: 12),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: GuidyUi.heading(context)),
                ),
                if (stepText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      stepText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13.5, color: context.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
          Icon(isAr ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, color: accent),
        ],
      ),
    );
  }
}
