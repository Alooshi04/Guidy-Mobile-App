import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/guidy_ui.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart' as intl;

import '../l10n/app_localizations.dart';
import '../services/instruction_formatter.dart';
import '../services/map_marker_service.dart';
import '../services/share_links.dart';
import '../theme/app_theme.dart';
import '../utils/minutes_text.dart';
import '../utils/route_line_style.dart';
import '../utils/clock_text.dart';

/// Follows someone's trip from a live share link (guidyapp.com/l/...).
/// Polls the share every 10 s until the trip ends.
class LiveTripViewerScreen extends StatefulWidget {
  final String token;

  /// False in widget tests, where the Google Maps platform view can't run.
  final bool showMap;

  /// Injectable for tests.
  final Future<Map<String, dynamic>?> Function(String token)? fetcher;

  const LiveTripViewerScreen({super.key, required this.token, this.showMap = true, this.fetcher});

  @override
  State<LiveTripViewerScreen> createState() => _LiveTripViewerScreenState();
}

class _LiveTripViewerScreenState extends State<LiveTripViewerScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _view;
  bool _gone = false;
  bool _offline = false;
  bool _loading = true;
  Timer? _timer;
  GoogleMapController? _map;
  bool _framed = false;

  /// The sender's dot: the same arrow riders see for themselves, gliding
  /// from one reported position to the next instead of jumping every 10 s.
  BitmapDescriptor? _puckIcon;
  // Created in initState, not lazily: a lazy controller first touched in
  // dispose() would be built while the element is deactivated, which throws.
  late final AnimationController _glide;
  LatLng? _glideFrom;
  LatLng? _glideTo;
  LatLng? _shownRider;

  /// The viewer's own blue dot, when they already allowed location (never
  /// asked for here).
  bool _myLocationOk = false;

  @override
  void initState() {
    super.initState();
    _glide = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..addListener(_onGlide);
    if (widget.showMap) {
      MapMarkerService.getUserPuckMarker()
          .then((icon) {
            if (mounted) setState(() => _puckIcon = icon);
          })
          .catchError((_) {});
      Geolocator.checkPermission()
          .then((p) {
            final ok = p == LocationPermission.whileInUse || p == LocationPermission.always;
            if (mounted && ok) setState(() => _myLocationOk = true);
          })
          .catchError((_) {});
    }
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _poll());
  }

  @override
  void dispose() {
    _glide.dispose();
    _timer?.cancel();
    _map?.dispose();
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final v = await (widget.fetcher ?? LiveTripShareView.fetch)(widget.token);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _offline = false;
        if (v == null) {
          _gone = true;
          _timer?.cancel();
        } else {
          _view = v;
          if (v['status'] != 'active') _timer?.cancel();
        }
      });
      _glideToRider();
      _follow();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _offline = true;
        });
      }
    }
  }

  Map<String, dynamic> get _summary =>
      (_view?['summary'] is Map) ? Map<String, dynamic>.from(_view!['summary']) : const {};
  Map<String, dynamic>? get _state => (_view?['state'] is Map) ? Map<String, dynamic>.from(_view!['state']) : null;

  LatLng? get _rider {
    final s = _state;
    final lat = s?['lat'], lon = s?['lon'];
    return (lat is num && lon is num) ? LatLng(lat.toDouble(), lon.toDouble()) : null;
  }

  void _glideToRider() {
    final to = _rider;
    if (to == null) return;
    if (_shownRider == null || _glideTo == to) {
      _shownRider ??= to;
      _glideTo = to;
      return;
    }
    _glideFrom = _shownRider;
    _glideTo = to;
    _glide.forward(from: 0);
  }

  void _onGlide() {
    final a = _glideFrom, b = _glideTo;
    if (a == null || b == null || !mounted) return;
    final t = Curves.easeOut.transform(_glide.value);
    setState(
      () => _shownRider = LatLng(
        a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t,
      ),
    );
  }

  void _centerOnRider() {
    final r = _shownRider ?? _rider;
    if (r == null || _map == null) return;
    _map!.animateCamera(CameraUpdate.newLatLngZoom(r, 16)).catchError((_) {});
  }

  LatLng? get _dest {
    final e = _summary['end'];
    if (e is Map && e['lat'] is num && e['lon'] is num) {
      return LatLng((e['lat'] as num).toDouble(), (e['lon'] as num).toDouble());
    }
    return null;
  }

  List<List<LatLng>> _segments(List<bool> walkOut, List<Color> colorOut) {
    final out = <List<LatLng>>[];
    for (final s in (_summary['segments'] as List? ?? const [])) {
      if (s is! Map) continue;
      final pts = <LatLng>[
        for (final p in (s['points'] as List? ?? const []))
          if (p is List && p.length >= 2 && p[0] is num && p[1] is num)
            LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()),
      ];
      if (pts.length < 2) continue;
      out.add(pts);
      walkOut.add(s['is_walk'] == true);
      final hex = (s['color'] ?? '').toString().replaceFirst('#', '');
      colorOut.add(hex.length == 6 ? Color(0xFF000000 | int.parse(hex, radix: 16)) : const Color(0xFF489CB5));
    }
    return out;
  }

  void _follow() {
    final r = _rider;
    if (_map == null) return;
    if (!_framed) {
      final pts = <LatLng>[?r, ?_dest];
      for (final seg in _segments([], [])) {
        pts.addAll(seg);
      }
      if (pts.length >= 2) {
        double s = 90, w = 180, n = -90, e = -180;
        for (final p in pts) {
          if (p.latitude < s) s = p.latitude;
          if (p.latitude > n) n = p.latitude;
          if (p.longitude < w) w = p.longitude;
          if (p.longitude > e) e = p.longitude;
        }
        _map!
            .animateCamera(
              CameraUpdate.newLatLngBounds(LatLngBounds(southwest: LatLng(s, w), northeast: LatLng(n, e)), 56),
            )
            .catchError((_) {});
        _framed = true;
      }
    }
  }

  String _currentText(AppLocalizations l10n) {
    final steps = (_summary['steps'] as List? ?? const []).whereType<Map>().toList();
    final i = (_state?['step'] as num?)?.toInt() ?? 0;
    if (i < 0 || i >= steps.length) return '';
    final st = steps[i];
    final riding = st['action'] == 'board' || st['action'] == 'transfer';
    return riding ? l10n.liveViewerOnVehicle(InstructionFormatter.lineLabelFull(l10n, st)) : l10n.liveViewerWalking;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dest = (_summary['dest_name'] ?? '').toString();
    final name = (_summary['sharer_name'] ?? '').toString();
    final status = _view?['status'];
    final now = DateTime.now();
    final eta = (_state?['eta'] as num?)?.toDouble();
    final etaTime = eta == null ? null : DateTime.fromMillisecondsSinceEpoch((eta * 1000).round());
    final updated = (_view?['updated_at'] as num?)?.toDouble();
    final timeFmt = intl.DateFormat.jm(l10n.localeName);

    final walk = <bool>[];
    final colors = <Color>[];
    final segs = _segments(walk, colors);
    final lines = <Polyline>{
      for (var i = 0; i < segs.length; i++)
        if (walk[i])
          RouteLineStyle.walk('w$i', segs[i], dark: context.isDark)
        else
          ...RouteLineStyle.ride('r$i', segs[i], colors[i]),
    };

    Widget card;
    if (_loading) {
      card = const Center(
        child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
      );
    } else if (_gone) {
      card = _line(context, Icons.link_off_rounded, l10n.liveViewerEnded);
    } else {
      card = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            name.isNotEmpty ? l10n.liveViewerHeading(name, dest) : l10n.liveViewerHeadingNoName(dest),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimary),
          ),
          const SizedBox(height: 10),
          if (status == 'arrived')
            _line(context, Icons.check_circle_rounded, l10n.liveViewerArrived(dest), color: const Color(0xFF2A9D8F))
          else if (status == 'ended')
            _line(context, Icons.link_off_rounded, l10n.liveViewerEnded)
          else if (_rider == null)
            _line(context, Icons.hourglass_top_rounded, l10n.liveViewerWaiting)
          else ...[
            _line(context, Icons.directions_bus_rounded, _currentText(l10n)),
            if (etaTime != null && etaTime.isAfter(now))
              _line(
                context,
                Icons.schedule_rounded,
                l10n.liveViewerEta(westernDigits(timeFmt.format(etaTime)), l10n.minutes(etaTime.difference(now).inMinutes)),
              ),
          ],
          if (updated != null && status == 'active')
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _offline
                    ? l10n.liveViewerOffline
                    : l10n.liveViewerUpdated(
                        westernDigits(timeFmt.format(DateTime.fromMillisecondsSinceEpoch((updated * 1000).round()))),
                      ),
                style: TextStyle(fontSize: 12, color: context.textSecondary),
              ),
            ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: context.surfaceCard,
      appBar: AppBar(
        backgroundColor: context.surfaceCard,
        elevation: 0,
        iconTheme: IconThemeData(color: context.textPrimary),
        title: Text(
          l10n.liveViewerTitle,
          style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold),
        ),
        actions: GuidyLanguageToggle.appBarActions,
      ),
      body: Column(
        children: [
          Expanded(
            child: widget.showMap
                ? Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _rider ?? _dest ?? const LatLng(30.0444, 31.2357),
                          zoom: 13,
                        ),
                        style: context.isDark ? darkMapStyleJson : null,
                        myLocationEnabled: _myLocationOk,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                        polylines: lines,
                        markers: {
                          if (_dest != null)
                            Marker(
                              markerId: const MarkerId('dest'),
                              position: _dest!,
                              infoWindow: InfoWindow(title: dest),
                            ),
                          if (_shownRider != null && status == 'active')
                            Marker(
                              markerId: const MarkerId('rider'),
                              position: _shownRider!,
                              zIndexInt: 50,
                              flat: true,
                              anchor: MapMarkerService.centerAnchor,
                              rotation: ((_state?['heading'] as num?)?.toDouble() ?? 0),
                              icon: _puckIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                              infoWindow: InfoWindow(title: name.isNotEmpty ? name : null),
                            ),
                        },
                        onMapCreated: (c) {
                          _map = c;
                          _follow();
                        },
                      ),
                      if (_shownRider != null)
                        PositionedDirectional(
                          top: 12,
                          end: 12,
                          child: Material(
                            color: context.surfaceCard,
                            elevation: 3,
                            shape: const CircleBorder(),
                            child: IconButton(
                              icon: const Icon(Icons.person_pin_circle_rounded),
                              color: AppColors.primaryTeal,
                              onPressed: _centerOnRider,
                            ),
                          ),
                        ),
                    ],
                  )
                : const SizedBox.expand(),
          ),
          Material(
            color: context.surfaceCard,
            elevation: 8,
            child: SafeArea(
              top: false,
              child: Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 16), child: card),
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(BuildContext context, IconData icon, String text, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Icon(icon, size: 20, color: color ?? AppColors.primaryTeal),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 15, color: context.textPrimary, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
