import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding, SchedulerPhase, Ticker;
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../l10n/app_localizations.dart';
import '../services/theme_controller.dart';
import '../services/instruction_formatter.dart';
import '../services/location_fallback.dart';
import '../services/analytics_service.dart';
import '../services/review_service.dart';
import '../services/live_tracking_service.dart';
import '../services/interstitial_ad_service.dart';
import '../services/navigation_session.dart';
import '../services/current_trip.dart';
import '../services/trip_notification.dart';
import '../services/trip_history_service.dart';
import '../services/map_marker_service.dart';
import '../widgets/guidy_tool_rail.dart';
import '../widgets/quick_commute_report_sheet.dart';
import '../widgets/ride_report_sheet.dart';
import '../widgets/walk_report_sheet.dart';
import '../services/walk_feedback_service.dart';
import 'trip/walk_step_ends.dart';
import '../theme/app_theme.dart';
import '../theme/guidy_ui.dart';
import '../services/locale_controller.dart';
import 'MainNavigator.dart';
import '../utils/minutes_text.dart';
import '../utils/fare_text.dart';
import '../utils/route_line_style.dart';
import '../services/trip_recorder.dart';
import '../services/trip_pip.dart';
import '../services/tour_service.dart';
import '../widgets/guidy_tour.dart';
import '../services/ride_report_service.dart';
import '../services/simple_mode.dart';
import 'package:share_plus/share_plus.dart';
import '../services/share_links.dart';
import '../utils/nav_math.dart';
import '../utils/route_progress.dart';
import 'trip/trip_plan.dart';
import 'trip/trip_progress.dart';
import 'trip/trip_location.dart';
import 'trip/trip_live_share.dart';
import 'trip/trip_maneuver.dart';
import 'trip/nav_camera.dart';
import 'trip/trip_puck.dart';
import 'trip/next_stop_line.dart';
import 'trip/vehicle_switch.dart';
import 'trip/trip_markers.dart';
import '../widgets/trip/trip_end_button.dart';
import '../widgets/trip/trip_maneuver_card.dart';
import '../widgets/trip/trip_arrival_sheet.dart';
import '../widgets/trip/trip_step_tile.dart';
import '../widgets/trip/trip_pip_rundown.dart';
import '../widgets/trip/trip_round_button.dart';
import '../widgets/trip/trip_boarding_options.dart';
import '../widgets/trip/trip_now_card.dart';
import '../widgets/trip/trip_toast.dart';
import '../widgets/trip/trip_stop_alarm_banner.dart';
import '../widgets/trip/trip_map_buttons.dart';
import '../widgets/trip/trip_sheets.dart';
import '../widgets/simple/simple_step_panel.dart';
import '../widgets/simple/simple_ui.dart';

/// Turn-by-turn navigation with high-DPI custom markers,
/// styled walking vs. transit polylines, auto-framing,
/// stop proximity alarms, and Egyptian transit localizations.
class MapScreen extends StatefulWidget {
  final Map<String, dynamic> pathData;
  final String? startName;
  final String? endName;

  /// The trip-history entry recorded when navigation started; marked
  /// completed when the rider arrives. Null when navigation was opened
  /// from somewhere that doesn't record a trip.
  final String? historyEntryId;

  /// When true, the trip is written to history only once the rider
  /// actually arrives (GPS reaches the last step). Leaving early records
  /// nothing.
  final bool recordHistoryOnArrival;

  /// The other routes that were offered for this trip, each a pathData
  /// ready for MapScreen. They are drawn faintly under the active route;
  /// tapping one switches to it mid-trip.
  final List<Map<String, dynamic>> alternatives;

  /// The step to open on, and when the trip began: set when a trip in
  /// progress is reopened from Home or after a restart (see CurrentTrip).
  final int initialStep;
  final DateTime? startedAt;

  const MapScreen({
    super.key,
    required this.pathData,
    this.startName,
    this.endName,
    this.historyEntryId,
    this.recordHistoryOnArrival = false,
    this.alternatives = const [],
    this.initialStep = 0,
    this.startedAt,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  final Set<Polyline> _routePolylines = {};
  final List<LatLng> _allPoints = [];
  final List<List<LatLng>> _walkSegments = [];
  Color _mainRouteColor = AppColors.primaryTeal;
  List<dynamic> _instructions = [];
  final List<LatLng?> _stepPoints = [];

  /// Distance-along-route view of the trip (see RouteProgress). Rebuilt
  /// when a step's point moves (a vehicle switch).
  RouteProgress? _progress;

  /// When the rider has reached a step (the stop alarm and the two-fix
  /// vote that stops one GPS jump skipping a step).
  final StepTracker _stepTracker = StepTracker();

  /// "I took a vehicle" during a long walk: the ride being recorded.
  RideReport? _rideReport;

  BitmapDescriptor? _startIcon;
  BitmapDescriptor? _endIcon;
  BitmapDescriptor? _transferIcon;
  BitmapDescriptor? _stationIcon;
  Set<Marker> _staticMarkers = {};
  final ValueNotifier<Set<Marker>> _markersNotifier = ValueNotifier<Set<Marker>>({});
  num? _asNum(dynamic val) => InstructionFormatter.asNum(val);

  bool _stopAlarmEnabled = true;
  String? _upcomingAlarmStation;
  String _destinationTitle = '';

  final ValueNotifier<LatLng?> _currentLocation = ValueNotifier(null);
  final ValueNotifier<String> _distanceToNextStop = ValueNotifier("");

  /// What is left of the whole trip, live: minutes, metres and the clock
  /// time it ends. Null until there is a position to measure from.
  final ValueNotifier<({double minutes, double meters, DateTime arrival})?> _remaining = ValueNotifier(null);

  /// The clock moves even when the rider doesn't (a red light, a wait for
  /// the bus): the arrival time is refreshed on this too.
  Timer? _remainingTimer;
  final ValueNotifier<String?> _locationProblem = ValueNotifier(null);
  final ValueNotifier<double> _cameraBearing = ValueNotifier(0);
  CameraPosition? _lastCamera;

  /// North-up: stop following the rider's heading and turn the map back.
  void _resetNorth() {
    final cam = _lastCamera;
    if (cam == null) return;
    HapticFeedback.selectionClick();
    setState(() => _followMode = false);
    _moveCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: cam.target, zoom: cam.zoom, bearing: 0, tilt: 0)),
    );
  }

  void _toggleStopAlarm(AppLocalizations l10n) {
    HapticFeedback.heavyImpact();
    setState(() {
      _stopAlarmEnabled = !_stopAlarmEnabled;
      if (!_stopAlarmEnabled) {
        _upcomingAlarmStation = null;
      }
    });
    if (_stopAlarmEnabled) {
      _showStopAlarmOnToast(l10n);
    } else {
      _showFloatingToast(l10n.navStopAlarmDisabledToast, icon: Icons.notifications_off_outlined);
    }
  }

  /// "Stop alert: on". Only when the rider switches it on, or as a ride
  /// starts (see _advanceTo): the alarm is for rides, and at the start of
  /// a trip that begins on foot it was one more orange box over the map.
  void _showStopAlarmOnToast(AppLocalizations l10n) => _showFloatingToast(
        l10n.navStopAlarmActiveToast,
        icon: Icons.notifications_active_rounded,
        color: const Color(0xFFE76F51),
      );

  bool _hasLoggedArrival = false;
  AppLocalizations? _l10n;
  num? _totalFare;
  int? _totalDurationMinutes;

  String? _floatingToastMessage;
  IconData? _floatingToastIcon;
  Color? _floatingToastColor;
  Timer? _floatingToastTimer;

  BitmapDescriptor? _userPuckIcon;
  Marker? _userMarker;

  // ------------------------------------------------------------- the puck
  //
  // One frame loop (_puckTicker) owns the rider's dot and, in follow mode,
  // the camera; TripPuck decides what each frame draws. It used to be three
  // writers (an eased animation per fix, the compass handler, a throttled
  // camera animation to the RAW fix): the dot sped up and stopped every
  // second and the camera ran ahead of it -- the "glitchy" icon.
  late final Ticker _puckTicker;

  /// The dot and the follow-mode camera, frame by frame (see TripPuck).
  final TripPuck _puck = TripPuck(zoom: _navZoom, tilt: _navTilt);

  /// Takes the wander out of fixes before they reach the dot.
  final FixSmoother _smoother = FixSmoother();

  /// GPS, its permission and the compass. Owns their subscriptions.
  late final TripLocation _location = TripLocation(
    onPosition: _onGpsPositionReceived,
    onLastKnown: _onLastKnownPosition,
    onHeading: _onCompassHeading,
    onProblem: _onLocationProblem,
    foreground: TripNotification.foregroundConfig,
    onForegroundService: (running) => TripNotification.foregroundService.value = running,
  );

  bool _isUserMoving = false;
  Position? _lastGpsPosition;
  Timer? _stationaryTimer;

  final LiveTrackingService _liveTracking = LiveTrackingService();

  /// The detailed log of this trip (see TripRecorder).
  late final TripRecorder _recorder;

  /// The opted-in path of each walking step (see WalkTraceRecorder).
  late final WalkTraceRecorder _walkTraces;

  /// Walking steps the rider has already said are wrong.
  final Set<int> _reportedWalks = {};
  final Map<int, WalkStepInfo?> _walkInfoCache = {};

  /// "Follow my trip" share, while one is running (see ShareLinks).
  final TripLiveShare _liveShare = TripLiveShare();
  GoogleMapController? _mapController;

  final DraggableScrollableController _sheet = DraggableScrollableController();
  final ScrollController _stepsScroll = ScrollController();

  /// Where the sheet is, as a fraction of the screen; null until it first
  /// moves (it opens at the half stop). The map is padded by it so the
  /// rider's dot stays above the sheet, not under it.
  double? _sheetExtent;

  void _onSheetMoved() {
    if (!mounted || !_sheet.isAttached) return;
    // The window changing size (the floating window opening) moves the sheet
    // while it is being laid out, too late in the frame to rebuild this
    // screen: catch up once the frame is done.
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _onSheetMoved());
      return;
    }
    final size = _sheet.size;
    if (_sheetExtent == null || (size - _sheetExtent!).abs() >= 0.02) setState(() => _sheetExtent = size);
  }

  /// The sheet header (handle and "Now" card), measured after layout. The
  /// lowest stop is at least this tall, so pulling the sheet down never
  /// cuts the card off at the ad banner whatever the phone's height or
  /// text size.
  final GlobalKey _sheetHeaderKey = GlobalKey(debugLabel: 'sheet_header');
  double _sheetHeaderHeight = 0;

  void _measureSheetHeader() {
    if (!mounted) return;
    final h = _sheetHeaderKey.currentContext?.size?.height;
    if (h != null && (h - _sheetHeaderHeight).abs() > 1) setState(() => _sheetHeaderHeight = h);
  }

  /// The sheet's lowest stop as a fraction of [parentHeight].
  double _peekFor(BuildContext c, double parentHeight, double half) {
    final double base = _peekOf(c);
    if (parentHeight <= 0 || _sheetHeaderHeight <= 0) return base;
    return math.max(base, _sheetHeaderHeight / parentHeight).clamp(base, half - 0.04);
  }

  /// The sheet's snap stops, the same list for as long as they don't
  /// change. The screen rebuilds while the sheet moves (_onSheetMoved), and
  /// DraggableScrollableSheet compares snapSizes by identity: a new list on
  /// each rebuild reads as new snap sizes, and it snaps the sheet back from
  /// under the finger -- the trip cards couldn't be dragged at all.
  List<double> _snapSizesFor(double half) {
    final current = _snapSizes;
    if (current != null && current.single == half) return current;
    return _snapSizes = List.unmodifiable([half]);
  }

  List<double>? _snapSizes;

  /// Sheet snap points, as a fraction of screen height.
  ///
  /// Landscape needs bigger fractions of a much shorter screen: 24% of a
  /// portrait phone is a readable instruction, 24% of a landscape one is a
  /// sliver. These are read per build from the current orientation, and the
  /// sheet is keyed on orientation so rotating rebuilds it against the new
  /// bounds instead of leaving it at a size that is now out of range.
  double _peekOf(BuildContext c) => _isLandscape(c) ? 0.34 : 0.24;
  double _halfOf(BuildContext c) => _isLandscape(c) ? 0.62 : 0.52;
  double _fullOf(BuildContext c) => _isLandscape(c) ? 0.94 : 0.88;
  bool _isLandscape(BuildContext c) => MediaQuery.of(c).orientation == Orientation.landscape;

  // ------------------------------------------------------------ nav camera
  //
  // A flat north-up map is a picture of the route. A tilted heading-up one is
  // a picture of what the rider is looking at, which is the whole point at a
  // junction: "the map is turning left, so I turn left." Google, Waze and
  // dashboard nav unit converge on the same four settings, and each carries
  // its own weight:
  //
  //   tilt      leans the map away so the road ahead occupies more pixels
  //             than the road behind, which is the ratio a rider needs
  //   bearing   rotates so "up" is "the way I am facing", removing the
  //             mental step of matching a north-up map to the street
  //   zoom      close enough that the next turn is legible
  //   padding   pushes the rider's dot low on screen, because the useful
  //             half of the view is what's ahead of them
  static const double _navTilt = 50;

  static const double _navZoom = 17.5;

  /// Follow mode: camera tracks the rider, tilted and heading-up. Panning the
  /// map turns it off (the rider wants to look somewhere else, and a camera
  /// that yanks itself back is the single most irritating thing a nav screen
  /// can do); the re-centre button turns it back on.
  bool _followMode = true;

  double _lastHeading = 0;

  /// Where the rider physically is. GPS writes this; taps never do.
  int _currentStepIndex = 0;

  /// Which steps the rider has unfolded. Taps write this; GPS never does.
  final Set<int> _expandedSteps = {};

  @override
  void initState() {
    super.initState();
    _puckTicker = createTicker(_onPuckTick);
    _sheet.addListener(_onSheetMoved);
    _parsePathData();
    // Reopened mid-trip: carry on from the step the rider was at.
    if (_instructions.isNotEmpty) _currentStepIndex = widget.initialStep.clamp(0, _instructions.length - 1);
    // One trip at a time: this replaces any other (see CurrentTrip).
    // After this frame: Home listens to it and is mid-build right now.
    final firstStep = _currentStepIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(CurrentTrip.begin(
        pathData: widget.pathData,
        alternatives: widget.alternatives,
        startName: widget.startName,
        endName: widget.endName,
        historyEntryId: widget.historyEntryId,
        recordHistoryOnArrival: widget.recordHistoryOnArrival,
        step: firstStep,
        startedAt: widget.startedAt,
      ));
    });
    _recorder = TripRecorder(pathData: widget.pathData, startName: widget.startName, endName: widget.endName);
    _walkTraces = WalkTraceRecorder(tripId: _recorder.id);
    if (widget.startedAt != null) _recorder.onEvent('resumed', {'step': _currentStepIndex});
    unawaited(WalkFeedbackService.flushAll());
    WidgetsBinding.instance.addObserver(this);
    _syncLiveTrackingForCurrentStep();
    _loadCustomIcons();
    _location.startCompass();
    _remainingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshRemaining();
      CurrentTrip.expireIfStale();
      unawaited(CurrentTrip.touch());
    });
    CurrentTrip.active.addListener(_onCurrentTripChanged);
    NavigationSession.begin();
    TripNotification.start();
    TripNotification.liveScreenVisible.value = true;
    InterstitialAdService.instance.preload();
    // Leaving the app mid-trip keeps the trip in a floating window
    // (Android picture-in-picture, see TripPip).
    TripPip.active.addListener(_onPipChanged);
    unawaited(TripPip.setAvailable(true));
    if (GuidyTour.autoStart) {
      Future.delayed(const Duration(milliseconds: 1500), _maybeTripTour);
    }
    AnalyticsService.setCrashlyticsKey('is_navigating', true);
    AnalyticsService.setCrashlyticsKey('active_screen', 'MapScreen');
    AnalyticsService.setCrashlyticsKey('active_step', 0);
    AnalyticsService.logBreadcrumb('MapScreen: Navigation started');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _location.start();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _l10n = AppLocalizations.of(context);
    // A language switch from anywhere redraws the names in the new one,
    // the map markers' titles included.
    final isAr = _isArabicNow;
    _updateLocalizedDestination(isAr);
    if (_markersLanguageAr != null && _markersLanguageAr != isAr) _buildMarkers();
    _updateDistanceDisplay();
  }

  void _showFloatingToast(String message, {IconData icon = Icons.info_outline, Color? color}) {
    _floatingToastTimer?.cancel();
    setState(() {
      _floatingToastMessage = message;
      _floatingToastIcon = icon;
      _floatingToastColor = color;
    });
    _floatingToastTimer = Timer(const Duration(milliseconds: 2800), () {
      if (mounted) {
        setState(() => _floatingToastMessage = null);
      }
    });
  }

  // ---------------------------------------------------------------- parsing
  void _parsePathData() {
    // Runs from initState, before Theme can be read: resolve the theme the
    // same way the app does.
    final mode = themeController.value;
    final dark = mode == ThemeMode.dark ||
        (mode == ThemeMode.system &&
            WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);
    final plan = TripPlan.fromPathData(widget.pathData, defaultColor: _mainRouteColor, dark: dark);
    _instructions = plan.instructions;
    _stepPoints.addAll(plan.stepPoints);
    _updateLocalizedDestination(localeController.isArabic);
    _totalFare = plan.totalFare;
    _totalDurationMinutes = plan.totalDurationMinutes;
    _mainRouteColor = plan.routeColor;
    _walkSegments
      ..clear()
      ..addAll(plan.walkSegments);
    _allPoints.addAll(plan.allPoints);
    for (var i = 0; i < plan.segments.length; i++) {
      final seg = plan.segments[i];
      if (seg.isWalk) {
        // Coloured for the theme in build(): see _themedPolylines.
        _routePolylines.add(RouteLineStyle.walk('walk_$i', seg.points, dark: false));
      } else {
        _routePolylines.addAll(RouteLineStyle.ride('route_$i', seg.points, seg.color));
      }
    }
    _addAlternativePolylines();
    _progress = RouteProgress(List.of(_allPoints), List.of(_stepPoints));
  }

  Set<Polyline>? _themedCache;
  String? _themedCacheKey;

  /// The route lines with the walking dots in the colour for the current
  /// theme (Google's walking blue, lighter on the dark map). Simple
  /// mode leaves out the faint alternative routes, so a stray tap can't
  /// offer to switch the trip.
  Set<Polyline> _themedPolylines(bool dark) {
    final simple = simpleMode.value;
    final key = '$dark/$simple';
    if (_themedCache != null && _themedCacheKey == key) return _themedCache!;
    _themedCacheKey = key;
    return _themedCache = _routePolylines
        .where((p) => !(simple && p.polylineId.value.startsWith('alt_')))
        .map((p) => p.polylineId.value.startsWith('walk_') ? p.copyWith(colorParam: RouteLineStyle.walkColor(dark)) : p)
        .toSet();
  }

  /// Faint, tappable lines for the other routes the rider could take.
  void _addAlternativePolylines() {
    for (var a = 0; a < widget.alternatives.length; a++) {
      final segs = widget.alternatives[a]['segments'];
      if (segs is! List) continue;
      var i = 0;
      for (final segment in segs) {
        if (segment is! Map) continue;
        final pts = TripPlan.pointsOfSegment(segment);
        if (pts.length < 2) continue;
        final isWalk = segment['is_walk'] == true || segment['vehicle_type'] == 'walk';
        final altColor = Colors.blueGrey.withValues(alpha: 0.5);
        if (isWalk) {
          _routePolylines.add(
            RouteLineStyle.walk(
              'alt_${a}_$i',
              pts,
              dark: false,
              width: 4,
              zIndex: 0,
              color: altColor,
              consumeTapEvents: true,
              onTap: () => _confirmSwitchRoute(a),
            ),
          );
        } else {
          _routePolylines.add(
            Polyline(
              polylineId: PolylineId('alt_${a}_$i'),
              points: pts,
              width: 5,
              color: altColor,
              jointType: JointType.round,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
              zIndex: 0,
              consumeTapEvents: true,
              onTap: () => _confirmSwitchRoute(a),
            ),
          );
        }
        i++;
      }
    }
  }

  Future<void> _confirmSwitchRoute(int index) async {
    final l10n = _l10n ?? AppLocalizations.of(context);
    final alt = widget.alternatives[index];
    final opt = alt['option'] is Map ? alt['option'] as Map : const {};
    final minutes = l10n.minutes(_asNum(opt['time'] ?? alt['duration_minutes']));
    final fare = _asNum(opt['fare_total_egp'] ?? opt['fare_egp']);
    HapticFeedback.selectionClick();
    final ok = await showSwitchRouteSheet(context, minutes: minutes, fare: fare);
    if (ok != true || !mounted) return;
    _recorder.onEvent('route_switch', {'step': _currentStepIndex, 'to_alternative': index});
    unawaited(_recorder.finish(completed: false, reason: 'switched_route', instructions: _instructions));
    _walkTraces.close();
    final others = <Map<String, dynamic>>[
      widget.pathData,
      for (var i = 0; i < widget.alternatives.length; i++)
        if (i != index) widget.alternatives[i],
    ];
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MapScreen(
          pathData: alt,
          startName: widget.startName,
          endName: widget.endName,
          historyEntryId: widget.historyEntryId,
          recordHistoryOnArrival: widget.recordHistoryOnArrival,
          alternatives: others,
        ),
      ),
    );
  }

  void _updateLocalizedDestination(bool isAr) {
    for (final step in _instructions) {
      if (step is Map && step['action'] == 'arrive') {
        final name = InstructionFormatter.localized(step, 'station', isAr: isAr);
        if (name != null) _destinationTitle = name;
      }
    }
  }

  /// A step's station in the current language ('' if it has none).
  /// The trip was cleared (arrived, End trip, timed out): no more
  /// background location, which also takes the service notification away.
  void _onCurrentTripChanged() {
    if (CurrentTrip.active.value == null) _location.endBackground();
  }

  bool _isRiding(int index) =>
      TripPlan.isRide(index >= 0 && index < _instructions.length ? _instructions[index] : null);

  static String _stationOf(dynamic step, bool isAr) =>
      step is Map ? (InstructionFormatter.localized(step, 'station', isAr: isAr) ?? '') : '';

  bool get _isArabicNow => Localizations.localeOf(context).languageCode == 'ar';

  Future<void> _loadCustomIcons() async {
    try {
      _startIcon = await MapMarkerService.getOriginMarker();
      _endIcon = await MapMarkerService.getDestinationMarker();
      _transferIcon = await MapMarkerService.getTransferMarker();
      _stationIcon = await MapMarkerService.getStationStopMarker(color: _mainRouteColor);
      _userPuckIcon = await MapMarkerService.getUserPuckMarker();
      _buildMarkers();
    } catch (e) {
      debugPrint("Error loading custom icons: $e");
    }
  }

  /// The language the markers' titles were last built in.
  bool? _markersLanguageAr;

  void _buildMarkers() {
    if (_allPoints.isEmpty) return;
    _markersLanguageAr = localeController.isArabic;
    final markers = tripMarkers(
      route: _allPoints,
      instructions: _instructions,
      destinationTitle: _destinationTitle,
      isArabic: localeController.isArabic,
      icons: (start: _startIcon, end: _endIcon, transfer: _transferIcon, station: _stationIcon),
    );

    _staticMarkers = markers;
    final allMarkers = {..._staticMarkers};
    if (_userMarker != null) {
      allMarkers.add(_userMarker!);
    }
    _markersNotifier.value = allMarkers;
  }

  void _onCompassHeading(double heading) {
    // The plugin already corrects for the screen being rotated (portrait,
    // landscape, upside down), so this is where the top of the screen points.
    if (_puck.onCompass(heading)) _wakePuck();
  }

  /// Every frame: move the dot along its current leg, ease the arrow and the
  /// camera towards their targets, and push to the map at most ~30 times a
  /// second, only when something visibly changed.
  void _wakePuck() {
    if (mounted && !_puckTicker.isActive) _puckTicker.start();
  }

  void _onPuckTick(Duration _) {
    if (!mounted) return;
    final frame = _puck.tick(follow: _followMode, hasMap: _mapController != null);
    if (frame.stop) _puckTicker.stop();
    if (!frame.push) return;
    _pushUserMarker();
    if (_followMode) _placeCamera();
  }

  void _placeCamera() {
    final c = _mapController;
    if (c == null) return;
    final cam = _puck.placeCamera(_lastCamera);
    if (cam != null) c.moveCamera(CameraUpdate.newCameraPosition(cam));
  }

  void _onMapTouched() {
    if (_followMode && mounted) setState(() => _followMode = false);
  }

  void _pushUserMarker() {
    final pos = _puck.shownPos;
    if (pos == null || !mounted) return;
    final marker = Marker(
      markerId: const MarkerId('guidy_user_puck'),
      position: pos,
      rotation: _puck.shownHeading,
      anchor: MapMarkerService.centerAnchor,
      flat: true,
      zIndexInt: 99,
      icon: _userPuckIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
    );
    _userMarker = marker;
    _markersNotifier.value = {..._staticMarkers, marker};
  }

  /// A new GPS fix for the dot: smoothed (FixSmoother), then drawn on the
  /// route when within GPS error of it, so the dot runs along the street
  /// instead of across it. The map's heading is read from there too, not
  /// from the raw fix, which wanders.
  void _feedPuck(Position position) {
    final smooth = _smoother.add(
      LatLng(position.latitude, position.longitude),
      accuracy: position.accuracy,
      speed: position.speed,
      course: position.heading,
      at: position.timestamp,
    );
    final fix = NavMath.snapToRoute(
      _allPoints,
      smooth,
      accuracy: position.accuracy,
      nearAlong: _progress?.lastAlong,
    );
    _puck.feed(
      fix,
      speed: position.speed,
      accuracy: position.accuracy,
      course: position.heading,
      routeHeading: _headingFor(position, at: fix),
    );
    _wakePuck();
  }

  void _onGpsPositionReceived(Position position) {
    _recorder.onFix(position, _currentStepIndex);
    _walkTraces.onFix(
      lat: position.latitude,
      lon: position.longitude,
      accuracy: position.accuracy,
      time: position.timestamp,
      step: _currentStepIndex,
      walk: _walkInfo(_currentStepIndex),
    );
    final ride = _rideReport;
    if (ride != null) {
      ride.addFix(position.latitude, position.longitude, position.timestamp);
      if (mounted) setState(() {}); // the recording line's distance and time
    }
    if (_liveShare.current?.isDue ?? false) {
      final here = LatLng(position.latitude, position.longitude);
      _liveShare.onFix(here, step: _currentStepIndex, heading: _puck.shownHeading, eta: _estimatedArrival(here));
    }
    // 1. Detect movement
    final double speed = position.speed; // meters per second
    bool moved = speed >= 0.5;
    if (!moved && _lastGpsPosition != null) {
      final d = Geolocator.distanceBetween(
        _lastGpsPosition!.latitude,
        _lastGpsPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      moved = d >= 2.0;
    }

    _stationaryTimer?.cancel();
    if (moved) {
      if (!_isUserMoving && mounted) {
        setState(() => _isUserMoving = true);
      }
      _stationaryTimer = Timer(const Duration(milliseconds: 3500), () {
        if (mounted && _isUserMoving) {
          setState(() => _isUserMoving = false);
        }
      });
    } else {
      if (_isUserMoving && mounted) {
        setState(() => _isUserMoving = false);
      }
    }
    _lastGpsPosition = position;

    // 2. The dot (and, in follow mode, the camera) glide there frame by
    // frame -- see _onPuckTick.
    final newTarget = LatLng(position.latitude, position.longitude);
    _feedPuck(position);

    // 3. Keep current location value notifier and navigation updated
    _currentLocation.value = newTarget;
    _locationProblem.value = null;
    _checkRiderNearStart(newTarget);
    _updateDistanceDisplay();
    _checkIfApproachingNextStep();
    _liveTracking.onPositionUpdate(position.latitude, position.longitude);
  }

  // ------------------------------------------------------------ nav camera
  /// One-off camera moves (overview, trip start, a step). While following
  /// the rider the frame loop places the camera instead (_placeCamera).
  void _moveCamera(CameraUpdate update) {
    if (_mapController == null) return;
    _mapController!.animateCamera(update);
  }

  /// The heading to point the map at, given a fresh fix; the route's way
  /// is read from [at] (the dot) when given.
  double _headingFor(Position position, {LatLng? at}) => _lastHeading = NavCamera.headingFor(
        speed: position.speed,
        course: position.heading,
        here: at ?? LatLng(position.latitude, position.longitude),
        route: _allPoints,
        last: _lastHeading,
        nearAlong: _progress?.lastAlong,
      );

  /// Puts the camera behind and below the rider, looking the way they're
  /// going. Throttled, and skipped entirely when the rider has taken manual
  /// control of the map.
  /// Null until the first GPS fix; false while a trip planned from
  /// somewhere else has the rider far from its start.
  bool? _riderAtStart;
  static const double _awayFromStartM = 300;

  /// A trip planned from another place (not "my location") should open on
  /// that place, not on wherever the rider happens to be. The camera stays
  /// on the start until the rider gets there, then follows them as usual.
  void _checkRiderNearStart(LatLng here) {
    if (_allPoints.isEmpty) return;
    final start = _allPoints.first;
    final bool near = NavCamera.distance(here, start) <= _awayFromStartM;
    if (_riderAtStart == null) {
      _riderAtStart = near || _currentStepIndex > 0;
      if (!_riderAtStart!) {
        if (mounted) setState(() => _followMode = false);
        _showTripStart();
      }
    } else if (_riderAtStart == false && near) {
      _riderAtStart = true;
      if (mounted) setState(() => _followMode = true);
      _wakePuck();
    }
  }

  void _showTripStart() {
    if (_allPoints.isEmpty) return;
    final bearing = _allPoints.length >= 2 ? NavCamera.bearing(_allPoints[0], _allPoints[1]) : 0.0;
    _moveCamera(CameraUpdate.newCameraPosition(CameraPosition(target: _allPoints.first, zoom: 16.5, bearing: bearing)));
  }

  /// Back to following the rider, from wherever they panned to.
  Future<void> _recenter() async {
    HapticFeedback.selectionClick();
    final l10n = _l10n ?? AppLocalizations.of(context);
    setState(() => _followMode = true);
    _wakePuck();

    final here = _currentLocation.value;
    if (here != null) {
      final routeBearing = NavCamera.forwardRouteBearing(_allPoints, _puck.shownPos ?? here,
          fallback: _lastHeading, nearAlong: _progress?.lastAlong);
      _lastHeading = routeBearing;
      // The frame loop glides the camera back from wherever it is now.
      _puck.recenterFrom(_lastCamera, bearing: routeBearing);
      _wakePuck();
      _showFloatingToast(l10n.navRecenterSuccess, icon: Icons.my_location_rounded, color: AppColors.primaryTeal);
      return;
    }

    _showFloatingToast(l10n.navRecenterFinding, icon: Icons.location_searching_rounded);

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: LocationFallback.fix(accuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 4)),
      );
      if (!mounted) return;
      _currentLocation.value = LatLng(pos.latitude, pos.longitude);
      _locationProblem.value = null;
      _updateDistanceDisplay();
      _moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentLocation.value!, zoom: _navZoom, tilt: _navTilt, bearing: _headingFor(pos)),
        ),
      );
      _showFloatingToast(l10n.navRecenterSuccess, icon: Icons.my_location_rounded, color: AppColors.primaryTeal);
    } catch (e) {
      LocationFallback.noteError(e);
      if (!mounted) return;
      if (_allPoints.isNotEmpty) {
        _moveCamera(CameraUpdate.newLatLngZoom(_allPoints.first, 16.0));
        _showFloatingToast(l10n.navRecenterFallback, icon: Icons.navigation_rounded);
      }
    }
  }

  /// Zooms and fits the full route in the camera viewport
  void _fitRouteBounds({bool animated = true}) {
    if (_mapController == null || _allPoints.isEmpty) return;
    setState(() => _followMode = false);

    if (_allPoints.length == 1) {
      final update = CameraUpdate.newLatLngZoom(_allPoints.first, 15.0);
      if (animated) {
        _moveCamera(update);
      } else {
        _mapController!.moveCamera(update);
      }
      return;
    }

    final update = CameraUpdate.newLatLngBounds(NavCamera.boundsOf(_allPoints), 60);
    if (animated) {
      _moveCamera(update);
    } else {
      _mapController!.moveCamera(update);
    }
  }

  /// The whole trip, flat and north-up.
  void _showOverview() {
    HapticFeedback.selectionClick();
    final l10n = _l10n ?? AppLocalizations.of(context);
    _fitRouteBounds(animated: true);
    _showFloatingToast(l10n.navOverviewToast, icon: Icons.fit_screen_rounded);
  }

  /// How much of the screen the sheet covers, for the map's padding: where
  /// it is, from its lowest stop up to the half stop. Pulled up further,
  /// the rider is reading the steps, and the map stays as at half.
  double _sheetCovers(BuildContext context, double height) {
    if (_instructions.isEmpty) return _peekOf(context);
    // Simple mode: a fixed panel about this tall, instead of the sheet.
    if (simpleMode.value && !TripPip.active.value) return 0.42;
    final half = _halfOf(context);
    final peek = _peekFor(context, height, half);
    return (_sheetExtent ?? half).clamp(peek, half);
  }

  /// Map padding: see NavCamera.padding.
  EdgeInsets _mapPadding(BuildContext context) {
    final double height = MediaQuery.of(context).size.height;
    return NavCamera.padding(
      height: height,
      sheetFraction: _sheetCovers(context, height),
      follow: _followMode,
      floatingWindow: TripPip.active.value,
    );
  }

  // ---------------------------------------------------------------- location
  /// Handles every permission outcome. The previous version only tested for
  /// `denied`; `deniedForever` — what you get after "Don't ask again" — fell
  /// through to `getCurrentPosition()`, which throws, uncaught and unawaited.
  /// Losing GPS mid-trip is normal here too: parts of Line 3 run underground,
  /// so the stream needs an onError.
  /// The phone's cached position, before the first fix: show it at once.
  void _onLastKnownPosition(Position last) {
    if (!mounted || _currentLocation.value != null) return;
    final p = LatLng(last.latitude, last.longitude);
    _puck.showAt(p);
    _wakePuck();
    _currentLocation.value = p;
    _updateDistanceDisplay();
  }

  void _onLocationProblem(LocationProblem problem) {
    if (!mounted) return;
    final l10n = _l10n ?? AppLocalizations.of(context);
    _locationProblem.value = switch (problem) {
      LocationProblem.off => l10n.navLocationOff,
      LocationProblem.blocked => l10n.navLocationBlocked,
      LocationProblem.lost => l10n.navLocationLost,
    };
  }

  void _syncLiveTrackingForCurrentStep() {
    if (_instructions.isEmpty || _currentStepIndex >= _instructions.length) return;
    final step = _instructions[_currentStepIndex] as Map<String, dynamic>;
    final routeId = step['route_id'];
    final action = step['action'];
    final isTransitLeg = (action == 'board' || action == 'transfer') && routeId != null;
    if (isTransitLeg) {
      _liveTracking.startLeg(routeId: routeId as String, directionId: (step['direction_id'] ?? '') as String);
    } else {
      _liveTracking.endLeg();
    }
  }

  void _updateDistanceDisplay() {
    if (!mounted || _instructions.isEmpty) return;
    _refreshRemaining();
    final line = nextStopLine(
      _l10n ?? AppLocalizations.of(context),
      instructions: _instructions,
      step: _currentStepIndex,
      stepPoints: _stepPoints,
      here: _currentLocation.value,
      destination: _destinationPoint(),
      progress: _progress,
      isArabic: _isArabicNow,
    );
    if (line != null) _distanceToNextStop.value = line;
  }

  // ------------------------------------------------------ live sharing
  Future<void> _onShareLivePressed(AppLocalizations l10n) async {
    HapticFeedback.selectionClick();
    final existing = _liveShare.current;
    if (existing != null) {
      final stop = await showLiveShareActiveSheet(context);
      if (!mounted || stop == null) return;
      if (stop) {
        setState(() => _liveShare.end(_currentLocation.value, step: _currentStepIndex));
        return;
      }
      await _shareLiveLink(existing, l10n);
      return;
    }
    if (_liveShare.starting) return;
    final share = await _liveShare.start(_liveShareSummary());
    if (!mounted) return;
    setState(() {}); // the share button shows it running
    if (share == null) {
      _showFloatingToast(l10n.shareLiveFailed, icon: Icons.wifi_off_rounded, color: Colors.redAccent);
      return;
    }
    final here = _currentLocation.value;
    if (here != null) _liveShare.sendNow(here, step: _currentStepIndex, eta: _estimatedArrival(here));
    await _shareLiveLink(share, l10n);
  }

  Future<void> _shareLiveLink(LiveTripShare share, AppLocalizations l10n) async {
    final dest = (widget.endName ?? '').trim().isNotEmpty ? widget.endName!.trim() : _destinationTitle;
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text: l10n.shareLiveText(dest, share.link.toString()),
        sharePositionOrigin: box != null ? box.localToGlobal(Offset.zero) & box.size : null,
      ),
    );
  }

  Map<String, dynamic> _liveShareSummary() => TripLiveShare.summaryOf(
        pathData: widget.pathData,
        instructions: _instructions,
        destName: (widget.endName ?? '').trim().isNotEmpty ? widget.endName!.trim() : _destinationTitle,
        startName: widget.startName,
        end: _destinationPoint(),
        plannedMinutes: _totalDurationMinutes,
      );

  /// Arrival time from where the rider is: the distance left along the
  /// drawn route at the trip's own average pace. Null before a route exists.
  DateTime? _estimatedArrival(LatLng here) =>
      _remainingFrom(here)?.arrival ??
      NavMath.estimateArrival(route: _allPoints, here: here, plannedMinutes: (_totalDurationMinutes ?? 30).toDouble());

  /// Minutes and metres left from [here], each step at its own pace (see
  /// TripEta). Off the route, the straight line to the next step stands in
  /// for what is left of this one.
  Remaining? _remainingFrom(LatLng here) => TripProgress.remaining(
        here,
        instructions: _instructions,
        step: _currentStepIndex,
        stepPoints: _stepPoints,
        progress: _progress,
        destination: _destinationPoint(),
        plannedMinutes: _totalDurationMinutes,
      );

  void _refreshRemaining() {
    final here = _currentLocation.value;
    if (here == null) return;
    _remaining.value = _remainingFrom(here);
  }

  /// Where the trip ends: the coordinates the trip was planned to, or the
  /// end of the drawn route when those are missing.
  LatLng? _destinationPoint() => TripProgress.destinationOf(widget.pathData, _allPoints);

  Future<void> _recordArrivedTrip() async {
    final data = widget.pathData;
    double? d(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
    final option = data['option'];
    try {
      await TripHistoryService.recordTrip(
        startName: widget.startName ?? (data['start_name'] ?? '').toString(),
        endName: widget.endName ?? (data['end_name'] ?? '').toString(),
        startLat: d(data['start_lat']),
        startLon: d(data['start_lon']),
        endLat: d(data['end_lat']),
        endLon: d(data['end_lon']),
        pathData: data,
        option: option is Map ? Map<String, dynamic>.from(option) : null,
        chosenProfile: data['profile']?.toString(),
        isCompleted: true,
      );
    } catch (_) {
      // History is best-effort; never interrupt the arrival flow.
    }
  }

  void _checkIfApproachingNextStep() {
    final l10n = _l10n ?? AppLocalizations.of(context);
    final here = _currentLocation.value;
    if (here == null || _instructions.isEmpty) return;

    if (_currentStepIndex >= _instructions.length - 1) {
      // Being on the last step is not the same as being there. A walk-only
      // trip has ONE step, so it used to "arrive" on the first GPS fix at
      // the start (Tahrir -> Egyptian Museum finished the moment it began).
      // Arrival needs the rider to actually reach the destination.
      if (!NavMath.hasArrived(onLastStep: true, here: here, destination: _destinationPoint())) {
        _updateDistanceDisplay();
        return;
      }
      _distanceToNextStop.value = l10n.youHaveArrived;
      if (!_hasLoggedArrival) {
        _hasLoggedArrival = true;
        unawaited(CurrentTrip.clear());
        unawaited(_recorder.finish(completed: true, reason: 'arrived', instructions: _instructions));
        _walkTraces.close();
        _liveShare.arrived(here, step: _currentStepIndex);
        AnalyticsService.logTripCompleted();
        ReviewService.onTripCompleted();
        unawaited(InterstitialAdService.instance.recordArrival());
        final historyId = widget.historyEntryId;
        if (historyId != null) unawaited(TripHistoryService.markCompleted(historyId));
        if (widget.recordHistoryOnArrival) unawaited(_recordArrivedTrip());
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showArrivalSheet();
        });
      }
      return;
    }

    final int next = _currentStepIndex + 1;
    final String station = _stationOf(_instructions[next], _isArabicNow);
    final check = _stepTracker.check(
      here,
      step: _currentStepIndex,
      stepPoints: _stepPoints,
      progress: _progress,
      alarmAllowed: _stopAlarmEnabled && station.isNotEmpty,
      end: StepEnd.of(_instructions, _currentStepIndex),
      accuracy: _lastGpsPosition?.accuracy ?? 0,
    );

    // Stop Proximity Alarm (~150m before the next transfer or arrival
    // station). Rides only: StepTracker never fires it on foot.
    if (check.alarm) {
      HapticFeedback.heavyImpact();
      if (mounted) setState(() => _upcomingAlarmStation = station);
    }

    // "Get ready" on the phone, for a rider who is not looking at this
    // screen: only while riding, once per stop (StepTracker), never in the
    // floating window (TripNotification.nearStop checks that too).
    if (check.near && !TripNotification.liveScreenVisible.value && _isRiding(_currentStepIndex)) {
      unawaited(TripNotification.nearStop(station));
    }

    if (check.atNextPoint) {
      _distanceToNextStop.value = station.isNotEmpty ? l10n.arrivingAt(station) : l10n.youHaveArrived;
      _advanceTo(next, updateDisplay: false);
      return;
    }

    final advanceTo = check.advanceTo;
    if (advanceTo != null) {
      _advanceTo(advanceTo);
      return;
    }
    _updateDistanceDisplay();
  }

  /// Moves navigation on to [target], recording every step passed on the way.
  void _advanceTo(int target, {bool updateDisplay = true}) {
    if (target <= _currentStepIndex || target >= _instructions.length) return;
    // Reaching the next step ends a ride the rider is recording.
    if (_rideReport != null) _finishRideReport();
    _stepTracker.onAdvanced();
    if (mounted) {
      final from = _currentStepIndex;
      setState(() {
        _currentStepIndex = target;
        _upcomingAlarmStation = null;
      });
      for (var s = from + 1; s <= target; s++) {
        _recorder.onStep(s, _instructions[s]);
      }
      AnalyticsService.setCrashlyticsKey('active_step', target);
      AnalyticsService.logBreadcrumb('MapScreen: Advanced to step $target');
      unawaited(CurrentTrip.setStep(target));
      // A ride starts: the stop alarm is for it. Not over another message.
      if (_stopAlarmEnabled && _isRiding(target) && _floatingToastMessage == null) {
        _showStopAlarmOnToast(_l10n ?? AppLocalizations.of(context));
      }
    }
    _syncLiveTrackingForCurrentStep();
    final p = target < _stepPoints.length ? _stepPoints[target] : null;
    if (p != null && !_followMode) _moveCamera(CameraUpdate.newLatLngZoom(p, 16.0));
    if (updateDisplay) _updateDistanceDisplay();
  }

  /// Goes back one step by hand, to read it again. Everything that follows
  /// the step follows it back: the stop alarm is re-armed, a ride being
  /// recorded ends, the recorder gets a step_back event, live sharing and the
  /// floating window read the new step. Auto-advance is held until the rider
  /// has moved on from where they asked (see StepTracker.hold), then works as
  /// before. Not after arrival.
  void _goBack() {
    if (_currentStepIndex <= 0 || _hasLoggedArrival) return;
    if (_rideReport != null) _finishRideReport();
    final from = _currentStepIndex;
    final target = from - 1;
    _stepTracker.onAdvanced();
    _stepTracker.hold(_currentLocation.value);
    if (mounted) {
      setState(() {
        _currentStepIndex = target;
        _upcomingAlarmStation = null;
      });
      _recorder.onEvent('step_back', {'from': from, 'to': target});
      AnalyticsService.setCrashlyticsKey('active_step', target);
      AnalyticsService.logBreadcrumb('MapScreen: Went back to step $target');
      unawaited(CurrentTrip.setStep(target));
    }
    _syncLiveTrackingForCurrentStep();
    final p = target < _stepPoints.length ? _stepPoints[target] : null;
    if (p != null && !_followMode) _moveCamera(CameraUpdate.newLatLngZoom(p, 16.0));
    _updateDistanceDisplay();
  }

  void _showArrivalSheet() {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    final start = widget.startName?.isNotEmpty == true
        ? widget.startName!
        : (widget.pathData['start_name']?.toString() ?? (isAr ? 'نقطة الانطلاق' : 'Origin'));
    final end = widget.endName?.isNotEmpty == true
        ? widget.endName!
        : (_destinationTitle.isNotEmpty
              ? _destinationTitle
              : (widget.pathData['end_name']?.toString() ?? (isAr ? 'المكان اللي رايحه' : 'Destination')));

    final opt = widget.pathData['option'] as Map<String, dynamic>?;
    final fare =
        _totalFare ?? _asNum(opt?['fare_total_egp'] ?? opt?['fare_egp'] ?? widget.pathData['fare_egp']) ?? 10;
    final duration =
        _totalDurationMinutes ?? _asNum(opt?['time'] ?? widget.pathData['duration_minutes'])?.toInt() ?? 30;

    showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TripArrivalSheet(
        startName: start,
        endName: end,
        durationMinutes: duration,
        fare: fare,
        onDone: () {
          Navigator.pop(ctx);
          Navigator.of(context).popUntil((route) => route.isFirst);
          unawaited(InterstitialAdService.instance.showAfterTrip());
        },
        onHistory: () {
          Navigator.pop(ctx);
          Navigator.of(context).popUntil((route) => route.isFirst);
          MainNavigator.goToTab(3);
          unawaited(InterstitialAdService.instance.showAfterTrip());
        },
      ),
    );
  }

  @override
  void deactivate() {
    _location.stop();
    _floatingToastTimer?.cancel();
    super.deactivate();
  }

  // ----------------------------------------------------------- trip tour
  final GlobalKey _tourNow = GlobalKey(debugLabel: 'tour_trip_now');
  final GlobalKey _tourLeft = GlobalKey(debugLabel: 'tour_trip_left');
  final GlobalKey _tourTools = GlobalKey(debugLabel: 'tour_trip_tools');
  final GlobalKey _tourButtons = GlobalKey(debugLabel: 'tour_trip_buttons');

  /// The first trip: what each part of the trip screen is for. Once.
  Future<void> _maybeTripTour() async {
    if (!mounted || TripPip.active.value || simpleMode.value || !GuidyTour.isOnTop(context)) return;
    if (await TourService.hasSeen(TourService.trip)) return;
    if (!mounted || TripPip.active.value || !GuidyTour.isOnTop(context)) return;
    final l10n = AppLocalizations.of(context);
    await GuidyTour.show(context, [
      TourStep(target: _tourNow, title: l10n.tourTripNowTitle, body: l10n.tourTripNowBody),
      TourStep(target: _tourLeft, title: l10n.tourTripLeftTitle, body: l10n.tourTripLeftBody),
      TourStep(target: _tourTools, title: l10n.tourTripToolsTitle, body: l10n.tourTripToolsBody),
      TourStep(target: _tourButtons, title: l10n.tourTripButtonsTitle, body: l10n.tourTripButtonsBody),
      if (defaultTargetPlatform == TargetPlatform.android)
        TourStep(title: l10n.tourTripPipTitle, body: l10n.tourTripPipBody),
    ]);
    // Cut short by the floating window: the rider never got to read it.
    if (TripPip.active.value) return;
    await TourService.markSeen(TourService.trip);
  }

  /// In the floating window there is room for the map and one card: follow
  /// the rider so the window shows where they are.
  void _onPipChanged() {
    if (!mounted) return;
    if (TripPip.active.value) {
      // A sheet left open (a report form, the share dialog) would fill the
      // window instead of the map, and its focused text box would bring the
      // keyboard back on return. Close sheets and dialogs above the trip --
      // each one treats a dismissal as "no" -- but not full screens.
      FocusManager.instance.primaryFocus?.unfocus();
      // The first-trip tour points at cards the window doesn't have: take
      // it off before the window is drawn (and first, so the sheets under
      // it close too).
      GuidyTour.close();
      Navigator.of(context).popUntil((route) => route is! PopupRoute);
    }
    // Walk traces stop in the floating window, as in the background.
    if (TripPip.active.value) {
      _walkTraces.pause();
    } else if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused) {
      _walkTraces.resume();
    }
    setState(() {
      if (TripPip.active.value) _followMode = true;
    });
    if (TripPip.active.value) _wakePuck();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The trip's phone notification shows whenever this screen is not
    // the one the rider is looking at (see TripNotification).
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      TripNotification.liveScreenVisible.value = false;
    } else if (state == AppLifecycleState.resumed) {
      TripNotification.liveScreenVisible.value = mounted && (ModalRoute.of(context)?.isCurrent ?? true);
    }
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _walkTraces.pause();
    } else if (state == AppLifecycleState.resumed && !TripPip.active.value) {
      _walkTraces.resume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    TripPip.active.removeListener(_onPipChanged);
    unawaited(TripPip.setAvailable(false));
    NavigationSession.end();
    CurrentTrip.active.removeListener(_onCurrentTripChanged);
    // A trip screen that replaced this one (route switch) has already
    // opened and claimed the flag.
    TripNotification.liveScreenVisible.value = NavigationSession.isActive;
    AnalyticsService.setCrashlyticsKey('is_navigating', false);
    AnalyticsService.logBreadcrumb('MapScreen: Navigation disposed');
    _floatingToastTimer?.cancel();
    _stationaryTimer?.cancel();
    _remainingTimer?.cancel();
    _puckTicker.dispose();
    _location.dispose();
    _liveTracking.endLeg();
    _finishRideReport(disposing: true);
    unawaited(_recorder.finish(completed: _hasLoggedArrival, reason: 'left', instructions: _instructions));
    _walkTraces.close();
    _liveShare.end(_currentLocation.value, step: _currentStepIndex);
    _currentLocation.dispose();
    _distanceToNextStop.dispose();
    _remaining.dispose();
    _locationProblem.dispose();
    _sheet.dispose();
    _stepsScroll.dispose();
    _markersNotifier.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  /// Where the trip ends: the place the rider searched for. Not
  /// [_destinationTitle], which is the last stop the ride lets them off at.
  String? get _tripEnd {
    final end = (widget.endName ?? widget.pathData['end_name']?.toString() ?? '').trim();
    return end.isEmpty ? null : end;
  }

  /// What the top card says now (see TripManeuver).
  WalkManeuverInfo? _maneuverNow(BuildContext context) => TripManeuver.current(
        _l10n ?? AppLocalizations.of(context),
        instructions: _instructions,
        step: _currentStepIndex,
        stepPoints: _stepPoints,
        walkSegments: _walkSegments,
        allPoints: _allPoints,
        here: _currentLocation.value,
        destinationTitle: _tripEnd ?? _destinationTitle,
      );

  Widget _buildManeuverCard(BuildContext context) {
    final maneuver = _maneuverNow(context);
    return maneuver == null ? const SizedBox.shrink() : TripManeuverCard(maneuver: maneuver);
  }

  /// The stop alarm's banner: on a ride only, and never while the top card
  /// is already orange for the stop coming up. Two orange boxes saying "get
  /// ready" (three, with the alarm's toast) covered the map; one at a time.
  bool _showsAlarmBanner(BuildContext context) =>
      _stopAlarmEnabled &&
      _upcomingAlarmStation != null &&
      _isRiding(_currentStepIndex) &&
      !(_maneuverNow(context)?.isProximityAlert ?? false);

  bool _hasAlternatives(int index) {
    if (index < 0 || index >= _instructions.length) return false;
    final opts = _instructions[index]['boarding_options'];
    return opts is List && opts.length > 1;
  }

  // ---------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = context.isDark;
    final double half = _halfOf(context);
    final double full = _fullOf(context);

    // Back (the arrow or the phone's) goes exactly one screen back, to the
    // screen the trip was started from as it was left; dispose() ends the
    // trip's tracking, recording and live share.
    // Simple mode asks first: a stray tap on Back would end the directions.
    final bool simple = simpleMode.value && !TripPip.active.value;
    return PopScope(
      canPop: !simple,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && simple) _confirmEndTrip();
      },
      child: Scaffold(
        body: Stack(
          children: [
            ValueListenableBuilder<Set<Marker>>(
              valueListenable: _markersNotifier,
              builder: (context, markers, _) {
                return Listener(
                  // A finger on the map means the rider wants to look around.
                  onPointerDown: (_) => _onMapTouched(),
                  child: GoogleMap(
                    // Map style is declarative now: GoogleMap(style: ...) replaced the
                    // deprecated controller.setMapStyle(). The old imperative version needed
                    // a _mapStyleIsDark latch and a post-frame callback to push the style
                    // after every theme change; the property just rebuilds with the widget.
                    style: isDark ? darkMapStyleJson : null,
                    initialCameraPosition: CameraPosition(
                      target: _allPoints.isNotEmpty ? _allPoints.first : const LatLng(30.0444, 31.2357),
                      zoom: 14.5,
                    ),
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    // Rotation and tilt are driven by the rider's heading, but the
                    // gestures stay enabled: someone who wants to look at the map
                    // their own way should be able to, and doing so drops follow mode.
                    // Google's own compass sits inside the map padding, which
                    // changes with the sheet and the header, so it jumped
                    // around the screen. A fixed compass button is drawn in
                    // the controls column instead (_compassButton).
                    compassEnabled: false,
                    // The rider's arrow is a FLAT marker (it lies on the street
                    // and turns with it), and at the nav camera's tilt and zoom
                    // Google draws 3D buildings over flat markers: the arrow
                    // vanished or flickered wherever a building overlapped it.
                    buildingsEnabled: false,
                    onCameraMove: (pos) {
                      _lastCamera = pos;
                      _cameraBearing.value = pos.bearing;
                    },
                    padding: _mapPadding(context),
                    // Follow mode ends on a finger touching the map (see the
                    // Listener around it), not on onCameraMoveStarted: the
                    // frame loop moves the camera many times a second and
                    // this callback can't tell its moves from the rider's.
                    polylines: _themedPolylines(isDark),
                    markers: markers,
                    onMapCreated: (controller) async {
                      _mapController = controller;
                      if (_allPoints.isNotEmpty) {
                        await Future.delayed(const Duration(milliseconds: 300));
                        if (mounted) {
                          final here = _currentLocation.value;
                          if (_riderAtStart == false) {
                            _showTripStart();
                          } else if (here != null) {
                            final bearing = NavCamera.forwardRouteBearing(_allPoints, here,
                                fallback: _lastHeading, nearAlong: _progress?.lastAlong);
                            _lastHeading = bearing;
                            _puck.cameraBearingTarget = bearing;
                            setState(() => _followMode = true);
                            _wakePuck();
                            _moveCamera(
                              CameraUpdate.newCameraPosition(
                                CameraPosition(target: here, zoom: _navZoom, tilt: _navTilt, bearing: bearing),
                              ),
                            );
                          } else if (_allPoints.length >= 2) {
                            final bearing = NavCamera.bearing(_allPoints[0], _allPoints[1]);
                            _lastHeading = bearing;
                            _puck.cameraBearingTarget = bearing;
                            setState(() => _followMode = true);
                            _wakePuck();
                            _moveCamera(
                              CameraUpdate.newCameraPosition(
                                CameraPosition(
                                  target: _allPoints.first,
                                  zoom: _navZoom,
                                  tilt: _navTilt,
                                  bearing: bearing,
                                ),
                              ),
                            );
                          } else {
                            _fitRouteBounds(animated: true);
                          }
                        }
                      }
                    },
                  ),
                );
              },
            ),

            if (TripPip.active.value)
              _pipRundown(context, l10n)
            else if (simple && _instructions.isNotEmpty)
              ..._simpleTrip(context, l10n)
            else ...[
            // --- Top navigation header bar & stop alarm banner ---
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              right: 16,
              // Back and language on the left, the tool rail at the edge on
              // the same row. Under it, the step card on one side and the
              // compass, recenter and stop alarm on the other.
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      TripRoundButton(icon: Icons.arrow_back_ios_new_rounded,
                        color: context.textPrimary,
                        tooltip: l10n.closeMapTooltip,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 8),
                      _buildQuickLanguageToggle(context, l10n),
                      const Spacer(),
                      KeyedSubtree(key: _tourTools, child: _buildToolRail(context, l10n)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                  KeyedSubtree(key: _tourNow, child: _buildManeuverCard(context)),
                  TripToast(message: _floatingToastMessage, icon: _floatingToastIcon, color: _floatingToastColor),
                  if (_showsAlarmBanner(context)) ...[
                    const SizedBox(height: 10),
                    TripStopAlarmBanner(
                      station: _upcomingAlarmStation!,
                      onDismiss: () => setState(() => _upcomingAlarmStation = null),
                    ),
                  ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // The tool rail in the top corner, beside the back button
                  // and the step card; compass, recenter and stop alarm
                  // continue its column of icons underneath.
                  // The rail hugs the screen edge (end), so the buttons hang
                  // from that edge too: each is the width of the rail's
                  // column (TripRoundButton.size), and they sit centred under it.
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      TripMapButtons(
                        key: _tourButtons,
                        cameraBearing: _cameraBearing,
                        onNorthUp: _resetNorth,
                        following: _followMode,
                        onRecenter: _recenter,
                        alarmOn: _stopAlarmEnabled,
                        onToggleAlarm: () => _toggleStopAlarm(l10n),
                      ),
                    ],
                  ),
                ],
              ),
                ],
              ),
            ),

            // --- the sheet ---
            if (_instructions.isNotEmpty)
              LayoutBuilder(builder: (context, box) {
                final double peekMin = _peekFor(context, box.maxHeight, half);
                WidgetsBinding.instance.addPostFrameCallback((_) => _measureSheetHeader());
                return DraggableScrollableSheet(
                controller: _sheet,
                initialChildSize: half,
                minChildSize: peekMin,
                maxChildSize: full,
                snap: true,
                snapSizes: _snapSizesFor(half),
                builder: (context, scrollController) => Container(
                  key: const ValueKey('sheet_body'),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(GuidyUi.radius)),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black.withValues(alpha: 0.5) : AppColors.brandNavy.withValues(alpha: 0.18),
                        blurRadius: 12,
                        offset: const Offset(0, -3),
                      ),
                    ],
                  ),
                  child: Material(
                    color: context.surfaceCard,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(GuidyUi.radius)),
                    clipBehavior: Clip.antiAlias,
                    // The Now card drags the sheet (it holds the sheet's
                    // scroll controller); the steps under it scroll on their
                    // own without moving it.
                    child: LayoutBuilder(builder: (context, inner) => Column(
                      children: [
                        // Capped to the sheet: in a window shorter than the
                        // card (just before the floating window) it clips.
                        ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: inner.maxHeight),
                          child: SingleChildScrollView(
                            key: const ValueKey('trip-sheet-grab'),
                            controller: scrollController,
                            child: _sheetHeader(context, l10n),
                          ),
                        ),
                        Expanded(
                          child: CustomScrollView(
                            key: const ValueKey('trip-sheet-steps'),
                            controller: _stepsScroll,
                            slivers: [
                              SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, i) => _stepTile(context, l10n, i),
                                  childCount: _instructions.length,
                                ),
                              ),
                              SliverToBoxAdapter(child: TripEndButton(onPressed: _confirmEndTrip)),
                            ],
                          ),
                        ),
                      ],
                    )),
                  ),
                ),
              );
              }),
            ],
          ],
        ),
      ),
    );
  }

  /// Simple mode's trip screen: the map, and one panel with the step the
  /// rider is on. No tool rail, language switch, sheet of every step or
  /// anything to swipe; "Next step" and "End trip" are the only controls.
  List<Widget> _simpleTrip(BuildContext context, AppLocalizations l10n) {
    final bool last = _currentStepIndex >= _instructions.length - 1;
    return [
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: SimpleStepPanel(
          instructions: _instructions,
          index: _currentStepIndex,
          destination: _tripEnd ?? _destinationTitle,
          alarmStation: _stopAlarmEnabled ? _upcomingAlarmStation : null,
          onNext: last ? null : () => _advanceTo(_currentStepIndex + 1),
          onPrevious: _currentStepIndex > 0 && !_hasLoggedArrival ? _goBack : null,
          onEnd: _confirmEndTrip,
          onReportWalk: _walkInfo(_currentStepIndex) == null ? null : () => _reportWalk(_currentStepIndex),
          walkReported: _reportedWalks.contains(_currentStepIndex),
        ),
      ),
    ];
  }

  /// "End this trip?", then back to Home. Simple mode's End trip, its Back,
  /// and the End trip at the bottom of the trip sheet.
  Future<void> _confirmEndTrip() async {
    final l10n = _l10n ?? AppLocalizations.of(context);
    final yes = await SimpleUi.confirm(
      context,
      title: l10n.simpleEndTripTitle,
      body: l10n.simpleEndTripBody,
      yes: l10n.simpleEndTripYes,
      no: l10n.simpleKeepGoing,
    );
    if (!yes) return;
    // Ended on purpose: Home must not offer to resume it.
    unawaited(CurrentTrip.clear());
    if (mounted) SimpleUi.goHome(context);
  }

  /// The trip in the floating window: what to do now and what is left, on
  /// one card under the map. Nothing to tap -- tapping the window brings
  /// the full trip screen back.
  Widget _pipRundown(BuildContext context, AppLocalizations l10n) {
    if (_instructions.isEmpty) return const SizedBox.shrink();
    return Positioned(
      left: 6,
      right: 6,
      bottom: 6,
      child: TripPipRundown(instructions: _instructions, step: _currentStepIndex, remaining: _remaining),
    );
  }

  /// The Figma tool rail: route overview and the fold-away menu on top,
  /// then live share and quick report.
  Widget _buildToolRail(BuildContext context, AppLocalizations l10n) {
    return GuidyToolRail(
      showTooltip: l10n.navToolsShow,
      hideTooltip: l10n.navToolsHide,
      lead: GuidyToolRailItem(
        key: const ValueKey('nav-tool-overview'),
        icon: Icons.map_outlined,
        tooltip: l10n.navToolsOverview,
        onTap: _showOverview,
      ),
      items: [
        GuidyToolRailItem(
          key: const ValueKey('nav-tool-share'),
          icon: Icons.share_outlined,
          tooltip: l10n.shareLiveTooltip,
          active: _liveShare.current != null,
          // The live "follow my trip" link.
          onTap: () => _onShareLivePressed(l10n),
        ),
        GuidyToolRailItem(
          key: const ValueKey('nav-tool-report'),
          icon: Icons.campaign_outlined,
          tooltip: l10n.quickReportTitle,
          onTap: () => QuickCommuteReportSheet.show(context, routeData: widget.pathData, steps: _instructions),
        ),
      ],
    );
  }

  Widget _buildQuickLanguageToggle(BuildContext context, AppLocalizations l10n) {
    return GuidyLanguageToggle(
      floating: true,
      onChanged: (arabic) {
        _updateLocalizedDestination(arabic);
        if (mounted) {
          setState(() {});
          _showFloatingToast(
            arabic ? 'اتحولت للعربي' : 'Switched to English',
            icon: Icons.translate_rounded,
            color: AppColors.primaryTeal,
          );
        }
      },
    );
  }

  // ------------------------------------------------ "This walk is wrong"
  /// Where walking step [index] starts and ends, or null if it is not a walk.
  WalkStepInfo? _walkInfo(int index) => _walkInfoCache.putIfAbsent(
        index,
        () => WalkStepEnds.of(
          tripId: _recorder.id,
          instructions: _instructions,
          stepPoints: _stepPoints,
          walkSegments: _walkSegments,
          index: index,
          tripStart: _tripStartPoint(),
          destination: _destinationPoint(),
        ),
      );

  LatLng? _tripStartPoint() {
    final lat = _asNum(widget.pathData['start_lat']), lon = _asNum(widget.pathData['start_lon']);
    return lat == null || lon == null ? null : LatLng(lat.toDouble(), lon.toDouble());
  }

  /// Asks what is wrong with the walk, queues the report (it never waits
  /// for signal) and thanks the rider. The trip carries on meanwhile.
  Future<void> _reportWalk(int index) async {
    final info = _walkInfo(index);
    if (info == null) return;
    final picked = await showWalkReportSheet(context, simple: simpleMode.value);
    if (picked == null || !mounted) return;
    WalkFeedbackService.report(info, picked.reason, picked.note);
    _recorder.onEvent('walk_report', {'step': index, 'reason': picked.reason.wire});
    setState(() => _reportedWalks.add(index));
    final l10n = _l10n ?? AppLocalizations.of(context);
    _showFloatingToast(l10n.walkReportThanks, icon: Icons.check_circle_outline, color: AppColors.primaryTeal);
  }

  // ------------------------------------------------- "I took a vehicle"
  bool _offersRideReport(Map<String, dynamic> step) =>
      InstructionFormatter.iconKey(step) == 'walk' &&
      (_asNum(step['distance_m']) ?? 0) >= RideReportService.minWalkM;

  Future<void> _startRideReport(AppLocalizations l10n) async {
    final picked = await showRideReportSheet(context);
    if (picked == null || !mounted) return;
    final step = _instructions[_currentStepIndex] as Map<String, dynamic>;
    final isAr = _isArabicNow;
    final next = _currentStepIndex + 1 < _instructions.length ? _instructions[_currentStepIndex + 1] : null;
    final to = _stationOf(step, isAr).isNotEmpty ? _stationOf(step, isAr) : _stationOf(next, isAr);
    final ride = RideReport(
      vehicleType: picked.vehicle,
      fareEgp: picked.fare,
      plannedStep: {
        'action': step['action'],
        'distance_m': step['distance_m'],
        'from': widget.startName ?? '',
        'to': to,
        'step_index': _currentStepIndex,
      },
    );
    final here = _currentLocation.value;
    if (here != null) ride.addFix(here.latitude, here.longitude, DateTime.now());
    setState(() => _rideReport = ride);
    _recorder.onEvent('ride_report_start', {'step': _currentStepIndex, 'vehicle': picked.vehicle});
  }

  /// Ends the recording (the rider got off, reached the next step, or left
  /// the trip) and sends it.
  void _finishRideReport({bool disposing = false}) {
    final ride = _rideReport;
    if (ride == null) return;
    ride.end();
    _rideReport = null;
    _recorder.onEvent('ride_report_end', {'distance_m': ride.distanceM.round()});
    unawaited(RideReportService.send(ride));
    if (disposing || !mounted) return;
    setState(() {});
    final l10n = _l10n ?? AppLocalizations.of(context);
    _showFloatingToast(l10n.rideReportThanks, icon: Icons.check_circle_outline, color: AppColors.primaryTeal);
  }

  /// The pinned part: grab handle, the CURRENT instruction, distance to the
  /// next step, and the direct route into alternatives. Visible at every
  /// snap point, including the smallest.
  Widget _sheetHeader(BuildContext context, AppLocalizations l10n) {
    final step = _instructions[_currentStepIndex] as Map<String, dynamic>;
    return TripNowCard(
      key: _sheetHeaderKey,
      tourKey: _tourLeft,
      instructions: _instructions,
      step: _currentStepIndex,
      distanceToNextStop: _distanceToNextStop,
      locationProblem: _locationProblem,
      rideReport: _rideReport,
      offersRideReport: _offersRideReport(step),
      onStartRideReport: () => _startRideReport(l10n),
      onStopRideReport: _finishRideReport,
      onReportWalk: _walkInfo(_currentStepIndex) == null ? null : () => _reportWalk(_currentStepIndex),
      walkReported: _reportedWalks.contains(_currentStepIndex),
      onPrevious: _currentStepIndex > 0 && !_hasLoggedArrival ? _goBack : null,
      onNext: _currentStepIndex < _instructions.length - 1 ? () => _advanceTo(_currentStepIndex + 1) : null,
    );
  }

  /// One row of the journey. Tapping a row that has alternatives unfolds
  /// them in place — this is the only thing that writes _expandedSteps.
  Widget _stepTile(BuildContext context, AppLocalizations l10n, int index) {
    final bool isOpen = _expandedSteps.contains(index);
    return TripStepTile(
      instructions: _instructions,
      index: index,
      isNow: index == _currentStepIndex,
      isOpen: isOpen,
      tappable: _hasAlternatives(index),
      onToggle: () => setState(() => isOpen ? _expandedSteps.remove(index) : _expandedSteps.add(index)),
      onReportWalk: index != _currentStepIndex && _walkInfo(index) != null ? () => _reportWalk(index) : null,
      walkReported: _reportedWalks.contains(index),
      alternatives: isOpen
          ? TripBoardingOptions(
              step: _instructions[index] as Map<String, dynamic>,
              onPick: (opt) => _switchToAlternativeVehicle(index, opt, l10n),
            )
          : null,
    );
  }

  void _switchToAlternativeVehicle(int stepIndex, Map<String, dynamic> opt, AppLocalizations l10n) {
    if (stepIndex < 0 || stepIndex >= _instructions.length) return;
    if (opt['is_primary'] == true) {
      HapticFeedback.selectionClick();
      return;
    }
    HapticFeedback.mediumImpact();

    // The walk that leads to the ride follows it to its stop.
    final before = stepIndex > 0 ? _instructions[stepIndex - 1] : null;
    final walkBefore = before is Map<String, dynamic> && before['action'].toString().contains('walk') ? before : null;
    final change = applyVehicleSwitch(_instructions[stepIndex] as Map<String, dynamic>, opt, walkBefore: walkBefore);
    final movedTo = change.movedTo;
    if (change.moved) {
      if (movedTo != null && stepIndex < _stepPoints.length) {
        _stepPoints[stepIndex] = movedTo;
        if (walkBefore != null) _stepPoints[stepIndex - 1] = movedTo;
        _progress = RouteProgress(List.of(_allPoints), List.of(_stepPoints));
      }
      _buildMarkers();
    }
    _recorder.onEvent('vehicle_switch', {'step': stepIndex, 'route_id': opt['route_id']});
    _walkInfoCache.clear();
    final waitDelta = change.waitDelta;
    if (waitDelta != null) _totalDurationMinutes = math.max(1, (_totalDurationMinutes ?? 30) + waitDelta);

    _totalFare = math.max(0, (_totalFare ?? 0) + change.fareDelta);
    widget.pathData['fare_egp'] = _totalFare;
    widget.pathData['fare_total_egp'] = _totalFare;
    widget.pathData['duration_minutes'] = _totalDurationMinutes;

    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final vehName = InstructionFormatter.optionSummary(l10n, Map<String, dynamic>.from(opt));
    final total = fareAmount(_totalFare ?? 0);
    final msg = isAr ? 'غيّرت لـ $vehName • الأجرة: $total ج.م' : 'Switched to $vehName • Total: $total EGP';
    _showFloatingToast(msg, icon: Icons.alt_route_rounded, color: AppColors.primaryTeal);

    setState(() {});
  }

}
