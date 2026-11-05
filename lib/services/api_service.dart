import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'reference_cache.dart';
import 'route_choice.dart';
import '../utils/deep_copy.dart';
import '../utils/polyline_utils.dart';

class ApiService {
  static const String _prefKey = 'active_api_base_url';

  static const String _defaultProductionUrl = 'https://api.guidyapp.com/api';

  /// The server's address before it had a domain. Still served (same
  /// machine, same certificate setup), so builds already on phones keep
  /// working and a new build can fall back to it.
  static const String _legacyProductionUrl = 'https://api.202.61.197.114.nip.io/api';

  static const String _envBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultProductionUrl,
  );

  /// Default candidate endpoints in priority order:
  /// 1. Built-in environment definition (passed at build time via --dart-define)
  /// 2..5. Development fallbacks: dev machine LAN IP, ADB reverse tunnel /
  ///    device loopback, Android emulator host alias, Windows Mobile Hotspot.
  ///
  /// The development fallbacks are DEBUG-ONLY on purpose. Shipped in a
  /// release build they would have every rider's phone probing 192.168.1.9
  /// and 127.0.0.1 on whatever network it happens to join -- a café or
  /// office LAN can easily have a device at that address, and the app would
  /// then happily talk to it and cache it in SharedPreferences as its API.
  /// A release build talks to the URL it was built with, or nothing.
  static final List<String> defaultCandidates = [
    if (_envBaseUrl.isNotEmpty) _envBaseUrl,
    if (_envBaseUrl != _defaultProductionUrl) _defaultProductionUrl,
    if (_envBaseUrl != _legacyProductionUrl) _legacyProductionUrl,
    if (!kReleaseMode) ...[
      'http://192.168.1.9:8000/api',
      'http://127.0.0.1:8000/api',
      'http://10.0.2.2:8000/api',
      'http://192.168.137.1:8000/api',
    ],
  ];

  static String _activeBaseUrl = _envBaseUrl.isNotEmpty
      ? _envBaseUrl
      : (kReleaseMode ? _defaultProductionUrl : 'http://192.168.1.9:8000/api');

  static Future<String>? _discoveryFuture;
  static bool _initialized = false;

  /// Dynamic baseUrl that always reflects the currently working endpoint.
  static String get baseUrl => _activeBaseUrl;

  static const String _installIdKey = 'guidy_install_id';
  static final RegExp _installIdPattern = RegExp(r'^[0-9a-f]{32}$');
  static String? _installId;

  /// Headers every request to our own backend carries.
  ///
  /// X-Guidy-Install is a random ID made once per install (not tied to the
  /// account, the phone or anything else). The server rate-limits per
  /// install instead of per IP address: mobile carriers put many phones
  /// behind one public IP, and per-IP limits made all of them share one
  /// rider's allowance. Empty until [init] has read or made the ID; the
  /// server then falls back to the IP, as before.
  static Map<String, String> get clientHeaders =>
      _installId == null ? const {} : {'X-Guidy-Install': _installId!};

  /// [clientHeaders] plus a JSON content type, for POSTs.
  static Map<String, String> get jsonHeaders =>
      {'Content-Type': 'application/json', ...clientHeaders};

  @visibleForTesting
  static String newInstallId() {
    final rnd = Random.secure();
    return List.generate(16, (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  @visibleForTesting
  static Future<void> loadInstallIdForTesting({SharedPreferences? prefs}) =>
      _loadInstallId(prefs: prefs);

  @visibleForTesting
  static void resetInstallIdForTesting() => _installId = null;

  static Future<void> _loadInstallId({SharedPreferences? prefs}) async {
    try {
      prefs ??= await SharedPreferences.getInstance();
      final stored = prefs.getString(_installIdKey);
      if (stored != null && _installIdPattern.hasMatch(stored)) {
        _installId = stored;
        return;
      }
      // Use the new ID straight away: requests made while it is being saved
      // carry it, and a failed save costs only a new ID next launch rather
      // than no ID at all this session.
      final id = newInstallId();
      _installId = id;
      await prefs.setString(_installIdKey, id);
    } catch (e) {
      debugPrint('[ApiService] Could not read or save the install ID: $e');
    }
  }

  /// Manually override or set active base URL (e.g. for testing).
  @visibleForTesting
  static void setBaseUrlForTesting(String url) {
    _activeBaseUrl = url;
  }

  /// Whether a base URL read back from SharedPreferences may be used. In a
  /// release build only one of [defaultCandidates] qualifies.
  @visibleForTesting
  static bool isAcceptableSavedUrl(String? url, {bool release = kReleaseMode}) =>
      url != null && url.isNotEmpty && (!release || defaultCandidates.contains(url));

  /// Initializes the working baseUrl from SharedPreferences and triggers background discovery.
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString(_prefKey);
      // In release, only honour a saved URL that is still a legitimate
      // candidate. Otherwise a LAN address cached during development (or by
      // an earlier debug install on the same device) would outlive it and
      // silently keep a shipped build pointed at a machine that is not ours.
      if (savedUrl != null && isAcceptableSavedUrl(savedUrl)) {
        _activeBaseUrl = savedUrl;
      }
    } catch (e) {
      debugPrint('[ApiService] Error reading saved base URL: $e');
    }
    await _loadInstallId();
    // Probe candidates in background without blocking app startup
    unawaited(discoverWorkingBaseUrl());
  }

  /// Discovers which candidate base URL is reachable and updates [baseUrl].
  static Future<String> discoverWorkingBaseUrl({Duration timeout = const Duration(milliseconds: 1500)}) async {
    if (_discoveryFuture != null) return _discoveryFuture!;

    _discoveryFuture = _performDiscovery(timeout);
    try {
      final winner = await _discoveryFuture!;
      return winner;
    } finally {
      _discoveryFuture = null;
    }
  }

  static Future<String> _performDiscovery(Duration timeout) async {
    final candidates = <String>[];

    void addCandidate(String? url) {
      if (url != null && url.trim().isNotEmpty && !candidates.contains(url.trim())) {
        candidates.add(url.trim());
      }
    }

    // 1. Current active URL
    addCandidate(_activeBaseUrl);

    // 2. Saved in SharedPreferences -- under the same rule init() applies.
    // Discovery used to add the saved URL unconditionally, so whenever the
    // real server was unreachable a release build would probe (and adopt,
    // and re-save) a LAN address left over from a debug install.
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (isAcceptableSavedUrl(saved)) addCandidate(saved);
    } catch (_) {}

    // 3. Default candidates
    for (final c in defaultCandidates) {
      addCandidate(c);
    }

    // Quick test on activeBaseUrl first
    if (candidates.isNotEmpty) {
      final activeOk = await _pingCandidate(candidates.first, timeout);
      if (activeOk) {
        return candidates.first;
      }
    }

    // Probe remaining candidates concurrently
    final futures = candidates.map((url) async {
      final ok = await _pingCandidate(url, timeout);
      return ok ? url : null;
    });

    final results = await Future.wait(futures);
    for (final match in results) {
      if (match != null) {
        _activeBaseUrl = match;
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefKey, match);
        } catch (_) {}
        debugPrint('[ApiService] Auto-discovered working base URL: $match');
        return match;
      }
    }

    return _activeBaseUrl;
  }

  static Future<bool> _pingCandidate(String candidateUrl, Duration timeout) async {
    try {
      final uri = Uri.parse('$candidateUrl/health');
      final resp = await http.get(uri, headers: clientHeaders).timeout(timeout);
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Executes an API request with automatic fallback: if it fails with a network exception,
  /// discovers a working candidate URL and retries the action once.
  ///
  /// [retryOnTimeout] must be false for expensive requests. A timeout means
  /// the server DID receive the request and is still working on it; asking
  /// again makes it compute the same answer twice (a route search is the
  /// costliest thing the server does) and doubles the load at exactly the
  /// moment it is already too slow. Connection failures are still retried:
  /// those never reached a working server.
  static Future<T> _withNetworkFallback<T>(Future<T> Function() action,
      {bool retryOnTimeout = true}) async {
    try {
      return await action();
    } on SocketException catch (_) {
      await discoverWorkingBaseUrl();
      return await action();
    } on http.ClientException catch (_) {
      await discoverWorkingBaseUrl();
      return await action();
    } on TimeoutException catch (_) {
      if (!retryOnTimeout) rethrow;
      await discoverWorkingBaseUrl();
      return await action();
    }
  }

  // --- In-Memory Route Cache ----------------------------------------
  // Short on purpose. Route answers carry live ETAs ("bus 4 min away"),
  // which the server now refreshes on every request even when the route
  // itself comes from its cache. At 15 minutes this client cache could
  // show a rider where a bus was a quarter of an hour ago.
  static const Duration routeCacheTtl = Duration(minutes: 2);
  static const int maxRouteCacheSize = 50;
  static final Map<String, _RouteCacheEntry> _routeCache = {};

  static String makeRouteCacheKey({
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
    String lang = 'en',
    bool excludeMetro = false,
    bool minWalk = false,
    bool minTransfers = false,
  }) {
    // Round coordinates to 4 decimal places (~11m precision) so nearby GPS fixes share cached routes.
    final sLat = startLat.toStringAsFixed(4);
    final sLon = startLon.toStringAsFixed(4);
    final eLat = endLat.toStringAsFixed(4);
    final eLon = endLon.toStringAsFixed(4);
    return '$sLat,$sLon,$eLat,$eLon,$lang,$excludeMetro,$minWalk,$minTransfers';
  }

  static Map<String, dynamic>? getCachedRoute({
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
    String lang = 'en',
    bool excludeMetro = false,
    bool minWalk = false,
    bool minTransfers = false,
  }) {
    final key = makeRouteCacheKey(
      startLat: startLat,
      startLon: startLon,
      endLat: endLat,
      endLon: endLon,
      lang: lang,
      excludeMetro: excludeMetro,
      minWalk: minWalk,
      minTransfers: minTransfers,
    );
    final entry = _routeCache[key];
    if (entry == null) return null;
    if (entry.isExpired(routeCacheTtl)) {
      _routeCache.remove(key);
      return null;
    }
    // A copy: the screen that gets it may change it.
    return deepCopyMap(entry.data);
  }

  static void cacheRoute({
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
    String lang = 'en',
    bool excludeMetro = false,
    bool minWalk = false,
    bool minTransfers = false,
    required Map<String, dynamic> data,
  }) {
    // Never cache error responses
    if (data['success'] == false) return;
    final key = makeRouteCacheKey(
      startLat: startLat,
      startLon: startLon,
      endLat: endLat,
      endLon: endLon,
      lang: lang,
      excludeMetro: excludeMetro,
      minWalk: minWalk,
      minTransfers: minTransfers,
    );
    if (_routeCache.length >= maxRouteCacheSize) {
      _routeCache.remove(_routeCache.keys.first);
    }
    _routeCache[key] = _RouteCacheEntry(data, DateTime.now());
  }

  @visibleForTesting
  static void clearRouteCache() {
    _routeCache.clear();
  }

  /// Fire-and-forget prefetch to warm up the client cache before the user enters RouteOptionsScreen.
  void prefetchRoute(
    double startLat, 
    double startLon, 
    double endLat, 
    double endLon, {
    String lang = 'en',
    bool excludeMetro = false,
    bool minWalk = false,
    bool minTransfers = false,
  }) {
    fetchRoute(
      startLat,
      startLon,
      endLat,
      endLon,
      lang: lang,
      excludeMetro: excludeMetro,
      minWalk: minWalk,
      minTransfers: minTransfers,
    ).ignore();
  }

  static final Map<String, Future<Map<String, dynamic>>> _inFlightRouteRequests = {};

  Future<Map<String, dynamic>> fetchRoute(
    double startLat, 
    double startLon, 
    double endLat, 
    double endLon, {
    String lang = 'en',
    bool excludeMetro = false,
    bool minWalk = false,
    bool minTransfers = false,
  }) async {
    // 1. Instant Cache Hit Check (0 ms)
    final cached = getCachedRoute(
      startLat: startLat,
      startLon: startLon,
      endLat: endLat,
      endLon: endLon,
      lang: lang,
      excludeMetro: excludeMetro,
      minWalk: minWalk,
      minTransfers: minTransfers,
    );
    if (cached != null) {
      return cached;
    }

    final requestKey = makeRouteCacheKey(
      startLat: startLat,
      startLon: startLon,
      endLat: endLat,
      endLon: endLon,
      lang: lang,
      excludeMetro: excludeMetro,
      minWalk: minWalk,
      minTransfers: minTransfers,
    );
    final inFlight = _inFlightRouteRequests[requestKey];
    if (inFlight != null) {
      return await inFlight;
    }

    final future = _fetchRouteInternal(
      startLat,
      startLon,
      endLat,
      endLon,
      lang: lang,
      excludeMetro: excludeMetro,
      minWalk: minWalk,
      minTransfers: minTransfers,
    );
    _inFlightRouteRequests[requestKey] = future;
    try {
      final res = await future;
      if (res['success'] != false) {
        cacheRoute(
          startLat: startLat,
          startLon: startLon,
          endLat: endLat,
          endLon: endLon,
          lang: lang,
          excludeMetro: excludeMetro,
          minWalk: minWalk,
          minTransfers: minTransfers,
          data: res,
        );
      }
      return res;
    } finally {
      _inFlightRouteRequests.remove(requestKey);
    }
  }

  Future<Map<String, dynamic>> _fetchRouteInternal(
    double startLat, 
    double startLon, 
    double endLat, 
    double endLon, {
    String lang = 'en',
    bool excludeMetro = false,
    bool minWalk = false,
    bool minTransfers = false,
  }) async {
    try {
      return await _withNetworkFallback(() async {
        final metroParam = excludeMetro ? '&exclude_metro=true' : '';
        final walkParam = minWalk ? '&min_walk=true' : '';
        final transferParam = minTransfers ? '&min_transfers=true' : '';
        final response = await http.get(
          Uri.parse('$baseUrl/route?start_lat=$startLat&start_lon=$startLon&end_lat=$endLat&end_lon=$endLon&lang=$lang$metroParam$walkParam$transferParam'),
          headers: clientHeaders,
        ).timeout(const Duration(seconds: 15));

        final decoded = await Isolate.run(() => _parseAndDecompressRouteResponse(response.body));

        if (response.statusCode == 200) {
          return decoded ?? {'success': false, 'error_code': 'server_error'};
        }
        final error = _errorFrom(decoded);
        final detail = decoded?['detail'];
        return {
          'success': false,
          'error_code': error.$1,
          'error': error.$2,
          'nearest_hubs': detail is Map ? detail['nearest_hubs'] : null,
        };
      }, retryOnTimeout: false);
    } catch (e) {
      // No English prose thrown from here: the screens turn a code into a
      // localized message. A raw exception string used to end up rendered
      // verbatim on an Arabic screen, "Exception:" prefix and all.
      return {'success': false, 'error_code': 'network'};
    }
  }

  /// Parses JSON and expands `points_encoded` into `points` off the UI thread.
  static Map<String, dynamic>? _parseAndDecompressRouteResponse(String body) {
    try {
      final decoded = json.decode(body);
      if (decoded is! Map<String, dynamic>) return null;

      final options = decoded['options'];
      if (options is List) {
        for (final option in options) {
          if (option is! Map) continue;
          RouteChoice.plannedLineFirst(option);
          final segments = option['segments'];
          if (segments is List) {
            for (final segment in segments) {
              if (segment is! Map) continue;
              final encoded = segment['points_encoded'];
              if (encoded is String && encoded.isNotEmpty) {
                segment['points'] = PolylineUtils.decode(encoded);
              }
            }
          }
        }
      }
      return decoded;
    } catch (_) {
      return null;
    }
  }

  /// (code, message) out of an error body, whichever shape it arrived in.
  (String?, String?) _errorFrom(Map<String, dynamic>? decoded) {
    final detail = decoded?['detail'];
    if (detail is Map) {
      return (detail['code'] as String?, detail['message'] as String?);
    }
    if (detail is String) return (null, detail);
    final error = decoded?['error'];
    return (decoded?['error_code'] as String?, error is String ? error : null);
  }

  Map<String, dynamic>? _tryDecode(String body) {
    try {
      return json.decode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // --- Live position reporting -------------------------------------
  // Crowdsourced vehicle tracking: while a rider is actively riding a
  // transit leg, the app periodically reports their GPS against that
  // leg's route_id/direction_id (see live_tracking_service.dart). The
  // backend uses these reports to attach a real-time ETA to every
  // interchangeable route on a leg instead of just picking one -- see
  // main.py's /api/live/position and raptor_engine.py's
  // _find_equivalent_routes(). Failures here are swallowed rather than
  // thrown: a dropped position report should never interrupt or error
  // out someone's in-progress trip, it just means one less live data
  // point this round.
  Future<void> reportLivePosition({
    required String sessionId,
    required String routeId,
    required String directionId,
    required double lat,
    required double lon,
  }) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/live/position'),
        headers: jsonHeaders,
        body: json.encode({
          'session_id': sessionId,
          'route_id': routeId,
          'direction_id': directionId,
          'lat': lat,
          'lon': lon,
        }),
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      // Best-effort -- see doc comment above.
    }
  }

  /// Explicitly terminates a live tracking session when the rider alights or arrives.
  Future<void> endLiveSession(String sessionId) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/live/end'),
        headers: jsonHeaders,
        body: json.encode({'session_id': sessionId}),
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      // Best-effort
    }
  }

  /// Submits crowdsourced GPS breadcrumbs recorded while riding a transit leg
  /// to refine and update the user-contributed GTFS overlay feed.
  Future<void> submitUserRouteTrace({
    required String sessionId,
    required String routeId,
    required String directionId,
    required List<Map<String, double>> points,
  }) async {
    if (points.length < 3) return;
    try {
      await http.post(
        Uri.parse('$baseUrl/live/submit_trace'),
        headers: jsonHeaders,
        body: json.encode({
          'session_id': sessionId,
          'route_id': routeId,
          'direction_id': directionId,
          'points': points,
        }),
      ).timeout(const Duration(seconds: 8));
    } catch (e) {
      // Best-effort trace contribution
    }
  }

  // --- Lookup tools -------------------------------------------------
  // These sit beside the trip planner rather than inside it: the browser
  // answers "what does line 65 actually do?" and the metro planner answers
  // "how do I get there on the metro only?". Both are served by
  // lookups.py, which reads the same GTFS structures the planner uses, so
  // a stop order or a metro fare shown here can never disagree with the
  // one shown on a planned trip.

  /// Search lines by number *or* by where they go. The second half matters:
  /// roughly 300 microbus routes in the feed have no number at all, only a
  /// corridor name, so a number-only search would hide them entirely.
  Future<List<Map<String, dynamic>>> searchRoutes({
    String query = '',
    String? vehicleType,
    String lang = 'en',
    int limit = 40,
  }) async {
    final params = <String, String>{
      'q': query,
      'lang': lang,
      'limit': '$limit',
      'vehicle_type': ?vehicleType,
    };

    // Only the unfiltered browse views are cached.
    final cacheKey =
        query.isEmpty ? 'routes_${vehicleType ?? 'all'}_${lang}_$limit' : null;
    if (cacheKey != null) {
      final cached = await ReferenceCache.read(cacheKey);
      if (cached != null) return List<Map<String, dynamic>>.from(cached as List);
    }

    try {
      return await _withNetworkFallback(() async {
        final uri = Uri.parse('$baseUrl/routes').replace(queryParameters: params);
        final response = await http.get(uri, headers: clientHeaders).timeout(const Duration(seconds: 10));
        final decoded = _tryDecode(response.body);
        if (response.statusCode == 200 && decoded != null) {
          final routes = List<Map<String, dynamic>>.from(decoded['routes'] ?? const []);
          if (cacheKey != null) await ReferenceCache.write(cacheKey, routes);
          return routes;
        }
        throw Exception(decoded?['detail'] ?? 'Failed to load lines.');
      });
    } catch (e) {
      if (cacheKey != null) {
        final stale = await ReferenceCache.readStale(cacheKey);
        if (stale != null) return List<Map<String, dynamic>>.from(stale as List);
      }
      throw Exception('Could not reach the Guidy server.');
    }
  }

  /// Every direction of one line, each as an ordered stop list.
  Future<Map<String, dynamic>> fetchRouteDetail(String routeId, {String lang = 'en'}) async {
    final cacheKey = 'route_detail_${routeId}_$lang';
    final cached = await ReferenceCache.read(cacheKey);
    if (cached != null) return Map<String, dynamic>.from(cached as Map);

    try {
      return await _withNetworkFallback(() async {
        final uri = Uri.parse('$baseUrl/routes/${Uri.encodeComponent(routeId)}?lang=$lang');
        final response = await http.get(uri, headers: clientHeaders).timeout(const Duration(seconds: 10));
        final decoded = _tryDecode(response.body);
        if (response.statusCode == 200 && decoded != null) {
          await ReferenceCache.write(cacheKey, decoded, persist: false);
          return decoded;
        }
        throw Exception(decoded?['detail'] ?? 'Failed to load that line.');
      });
    } catch (e) {
      final stale = await ReferenceCache.readStale(cacheKey);
      if (stale != null) return Map<String, dynamic>.from(stale as Map);
      throw Exception('Could not reach the Guidy server.');
    }
  }

  Future<List<Map<String, dynamic>>> fetchMetroStations({String lang = 'en'}) async {
    final cacheKey = 'metro_stations_$lang';
    final cached = await ReferenceCache.read(cacheKey);
    if (cached != null) return List<Map<String, dynamic>>.from(cached as List);

    try {
      return await _withNetworkFallback(() async {
        final uri = Uri.parse('$baseUrl/metro/stations?lang=$lang');
        final response = await http.get(uri, headers: clientHeaders).timeout(const Duration(seconds: 10));
        final decoded = _tryDecode(response.body);
        if (response.statusCode == 200 && decoded != null) {
          final stations = List<Map<String, dynamic>>.from(decoded['stations'] ?? const []);
          await ReferenceCache.write(cacheKey, stations);
          return stations;
        }
        throw Exception(decoded?['detail'] ?? 'Failed to load metro stations.');
      });
    } catch (e) {
      final stale = await ReferenceCache.readStale(cacheKey);
      if (stale != null) return List<Map<String, dynamic>>.from(stale as List);
      throw Exception('Could not reach the Guidy server.');
    }
  }

  /// Metro-only plan between two stations. Returns the backend's own
  /// `detail` message on 404 rather than a generic failure, because the
  /// useful cases -- same station, or two stations with no metro-only
  /// connection -- are worth saying out loud.
  Future<Map<String, dynamic>> planMetro({
    required String fromStop,
    required String toStop,
    String lang = 'en',
  }) async {
    try {
      return await _withNetworkFallback(() async {
        final uri = Uri.parse('$baseUrl/metro/plan').replace(queryParameters: {
          'from_stop': fromStop,
          'to_stop': toStop,
          'lang': lang,
        });
        final response = await http.get(uri, headers: clientHeaders).timeout(const Duration(seconds: 10));
        final decoded = _tryDecode(response.body);
        if (response.statusCode == 200 && decoded != null) return decoded;
        return {
          'success': false,
          'error': decoded?['detail'] ?? decoded?['error'] ?? 'Failed to plan that metro trip.',
        };
      });
    } catch (e) {
      return {'success': false, 'error': 'Could not reach the Guidy server.'};
    }
  }
}

class _RouteCacheEntry {
  final Map<String, dynamic> data;
  final DateTime timestamp;

  _RouteCacheEntry(this.data, this.timestamp);

  bool isExpired(Duration ttl) => DateTime.now().difference(timestamp) > ttl;
}