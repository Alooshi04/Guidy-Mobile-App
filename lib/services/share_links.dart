import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'api_service.dart';

/// Guidy's own share links, and the live-trip share behind "follow my trip".
///
///   https://guidyapp.com/r?f=LAT,LON&fn=NAME&t=LAT,LON&tn=NAME&v=ROUTE.ROUTE
///       a route: opens the routes screen for the same start and destination,
///       with the shared vehicles picked if they're still offered.
///   https://guidyapp.com/l/TOKEN
///       a live trip: opens a map following the sender until they arrive.
///
/// Both also work as guidy://r?... and guidy://l/TOKEN, which the web page
/// behind the https links uses when Android hasn't verified the https ones
/// for the app (and on iPhone). Without Guidy installed, the web page sends
/// the person to the store.
class ShareLinks {
  ShareLinks._();

  static const String host = 'guidyapp.com';

  /// Hosts whose /r and /l links are Guidy's. Links shared before the
  /// domain existed use the Firebase address, and still open.
  static const Set<String> hosts = {'guidyapp.com', 'www.guidyapp.com', 'guidy-19e46.web.app'};
  static const String scheme = 'guidy';

  static String _coord(double v) => v.toStringAsFixed(6);

  static Uri routeLink({
    required double startLat,
    required double startLon,
    required String startName,
    required double endLat,
    required double endLon,
    required String endName,
    List<String> routeIds = const [],
  }) {
    return Uri.https(host, '/r', {
      'f': '${_coord(startLat)},${_coord(startLon)}',
      'fn': startName,
      't': '${_coord(endLat)},${_coord(endLon)}',
      'tn': endName,
      if (routeIds.isNotEmpty) 'v': routeIds.join('.'),
    });
  }

  static Uri liveLink(String token) => Uri.https(host, '/l/$token');

  /// A Guidy link in [uri], or null when it is something else (a Google
  /// Maps link, say).
  static GuidyLink? parse(Uri uri) {
    final isWeb = (uri.scheme == 'https' || uri.scheme == 'http') && hosts.contains(uri.host);
    final isApp = uri.scheme == scheme;
    if (!isWeb && !isApp) return null;
    // guidy://r?... puts "r" in the host; https://host/r puts it in the path.
    final parts = <String>[
      if (isApp && uri.host.isNotEmpty) uri.host,
      ...uri.pathSegments.where((s) => s.isNotEmpty),
    ];
    if (parts.isEmpty) return null;
    if (parts.first == 'l' && parts.length >= 2 && RegExp(r'^[A-Za-z0-9_-]{8,64}$').hasMatch(parts[1])) {
      return LiveShareLink(parts[1]);
    }
    if (parts.first == 'r') {
      final q = uri.queryParameters;
      final f = _latLon(q['f']);
      final t = _latLon(q['t']);
      if (f == null || t == null) return null;
      return RouteShareLink(
        startLat: f.$1,
        startLon: f.$2,
        startName: (q['fn'] ?? '').trim(),
        endLat: t.$1,
        endLon: t.$2,
        endName: (q['tn'] ?? '').trim(),
        routeIds: (q['v'] ?? '').split('.').where((s) => s.isNotEmpty).toList(),
      );
    }
    return null;
  }

  static (double, double)? _latLon(String? s) {
    if (s == null) return null;
    final p = s.split(',');
    if (p.length != 2) return null;
    final lat = double.tryParse(p[0]);
    final lon = double.tryParse(p[1]);
    if (lat == null || lon == null || lat.abs() > 90 || lon.abs() > 180) return null;
    return (lat, lon);
  }
}

sealed class GuidyLink {
  const GuidyLink();
}

class RouteShareLink extends GuidyLink {
  final double startLat, startLon, endLat, endLon;
  final String startName, endName;
  final List<String> routeIds;
  const RouteShareLink({
    required this.startLat,
    required this.startLon,
    required this.startName,
    required this.endLat,
    required this.endLon,
    required this.endName,
    this.routeIds = const [],
  });
}

class LiveShareLink extends GuidyLink {
  final String token;
  const LiveShareLink(this.token);
}

/// The sending side of a live trip share.
class LiveTripShare {
  final String token;
  final String _secret;
  final Uri link;
  DateTime? _lastSent;
  bool _ended = false;

  LiveTripShare._(this.token, this._secret) : link = ShareLinks.liveLink(token);

  static const Duration _interval = Duration(seconds: 12);

  /// Creates the share on the server. Null when that fails (no signal).
  static Future<LiveTripShare?> start(Map<String, dynamic> summary) async {
    try {
      final name = FirebaseAuth.instance.currentUser?.displayName;
      final resp = await http
          .post(Uri.parse('${ApiService.baseUrl}/share/live'),
              headers: ApiService.jsonHeaders,
              body: jsonEncode({
                'summary': {
                  ...summary,
                  if (name != null && name.trim().isNotEmpty) 'sharer_name': name.trim().split(' ').first,
                },
              }))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return null;
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      return LiveTripShare._(body['token'] as String, body['secret'] as String);
    } catch (_) {
      return null;
    }
  }

  bool get ended => _ended;

  /// Whether a regular update would be sent now (callers skip the work of
  /// building one otherwise).
  bool get isDue => !_ended && (_lastSent == null || DateTime.now().difference(_lastSent!) >= _interval);

  /// Sends the rider's position, at most every 12 s unless [force].
  Future<void> update({
    required double lat,
    required double lon,
    required int step,
    DateTime? eta,
    double? heading,
    String status = 'active',
    bool force = false,
  }) async {
    if (_ended) return;
    final now = DateTime.now();
    if (!force && _lastSent != null && now.difference(_lastSent!) < _interval) return;
    _lastSent = now;
    if (status != 'active') _ended = true;
    try {
      await http
          .post(Uri.parse('${ApiService.baseUrl}/share/live/$token'),
              headers: {...ApiService.jsonHeaders, 'X-Share-Secret': _secret},
              body: jsonEncode({
                'lat': lat,
                'lon': lon,
                'step': step,
                if (eta != null) 'eta': eta.millisecondsSinceEpoch / 1000.0,
                if (heading != null && heading.isFinite) 'heading': heading,
                'status': status,
              }))
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
  }
}

/// The receiving side: fetches the public view of a live share.
class LiveTripShareView {
  static Future<Map<String, dynamic>?> fetch(String token) async {
    final resp = await http
        .get(Uri.parse('${ApiService.baseUrl}/share/live/$token'), headers: ApiService.clientHeaders)
        .timeout(const Duration(seconds: 8));
    if (resp.statusCode == 410 || resp.statusCode == 404) return null;
    if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
    return jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
  }
}
