import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' show TemplateType;

import '../services/api_service.dart';
import '../l10n/app_localizations.dart';
import '../services/instruction_formatter.dart';
import '../services/map_marker_service.dart';
import '../services/transit_modes.dart';
import '../theme/app_theme.dart';
import '../theme/guidy_ui.dart';
import '../widgets/error_state.dart';
import '../widgets/line_report_sheet.dart';
import '../widgets/marquee_text.dart';
import '../widgets/native_ad_card.dart';
import '../utils/polyline_utils.dart';
import '../utils/minutes_text.dart';
import '../utils/route_line_style.dart';
import '../utils/clock_text.dart';

enum _LineViewMode { list, map }

/// One line, every stop, in order.
///
/// Most routes run two directions and the stop lists are not mirror
/// images of each other -- one-way streets and turning restrictions mean
/// the outbound and inbound sequences genuinely differ, so showing a
/// single reversed list would be wrong. Directions therefore get their
/// own tabs, each labelled by its terminus, which is what is written on
/// the vehicle's windscreen.
class LineDetailScreen extends StatefulWidget {
  final String routeId;
  final String fallbackTitle;

  const LineDetailScreen({super.key, required this.routeId, required this.fallbackTitle});

  static List<LatLng> extractCoords(Map<String, dynamic> direction) {
    final stopsRaw = List<Map<String, dynamic>>.from(direction['stops'] ?? const []);
    final stopCoords = stopsRaw
        .where((s) => s['lat'] != null && s['lon'] != null)
        .map((s) {
          final lat = InstructionFormatter.asNum(s['lat'])?.toDouble();
          final lon = InstructionFormatter.asNum(s['lon'])?.toDouble();
          return (lat != null && lon != null) ? LatLng(lat, lon) : null;
        })
        .whereType<LatLng>()
        .toList();

    final pointsEncoded = direction['points_encoded'];
    final pointsRaw = (direction['points'] as List?) ?? [];
    List<LatLng> coords = [];
    if (pointsEncoded is String && pointsEncoded.isNotEmpty) {
      final decoded = PolylineUtils.decode(pointsEncoded);
      coords = decoded.map((p) => LatLng(p['lat']!, p['lon']!)).toList();
    } else if (pointsRaw.isNotEmpty) {
      coords = pointsRaw
          .where((p) => p is Map && p['lat'] != null && p['lon'] != null)
          .map((p) {
            final lat = InstructionFormatter.asNum(p['lat'])?.toDouble();
            final lon = InstructionFormatter.asNum(p['lon'])?.toDouble();
            return (lat != null && lon != null) ? LatLng(lat, lon) : null;
          })
          .whereType<LatLng>()
          .toList();
    }

    // Fall back to sequential stops if polyline points are missing or too few
    if (coords.length < 2) {
      return stopCoords;
    }

    // Strict connectivity guarantee:
    // Ensure the polyline connects directly to the origin marker and destination marker
    if (stopCoords.isNotEmpty) {
      final firstStop = stopCoords.first;
      final lastStop = stopCoords.last;

      if (coords.first.latitude != firstStop.latitude ||
          coords.first.longitude != firstStop.longitude) {
        coords.insert(0, firstStop);
      }
      if (coords.last.latitude != lastStop.latitude ||
          coords.last.longitude != lastStop.longitude) {
        coords.add(lastStop);
      }
    }

    return coords;
  }

  @override
  State<LineDetailScreen> createState() => _LineDetailScreenState();
}

class _LineDetailScreenState extends State<LineDetailScreen> {
  final ApiService _api = ApiService();

  bool _loading = true;
  // A flag rather than a translated sentence -- see the same fix in
  // LinesScreen. Holding the localized string froze the error in the
  // language that happened to be active when the request failed.
  bool _failed = false;
  Map<String, dynamic>? _detail;
  int _directionIndex = 0;
  _LineViewMode _viewMode = _LineViewMode.list;
  GoogleMapController? _mapController;
  int? _selectedStopIndex;

  BitmapDescriptor? _originIcon;
  BitmapDescriptor? _destinationIcon;
  BitmapDescriptor? _stopDotIcon;
  BitmapDescriptor? _selectedStopDotIcon;
  Color? _cachedModeColor;
  bool _creatingIcons = false;

  Future<void> _initStopDotIcons(Color modeColor) async {
    if ((_cachedModeColor == modeColor && _stopDotIcon != null && _originIcon != null) || _creatingIcons) return;
    _creatingIcons = true;
    _cachedModeColor = modeColor;

    try {
      final origin = await MapMarkerService.getOriginMarker();
      final dest = await MapMarkerService.getDestinationMarker();
      final dot = await MapMarkerService.getStationStopMarker(color: modeColor, isSelected: false);
      final selectedDot = await MapMarkerService.getStationStopMarker(color: modeColor, isSelected: true);

      if (mounted) {
        setState(() {
          _originIcon = origin;
          _destinationIcon = dest;
          _stopDotIcon = dot;
          _selectedStopDotIcon = selectedDot;
          _creatingIcons = false;
        });
      }
    } catch (_) {
      _creatingIcons = false;
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  /// Language of the last load attempt. Stop names, ends and the
  /// description come from the backend already in one language, so a
  /// language switch (the header toggle) has to fetch the line again.
  String _loadedLang = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang = Localizations.localeOf(context).languageCode == 'ar' ? 'ar' : 'en';
    if (_loadedLang.isNotEmpty && _loadedLang != lang) _load(keepDirection: true);
  }

  Future<void> _load({bool keepDirection = false}) async {
    if (!mounted) return;
    final lang = Localizations.localeOf(context).languageCode == 'ar' ? 'ar' : 'en';
    _loadedLang = lang;
    setState(() {
      _loading = true;
      _failed = false;
      // The spinner replaces the map, and that map takes its controller
      // with it; the map built after the load hands over a new one.
      _mapController = null;
    });
    try {
      final detail = await _api.fetchRouteDetail(widget.routeId, lang: lang);
      // A newer load (another language switch) has started meanwhile.
      if (!mounted || lang != _loadedLang) return;
      setState(() {
        _detail = detail;
        if (!keepDirection) _directionIndex = 0;
        _selectedStopIndex = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || lang != _loadedLang) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _openReport(Map<String, dynamic> detail, Map<String, dynamic> direction) {
    final stops = List<Map<String, dynamic>>.from(direction['stops'] ?? const []);
    Map<String, dynamic>? selectedStop;
    if (_selectedStopIndex != null &&
        _selectedStopIndex! >= 0 &&
        _selectedStopIndex! < stops.length) {
      selectedStop = stops[_selectedStopIndex!];
    }
    LineReportSheet.show(
      context,
      routeId: widget.routeId,
      routeNumber: detail['number']?.toString(),
      routeDescription: detail['description']?.toString(),
      vehicleType: detail['vehicle_type']?.toString(),
      directionIndex: _directionIndex,
      directionTerminus: direction['towards']?.toString(),
      stops: stops,
      selectedStop: selectedStop,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final detail = _detail;

    final title = detail != null &&
            InstructionFormatter.cleanRouteNumber(detail['number']?.toString()) != null
        ? InstructionFormatter.lineLabel(l10n, {...detail, 'route_number': detail['number']})
        : widget.fallbackTitle;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: SafeArea(
          bottom: false,
          child: GuidyHeader(
            title: title,
            titleColor: detail == null ? null : _lineColor(detail),
            trailing: detail == null
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.flag_outlined, size: 20),
                        color: AppColors.brandBlue,
                        tooltip: l10n.reportAnIssueWithThisLine,
                        onPressed: () {
                          final directions = List<Map<String, dynamic>>.from(detail['directions'] ?? const []);
                          final dir = directions.isNotEmpty
                              ? directions[_directionIndex.clamp(0, directions.length - 1)]
                              : <String, dynamic>{};
                          _openReport(detail, dir);
                        },
                      ),
                      IconButton(
                        icon: Icon(_viewMode == _LineViewMode.map ? Icons.format_list_bulleted_rounded : Icons.map_rounded),
                        color: AppColors.brandBlue,
                        tooltip: _viewMode == _LineViewMode.map ? l10n.linesViewList : l10n.linesViewMap,
                        onPressed: () {
                          setState(() {
                            _viewMode = _viewMode == _LineViewMode.map ? _LineViewMode.list : _LineViewMode.map;
                            // Either the map is leaving with this controller,
                            // or a new map is coming that hands over its own
                            // in onMapCreated and frames the route there. The
                            // one held now belongs to a map that is gone.
                            _mapController = null;
                          });
                        },
                      ),
                    ],
                  ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed
              ? ErrorState(message: l10n.linesLoadFailed, onRetry: _load)
              : _buildDetail(l10n, detail!),
    );
  }

  Widget _buildDetail(AppLocalizations l10n, Map<String, dynamic> detail) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final directions = List<Map<String, dynamic>>.from(detail['directions'] ?? const []);
    if (directions.isEmpty) {
      return ErrorState(message: l10n.linesLoadFailed, onRetry: _load);
    }
    final index = _directionIndex.clamp(0, directions.length - 1);
    final direction = directions[index];
    final stops = List<Map<String, dynamic>>.from(direction['stops'] ?? const []);
    final isMetro = TransitModes.isRail(detail['vehicle_type'] as String?);
    final modeColor = _lineColor(detail);

    return Column(
      children: [
        _header(l10n, detail, direction, isMetro),
        if (directions.length > 1)
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              itemCount: directions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => GuidyPill(
                label: _towardsLabel(l10n, directions, i, isArabic),
                icon: Icons.arrow_forward_rounded,
                selected: i == index,
                onTap: () {
                  setState(() {
                    _directionIndex = i;
                    _selectedStopIndex = null;
                  });
                  if (_viewMode == _LineViewMode.map) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _fitRouteBounds(_extractCoords(directions[i]));
                    });
                  }
                },
              ),
            ),
          ),
        Expanded(
          child: _viewMode == _LineViewMode.list
              ? _stopList(l10n, stops, isArabic, modeColor)
              : _mapView(l10n, detail, direction, stops, isArabic, modeColor),
        ),
      ],
    );
  }

  String _cleanStationName(String raw, bool isArabic) {
    var s = raw.trim();
    if (isArabic &&
        (s == 'Moushir Tantawi' ||
            s.contains('Moushir Tantawi') ||
            s.contains('Mosheer Tantawy'))) {
      s = s
          .replaceAll('Moushir Tantawi', 'المشير طنطاوي')
          .replaceAll('Mosheer Tantawy', 'المشير طنطاوي');
    }
    return s;
  }

  String _cleanTerminus(String raw, bool isArabic) {
    var s = _cleanStationName(raw, isArabic);
    s = s
        .replaceAll('محطة مونوريل ', '')
        .replaceAll('محطة ', '')
        .replaceAll(' Monorail Station', '')
        .replaceAll(' Station', '')
        .trim();
    return s;
  }

  String _towardsLabel(
      AppLocalizations l10n, List<Map<String, dynamic>> all, int i, bool isArabic) {
    final direction = all[i];
    final rawTowards = direction['towards']?.toString() ?? '';
    if (rawTowards.isEmpty) return '${i + 1}';

    final towards = _cleanTerminus(rawTowards, isArabic);
    final shared = all.where((d) => d['towards'] == rawTowards).length > 1;
    final rawFrom = direction['from']?.toString() ?? '';
    final from = _cleanTerminus(rawFrom, isArabic);

    if (shared && from.isNotEmpty) {
      return l10n.linesDirectionTowardsFrom(towards, from);
    }
    return l10n.linesDirectionTowards(towards);
  }

  /// The line's colour in the design: each metro line has its own, every
  /// other mode uses its mode colour.
  Color _lineColor(Map<String, dynamic> detail) {
    return GuidyModeStyle.forRide(detail, dark: context.isDark);
  }

  /// "06:00" -> "6:00 AM" / "6:00 ص", in the app language's own format.
  String _clock(String hhmm) {
    final parts = hhmm.trim().split(':');
    final h = int.tryParse(parts.first);
    final m = parts.length < 2 ? null : int.tryParse(parts[1].padLeft(2, '0').substring(0, 2));
    if (h == null || m == null) return hhmm.trim();
    return clockText(context, TimeOfDay(hour: h % 24, minute: m));
  }

  /// The fare's headline ("10 to 20 EGP") and its breakdown by stage or
  /// kind of bus (the part in brackets), which may be empty.
  static ({String headline, String breakdown}) _fareParts(String full) {
    final open = full.indexOf(' (');
    if (open < 0 || !full.endsWith(')')) return (headline: full, breakdown: '');
    return (headline: full.substring(0, open), breakdown: full.substring(open + 2, full.length - 1));
  }

  Widget _header(AppLocalizations l10n, Map<String, dynamic> detail,
      Map<String, dynamic> direction, bool isMetro) {
    final mode = detail['vehicle_type'] as String?;
    final color = _lineColor(detail);
    final number = GuidyModeStyle.badgeNumber(InstructionFormatter.cleanRouteNumber(detail['number']?.toString()));
    final metroNumber = mode == 'metro' ? GuidyModeStyle.metroLineNumber(detail) : null;
    final icon = GuidyModeStyle.icon(mode);
    final headway = direction['typical_headway_min'];
    final serviceHours = (detail['service_hours'] as String?)?.trim();
    final isOperating = detail['is_operating'] as bool?;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final from = _cleanTerminus((direction['from'] ?? '').toString(), isArabic);
    final towards = _cleanTerminus((direction['towards'] ?? '').toString(), isArabic);
    final description = (detail['description'] ?? '').toString().trim();
    final muted = GuidyUi.mutedText(context);
    final hours = serviceHours == null ? const <String>[] : serviceHours.split(RegExp(r'\s*[-–]\s*'));
    final fare = _fareParts(_detailedFareText(detail, isArabic, l10n));
    final operator = InstructionFormatter.brandOf({...detail, 'route_number': detail['number']}) != TransitBrand.none
        ? InstructionFormatter.vehicleLabelFor(l10n, {...detail, 'route_number': detail['number']})
        : '';
    final hasEnds = from.isNotEmpty && towards.isNotEmpty;
    final tileLabel = [
      InstructionFormatter.vehicleTypeLabel(l10n, mode),
      if (metroNumber != null) 'M$metroNumber' else if (number.isNotEmpty) number,
    ].join(' ');

    Widget infoCard(IconData ic, String label, String value) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            decoration: BoxDecoration(color: GuidyUi.chipFill(context), borderRadius: BorderRadius.circular(GuidyUi.radius)),
            child: Column(
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(ic, size: 13, color: muted),
                  const SizedBox(width: 3),
                  Flexible(child: MarqueeText(label, style: TextStyle(fontSize: 11.5, color: muted))),
                ]),
                const SizedBox(height: 6),
                MarqueeText(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: GuidyUi.heading(context))),
              ],
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // The line's tile: "M3" for metro lines, otherwise the mode
              // icon with the line number under it.
              Semantics(
                label: tileLabel,
                excludeSemantics: true,
                child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: context.surfaceCard,
                  borderRadius: BorderRadius.circular(GuidyUi.radius),
                  border: Border.all(color: color),
                  boxShadow: GuidyUi.cardShadow(context),
                ),
                alignment: Alignment.center,
                child: metroNumber != null
                    ? Text('M$metroNumber', style: GuidyUi.display(context, size: 32, color: color, weight: FontWeight.w700))
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (icon != null)
                            GuidySvgIcon(icon, size: number.isEmpty ? 48 : 40, color: color)
                          else
                            Icon(TransitModes.icon(mode), size: 40, color: color),
                          if (number.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            MarqueeText(number,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic, color: color)),
                          ],
                        ],
                      ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasEnds) ...[
                      MarqueeText(from.toUpperCase(), style: TextStyle(fontSize: 13, color: GuidyUi.heading(context))),
                      Row(children: [
                        Icon(Icons.arrow_forward_rounded, size: 13, color: color),
                        const SizedBox(width: 4),
                        Expanded(child: MarqueeText(towards, style: TextStyle(fontSize: 13, color: GuidyUi.heading(context)))),
                      ]),
                      // The description names the variant ("via X") and
                      // the corridor, which the ends alone don't.
                      if (description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: MarqueeText(description, style: TextStyle(fontSize: 12, color: muted, height: 1.3)),
                        ),
                    ] else if (description.isNotEmpty)
                      Text(description, style: TextStyle(fontSize: 13.5, color: GuidyUi.heading(context), height: 1.3)),
                    if (operator.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(operator, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
                      ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        _fact(context, Icons.commit_rounded, l10n.linesStopCount((direction['stops'] as List?)?.length ?? 0)),
                        if (headway != null)
                          _fact(context, Icons.schedule_rounded, l10n.linesEveryMinutes(l10n.minutes(InstructionFormatter.asNum(headway)))),
                        if (isOperating != null)
                          _fact(
                            context,
                            isOperating ? Icons.check_circle_outline_rounded : Icons.nightlight_round,
                            isOperating ? l10n.lineOpenNow : l10n.lineClosedNow,
                            color: isOperating ? GuidyUi.greenText(context) : AppColors.errorRed,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: context.isDark ? Colors.white10 : GuidyUi.mist.withValues(alpha: 0.5)),
          const SizedBox(height: 14),
          // Start | End | Fare, as in the design.
          Row(
            children: [
              if (hours.length == 2) ...[
                infoCard(Icons.schedule_rounded, l10n.lineFirstTrip, _clock(hours[0])),
                const SizedBox(width: 10),
                infoCard(Icons.schedule_rounded, l10n.lineLastTrip, _clock(hours[1])),
                const SizedBox(width: 10),
              ] else if (serviceHours != null && serviceHours.isNotEmpty) ...[
                infoCard(Icons.schedule_rounded, l10n.lineServiceHours, serviceHours),
                const SizedBox(width: 10),
              ],
              infoCard(Icons.paid_outlined, l10n.statFare, fare.headline),
            ],
          ),
          // The fare by stage (metro, LRT, monorail, BRT) or by kind of bus.
          if (fare.breakdown.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: muted),
                const SizedBox(width: 5),
                Expanded(child: Text(fare.breakdown, style: TextStyle(fontSize: 12, color: muted, height: 1.35))),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _detailedFareText(
      Map<String, dynamic> detail, bool isArabic, AppLocalizations l10n) {
    final mode = (detail['vehicle_type'] as String? ?? 'bus').toLowerCase();
    final fare = detail['fare_egp'];

    if (mode == 'metro' || mode.contains('subway')) {
      return isArabic
          ? '10 لـ 20 ج.م (1-9 محطات: 10 ج • 10-16: 12 ج • 17-23: 15 ج • 24+: 20 ج)'
          : '10 to 20 EGP (1-9 stops: 10 • 10-16: 12 • 17-23: 15 • 24+: 20)';
    } else if (mode == 'lrt') {
      return isArabic
          ? '10 لـ 20 ج.م (1-3 محطات: 10 ج • 4-7: 15 ج • 8+: 20 ج)'
          : '10 to 20 EGP (1-3 stops: 10 • 4-7: 15 • 8+: 20)';
    } else if (mode == 'monorail') {
      return isArabic
          ? '20 لـ 80 ج.م (لحد 5 محطات: 20 ج • 10: 40 ج • 15: 55 ج • الخط كله: 80 ج)'
          : '20 to 80 EGP (up to 5 stops: 20 • 10: 40 • 15: 55 • full line: 80)';
    } else if (mode == 'minibus') {
      final n = fare != null ? _formatNumber(fare) : '20';
      return isArabic
          ? '$n ج.م (تذكرة موحدة للميني باص)'
          : '$n EGP (Standard flat minibus fare)';
    } else if (mode == 'brt') {
      // Ring Road BRT: 5 / 10 / 15 EGP for up to 4 / 9 / 14 stations.
      return isArabic
          ? '5 لـ 15 ج.م (لحد 4 محطات: 5 ج • 9: 10 ج • 14: 15 ج)'
          : '5 to 15 EGP (up to 4 stops: 5 • 9: 10 • 14: 15)';
    } else if (mode == 'microbus') {
      // Lines with a published fare (Alexandria, Cairo-Alexandria) report
      // it as fare_egp; a Cairo microbus is priced by distance.
      // An Alexandria microbus charges by distance up to its line fare:
      // fare_from_egp is the shortest ride.
      final own = InstructionFormatter.asNum(fare);
      if (own != null) {
        String fmt(num v) => v % 1 == 0 ? v.toInt().toString() : v.toString();
        final from = InstructionFormatter.asNum(detail['fare_from_egp']);
        if (from != null && from < own) {
          return isArabic
              ? '${fmt(from)} لـ ${fmt(own)} ج.م (الأجرة على حسب المسافة)'
              : '${fmt(from)} to ${fmt(own)} EGP (Microbus fare based on distance)';
        }
        return isArabic ? '${fmt(own)} ج.م' : '${fmt(own)} EGP';
      }
      return isArabic
          ? '10 لـ 15 ج.م (الأجرة على حسب المسافة)'
          : '10 to 15 EGP (Microbus fare based on distance)';
    } else if (mode == 'apm') {
      return isArabic ? 'ببلاش (شاتل بين الصالات)' : 'Free (Inter-terminal shuttle)';
    } else {
      final routeId = (detail['route_id'] ?? '').toString().toUpperCase();
      final isAC = InstructionFormatter.isAcBus({...detail, 'route_number': detail['number']});
      if (fare != null) {
        final n = _formatNumber(fare);
        if (isAC || routeId.startsWith('NC_')) {
          return isArabic ? '$n ج.م (باص مكيف / مجتمعي)' : '$n EGP (Express / Community bus)';
        }
        return isArabic
            ? '$n ج.م (تذكرة الأتوبيس العادية)'
            : '$n EGP (Standard bus fare)';
      }
      if (isAC) {
        return isArabic ? '45 ج.م (أتوبيس مكيف)' : '45 EGP (Air-conditioned bus)';
      }
      return isArabic ? '20 ج.م (تذكرة الأتوبيس العادية)' : '20 EGP (Standard bus fare)';
    }
  }

  static String _formatNumber(dynamic value) {
    final n = InstructionFormatter.asNum(value)?.toDouble() ?? 0.0;
    return n == n.roundToDouble() ? n.round().toString() : n.toStringAsFixed(1);
  }

  Widget _fact(BuildContext context, IconData icon, String text, {Color? color}) {
    final effectiveColor = color ?? context.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: effectiveColor),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              color: effectiveColor,
              fontWeight: color != null ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }


  List<LatLng> _extractCoords(Map<String, dynamic> direction) =>
      LineDetailScreen.extractCoords(direction);

  void _fitRouteBounds(List<LatLng> coords) {
    if (coords.isEmpty || _mapController == null) return;
    if (coords.length == 1) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(coords.first, 15),
      );
      return;
    }
    double minLat = 90, maxLat = -90, minLon = 180, maxLon = -180;
    for (final c in coords) {
      if (c.latitude < minLat) minLat = c.latitude;
      if (c.latitude > maxLat) maxLat = c.latitude;
      if (c.longitude < minLon) minLon = c.longitude;
      if (c.longitude > maxLon) maxLon = c.longitude;
    }
    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLon),
      northeast: LatLng(maxLat, maxLon),
    );
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 48),
    );
  }

  Widget _mapView(
    AppLocalizations l10n,
    Map<String, dynamic> detail,
    Map<String, dynamic> direction,
    List<Map<String, dynamic>> stops,
    bool isArabic,
    Color modeColor,
  ) {
    final isDark = context.isDark;
    final polylineCoords = _extractCoords(direction);

    if (_stopDotIcon == null || _cachedModeColor != modeColor) {
      _initStopDotIcons(modeColor);
    }

    final markers = <Marker>{};
    for (int i = 0; i < stops.length; i++) {
      final s = stops[i];
      final lat = InstructionFormatter.asNum(s['lat'])?.toDouble();
      final lon = InstructionFormatter.asNum(s['lon'])?.toDouble();
      if (lat == null || lon == null) continue;
      final isFirst = i == 0;
      final isLast = i == stops.length - 1;
      final isSelected = _selectedStopIndex == i;
      final name = _cleanStationName((s['name'] ?? '').toString(), isArabic);
      final note = s['note']?.toString();

      BitmapDescriptor icon;
      Offset anchor;
      int zIndex;

      if (isFirst) {
        icon = _originIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
        anchor = MapMarkerService.centerAnchor;
        zIndex = isSelected ? 20 : 10;
      } else if (isLast) {
        icon = _destinationIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
        anchor = MapMarkerService.pinAnchor;
        zIndex = isSelected ? 20 : 10;
      } else {
        if (isSelected && _selectedStopDotIcon != null) {
          icon = _selectedStopDotIcon!;
          anchor = MapMarkerService.centerAnchor;
          zIndex = 15;
        } else if (_stopDotIcon != null) {
          icon = _stopDotIcon!;
          anchor = MapMarkerService.centerAnchor;
          zIndex = 2;
        } else {
          // Skip intermediate stop markers until custom dot icon is ready.
          // Never clutter the map with giant default balloon pins!
          continue;
        }
      }

      markers.add(
        Marker(
          markerId: MarkerId('stop_${s['stop_id'] ?? i}'),
          position: LatLng(lat, lon),
          icon: icon,
          anchor: anchor,
          zIndexInt: zIndex,
          infoWindow: (isFirst || isLast)
              ? InfoWindow(
                  title: '${i + 1}. $name',
                  snippet: note,
                )
              : InfoWindow.noText,
          onTap: () {
            setState(() {
              _selectedStopIndex = i;
            });
            _mapController?.animateCamera(
              CameraUpdate.newLatLng(LatLng(lat, lon)),
            );
          },
        ),
      );
    }

    final polylines = polylineCoords.isNotEmpty
        ? RouteLineStyle.ride('route_${widget.routeId}_$_directionIndex', polylineCoords, modeColor).toSet()
        : <Polyline>{};

    final defaultCenter = polylineCoords.isNotEmpty
        ? polylineCoords.first
        : const LatLng(30.0444, 31.2357);

    return Stack(
      children: [
        GoogleMap(
            compassEnabled: false,
            rotateGesturesEnabled: false,
          initialCameraPosition: CameraPosition(target: defaultCenter, zoom: 12),
          polylines: polylines,
          markers: markers,
          style: isDark ? darkMapStyleJson : null,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          myLocationButtonEnabled: false,
          onMapCreated: (controller) {
            _mapController = controller;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _fitRouteBounds(polylineCoords);
            });
          },
          onTap: (_) {
            if (_selectedStopIndex != null) {
              setState(() => _selectedStopIndex = null);
            }
          },
        ),
        Positioned(
          top: 14,
          right: isArabic ? null : 14,
          left: isArabic ? 14 : null,
          child: FloatingActionButton.small(
            heroTag: 'fit_line_route_btn',
            backgroundColor: context.surfaceCard,
            foregroundColor: AppColors.primaryTeal,
            elevation: 3,
            tooltip: l10n.linesFitRoute,
            onPressed: () => _fitRouteBounds(polylineCoords),
            child: const Icon(Icons.crop_free_rounded, size: 20),
          ),
        ),
        if (_selectedStopIndex != null && _selectedStopIndex! < stops.length)
          Positioned(
            bottom: 14,
            left: 14,
            right: 14,
            child: _selectedStopCard(
              stops[_selectedStopIndex!],
              _selectedStopIndex!,
              stops.length,
              isArabic,
              modeColor,
            ),
          ),
      ],
    );
  }

  Widget _selectedStopCard(
    Map<String, dynamic> stop,
    int index,
    int totalCount,
    bool isArabic,
    Color modeColor,
  ) {
    final name = _cleanStationName((stop['name'] ?? '').toString(), isArabic);
    final note = stop['note']?.toString();
    final isFirst = index == 0;
    final isLast = index == totalCount - 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.45 : 0.16),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: (isFirst
                      ? Colors.green
                      : (isLast ? Colors.red : modeColor))
                  .withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isFirst ? Colors.green : (isLast ? Colors.red : modeColor),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.5,
                    color: context.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (note != null && note.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    note,
                    style: TextStyle(fontSize: 12, color: context.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            color: context.textSecondary,
            onPressed: () => setState(() => _selectedStopIndex = null),
          ),
        ],
      ),
    );
  }

  /// A timeline rather than a plain list: the line down the left is the
  /// thing that makes "in order" readable at a glance, and the first and
  /// last stops are marked because those are the two a rider checks first.
  Widget _stopList(
    AppLocalizations l10n,
    List<Map<String, dynamic>> stops,
    bool isArabic,
    Color modeColor,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: stops.length + 3,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              l10n.linesStopsInOrder.toUpperCase(),
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                  color: context.textSecondary),
            ),
          );
        }
        if (i == stops.length + 1) {
          final detail = _detail;
          final directions = List<Map<String, dynamic>>.from(detail?['directions'] ?? const []);
          final dir = directions.isNotEmpty
              ? directions[_directionIndex.clamp(0, directions.length - 1)]
              : <String, dynamic>{};
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Center(
              child: TextButton.icon(
                onPressed: detail == null ? null : () => _openReport(detail, dir),
                icon: Icon(Icons.flag_outlined, size: 16, color: context.textSecondary),
                label: Text(
                  l10n.reportAnIssueWithThisLine,
                  style: TextStyle(color: context.textSecondary, fontSize: 12.5),
                ),
              ),
            ),
          );
        }
        // After the report link, never between stops.
        if (i == stops.length + 2) return const NativeAdCard(template: TemplateType.small);
        final index = i - 1;
        final isFirst = index == 0;
        final isLast = index == stops.length - 1;
        final name = _cleanStationName((stops[index]['name'] ?? '').toString(), isArabic);

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 28,
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        width: 2,
                        color: isFirst
                            ? Colors.transparent
                            : modeColor.withValues(alpha: 0.85),
                      ),
                    ),
                    Container(
                      width: isFirst || isLast ? 13 : 9,
                      height: isFirst || isLast ? 13 : 9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFirst ? modeColor : context.surfaceCard,
                        border: Border.all(color: modeColor, width: 2),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        width: 2,
                        color: isLast
                            ? Colors.transparent
                            : modeColor.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.3,
                      fontWeight: isFirst || isLast ? FontWeight.bold : FontWeight.w500,
                      color: context.textPrimary,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Text('${index + 1}',
                    style: TextStyle(fontSize: 12, color: context.textSecondary)),
              ),
            ],
          ),
        );
      },
    );
  }
}
