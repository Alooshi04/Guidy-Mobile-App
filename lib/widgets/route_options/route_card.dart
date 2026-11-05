import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/instruction_formatter.dart';
import '../../services/route_summary.dart';
import '../../services/transit_modes.dart';
import '../../theme/app_theme.dart';
import '../../theme/guidy_ui.dart';
import '../../utils/duration_text.dart';
import '../../utils/minutes_text.dart';
import '../../utils/clock_text.dart';

/// One route in the Route Options list, Moovit style: the total time and
/// leave/arrive times on the left; on the right the modes (walk 376 m ›
/// minibus 66 › walk 120 m › M3), wrapping onto a second line rather than
/// being cut, and at most one tag. Tapping it opens the route's detail
/// page.
///
/// There used to be a line of "every 12 min from X" under the modes. The
/// beta reviewer couldn't tell which ride it described and it cost the
/// space the line numbers now use (2026-11); the frequency is on the
/// detail page, by its ride.
class RouteCard extends StatelessWidget {
  const RouteCard({
    super.key,
    required this.summary,
    required this.onTap,
    this.selected = false,
    this.closedNote,
    this.now,
  });

  final RouteSummary summary;
  final VoidCallback onTap;
  final bool selected;

  /// Why the route can't be taken right now, if it can't.
  final String? closedNote;

  /// When the rider would leave; defaults to now.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final radius = BorderRadius.circular(GuidyUi.radius);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: radius, boxShadow: GuidyUi.cardShadow(context)),
        child: Material(
          color: context.surfaceCard,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  color: selected
                      ? AppColors.brandBlue
                      : closedNote != null
                          ? const Color(0xFFDC2626).withValues(alpha: 0.4)
                          : Colors.transparent,
                  width: selected ? 1.6 : 1,
                ),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 100,
                      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 8, 12),
                      color: AppColors.brandBlue.withValues(alpha: context.isDark ? 0.14 : 0.07),
                      alignment: AlignmentDirectional.centerStart,
                      child: RouteTimes(minutes: summary.minutes, now: now, fare: summary.fareText(l10n)),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            RouteModeRow(summary: summary),
                            if (summary.shortRide != null) ...[
                              const SizedBox(height: 8),
                              RouteTag(tier: 'ShortRide', label: summary.shortRide),
                            ] else if (summary.tag != null) ...[
                              const SizedBox(height: 8),
                              RouteTag(tier: summary.tag!),
                            ],
                            if (summary.longWalkMinutes case final int walkMin) ...[
                              const SizedBox(height: 6),
                              RouteTag(
                                key: const ValueKey('route-card-long-walk'),
                                tier: 'LongWalk',
                                label: l10n.routeLongWalk(l10n.minutes(walkMin)),
                              ),
                            ],
                            if (closedNote != null) ...[
                              const SizedBox(height: 6),
                              Text(closedNote!,
                                  style: const TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "44 min" (or "1 h" over "18 min") and the trip's fare, over the leave
/// and arrive times.
class RouteTimes extends StatelessWidget {
  const RouteTimes({super.key, required this.minutes, this.now, this.fare});

  final int minutes;

  /// The total fare ("22 EGP"), shown right under the minutes in the same
  /// weight; omitted when null.
  final String? fare;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final leave = now ?? DateTime.now();
    final arrive = leave.add(Duration(minutes: minutes));
    String clock(DateTime t) => clockText(context, TimeOfDay.fromDateTime(t));
    final lines = l10n.durationLines(minutes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // "41 دقيقة" on one line; over an hour the hours over the minutes
        // ("ساعة" / "و18 دقيقة"), which in one line would shrink to
        // nothing in this column. Each line shrinks to fit if it must.
        Semantics(
          key: const ValueKey('route-card-time'),
          label: l10n.duration(minutes),
          excludeSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var k = 0; k < lines.length; k++)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(lines[k],
                      maxLines: 1,
                      style: TextStyle(
                          fontSize: k == 0 ? 22 : 19,
                          height: lines.length > 1 ? 1.15 : null,
                          fontWeight: FontWeight.w800,
                          color: GuidyUi.heading(context))),
                ),
            ],
          ),
        ),
        if (fare != null)
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(fare!,
                key: const ValueKey('route-card-fare'),
                maxLines: 1,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: GuidyUi.greenText(context))),
          ),
        const SizedBox(height: 2),
        Text('${clock(leave)}\n${clock(arrive)}',
            style: TextStyle(fontSize: 11.5, height: 1.35, color: GuidyUi.mutedText(context))),
      ],
    );
  }
}

/// Walk 376 m › minibus 66 › walk 120 m › M3: every walk with its
/// distance and every ride with the line the route was planned with. A
/// long route wraps onto another line (in reading order, right to left in
/// Arabic) rather than being cut off.
class RouteModeRow extends StatelessWidget {
  const RouteModeRow({super.key, required this.summary});

  final RouteSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final muted = GuidyUi.mutedText(context);
    final items = <Widget>[];
    for (var k = 0; k < summary.legs.length; k++) {
      final leg = summary.legs[k];
      final chip = leg.isWalk ? RouteWalkChip(leg: leg) : RouteLineChip(leg: leg);
      // The chevron goes with the leg after it, so a line never ends on one.
      items.add(k == 0
          ? chip
          : Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.chevron_right_rounded, size: 16, color: muted),
              Flexible(child: chip),
            ]));
    }
    if (items.isEmpty) items.add(Icon(Icons.directions_walk_rounded, size: 24, color: muted));
    return Semantics(
      label: [
        for (final leg in summary.legs)
          leg.isWalk
              ? '${l10n.vehicleWalk} ${leg.walkText(l10n)}'
              : leg.vehicleType == 'metro'
                  ? '${TransitModes.label(l10n, leg.vehicleType)} ${leg.line}'
                  : leg.line,
      ].join(', '),
      child: ExcludeSemantics(
        child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 6, children: items),
      ),
    );
  }
}

/// A walk: the walking icon and how far ("376 m").
class RouteWalkChip extends StatelessWidget {
  const RouteWalkChip({super.key, required this.leg});

  final RouteLeg leg;

  @override
  Widget build(BuildContext context) {
    final muted = GuidyUi.mutedText(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.directions_walk_rounded, size: 21, color: muted),
        Text(leg.walkText(AppLocalizations.of(context)),
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: muted)),
      ]),
    );
  }
}

/// A ride's mode icon and its one line ("Minibus 66", "M3"), underlined in
/// the line's colour. A long name wraps inside the chip; it is never cut.
class RouteLineChip extends StatelessWidget {
  const RouteLineChip({super.key, required this.leg});

  final RouteLeg leg;

  @override
  Widget build(BuildContext context) {
    final color = GuidyModeStyle.forRide(leg.step, dark: context.isDark);
    final edge = BorderSide(color: GuidyUi.mist.withValues(alpha: 0.8));
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(6, 4, 8, 4),
      decoration: BoxDecoration(
        border: Border(top: edge, left: edge, right: edge, bottom: BorderSide(color: color, width: 3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(TransitModes.icon(leg.vehicleType), size: 22, color: color),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            leg.line,
            style: TextStyle(fontSize: 15, height: 1.2, fontWeight: FontWeight.w800, color: context.textPrimary),
          ),
        ),
      ]),
    );
  }
}

/// The one tag a route card shows: Recommended in green, the rest amber.
class RouteTag extends StatelessWidget {
  const RouteTag({super.key, required this.tier, this.label});

  final String tier;

  /// Overrides the tier's own name.
  final String? label;

  /// Recommended in green, the rest amber (Walk blue): shared with Simple Mode.
  static Color colorFor(BuildContext context, String tier) => switch (tier) {
        'Recommended' => GuidyUi.greenText(context),
        'Available now' => context.isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4338CA),
        'Walk' => AppColors.brandBlue,
        _ => context.accentAmber,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final Color fg = colorFor(context, tier);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: fg.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
      child: Text(label ?? InstructionFormatter.routeTierLabel(l10n, tier),
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}
