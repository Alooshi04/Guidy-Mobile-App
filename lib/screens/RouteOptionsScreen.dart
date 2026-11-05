import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../l10n/app_localizations.dart';
import '../services/analytics_service.dart';
import '../services/api_service.dart';
import '../services/trip_sharing.dart';
import '../services/instruction_formatter.dart';
import '../services/locale_controller.dart';
import '../services/route_report_service.dart';
import '../theme/app_theme.dart';
import '../theme/guidy_ui.dart';
import '../utils/duration_text.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' show TemplateType;
import '../widgets/error_state.dart';
import '../widgets/native_ad_card.dart';
import '../widgets/route_card_skeleton.dart';
import '../widgets/route_options/better_route_sheet.dart';
import '../widgets/route_options/route_card.dart';
import '../widgets/simple/simple_route_card.dart';
import '../widgets/simple/simple_ui.dart';
import 'BetterRouteBuilderScreen.dart';
import 'RouteDetailScreen.dart';
import '../services/better_route.dart';
import '../services/route_choice.dart';
import '../services/route_summary.dart';
import 'MapScreen.dart';
import '../utils/route_line_style.dart';
import '../services/simple_mode.dart';
import 'package:share_plus/share_plus.dart';
import '../services/share_links.dart';
import '../utils/deep_copy.dart';
import '../services/maps_link_parser.dart';
import '../services/commute/commute_notifications.dart';

/// Route chooser: every route the server found is drawn on one map, the
/// best one highlighted. The rider picks a route by tapping its line or its
/// row, sees its steps in plain words, and picks the exact vehicle for each
/// leg from the ones that serve it, then starts the trip.
///
/// This replaced a list of Recommended / Cheapest / Alternative cards, a
/// comparison view and a separate "customise your route" card, all of which
/// said the same thing three ways without showing where the routes go.
class RouteOptionsScreen extends StatefulWidget {
  final double startLat;
  final double startLon;
  final String startName;
  final double endLat;
  final double endLon;
  final String endName;
  final Map<String, dynamic>? initialData;

  /// From a shared route link: the vehicles the sender took. The option
  /// using exactly these is selected when it is still offered.
  final List<String> preferRouteIds;

  /// False in widget tests, where the Google Maps platform view can't run.
  final bool showMap;

  /// Tests pass fakes for the "Know a better route?" flow (the line search
  /// and the report); the app uses the real ones.
  @visibleForTesting
  final ApiService? api;
  @visibleForTesting
  final BetterRouteSubmit? submitBetterRoute;

  const RouteOptionsScreen({
    super.key,
    required this.startLat,
    required this.startLon,
    required this.startName,
    required this.endLat,
    required this.endLon,
    required this.endName,
    this.initialData,
    this.preferRouteIds = const [],
    this.showMap = true,
    this.api,
    this.submitBetterRoute,
  });

  @override
  State<RouteOptionsScreen> createState() => _RouteOptionsScreenState();

  /// The vehicles of an option, in order (walks left out).
  static List<String> routeIdsOf(Map<String, dynamic> option) => [
        for (final i in (option['instructions'] as List? ?? const []))
          if (i is Map && (i['action'] == 'board' || i['action'] == 'transfer') && i['route_id'] != null)
            i['route_id'].toString(),
      ];

  /// Index of the option that uses exactly [routeIds], if there is one.
  static Map<String, dynamic>? nightServiceOf(Map<String, dynamic> data) {
    final ns = data['night_service'];
    return ns is Map ? Map<String, dynamic>.from(ns) : null;
  }

  /// Whether [option] is the usual route that isn't running now: it rides
  /// a line the engine listed as stopped.
  static bool isUsualOnly(Map<String, dynamic> option, Map<String, dynamic>? nightService) {
    if (nightService == null || option['type'] == 'Available now') return false;
    final closed = {for (final r in (nightService['closed_route_ids'] as List? ?? const [])) r.toString()};
    if (closed.isEmpty) return option['is_operating'] == false;
    return (option['instructions'] as List? ?? const []).any((i) =>
        i is Map &&
        (i['action'] == 'board' || i['action'] == 'transfer') && closed.contains(i['route_id']?.toString()));
  }

  static int? preferredOptionIndex(List<Map<String, dynamic>> options, List<String> routeIds) {
    if (routeIds.isEmpty) return null;
    for (var i = 0; i < options.length; i++) {
      final ids = routeIdsOf(options[i]);
      if (ids.length == routeIds.length && Iterable.generate(ids.length).every((k) => ids[k] == routeIds[k])) {
        return i;
      }
    }
    return null;
  }
}

class _RouteOptionsScreenState extends State<RouteOptionsScreen> {
  late final ApiService _apiService = widget.api ?? ApiService();
  late Future<Map<String, dynamic>> _optionsFuture;
  bool _excludeMetro = false;
  bool _minWalk = false;
  bool _minTransfers = false;
  /// Route Options view: false shows the cards only, true adds the
  /// side-by-side comparison table above them.
  bool _compare = false;

  int _selected = 0;

  bool _preferApplied = false;
  List<Map<String, dynamic>> _lastOptions = const [];
  Map<String, dynamic>? _lastNight;

  /// option index -> instruction index -> chosen index in boarding_options.
  final Map<int, Map<int, int>> _chosenVehicle = {};

  GoogleMapController? _map;

  /// The cards sheet over the map: where it is (fraction of the space under
  /// the header), the height of its grab strip (measured), and the map's
  /// bottom padding, so the route is framed in the part left uncovered.
  /// Null until the sheet first lays out.
  final ValueNotifier<double?> _sheetExtent = ValueNotifier(null);
  final GlobalKey _sheetGrabKey = GlobalKey(debugLabel: 'sheet_grab');
  double _sheetGrabHeight = 0;
  double? _mapPadBottom;
  double _sheetSpace = 0;
  Timer? _refitTimer;
  List<Map<String, dynamic>> _sheetOptions = const [];
  List<double>? _sheetSnaps;
  final ScrollController _cardsScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _optionsFuture = widget.initialData != null ? Future.value(widget.initialData!) : _fetchOptions();
  }

  @override
  void dispose() {
    _refitTimer?.cancel();
    _sheetExtent.dispose();
    _cardsScroll.dispose();
    _map?.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------------- data

  Future<Map<String, dynamic>> _fetchOptions() async {
    try {
      final data = await _apiService.fetchRoute(
        widget.startLat,
        widget.startLon,
        widget.endLat,
        widget.endLon,
        lang: localeController.isArabic ? 'ar' : 'en',
        excludeMetro: _excludeMetro,
        minWalk: _minWalk,
        minTransfers: _minTransfers,
      );
      AnalyticsService.logRouteCalculated(success: data['success'] != false);
      return data;
    } catch (e) {
      AnalyticsService.logRouteCalculated(success: false);
      rethrow;
    }
  }

  void _refetch(VoidCallback change) {
    setState(() {
      change();
      _selected = 0;
      _chosenVehicle.clear();
      // The map gives way to the loading cards; its controller goes with it
      // until the next map reports in (onMapCreated).
      _map = null;
      _optionsFuture = _fetchOptions();
    });
  }

  static num? _num(dynamic v) => InstructionFormatter.asNum(v);

  Future<void> _shareRoute(AppLocalizations l10n) async {
    HapticFeedback.selectionClick();
    final ids = _selected < _lastOptions.length
        ? RouteOptionsScreen.routeIdsOf(_effectiveOption(_selected, _lastOptions[_selected]))
        : const <String>[];
    // "My current location" means the sender's location; name the place
    // instead, or the other person reads it as their own.
    var startName = widget.startName;
    const mine = {'My Current Location', 'موقعي الحالي', 'الموقع الحالي'};
    if (mine.contains(startName.trim()) || startName.trim() == l10n.myCurrentLocation) {
      startName = await MapsLinkParser.reverseGeocodeName(widget.startLat, widget.startLon,
          fallbackLabel: l10n.pinnedLocation, lang: localeController.isArabic ? 'ar' : 'en');
      if (!mounted) return;
    }
    final link = ShareLinks.routeLink(
      startLat: widget.startLat,
      startLon: widget.startLon,
      startName: startName,
      endLat: widget.endLat,
      endLon: widget.endLon,
      endName: widget.endName,
      routeIds: ids,
    );
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(ShareParams(
      text: l10n.shareRouteText(startName, widget.endName, link.toString()),
      sharePositionOrigin: box != null ? box.localToGlobal(Offset.zero) & box.size : null,
    ));
  }

  /// The cards to show. Late at night, when the usual route's lines have
  /// stopped, the trip on lines running right now comes first.
  static List<Map<String, dynamic>> _options(Map<String, dynamic> data) {
    final now = RouteOptionsScreen.nightServiceOf(data)?['available_now'];
    return [
      if (now is Map) Map<String, dynamic>.from(now),
      for (final o in (data['options'] as List? ?? const []))
        if (o is Map) Map<String, dynamic>.from(o),
    ];
  }

  static List<Map<String, dynamic>> _instructions(Map<String, dynamic> option) => [
        for (final i in (option['instructions'] as List? ?? const []))
          if (i is Map) Map<String, dynamic>.from(i),
      ];

  /// The option with every leg switched to the vehicle the rider chose,
  /// and the total fare adjusted by the difference.
  Map<String, dynamic> _effectiveOption(int optionIndex, Map<String, dynamic> option) =>
      RouteChoice.apply(option, _chosenVehicle[optionIndex] ?? const {});

  // ------------------------------------------------------------------ map

  static List<LatLng> _segmentPoints(dynamic seg) {
    if (seg is! Map) return const [];
    final pts = seg['points'];
    if (pts is! List) return const [];
    final out = <LatLng>[];
    for (final p in pts) {
      if (p is Map) {
        final lat = _num(p['lat']);
        final lon = _num(p['lon']);
        if (lat != null && lon != null) out.add(LatLng(lat.toDouble(), lon.toDouble()));
      }
    }
    return out;
  }

  Set<Polyline> _polylines(List<Map<String, dynamic>> options, bool dark) {
    final lines = <Polyline>{};
    const other = Color(0xFF94A3B8);
    // Unselected routes first (grey, underneath), the selected one on top.
    for (var oi = 0; oi < options.length; oi++) {
      if (oi == _selected) continue;
      final segs = options[oi]['segments'] as List? ?? const [];
      for (var si = 0; si < segs.length; si++) {
        final seg = segs[si];
        final pts = _segmentPoints(seg);
        if (pts.length < 2) continue;
        final isWalk = seg is Map && (seg['is_walk'] == true || seg['vehicle_type'] == 'walk');
        if (isWalk) {
          lines.add(RouteLineStyle.walk('o${oi}_s$si', pts,
              dark: dark, width: 5, zIndex: 1, color: other,
              consumeTapEvents: true, onTap: () => _select(oi, options)));
        } else {
          lines.add(Polyline(
            polylineId: PolylineId('o${oi}_s$si'),
            points: pts,
            width: 5,
            color: other.withValues(alpha: 0.9),
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            zIndex: 1,
            consumeTapEvents: true,
            onTap: () => _select(oi, options),
          ));
        }
      }
    }
    if (_selected < options.length) {
      final segs = options[_selected]['segments'] as List? ?? const [];
      final colors = GuidyModeStyle.segmentColors(segs, _instructions(options[_selected]), dark: dark);
      for (var si = 0; si < segs.length; si++) {
        final seg = segs[si];
        final pts = _segmentPoints(seg);
        if (pts.length < 2) continue;
        final color = colors[si];
        if (color == null) {
          lines.add(RouteLineStyle.walk('sel_s$si', pts, dark: dark, zIndex: 6));
        } else {
          lines.addAll(RouteLineStyle.ride('sel_s$si', pts, color, width: 6, zIndex: 3));
        }
      }
    }
    return lines;
  }

  Set<Marker> _markers() => {
        Marker(
          markerId: const MarkerId('start'),
          position: LatLng(widget.startLat, widget.startLon),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(title: widget.startName),
        ),
        Marker(
          markerId: const MarkerId('end'),
          position: LatLng(widget.endLat, widget.endLon),
          infoWindow: InfoWindow(title: widget.endName),
        ),
      };

  LatLngBounds? _boundsFor(List<Map<String, dynamic>> options, {int? only}) {
    double? minLat, maxLat, minLon, maxLon;
    void add(LatLng p) {
      minLat = minLat == null ? p.latitude : math.min(minLat!, p.latitude);
      maxLat = maxLat == null ? p.latitude : math.max(maxLat!, p.latitude);
      minLon = minLon == null ? p.longitude : math.min(minLon!, p.longitude);
      maxLon = maxLon == null ? p.longitude : math.max(maxLon!, p.longitude);
    }

    add(LatLng(widget.startLat, widget.startLon));
    add(LatLng(widget.endLat, widget.endLon));
    for (var oi = 0; oi < options.length; oi++) {
      if (only != null && oi != only) continue;
      for (final seg in (options[oi]['segments'] as List? ?? const [])) {
        _segmentPoints(seg).forEach(add);
      }
    }
    if (minLat == null) return null;
    return LatLngBounds(southwest: LatLng(minLat!, minLon!), northeast: LatLng(maxLat!, maxLon!));
  }

  void _fit(List<Map<String, dynamic>> options, {int? only}) {
    final b = _boundsFor(options, only: only);
    if (b == null || _map == null) return;
    _map!.animateCamera(CameraUpdate.newLatLngBounds(b, 48)).catchError((_) {});
  }

  void _select(int index, List<Map<String, dynamic>> options) {
    if (index == _selected) return;
    HapticFeedback.selectionClick();
    setState(() => _selected = index);
    _fit(options, only: index);
  }

  /// A tap on a card: picks the route on the map and opens its detail
  /// page, where the rider picks lines and starts the trip.
  void _tapCard(Map<String, dynamic> data, int index, List<Map<String, dynamic>> options, String? closedNote) {
    _select(index, options);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RouteDetailScreen(
          option: options[index],
          startName: widget.startName,
          endName: widget.endName,
          closedNote: closedNote,
          choices: _chosenVehicle[index] ?? const {},
          onChoicesChanged: (c) {
            if (mounted) setState(() => _chosenVehicle[index] = c);
          },
          onStart: (c) {
            setState(() => _chosenVehicle[index] = c);
            _start(data, index, options[index]);
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- start

  /// Everything MapScreen needs to navigate one of the offered routes.
  Map<String, dynamic> _pathDataFor(Map<String, dynamic> data, int optionIndex) {
    final options = _options(data);
    final chosen = _effectiveOption(optionIndex, options[optionIndex]);
    return <String, dynamic>{
      'segments': chosen['segments'],
      'station_markers': chosen['station_markers'],
      'instructions': chosen['instructions'],
      'option': chosen,
      'type': chosen['type'],
      'color': chosen['color'] ?? '#489CB5',
      'duration_minutes': _num(chosen['time']),
      'fare_egp': chosen['fare_total_egp'] ?? chosen['fare_egp'],
      'fare_total_egp': chosen['fare_total_egp'] ?? chosen['fare_egp'],
      'distance_km': (_num(chosen['distance_m']) ?? 0) / 1000,
      'metro_stops': chosen['metro_stops'],
      'start_name': widget.startName,
      'end_name': widget.endName,
      'start_lat': widget.startLat,
      'start_lon': widget.startLon,
      'end_lat': widget.endLat,
      'end_lon': widget.endLon,
      // What the rider chose between, so history can say what the choice
      // actually saved (TripHistoryService.computeSavings). Summaries only.
      'chosen_index': optionIndex,
      'compared_options': [
        for (final o in options)
          {'type': o['type'], 'time': o['time'], 'fare_total_egp': o['fare_total_egp'] ?? o['fare_egp']},
      ],
    };
  }

  Future<void> _start(Map<String, dynamic> data, int optionIndex, Map<String, dynamic> option) async {
    // One-time ask, before the navigation screen opens.
    await TripSharing.askIfNeeded(context);
    if (!mounted) return;
    final options = _options(data);
    final pathData = _pathDataFor(data, optionIndex);
    // Simple mode: no faint alternative routes, so a stray tap can't switch
    // the trip.
    final alternatives = <Map<String, dynamic>>[
      for (var i = 0; i < options.length; i++)
        if (!simpleMode.value && i != optionIndex && options[i]['partial'] != true && _instructions(options[i]).isNotEmpty)
          _pathDataFor(data, i),
    ];
    // The Home <-> Work trip: its lines become the commute's, for the
    // commute notifications (only if the ends are the saved Home and Work).
    unawaited(CommuteNotifications.captureIfCommute(
      l10n: AppLocalizations.of(context),
      option: _effectiveOption(optionIndex, options[optionIndex]),
      startLat: widget.startLat,
      startLon: widget.startLon,
      endLat: widget.endLat,
      endLon: widget.endLon,
    ));
    // The trip gets its own copies: switching a vehicle or a stop during
    // the trip must not change these cards, which back returns to.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapScreen(
          pathData: deepCopyMap(pathData),
          startName: widget.startName,
          endName: widget.endName,
          recordHistoryOnArrival: true,
          alternatives: [for (final a in alternatives) deepCopyMap(a)],
        ),
      ),
    );
  }

  // --------------------------------------------------------------- report

  /// Lets a rider describe a route the engine doesn't have -- the only
  /// channel that produces data about coverage holes.
  Future<void> _reportMissingRoute({String? failureCode, int? uncoveredM, String? lastCoveredStop}) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.reportMissingRouteTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.reportMissingRouteIntro, style: TextStyle(fontSize: 13, color: dialogContext.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              maxLength: RouteReportService.maxCommentLength,
              decoration: InputDecoration(hintText: l10n.reportMissingRouteHint, border: const OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.cancelButton)),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, controller.text), child: Text(l10n.reportSubmit)),
        ],
      ),
    );
    controller.dispose();
    if (text == null) return;
    if (text.trim().isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.reportCommentRequired)));
      return;
    }
    final outcome = await RouteReportService.submitMissingRoute(
      startLat: widget.startLat,
      startLon: widget.startLon,
      endLat: widget.endLat,
      endLon: widget.endLon,
      startName: widget.startName,
      endName: widget.endName,
      comment: text,
      locale: localeController.isArabic ? 'ar' : 'en',
      failureCode: failureCode,
      uncoveredM: uncoveredM,
      lastCoveredStop: lastCoveredStop,
    );
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(reportOutcomeText(l10n, outcome))));
  }

  /// "Know a better route?": the rider writes the route they know, or
  /// builds it from the network. Both reports carry the ends and the
  /// routes shown here, as the rider has them (lines picked included).
  Future<void> _betterRoute() async {
    HapticFeedback.selectionClick();
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final choice = await BetterRouteSheet.show(context);
    if (!mounted || choice == null) return;
    final shownIndexes = simpleMode.value
        ? SimpleModeController.easiest(_lastOptions)
        : [for (var i = 0; i < _lastOptions.length; i++) i];
    final shown = BetterRouteReport.summarize([for (final i in shownIndexes) _effectiveOption(i, _lastOptions[i])]);
    final submit = widget.submitBetterRoute ?? RouteReportService.submitBetterRoute;
    final RouteReportOutcome? outcome;
    switch (choice) {
      case BetterRouteWritten(:final text):
        outcome = await submit(BetterRouteReport(
          startLat: widget.startLat,
          startLon: widget.startLon,
          endLat: widget.endLat,
          endLon: widget.endLon,
          startName: widget.startName,
          endName: widget.endName,
          locale: localeController.isArabic ? 'ar' : 'en',
          comment: text,
          shownOptions: shown,
        ));
      case BetterRouteBuild():
        // The builder says itself when a report couldn't go, and stays.
        outcome = await Navigator.push<RouteReportOutcome>(
          context,
          MaterialPageRoute(
            builder: (_) => BetterRouteBuilderScreen(
              startLat: widget.startLat,
              startLon: widget.startLon,
              startName: widget.startName,
              endLat: widget.endLat,
              endLon: widget.endLon,
              endName: widget.endName,
              shownOptions: shown,
              submit: submit,
              api: _apiService,
            ),
          ),
        );
    }
    if (!mounted || outcome == null) return;
    messenger.showSnackBar(SnackBar(content: Text(reportOutcomeText(l10n, outcome))));
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: context.surfaceCard,
      // The header is part of the body, not a fixed-height app bar: the
      // start and destination under the title take as many lines as they
      // need (see GuidyTripEndpoints).
      body: Column(
        children: [
        SafeArea(
          bottom: false,
          child: GuidyHeader(
            title: simpleMode.value ? l10n.simpleRoutesTitle : l10n.routeOptionsTitle,
            showLanguageToggle: !simpleMode.value,
            below: GuidyTripEndpoints(start: widget.startName, end: widget.endName),
            trailing: simpleMode.value
                ? null
                : IconButton(
              icon: const Icon(Icons.ios_share_rounded),
              color: AppColors.brandBlue,
              tooltip: l10n.shareRouteTooltip,
              onPressed: () => _shareRoute(l10n),
            ),
            // Every name comes in both languages (key_en / key_ar), so the
            // same cards redraw in the new one: no new search, and the
            // selected card and chosen vehicles stay.
            onLanguageChanged: (_) {
              if (mounted) setState(() {});
            },
          ),
        ),
        Expanded(
          child: FutureBuilder<Map<String, dynamic>>(
        future: _optionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return RouteCardSkeletonList(
              mapHeight: widget.showMap && !simpleMode.value ? MediaQuery.of(context).size.height * 0.36 : null,
            );
          }
          if (snapshot.hasError || snapshot.data?['success'] == false) {
            return ErrorState(
              icon: snapshot.hasError || InstructionFormatter.isNetworkError(snapshot.data!)
                  ? Icons.wifi_off_rounded
                  : Icons.wrong_location_rounded,
              title: snapshot.hasError ? null : InstructionFormatter.errorTitle(l10n, snapshot.data!),
              message: snapshot.hasError ? l10n.serverUnreachable : InstructionFormatter.errorMessage(l10n, snapshot.data!),
              onRetry: () => _refetch(() {}),
              nearestHubs: snapshot.data?['nearest_hubs'] as Map<String, dynamic>?,
              onReportMissing: () => _reportMissingRoute(failureCode: snapshot.data?['error_code'] as String?),
            );
          }
          final data = snapshot.data!;
          final options = _options(data);
          if (options.isEmpty) {
            return ErrorState(icon: Icons.wrong_location_rounded, message: l10n.errorNoRouteFound, onRetry: () => _refetch(() {}));
          }
          if (!_preferApplied) {
            _preferApplied = true;
            final i = RouteOptionsScreen.preferredOptionIndex(options, widget.preferRouteIds);
            if (i != null) _selected = i;
          }
          _lastOptions = options;
          _lastNight = RouteOptionsScreen.nightServiceOf(data);
          if (_selected >= options.length) _selected = 0;
          final simple = simpleMode.value;
          if (simple) return _buildSimple(l10n, data, options);
          final cards = <Widget>[
                    // Under the filters, above the list/compare switch.
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: BetterRouteButton(onPressed: _betterRoute),
                    ),
                    if (options.length > 1) ...[
                      _buildViewSwitch(l10n),
                      const SizedBox(height: 12),
                    ],
                    AnimatedSize(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: _compare && options.length > 1 ? _buildCompareTable(l10n, options) : const SizedBox(width: double.infinity),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(l10n.availableRoutes,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: GuidyUi.heading(context))),
                    ),
                    _buildNightNotice(l10n, data),
                    _buildPartialNotice(l10n, options),
                    for (var i = 0; i < options.length; i++)
                      _buildRouteCard(l10n, data, i, options),
                    const SizedBox(height: 8),
                    Text(l10n.fareEstimateNote,
                        textAlign: TextAlign.center, style: TextStyle(color: context.textSecondary, fontSize: 11)),
                    // After the last card and the fare note, never between
                    // route cards (they are the product, and tappable).
                    const NativeAdCard(template: TemplateType.small),
          ];
          return Column(
            children: [
              Expanded(
                child: widget.showMap
                    ? _mapAndSheet(l10n, options, cards)
                    : Column(children: [
                        _buildFilters(l10n),
                        Expanded(child: ListView(padding: _cardsPadding, children: cards)),
                      ]),
              ),
            ],
          );
        },
          ),
        ),
        ],
      ),
    );
  }

  static const EdgeInsets _cardsPadding = EdgeInsets.fromLTRB(16, 4, 16, 16);

  /// The map's height when the screen opens: the sheet starts just under it.
  double _openingMapHeight(BuildContext c) => MediaQuery.of(c).size.height * 0.36;

  /// The map under a sheet of the cards. It opens where the cards always
  /// started, under a map 36% of the screen tall; pulled up it covers the
  /// map and shows every card, pulled down it leaves only its grab strip
  /// and the map.
  Widget _mapAndSheet(AppLocalizations l10n, List<Map<String, dynamic>> options, List<Widget> cards) {
    _sheetOptions = options;
    return LayoutBuilder(builder: (context, box) {
      final space = box.maxHeight;
      final mapOpen = math.min(_openingMapHeight(context), space);
      final opening = space <= 0 ? 1.0 : ((space - mapOpen) / space).clamp(0.05, 1.0);
      final grab = _sheetGrabHeight > 0 ? _sheetGrabHeight : 28.0;
      final lowest = space <= 0 ? opening : (grab / space).clamp(0.0, opening);
      if (space != _sheetSpace) {
        _sheetSpace = space;
        _mapPadBottom = null;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _measureSheetGrab());
      return Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: space,
            child: _buildMap(options, padBottom: _mapPadBottom ?? space - mapOpen, space: space),
          ),
          NotificationListener<DraggableScrollableNotification>(
            onNotification: (n) {
              _sheetExtent.value = n.extent;
              _refitTimer?.cancel();
              _refitTimer = Timer(const Duration(milliseconds: 350), _refitToSheet);
              return false;
            },
            child: DraggableScrollableSheet(
              key: const ValueKey('route-sheet'),
              initialChildSize: opening,
              minChildSize: lowest,
              maxChildSize: 1.0,
              snap: true,
              // The same list while it holds: a new one on a rebuild reads
              // as new snap sizes and snaps the sheet back (see MapScreen).
              snapSizes: _sheetSnaps = (_sheetSnaps?.single == opening ? _sheetSnaps! : List.unmodifiable([opening])),
              builder: (context, scroll) => DecoratedBox(
                decoration: BoxDecoration(
                  color: context.surfaceCard,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: context.isDark ? 0.4 : 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                // The handle and filters drag the sheet (they hold its
                // scroll controller); the cards under them scroll on their
                // own without moving it.
                child: LayoutBuilder(builder: (context, inner) => Column(
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: inner.maxHeight),
                      child: SingleChildScrollView(
                        controller: scroll,
                        child: KeyedSubtree(
                          key: _sheetGrabKey,
                          child: Column(children: [
                            _grabHandle(),
                            _buildFilters(l10n),
                          ]),
                        ),
                      ),
                    ),
                    Expanded(
                      child: CustomScrollView(
                        key: const ValueKey('route-sheet-cards'),
                        controller: _cardsScroll,
                        slivers: [
                          SliverPadding(padding: _cardsPadding, sliver: SliverList(delegate: SliverChildListDelegate(cards))),
                        ],
                      ),
                    ),
                  ],
                )),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _grabHandle() => Padding(
        key: const ValueKey('route-sheet-handle'),
        padding: const EdgeInsets.only(top: 6, bottom: 6),
        child: Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: context.isDark ? Colors.white24 : GuidyUi.mist,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );

  void _measureSheetGrab() {
    if (!mounted) return;
    final h = _sheetGrabKey.currentContext?.size?.height;
    if (h != null && (h - _sheetGrabHeight).abs() > 1) setState(() => _sheetGrabHeight = h);
  }

  /// Once the sheet comes to rest, the map frames the chosen route in the
  /// part the sheet leaves uncovered (not on every frame of the drag: a map
  /// re-padded mid-drag jumps around under the finger).
  void _refitToSheet() {
    final extent = _sheetExtent.value;
    if (!mounted || extent == null || _sheetSpace <= 0) return;
    final covered = _sheetSpace * extent;
    if (_sheetSpace - covered < 120) return;
    setState(() => _mapPadBottom = covered);
    Future.delayed(const Duration(milliseconds: 60), () {
      if (mounted && _sheetOptions.isNotEmpty) _fit(_sheetOptions, only: _selected);
    });
  }

  Widget _buildMap(List<Map<String, dynamic>> options, {required double padBottom, required double space}) {
    return SizedBox(
      height: space,
      child: Stack(
        children: [
          GoogleMap(
            padding: EdgeInsets.only(bottom: padBottom),
            compassEnabled: false,
            rotateGesturesEnabled: false,
            initialCameraPosition: CameraPosition(
              target: LatLng((widget.startLat + widget.endLat) / 2, (widget.startLon + widget.endLon) / 2),
              zoom: 12,
            ),
            style: context.isDark ? darkMapStyleJson : null,
            polylines: _polylines(options, context.isDark),
            markers: _markers(),
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            myLocationButtonEnabled: false,
            onMapCreated: (c) {
              _map = c;
              Future.delayed(const Duration(milliseconds: 250), () {
                if (mounted) _fit(options);
              });
            },
          ),
          PositionedDirectional(
            start: 10,
            bottom: padBottom + 10,
            end: 10,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: context.surfaceCard.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  AppLocalizations.of(context).plannerHint,
                  style: TextStyle(fontSize: 11.5, color: context.textSecondary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(AppLocalizations l10n) {
    Widget chip(String label, IconData icon, bool value, ValueChanged<bool> onChanged) => Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: GuidyPill(
            label: label,
            icon: icon,
            selected: value,
            color: value ? null : (GuidyUi.mutedText(context)),
            onTap: () => onChanged(!value),
          ),
        );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Row(children: [
        chip(l10n.filterMinWalk, Icons.directions_walk, _minWalk, (v) => _refetch(() => _minWalk = v)),
        chip(l10n.excludeMetro, Icons.subway_rounded, _excludeMetro, (v) => _refetch(() => _excludeMetro = v)),
        chip(l10n.filterMinTransfers, Icons.swap_horiz_rounded, _minTransfers, (v) => _refetch(() => _minTransfers = v)),
      ]),
    );
  }

  /// "Route list | Quick compare" switch from the design.
  Widget _buildViewSwitch(AppLocalizations l10n) {
    Widget segment(String label, IconData icon, bool active, VoidCallback onTap) => Expanded(
          child: Semantics(
            button: true,
            selected: active,
            child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              // 44dp tall with the border, like any other tap target.
              constraints: const BoxConstraints(minHeight: 42),
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: active ? AppColors.brandBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(GuidyUi.radius),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 15, color: active ? Colors.white : (GuidyUi.mutedText(context))),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12.5,
                            color: active ? Colors.white : (GuidyUi.mutedText(context)))),
                  ),
                ],
              ),
            ),
          ),
          ),
        );
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(GuidyUi.radius),
        border: Border.all(color: AppColors.brandBlue),
      ),
      child: Row(children: [
        segment(l10n.routeListTab, Icons.format_list_bulleted_rounded, !_compare, () => setState(() => _compare = false)),
        segment(l10n.quickCompareTab, Icons.compare_arrows_rounded, _compare, () => setState(() => _compare = true)),
      ]),
    );
  }

  /// Every route side by side: kind, time, fare and walking. Tapping a row
  /// selects that route, same as tapping its card.
  Widget _buildCompareTable(AppLocalizations l10n, List<Map<String, dynamic>> options) {
    final muted = GuidyUi.mutedText(context);
    TextStyle head(Color c) => TextStyle(fontSize: 11.5, color: c);
    Widget cell(String text, Color color, {FontWeight weight = FontWeight.w600}) =>
        Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: weight, color: color));
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GuidyCard(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(color: GuidyUi.chipFill(context), borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Expanded(flex: 5, child: Text(l10n.routeOptionsTitle, style: head(muted))),
                Expanded(flex: 4, child: Row(children: [Icon(Icons.schedule_rounded, size: 13, color: context.accentAmber), const SizedBox(width: 3), Flexible(child: Text(l10n.statDuration, style: head(context.accentAmber), overflow: TextOverflow.ellipsis))])),
                Expanded(flex: 4, child: Row(children: [const Icon(Icons.paid_outlined, size: 13, color: GuidyUi.green), const SizedBox(width: 3), Flexible(child: Text(l10n.statFare, style: head(GuidyUi.greenText(context)), overflow: TextOverflow.ellipsis))])),
                Expanded(flex: 4, child: Row(children: [const Icon(Icons.directions_walk_rounded, size: 13, color: AppColors.brandBlue), const SizedBox(width: 3), Flexible(child: Text(l10n.vehicleWalk, style: head(AppColors.brandBlue), overflow: TextOverflow.ellipsis))])),
              ]),
            ),
            for (var i = 0; i < options.length; i++)
              Builder(builder: (context) {
                final o = _effectiveOption(i, options[i]);
                final type = (o['type'] ?? '').toString();
                final walkM = _walkMeters(o);
                final selected = i == _selected;
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _select(i, options),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.brandBlue.withValues(alpha: context.isDark ? 0.16 : 0.07) : null,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      Expanded(flex: 5, child: cell(InstructionFormatter.routeTierLabel(l10n, type), muted, weight: FontWeight.w400)),
                      // Over an hour, the hours over the minutes: "1 h 18 min"
                      // in one line would be cut in this column.
                      Expanded(
                          flex: 4,
                          child: Text(l10n.durationLines(_num(o['time'])).join('\n'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.accentAmber))),
                      Expanded(flex: 4, child: cell(type == 'Walk' ? l10n.fareFree : InstructionFormatter.fareText(l10n, o), GuidyUi.greenText(context))),
                      Expanded(flex: 4, child: cell(_distance(l10n, walkM), AppColors.brandBlue)),
                    ]),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  String _opensAt(Map<String, dynamic> ns) =>
      ((localeController.isArabic ? ns['usual_opens_at_ar'] : ns['usual_opens_at']) ?? ns['usual_opens_at'] ?? '')
          .toString();

  /// Late at night: either what is running now is the first card, or
  /// nothing can get the rider there until the usual lines reopen.
  Widget _buildNightNotice(AppLocalizations l10n, Map<String, dynamic> data) {
    final ns = RouteOptionsScreen.nightServiceOf(data);
    if (ns == null) return const SizedBox.shrink();
    final nothing = ns['nothing_running'] == true;
    final time = _opensAt(ns);
    final wait = l10n.duration(_num(ns['usual_opens_in_min']));
    final color = nothing ? const Color(0xFFDC2626) : const Color(0xFF6366F1);
    return Container(
      key: const ValueKey('night-notice'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(nothing ? Icons.do_not_disturb_on_rounded : Icons.nightlight_round, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nothing ? l10n.nightNothingRunningTitle : l10n.nightAvailableTitle,
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: context.textPrimary)),
                const SizedBox(height: 4),
                Text(nothing ? l10n.nightNothingRunningBody(time, wait) : l10n.nightAvailableBody(time, wait),
                    style: TextStyle(fontSize: 13, height: 1.35, color: context.textPrimary)),
                if (nothing && ns['can_walk'] == true) ...[
                  const SizedBox(height: 4),
                  Text(l10n.nightCanWalk,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimary)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartialNotice(AppLocalizations l10n, List<Map<String, dynamic>> options) {
    final partial = options.where((o) => o['partial'] == true).cast<Map<String, dynamic>?>().firstWhere(
          (_) => true,
          orElse: () => null,
        );
    if (partial == null) return const SizedBox.shrink();
    final km = ((_num(partial['uncovered_m']) ?? 0) / 1000).toStringAsFixed(1);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.partialUncoveredNotice(l10n.distanceKm(km)),
              style: TextStyle(fontSize: 13, color: context.textPrimary)),
          if (partial['last_covered_stop'] != null)
            Text(l10n.partialLastCoveredStop(partial['last_covered_stop'].toString()),
                style: TextStyle(fontSize: 12, color: context.textSecondary)),
          TextButton.icon(
            onPressed: () => _reportMissingRoute(
              failureCode: 'partial',
              uncoveredM: _num(partial['uncovered_m'])?.round(),
              lastCoveredStop: partial['last_covered_stop']?.toString(),
            ),
            icon: const Icon(Icons.add_road_rounded, size: 18),
            label: Text(l10n.reportMissingRouteButton),
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryTeal, padding: EdgeInsets.zero),
          ),
        ],
      ),
    );
  }

  /// Why a route can't be taken right now, if it can't.
  String? _closedNote(AppLocalizations l10n, Map<String, dynamic> option) {
    final night = _lastNight;
    final usualOnly = RouteOptionsScreen.isUsualOnly(option, night);
    final closed = usualOnly ||
        option['is_operating'] == false ||
        (option['closed_lines'] is List && (option['closed_lines'] as List).isNotEmpty);
    if (!closed) return null;
    return usualOnly && night != null ? l10n.nightUsualRoute(_opensAt(night)) : l10n.plannerClosedNow;
  }

  /// Simple mode: the easiest one to three routes as big plain-word cards,
  /// each with its own "Start this trip" button, and a way back Home. No
  /// filters, comparison table, map sheet or share button.
  Widget _buildSimple(AppLocalizations l10n, Map<String, dynamic> data, List<Map<String, dynamic>> options) {
    final shown = SimpleModeController.easiest(options);
    return ListView(
      key: const ValueKey('simple_route_list'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(l10n.simpleRoutesHint, style: TextStyle(fontSize: 18, color: context.textSecondary, height: 1.3)),
        const SizedBox(height: 12),
        _buildNightNotice(l10n, data),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(l10n.simpleNoRoutes,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.textPrimary, height: 1.3)),
          ),
        for (var n = 0; n < shown.length; n++)
          SimpleRouteCard(
            summary: RouteSummary.of(l10n, _effectiveOption(shown[n], options[shown[n]])),
            number: n + 1,
            easiest: n == 0,
            closedNote: _closedNote(l10n, _effectiveOption(shown[n], options[shown[n]])),
            onStart: () => _start(data, shown[n], options[shown[n]]),
          ),
        if (shown.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SimpleButton(
              key: const ValueKey('simple-better-route'),
              icon: Icons.tips_and_updates_outlined,
              label: l10n.betterRouteButton,
              onPressed: _betterRoute,
            ),
          ),
        const SimpleHomeButton(),
      ],
    );
  }

  /// One compact card per route (RouteCard). Tapping it selects the route
  /// on the map and opens its detail page.
  Widget _buildRouteCard(AppLocalizations l10n, Map<String, dynamic> data, int index, List<Map<String, dynamic>> options) {
    final option = _effectiveOption(index, options[index]);
    final closedNote = _closedNote(l10n, option);
    return RouteCard(
      key: ValueKey('route-card-$index'),
      summary: RouteSummary.of(l10n, option),
      selected: index == _selected,
      closedNote: closedNote,
      onTap: () => _tapCard(data, index, options, closedNote),
    );
  }

  /// Total walking in a route, in metres.
  int _walkMeters(Map<String, dynamic> option) => _instructions(option)
      .where((s) => (s['action'] ?? '').toString().contains('walk'))
      .fold<num>(0, (t, s) => t + (_num(s['distance_m']) ?? 0))
      .round();

  String _distance(AppLocalizations l10n, num? meters) {
    final m = (meters ?? 0).round();
    if (m >= 1000) return l10n.distanceKm((m / 1000).toStringAsFixed(1));
    return l10n.plannerMeters('$m');
  }


}
