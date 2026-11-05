import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' show TemplateType;

import '../l10n/app_localizations.dart';
import '../services/route_choice.dart';
import '../services/route_summary.dart';
import '../theme/app_theme.dart';
import '../theme/guidy_ui.dart';
import '../utils/duration_text.dart';
import '../widgets/native_ad_card.dart';
import '../widgets/route_options/route_card.dart';
import '../widgets/route_options/route_timeline.dart';
import '../utils/clock_text.dart';

/// One route from Route Options, opened from its card: the time, the
/// modes, and a timeline of every step where the rider can pick the line
/// for each ride. The trip starts here.
class RouteDetailScreen extends StatefulWidget {
  const RouteDetailScreen({
    super.key,
    required this.option,
    required this.startName,
    required this.endName,
    required this.onStart,
    this.choices = const {},
    this.onChoicesChanged,
    this.closedNote,
  });

  /// The route as the server sent it (no lines picked).
  final Map<String, dynamic> option;
  final String startName;
  final String endName;

  /// Lines already picked for its rides.
  final LineChoices choices;

  /// Each pick, so the card behind shows the same route.
  final ValueChanged<LineChoices>? onChoicesChanged;
  final ValueChanged<LineChoices> onStart;
  final String? closedNote;

  @override
  State<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<RouteDetailScreen> {
  late final LineChoices _choices = {...widget.choices};

  void _pick(int stepIndex, int optionIndex) {
    HapticFeedback.selectionClick();
    setState(() => _choices[stepIndex] = optionIndex);
    widget.onChoicesChanged?.call({..._choices});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final option = RouteChoice.apply(widget.option, _choices);
    final summary = RouteSummary.of(l10n, option);
    final now = DateTime.now();
    String clock(DateTime t) => clockText(context, TimeOfDay.fromDateTime(t));
    final canStart = !(option['partial'] == true && summary.legs.isEmpty);
    return Scaffold(
      backgroundColor: context.surfaceCard,
      appBar: AppBar(
        title: Text(l10n.routeDetailsTitle),
        backgroundColor: context.surfaceCard,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              children: [
                Text.rich(
                  TextSpan(
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.textPrimary),
                    children: [
                      TextSpan(text: '${l10n.duration(summary.minutes)}  |  '),
                      TextSpan(
                        text: summary.fareText(l10n),
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: GuidyUi.greenText(context)),
                      ),
                      TextSpan(
                          text: '  |  ${clock(now)} – ${clock(now.add(Duration(minutes: summary.minutes)))}'),
                    ],
                  ),
                  key: const ValueKey('route-detail-header'),
                ),
                if (widget.closedNote != null) ...[
                  const SizedBox(height: 6),
                  Text(widget.closedNote!,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                ],
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: GuidyUi.mist.withValues(alpha: 0.7)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: RouteModeRow(summary: summary),
                  ),
                ),
                const SizedBox(height: 16),
                RouteTimeline(
                  option: option,
                  startName: widget.startName,
                  endName: widget.endName,
                  now: now,
                  pickedLine: (i) => RouteChoice.pickedIndex(widget.option, _choices, i),
                  onPickLine: _pick,
                ),
                Text(l10n.fareEstimateNote,
                    textAlign: TextAlign.center, style: TextStyle(color: context.textSecondary, fontSize: 11)),
                // After the whole itinerary, never between its steps; the
                // card's own gap keeps it off the Start button below.
                const NativeAdCard(template: TemplateType.small),
                // The Start bar is pinned outside this list, so on a short
                // itinerary it sits right under the card: the card's own 24
                // plus this 16 (and the bar's padding) keep well over 32 dp
                // between the ad and the button.
                const SizedBox(height: 16),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: GuidyGradientButton(
                height: 52,
                fontSize: 15,
                icon: Icons.navigation_rounded,
                label: l10n.plannerStart,
                onPressed: canStart ? () => widget.onStart({..._choices}) : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
