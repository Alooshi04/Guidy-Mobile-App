import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' show TemplateType;
import 'MapScreen.dart';
import '../l10n/app_localizations.dart';
import '../services/instruction_formatter.dart';
import '../services/metro_ticket_advisor.dart';
import '../services/transit_modes.dart';
import '../services/trip_sharing.dart';
import '../services/trip_sharing_service.dart';
import '../widgets/native_ad_card.dart';
import '../widgets/quick_commute_report_sheet.dart';
import '../theme/app_theme.dart';
import '../theme/guidy_ui.dart';
import '../utils/deep_copy.dart';
import '../utils/minutes_text.dart';

class TripRecapScreen extends StatefulWidget {
  final Map<String, dynamic> option;
  final Map<String, dynamic> pathData;
  final String startName;
  final String endName;

  const TripRecapScreen({
    super.key,
    required this.option,
    required this.pathData,
    required this.startName,
    required this.endName,
  });

  @override
  State<TripRecapScreen> createState() => _TripRecapScreenState();
}

class _TripRecapScreenState extends State<TripRecapScreen> {

  IconData _stepIcon(String iconKey) => TransitModes.icon(iconKey);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final isDark = context.isDark;
    final option = widget.option;
    final pathData = widget.pathData;
    final startName = widget.startName;
    final endName = widget.endName;
    final List<dynamic> instructions = option['instructions'] ?? [];
    final int? fareTotalEgp = option['fare_total_egp'] is int ? option['fare_total_egp'] : null;
    final bool hasFareBreakdown = instructions.any((i) => i['fare_egp'] != null);
    final bool hasMetro = instructions.any((i) => i['vehicle_type'] == 'metro');
    final bool isClosed = option['is_operating'] == false ||
        (option['closed_lines'] is List && (option['closed_lines'] as List).isNotEmpty);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: SafeArea(
          bottom: false,
          child: GuidyHeader(
            title: l10n.tripRecapTitle,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.ios_share_rounded),
                  color: AppColors.brandBlue,
                  tooltip: l10n.shareTripTooltip,
                  onPressed: () {
                    TripSharingService.shareTrip(
                      context: context,
                      destinationName: widget.endName,
                      transitMode: widget.option['vehicle_type'],
                      durationMinutes: '${widget.option['time']}',
                      lang: isAr ? 'ar' : 'en',
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.campaign_outlined),
                  color: AppColors.brandBlue,
                  tooltip: l10n.quickReportTitle,
                  onPressed: () => _openReport(context),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              children: [
                // --- Header: route + summary stats ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.brandNavy, Color(0xFF1C75B0), AppColors.brandBlue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(GuidyUi.radius),
                    boxShadow: GuidyUi.cardShadow(context),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Origin & Destination chain
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: AppColors.brandBlue,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.white54, spreadRadius: 1.5)],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              startName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 4, top: 3, bottom: 3),
                        child: Container(
                          width: 2,
                          height: 14,
                          color: Colors.white38,
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(Icons.place_rounded, size: 15, color: AppColors.brandBlue),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              endName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(GuidyUi.radius),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _headerStat(
                              Icons.access_time_rounded,
                              l10n.minutes(InstructionFormatter.asNum(option['time'])),
                              l10n.statDuration,
                            ),
                            Container(width: 1, height: 28, color: Colors.white24),
                            _headerStat(
                              Icons.payments_outlined,
                              InstructionFormatter.fareText(l10n, option),
                              l10n.statFare,
                            ),
                            if (option['distance_m'] != null) ...[
                              Container(width: 1, height: 28, color: Colors.white24),
                              _headerStat(
                                Icons.straighten_rounded,
                                l10n.distanceKm((option['distance_m'] / 1000).toStringAsFixed(1)),
                                l10n.statDistance,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                if (isClosed) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF381212) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFFEF5350) : const Color(0xFFDC2626),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isDark ? const Color(0xFFEF5350) : const Color(0xFFDC2626)).withValues(alpha: isDark ? 0.2 : 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFFEF5350).withValues(alpha: 0.25) : const Color(0xFFDC2626).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.schedule_rounded, color: isDark ? const Color(0xFFEF5350) : const Color(0xFFDC2626), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAr ? 'مواعيد المواصلات' : 'Service Schedule Notice',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xFFEF5350) : const Color(0xFFDC2626),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                isAr 
                                  ? (option['operating_alert_ar'] ?? option['operating_alert'] ?? 'المسار ده فيه مواصلات مش شغالة دلوقتي لحد الصبح.')
                                  : (option['operating_alert_en'] ?? option['operating_alert'] ?? 'This route includes transit lines currently out of service until morning.'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFFFFCDD2) : const Color(0xFF991B1B),
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                if (hasMetro) ...[
                  Builder(builder: (ctx) {
                    final metroStops = (option['metro_stops'] as int?) ?? 6;
                    final advice = MetroTicketAdvisor.calculate(stationCount: metroStops > 0 ? metroStops + 1 : 6);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: advice.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: advice.color.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: advice.color, shape: BoxShape.circle),
                            child: const Icon(Icons.confirmation_number_outlined, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.metroTicketTitle,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: context.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  advice.adviceText(Localizations.localeOf(context).languageCode),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: context.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                GuidySectionLabel(l10n.tripStepsLabel, padding: const EdgeInsets.fromLTRB(2, 0, 2, 14)),

                // --- Connected vertical transit timeline ---
                ...instructions.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final step = entry.value as Map<String, dynamic>;
                  final prevStep = idx > 0 ? (instructions[idx - 1] as Map<String, dynamic>) : null;
                  final nextStep = idx < instructions.length - 1 ? (instructions[idx + 1] as Map<String, dynamic>) : null;

                  return _buildTimelineStep(
                    context: context,
                    l10n: l10n,
                    isAr: isAr,
                    index: idx,
                    totalSteps: instructions.length,
                    step: step,
                    nextStep: nextStep,
                    prevStep: prevStep,
                  );
                }),

                if (hasFareBreakdown) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.fieldFill,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(l10n.fareTotalLabel, style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary)),
                        Text(
                          fareTotalEgp != null ? l10n.fareEgp('$fareTotalEgp') : InstructionFormatter.fareText(l10n, option),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryTeal, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(l10n.fareEstimateNote, style: TextStyle(color: context.textSecondary, fontSize: 11), textAlign: TextAlign.center),
                const SizedBox(height: 12),

                // The feed is stitched from open data of uneven quality and
                // none of it is verified against what runs today. Riders are
                // the only people who know when a leg is wrong, so the way to
                // say so sits under the trip they are doubting rather than
                // buried in Settings.
                Center(
                  child: TextButton.icon(
                    onPressed: () => _openReport(context),
                    icon: Icon(Icons.flag_outlined, size: 16, color: context.textSecondary),
                    label: Text(
                      l10n.reportEntryPoint,
                      style: TextStyle(color: context.textSecondary, fontSize: 12.5),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Below the report link and well clear of the pinned Start
                // button (the card's own gap plus the list padding).
                const NativeAdCard(template: TemplateType.small),
              ],
            ),
          ),

          // --- Start navigation button ---
          SafeArea(
            top: false,
            bottom: true,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              decoration: BoxDecoration(
                color: context.surfaceCard,
                boxShadow: [
                  BoxShadow(
                    color: context.isDark ? Colors.black.withValues(alpha: 0.3) : AppColors.brandNavy.withValues(alpha: 0.10),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: GuidyGradientButton(
                icon: Icons.navigation_rounded,
                label: l10n.startNavigationButton,
                onPressed: () async {
                    await TripSharing.askIfNeeded(context);
                    if (!context.mounted) return;
                    // Its own copy: the trip must not change this recap.
                    final mapData = deepCopyMap(pathData);
                    mapData['option'] = widget.option;
                    if (widget.option['type'] != null) {
                      mapData['type'] = widget.option['type'];
                    }
                    mapData['start_name'] = widget.startName;
                    mapData['end_name'] = widget.endName;
                    mapData['profile'] = widget.option['type']?.toString();
                    // History is written by MapScreen only when the rider
                    // actually arrives. Pushed, so back from the trip
                    // returns to this recap.
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MapScreen(
                          pathData: mapData,
                          startName: widget.startName,
                          endName: widget.endName,
                          recordHistoryOnArrival: true,
                        ),
                      ),
                    );
                  },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openReport(BuildContext context) {
    QuickCommuteReportSheet.show(
      context,
      routeData: widget.pathData,
      steps: widget.option['instructions'] as List<dynamic>?,
    );
  }

  // Same idea as MapScreen's live boarding-options row, but shown ahead
  // of time (before the rider taps "start navigation") so it's clear
  // from the trip preview that this leg isn't a single fixed bus --
  // several routes cover the same corridor and any of them work. No
  // live GPS state to show yet at this point (the rider hasn't started
  // riding), so this is just the list of substitutable routes; a real
  // ETA only appears once they're on the live-tracked MapScreen.
  Widget _buildBoardingOptions(BuildContext context, Map<String, dynamic> step) {
    final l10n = AppLocalizations.of(context);
    final List options = step['boarding_options'] ?? [];
    if (options.length < 2) return const SizedBox.shrink();

    final labels = options.where((o) => o['is_primary'] != true).map((o) {
      // vehicle_type arrives as a raw backend token ('bus', 'microbus'),
      // not a display word -- printing it straight was how "Microbus 302"
      // stayed English on an Arabic screen.
      final base = InstructionFormatter.optionSummary(l10n, Map<String, dynamic>.from(o));
      // No live ETA to show before the trip even starts, but the
      // schedule-derived typical headway (see raptor_engine.py's
      // route_typical_headway_min) is still a useful "how often does
      // this actually run" hint at this stage.
      final headway = o['typical_headway_min'];
      if (base.isEmpty) return '';
      if (headway != null) {
        final h = InstructionFormatter.asNum(headway)?.round() ?? 0;
        return h > 0 ? l10n.routeEveryMinutes(base, l10n.minutes(h)) : base;
      }
      return base;
    }).where((s) => s.isNotEmpty).toList();

    if (labels.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.swap_horiz_rounded, size: 14, color: context.textSecondary),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              l10n.alsoWorksLabel(labels.join(l10n.listSeparator)),
              style: TextStyle(color: context.textSecondary, fontSize: 11.5, fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _buildTimelineStep({
    required BuildContext context,
    required AppLocalizations l10n,
    required bool isAr,
    required int index,
    required int totalSteps,
    required Map<String, dynamic> step,
    required Map<String, dynamic>? nextStep,
    required Map<String, dynamic>? prevStep,
  }) {
    final isFirst = index == 0;
    final isLast = index == totalSteps - 1;
    final action = (step['action'] ?? '').toString();
    final iconKey = InstructionFormatter.iconKey(step);
    final color = GuidyModeStyle.forStep(step, dark: context.isDark);
    final isWalk = action.contains('walk');
    final isArrive = action == 'arrive';
    final fare = step['fare_egp'];
    final station = InstructionFormatter.localized(
        step, 'station', isAr: Localizations.localeOf(context).languageCode == 'ar');
    final waitMin = step['wait_min'];
    final opensAt = ((isAr ? step['opens_at_ar'] ?? step['opens_at'] : step['opens_at']) ?? '').toString().trim();
    final dist = InstructionFormatter.asNum(step['distance_m'])?.round();
    final isDark = context.isDark;

    // Top connector line
    Color topColor = Colors.grey.withValues(alpha: isDark ? 0.35 : 0.4);
    bool topDashed = true;
    if (prevStep != null) {
      final prevAction = (prevStep['action'] ?? '').toString();
      if (!prevAction.contains('walk') && prevAction != 'arrive') {
        topColor = GuidyModeStyle.forStep(prevStep, dark: isDark);
        topDashed = false;
      }
    }

    // Bottom connector line
    Color bottomColor = Colors.grey.withValues(alpha: isDark ? 0.35 : 0.4);
    bool bottomDashed = true;
    if (!isWalk && !isArrive) {
      bottomColor = color;
      bottomDashed = false;
    }

    // Node widget
    Widget nodeWidget;
    if (isFirst && isWalk) {
      nodeWidget = Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.primaryTeal.withValues(alpha: isDark ? 0.2 : 0.12),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primaryTeal, width: 2.5),
        ),
        child: Center(
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.primaryTeal,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    } else if (isArrive || isLast) {
      nodeWidget = Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFFE63946).withValues(alpha: isDark ? 0.25 : 0.12),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE63946), width: 2.5),
        ),
        child: const Center(
          child: Icon(Icons.place_rounded, size: 16, color: Color(0xFFE63946)),
        ),
      );
    } else if (!isWalk) {
      nodeWidget = Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Icon(_stepIcon(iconKey), size: 18, color: Colors.white),
        ),
      );
    } else {
      nodeWidget = Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: context.surfaceCard,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.grey.withValues(alpha: isDark ? 0.5 : 0.4),
            width: 2,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.directions_walk_rounded,
            size: 13,
            color: context.textSecondary,
          ),
        ),
      );
    }

    final title = InstructionFormatter.title(l10n, step);
    final subtitle = InstructionFormatter.subtitle(l10n, step);

    final card = Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: context.surfaceCard,
        borderRadius: BorderRadius.circular(GuidyUi.radius),
        boxShadow: GuidyUi.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: GuidyUi.heading(context),
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: isWalk ? context.textSecondary : color,
                          fontSize: 12.5,
                          fontWeight: isWalk ? FontWeight.normal : FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (fare != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: GuidyUi.green.withValues(alpha: isDark ? 0.22 : 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    l10n.fareEgp('$fare'),
                    style: TextStyle(
                      color: GuidyUi.greenText(context),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ] else if (isWalk && dist != null && dist > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: GuidyUi.chipFill(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.directions_walk_rounded, size: 11, color: context.textSecondary),
                      const SizedBox(width: 3),
                      Text(
                        l10n.walkMetersBadge(dist.toString()),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (station != null && station.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on_rounded, size: 15, color: AppColors.brandBlue),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    station,
                    style: TextStyle(
                      color: GuidyUi.heading(context),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (waitMin != null && (InstructionFormatter.asNum(waitMin) ?? 0) > 0) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.hourglass_empty_rounded, size: 12, color: context.textSecondary),
                const SizedBox(width: 4),
                Text(
                  l10n.stepWaitHint(l10n.minutes(waitMin)),
                  style: TextStyle(color: context.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ],
          _buildBoardingOptions(context, step),
          if (step['is_closed'] == true || step['is_operating'] == false) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF381212) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? const Color(0xFFEF5350) : const Color(0xFFDC2626),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule_rounded, size: 12, color: isDark ? const Color(0xFFEF5350) : const Color(0xFFDC2626)),
                  const SizedBox(width: 5),
                  Text(
                    opensAt.isEmpty ? l10n.lineClosedNow : l10n.lineClosedOpensAt(opensAt),
                    style: TextStyle(
                      color: isDark ? const Color(0xFFFFCDD2) : const Color(0xFF991B1B),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 38,
            child: Column(
              children: [
                if (!isFirst)
                  CustomPaint(
                    size: const Size(38, 12),
                    painter: _TimelineConnectorPainter(
                      color: topColor,
                      isDashed: topDashed,
                      strokeWidth: topDashed ? 2.2 : 3.5,
                    ),
                  )
                else
                  const SizedBox(height: 6),
                nodeWidget,
                if (!isLast)
                  Expanded(
                    child: CustomPaint(
                      size: const Size(38, double.infinity),
                      painter: _TimelineConnectorPainter(
                        color: bottomColor,
                        isDashed: bottomDashed,
                        strokeWidth: bottomDashed ? 2.2 : 3.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: card,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineConnectorPainter extends CustomPainter {
  final Color color;
  final bool isDashed;
  final double strokeWidth;

  _TimelineConnectorPainter({
    required this.color,
    this.isDashed = false,
    this.strokeWidth = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final x = size.width / 2;
    if (!isDashed) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      return;
    }

    const dashHeight = 4.0;
    const dashSpace = 4.0;
    double startY = 0.0;
    while (startY < size.height) {
      final endY = (startY + dashHeight).clamp(0.0, size.height);
      canvas.drawLine(Offset(x, startY), Offset(x, endY), paint);
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _TimelineConnectorPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.isDashed != isDashed ||
      oldDelegate.strokeWidth != strokeWidth;
}
