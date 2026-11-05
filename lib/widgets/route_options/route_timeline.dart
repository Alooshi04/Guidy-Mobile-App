import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/instruction_formatter.dart';
import '../../services/route_summary.dart';
import '../../services/step_action.dart';
import '../../services/transit_modes.dart';
import '../../theme/app_theme.dart';
import '../../theme/guidy_ui.dart';
import '../trip/ask_driver.dart';
import '../../utils/fare_text.dart';
import '../../utils/minutes_text.dart';
import '../../utils/clock_text.dart';

/// A route top to bottom, Moovit style: a rail coloured by each ride,
/// dotted for walks. Each boarding point says what to do there (the live
/// trip pager's words, StepAction) and lists every line that works, the
/// ride folds into "Ride 30 stops | 49 min", and each ride's fare sits on
/// the right.
class RouteTimeline extends StatefulWidget {
  const RouteTimeline({
    super.key,
    required this.option,
    required this.startName,
    required this.endName,
    required this.pickedLine,
    required this.onPickLine,
    this.now,
  });

  /// The route with the rider's picked lines applied (RouteChoice.apply).
  final Map<String, dynamic> option;
  final String startName;
  final String endName;

  /// The boarding option in use for the ride at an instruction index.
  final int Function(int stepIndex) pickedLine;
  final void Function(int stepIndex, int optionIndex) onPickLine;
  final DateTime? now;

  @override
  State<RouteTimeline> createState() => _RouteTimelineState();
}

class _RouteTimelineState extends State<RouteTimeline> {
  final Set<int> _folds = {};

  bool get _isAr => Localizations.localeOf(context).languageCode == 'ar';

  String _clock(DateTime t) => clockText(context, TimeOfDay.fromDateTime(t));

  String _distance(AppLocalizations l10n, int m) =>
      m >= 1000 ? l10n.distanceKm((m / 1000).toStringAsFixed(1)) : l10n.plannerMeters('$m');

  /// Where a ride lets the rider off, and whether that is on the street
  /// (ask the driver to stop) rather than at a stop.
  (String, bool) _getOff(List steps, int stepIndex, Map<String, dynamic> ride) {
    final named = InstructionFormatter.localized(ride, 'alight_station', isAr: _isAr);
    for (var j = stepIndex + 1; j < steps.length; j++) {
      final s = steps[j];
      if (s is! Map) continue;
      final a = s['action'];
      if (a == 'walk_to_transfer' || a == 'transfer' || a == 'arrive') {
        final name = named ?? InstructionFormatter.localized(s, 'station', isAr: _isAr) ?? '';
        return (name, s['hail'] == true && a != 'walk_to_transfer');
      }
    }
    return (named ?? '', false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final summary = RouteSummary.of(l10n, widget.option);
    final steps = widget.option['instructions'] as List? ?? const [];
    final legs = summary.legs;
    final muted = GuidyUi.mutedText(context);
    final now = widget.now ?? DateTime.now();
    var t = now;
    Color rail(RouteLeg leg) => GuidyModeStyle.forRide(leg.step, dark: context.isDark);

    final rows = <Widget>[
      _node(
        dot: _Dot.ring(AppColors.brandBlue),
        below: legs.isEmpty || legs.first.isWalk ? _Rail.dots : _Rail.solid(rail(legs.first)),
        child: _place(widget.startName, _clock(now), l10n.routeLeave),
      ),
    ];

    for (var k = 0; k < legs.length; k++) {
      final leg = legs[k];
      if (leg.isWalk) {
        rows.add(_walk(l10n.routeWalkLeg(l10n.minutes(leg.walkMinutes), _distance(l10n, leg.meters)), muted));
        t = t.add(Duration(minutes: leg.walkMinutes));
        continue;
      }
      final color = rail(leg);
      final action = StepAction.of(l10n, steps, leg.stepIndex, destination: widget.endName);
      rows.add(_node(
        dot: _Dot.icon(color, TransitModes.icon(leg.vehicleType)),
        above: k > 0 && legs[k - 1].isWalk ? _Rail.dots : null,
        below: _Rail.solid(color),
        child: _ride(l10n, leg, action, color, muted, _getOff(steps, leg.stepIndex, leg.step).$1),
      ));
      t = t.add(Duration(minutes: (leg.waitMinutes + (leg.rideMinutes ?? 0)).round()));
      final (getOff, askDriver) = _getOff(steps, leg.stepIndex, leg.step);
      final next = k + 1 < legs.length ? legs[k + 1] : null;
      rows.add(_node(
        dot: _Dot.plain(color),
        above: _Rail.solid(color),
        below: next == null || next.isWalk ? _Rail.dots : _Rail.solid(rail(next)),
        child: _place(getOff, _clock(t), askDriver ? l10n.routeAskDriverStop : l10n.routeGetOff),
      ));
    }

    rows.add(_node(
      dot: _Dot.ring(const Color(0xFFE76F51)),
      child: _place(widget.endName, _clock(now.add(Duration(minutes: summary.minutes))), l10n.routeArrive),
    ));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }

  Widget _ride(AppLocalizations l10n, RouteLeg leg, StepAction action, Color color, Color muted, String getOff) {
    final i = leg.stepIndex;
    final picked = widget.pickedLine(i);
    final open = _folds.contains(i);
    final fold = [
      if (leg.stops != null && leg.stops! > 0) l10n.routeRideFold(l10n.stepStops(leg.stops!)),
      if (leg.rideMinutes != null) l10n.minutes(leg.rideMinutes),
    ].join('  |  ');
    // The stops between boarding and getting off, when the route names them.
    final stops = [
      for (final st in (leg.step['intermediate_stops'] as List? ?? const []))
        if (st is Map ? InstructionFormatter.localized(st, 'name', isAr: _isAr) != null : st != null)
          st is Map ? InstructionFormatter.localized(st, 'name', isAr: _isAr)! : '$st',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(action.header, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
              Text(action.title,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.textPrimary)),
            ]),
          ),
          if (leg.fare != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 8),
              child: Text(leg.fare == 0 ? l10n.fareFree : l10n.fareEgp(fareAmount(leg.fare!)),
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: GuidyUi.greenText(context))),
            ),
        ]),
        for (final n in action.notes) Text(n, style: TextStyle(fontSize: 12, color: muted)),
        const SizedBox(height: 8),
        if (action.askDriver != null) AskDriverText(action.askDriver!, color: color),
        Wrap(
          key: ValueKey('timeline-lines-$i'),
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var j = 0; j < action.lines.length; j++)
              _lineChip(l10n, action.lines[j], color, selected: j == picked, onTap: () => widget.onPickLine(i, j)),
          ],
        ),
        // The stars had no key, so riders couldn't tell what they meant
        // (QA 2026-10-22).
        if (action.lines.length > 1 && action.lines.any((l) => l.option['recommended'] == true))
          Padding(
            key: ValueKey('timeline-star-legend-$i'),
            padding: const EdgeInsets.only(top: 6),
            child: Row(children: [
              const Icon(Icons.star_rounded, size: 13, color: AppColors.primaryTeal),
              const SizedBox(width: 4),
              Flexible(child: Text(l10n.lineRecommendedLegend, style: TextStyle(fontSize: 11.5, color: muted))),
            ]),
          ),
        // No "every 12 min", "towards X" or "wait about 6 min" lines: the
        // beta reviewer found them unnecessary, space-taking and confusing.
        // The header, the lines, the fare and the ride fold say what to do.
        if (fold.isNotEmpty)
          stops.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(fold,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimary)),
                )
              : InkWell(
                  key: ValueKey('ride-fold-$i'),
                  onTap: () => setState(() => open ? _folds.remove(i) : _folds.add(i)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(children: [
                      Flexible(
                        child: Text(fold,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimary)),
                      ),
                      Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 20, color: muted),
                    ]),
                  ),
                ),
        if (open && stops.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _stopRow('ride-stop-first-$i', InstructionFormatter.localized(leg.step, 'station', isAr: _isAr) ?? '',
                  color, emphasised: true),
              for (var n = 0; n < stops.length; n++) _stopRow('ride-stop-$i-$n', stops[n], color),
              _stopRow('ride-stop-last-$i', getOff, color, emphasised: true),
            ]),
          ),
      ],
    );
  }

  Widget _stopRow(String key, String name, Color color, {bool emphasised = false}) => Padding(
        key: ValueKey(key),
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Container(
            width: emphasised ? 9 : 6,
            height: emphasised ? 9 : 6,
            decoration: BoxDecoration(color: emphasised ? color : color.withValues(alpha: 0.5), shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(name,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: emphasised ? FontWeight.w800 : FontWeight.w400,
                    color: context.textPrimary)),
          ),
        ]),
      );

  Widget _lineChip(AppLocalizations l10n, StepLine line, Color color,
      {required bool selected, required VoidCallback onTap}) {
    // A line as good as the planned one (whole leg, no extra walk, a
    // similar fare) is marked (owner, 2026-10-14).
    final recommended = line.option['recommended'] == true;
    final fg = selected ? Colors.white : context.textPrimary;
    return Semantics(
      label: 'line ${RouteSummary.lineLabel(l10n, line.option)}${recommended ? ' ${l10n.lineRecommended}' : ''}',
      button: true,
      selected: selected,
      excludeSemantics: true,
      child: Material(
        color: selected ? color : GuidyUi.chipFill(context),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (recommended) ...[
                  Icon(Icons.star_rounded, size: 14, color: selected ? Colors.white : AppColors.primaryTeal),
                  const SizedBox(width: 3),
                ],
                Flexible(
                  child: Text(line.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
                ),
              ]),
              if (line.note != null)
                Text(line.note!,
                    style: TextStyle(fontSize: 11, color: selected ? Colors.white70 : GuidyUi.mutedText(context))),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _place(String name, String time, String caption) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(name,
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: context.textPrimary)),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(time, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.textPrimary)),
            Text(caption, style: TextStyle(fontSize: 11, color: GuidyUi.mutedText(context))),
          ]),
        ],
      );

  Widget _walk(String text, Color muted) => IntrinsicHeight(
        child: Row(children: [
          SizedBox(width: _railWidth, child: Center(child: _Dots(color: muted))),
          Icon(Icons.directions_walk_rounded, size: 18, color: muted),
          const SizedBox(width: 6),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(text, style: TextStyle(fontSize: 13, color: muted)),
            ),
          ),
        ]),
      );

  static const double _railWidth = 40;

  /// A point on the rail and what happens there; [above] and [below] are
  /// the rail running into and out of it.
  Widget _node({required _Dot dot, required Widget child, _Rail? above, _Rail? below}) {
    final muted = GuidyUi.mutedText(context);
    Widget piece(_Rail? r) => r == null
        ? const SizedBox.shrink()
        : r.color == null
            ? _Dots(color: muted)
            : Container(width: 6, color: r.color);
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: _railWidth,
          child: Column(children: [
            SizedBox(height: 8, child: piece(above)),
            dot.build(context),
            Expanded(child: piece(below)),
          ]),
        ),
        const SizedBox(width: 8),
        Expanded(child: Padding(padding: const EdgeInsets.only(top: 6, bottom: 14), child: child)),
      ]),
    );
  }
}

/// A stretch of rail: a ride's colour, or dots (null) for a walk.
class _Rail {
  const _Rail._(this.color);
  const _Rail.solid(Color c) : this._(c);
  static const dots = _Rail._(null);
  final Color? color;
}

class _Dot {
  const _Dot._(this.color, {this.icon, this.ring = false});
  const _Dot.ring(Color c) : this._(c, ring: true);
  const _Dot.plain(Color c) : this._(c);
  const _Dot.icon(Color c, IconData i) : this._(c, icon: i);

  final Color color;
  final IconData? icon;
  final bool ring;

  Widget build(BuildContext context) {
    final size = icon != null ? 30.0 : 18.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: ring ? context.surfaceCard : color,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: ring ? 4 : 2),
      ),
      child: icon != null ? Icon(icon, size: 17, color: Colors.white) : null,
    );
  }
}

/// A dotted rail for a walk. Painted, so it can sit in an IntrinsicHeight.
class _Dots extends StatelessWidget {
  const _Dots({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _DotsPainter(color), child: const SizedBox(width: 6, height: double.infinity));
}

class _DotsPainter extends CustomPainter {
  _DotsPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    for (var y = 4.0; y < size.height - 2; y += 9) {
      canvas.drawCircle(Offset(size.width / 2, y), 2, p);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.color != color;
}
