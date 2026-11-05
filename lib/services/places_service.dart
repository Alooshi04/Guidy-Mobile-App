import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'location_localizer.dart';

/// Google Places Autocomplete (New), replacing the previous Nominatim
/// (OpenStreetMap) search -- see PLACES_COST_NOTES.md for the full
/// reasoning. The short version: Google bills Places by the SESSION, not
/// the keystroke, but only if you actually use session tokens correctly.
/// Get that wrong (omit the token, reuse it, or request the wrong Place
/// Details fields) and every keystroke becomes a separate billable
/// request instead of one cheap session -- this class exists specifically
/// to make that mistake hard to make by accident.
///
/// The pattern, end to end:
/// 1. [startSession] once, when the person starts a fresh search (not on
///    every keystroke -- reusing a token across an entire search is what
///    makes the session model cheap).
/// 2. [autocomplete] on each debounced keystroke, passing that same
///    token. These calls fold into the free "Autocomplete Session Usage"
///    SKU as long as the session is later terminated properly by step 3.
/// 3. [getPlaceDetails] exactly once, when the person taps a suggestion,
///    passing the same token. This is the ONE call that actually costs
///    money -- and only beyond the first 10,000 free per month at the
///    Essentials tier ($5/1,000 after that, as of this writing). This
///    call also terminates the session: generate a fresh token before
///    starting the next search.
///
/// If a search is abandoned (person clears the field, navigates away, or
/// the screen is disposed without a selection), just call [startSession]
/// again for the next search -- there's nothing to "cancel". An
/// un-terminated session's Autocomplete calls bill individually rather
/// than as a session, which is a real cost, but it's the cost of a user
/// not finding what they wanted, not a bug to work around.
class PlacesService {
  // Keys come only from --dart-define (run_app.ps1 / build_release.ps1 pass
  // them from secrets.properties); none is stored in source. A build without
  // one fails soft: [isConfigured] is false, search returns nothing and the
  // search screens say it is unavailable.
  static const String _apiKeyAndroid = String.fromEnvironment('MAPS_API_KEY_ANDROID');
  static const String _apiKeyIOS = String.fromEnvironment('MAPS_API_KEY_IOS');
  static String get _apiKey => Platform.isAndroid ? _apiKeyAndroid : _apiKeyIOS;

  /// Whether this build was given a Places key.
  static bool get isConfigured => isKeyPresent(_apiKey);

  @visibleForTesting
  static bool isKeyPresent(String key) => key.trim().isNotEmpty;

  static bool _loggedMissingKey = false;

  /// True (and logged once) when there is no key to call Places with.
  static bool _missingKey() {
    if (isConfigured) return false;
    if (!_loggedMissingKey) {
      _loggedMissingKey = true;
      debugPrint('Places: no MAPS_API_KEY_* --dart-define in this build; search is unavailable.');
    }
    return true;
  }

  // When the Maps API key has an "Android apps" restriction in Cloud
  // Console, Google identifies the calling app via two special headers
  // (X-Android-Package / X-Android-Cert). The native Maps SDK
  // (google_maps_flutter) attaches these automatically at the OS level,
  // but a plain http.post/http.get call -- which is all this class makes
  // -- does not get them for free. Without setting them explicitly here,
  // every request shows up to Google as identifying no app at all and
  // gets rejected with "Requests from this Android client application
  // <empty> are blocked", regardless of how correctly the key itself is
  // configured.
  //
  // Package name is stable across debug/release (it's the applicationId
  // in android/app/build.gradle.kts). The certificate fingerprint is NOT
  // -- debug and release builds are signed with different keys, so they
  // have different SHA-1s. ANDROID_CERT_SHA1 below must match whichever
  // build is actually running: the debug keystore's fingerprint for
  // local dev (get it via `keytool -list -v -keystore
  // %USERPROFILE%\.android\debug.keystore -alias androiddebugkey
  // -storepass android -keypass android`, colons stripped), or the
  // release signing key's fingerprint for a release build. Cloud
  // Console's "Android apps" restriction accepts multiple package+SHA-1
  // pairs under one key, so add the release fingerprint there as an
  // ADDITIONAL entry (not a replacement) once a release keystore exists,
  // and pass the matching value here via --dart-define at build time.
  static const String _androidPackageName = 'com.guidy.guidy_app';
  static const String _androidCertSha1Debug = '10353F98C4901BABC759A03AD2181CCA42DC1505';
  static const String _androidCertSha1Release = '1817EF13606F405BFDFD7A14A8D07FE4FC0B6727';
  static const String _androidCertSha1Env = String.fromEnvironment('ANDROID_CERT_SHA1');
  static const String _androidCertSha1ReleaseEnv = String.fromEnvironment('ANDROID_CERT_SHA1_RELEASE');

  /// ANDROID_CERT_SHA1 describes the DEBUG keystore of whichever machine is
  /// building (each PC has its own), so it only ever applies to debug and
  /// profile builds. It used to win in release builds too, and every build
  /// script passes it from secrets.properties -- so a release APK announced
  /// the debug fingerprint and, once the key is Android-restricted, Google
  /// rejects every Places call from it. A release build is always signed
  /// with guidy-release-key.jks; ANDROID_CERT_SHA1_RELEASE exists only in
  /// case that key is ever replaced.
  @visibleForTesting
  static String certSha1For({required bool release, String debugEnv = '', String releaseEnv = ''}) {
    if (release) return releaseEnv.isNotEmpty ? releaseEnv : _androidCertSha1Release;
    return debugEnv.isNotEmpty ? debugEnv : _androidCertSha1Debug;
  }

  static String get _androidCertSha1 => certSha1For(
        release: kReleaseMode,
        debugEnv: _androidCertSha1Env,
        releaseEnv: _androidCertSha1ReleaseEnv,
      );

  // Same story on iOS: an "iOS apps" key restriction checks this header,
  // which the native Maps SDK sends by itself but a raw HTTP call does not.
  // Must match PRODUCT_BUNDLE_IDENTIFIER in ios/Runner.xcodeproj.
  static const String _iosBundleId = 'com.guidy.guidyApp';

  static Map<String, String> get _androidIdentityHeaders => Platform.isAndroid
      ? {'X-Android-Package': _androidPackageName, 'X-Android-Cert': _androidCertSha1}
      : Platform.isIOS
          ? {'X-Ios-Bundle-Identifier': _iosBundleId}
          : {};

  static const String _autocompleteUrl = 'https://places.googleapis.com/v1/places:autocomplete';
  static const String _placeDetailsBaseUrl = 'https://places.googleapis.com/v1/places';

  // Essentials-tier fields ONLY. Google bills the entire Place Details
  // request at whichever tier the highest-priced requested field belongs
  // to -- adding a single Pro or Enterprise field (rating, openingHours,
  // photos, phone number, website, etc.) here would silently upgrade
  // every request from ~$5/1,000 to $17+/1,000. Guidy only needs a name
  // and coordinates, so there's no reason to ever add to this mask.
  static const String _essentialsFieldMask = 'id,location,formattedAddress,displayName';

  // Bias (never restrict) results toward where the rider is -- relevant
  // results in fewer keystrokes, so fewer billed requests. A bias still
  // returns places outside it, so a rider in Cairo can find "محطة الرمل"
  // in Alexandria (and plan the intercity trip).
  //
  // Guidy covers Greater Cairo AND Alexandria, so there is no single
  // "home" centre any more: with a known rider location the bias is a
  // circle around the rider; without one it is a rectangle spanning both
  // cities, preferring neither.
  //
  // Google's hard cap is 50,000m -- 60,000 got every request rejected with
  // a 400 INVALID_ARGUMENT ("Radius must be between 0 and 50,000 meters"),
  // which is why Autocomplete looked completely dead regardless of query.
  static const int _biasRadiusMeters = 50000;
  // Alexandria + Borg El Arab (SW corner) to Greater Cairo incl. New Cairo
  // and the New Capital (NE corner).
  static const Map<String, double> _bothCitiesLow = {'latitude': 29.70, 'longitude': 29.40};
  static const Map<String, double> _bothCitiesHigh = {'latitude': 31.40, 'longitude': 31.90};

  static double? _riderLat;
  static double? _riderLon;

  /// Call wherever the app learns the rider's position; later searches
  /// are biased around it. (null, null) forgets it.
  static void rememberRiderLocation(double? lat, double? lon) {
    _riderLat = lat;
    _riderLon = lon;
  }

  static Map<String, dynamic> currentLocationBias() => locationBias(_riderLat, _riderLon);

  static bool _inEgypt(double? lat, double? lon) =>
      lat != null && lon != null && lat >= 22 && lat <= 32 && lon >= 24.5 && lon <= 37;

  /// A place this close to the rider is in their own city.
  static const int _sameCityMeters = 40000;

  /// The bias alone still put "Mansheya, Egypt" and four Cairo/Delta
  /// Mansheyas above Alexandria's for a rider in Alexandria (QA
  /// 2026-10-22). With an `origin`, each prediction carries its distance
  /// from the rider: places in the rider's city go first, in Google's
  /// order, then the rest in Google's order.
  static List<Map<String, dynamic>> rankByRiderCity(List<Map<String, dynamic>> predictions) {
    bool near(Map<String, dynamic> p) {
      final d = p['distanceMeters'];
      return d is num && d <= _sameCityMeters;
    }

    return [...predictions.where(near), ...predictions.where((p) => !near(p))];
  }

  /// Where the rider was last seen, for screens that open a map before
  /// they have a position of their own (the location picker). Null when
  /// unknown.
  static ({double lat, double lon})? get riderLocation =>
      _riderLat != null && _riderLon != null ? (lat: _riderLat!, lon: _riderLon!) : null;

  /// The Places `locationBias` for a rider at (lat, lon), or for an
  /// unknown location. A position outside Egypt (an emulator's default,
  /// a VPN) is treated as unknown.
  static Map<String, dynamic> locationBias(double? lat, double? lon) {
    if (_inEgypt(lat, lon)) {
      return {
        'circle': {
          'center': {'latitude': lat, 'longitude': lon},
          'radius': _biasRadiusMeters,
        }
      };
    }
    return {
      'rectangle': {'low': _bothCitiesLow, 'high': _bothCitiesHigh}
    };
  }

  /// Call once per fresh search (e.g. when a previously-empty field gets
  /// its first keystroke). Never reuse the returned token across two
  /// different searches -- Google treats a reused token as no token at
  /// all, which reverts every Autocomplete call in that "session" to
  /// individual per-request billing.
  /// Below this, no request leaves the device. The old floor was two
  /// characters; in Cairo a two-letter query returns noise the rider
  /// scrolls straight past, and every one of them is a billable request
  /// inside the session. Three is still short enough for real Arabic
  /// queries -- "مصر" is exactly three.
  static const int minQueryLength = 3;

  static bool isQueryTooShort(String query) => query.trim().length < minQueryLength;

  /// Memory only, and short, on purpose. Autocomplete responses carry
  /// place text and Place Details carries coordinates, and Maps Platform
  /// Service Terms §14.3 caps cached Places latitude/longitude at 30
  /// days. Nothing here survives an app restart, which puts it far inside
  /// that limit without needing a policy to enforce it.
  static const Duration _cacheTtl = Duration(hours: 6);

  /// Bounded so a long-running process cannot accumulate every query a
  /// rider has ever typed. Oldest entries go first.
  static const int _maxCacheEntries = 60;

  static final Map<String, _Cached<List<Map<String, dynamic>>>> _autocompleteCache = {};
  static final Map<String, _Cached<({double lat, double lon, String? name})>> _detailsCache = {};

  /// Requests currently in the air, keyed the same way as the cache. A
  /// second identical query joins the first rather than starting its own.
  static final Map<String, Future<List<Map<String, dynamic>>>> _inFlight = {};

  static void _remember<T>(Map<String, _Cached<T>> cache, String key, T value) {
    if (cache.length >= _maxCacheEntries) cache.remove(cache.keys.first);
    cache[key] = _Cached<T>(value);
  }

  static String startSession() {
    final rand = Random.secure();
    // Manual UUID v4 -- avoids pulling in the `uuid` package for
    // something this small. Format/version bits per RFC 4122.
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  /// Returns predictions WITHOUT coordinates -- Autocomplete (New)
  /// deliberately doesn't return lat/lon, that's what makes the session
  /// model cheap (you're not paying for geometry on every candidate the
  /// person doesn't pick). Call [getPlaceDetails] with the chosen
  /// prediction's placeId to resolve actual coordinates.
  static Future<List<Map<String, dynamic>>> autocomplete(String query, String sessionToken) async {
    if (isQueryTooShort(query)) return const [];
    if (_missingKey()) return const [];
    // The order depends on where the rider is, so a cached answer is
    // only reused near where it was asked (about 50 km).
    final where = _inEgypt(_riderLat, _riderLon)
        ? '@${(_riderLat! * 2).round()},${(_riderLon! * 2).round()}'
        : '';
    final key = '${query.trim().toLowerCase()}$where';

    final cached = _autocompleteCache[key];
    if (cached != null && cached.isFresh) return cached.value;

    // Backspacing over a word re-asks for prefixes already answered, and
    // two fields on the same screen can ask at once. Either way, one
    // request.
    final pending = _inFlight[key];
    if (pending != null) return pending;

    final request = _fetchAutocomplete(query, sessionToken);
    _inFlight[key] = request;
    try {
      final results = await request;
      // An empty list is usually a network failure rather than "no such
      // place", and caching that would hide real results for six hours.
      if (results.isNotEmpty) _remember(_autocompleteCache, key, results);
      return results;
    } finally {
      _inFlight.remove(key);
    }
  }

  static Future<List<Map<String, dynamic>>> _fetchAutocomplete(
      String query, String sessionToken) async {

    final bool queryIsArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(query);

    try {
      final response = await http.post(
        Uri.parse(_autocompleteUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey,
          ..._androidIdentityHeaders,
        },
        body: json.encode({
          'input': query,
          'sessionToken': sessionToken,
          'languageCode': queryIsArabic ? 'ar' : 'en',
          'includedRegionCodes': ['eg'],
          'locationBias': currentLocationBias(),
          if (_inEgypt(_riderLat, _riderLon))
            'origin': {'latitude': _riderLat, 'longitude': _riderLon},
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        debugPrint('Places Autocomplete error: ${response.statusCode} ${response.body}');
        return [];
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final suggestions = (data['suggestions'] as List?) ?? [];

      return rankByRiderCity(suggestions
          .map((s) => s['placePrediction'])
          .where((p) => p != null)
          .map<Map<String, dynamic>>((p) {
            final main = (p['structuredFormat']?['mainText']?['text'] ?? p['text']?['text'] ?? '').toString().trim();
            final secondary = (p['structuredFormat']?['secondaryText']?['text'] ?? '').toString().trim();
            final full = (p['text']?['text'] ?? '').toString().trim();

            String name = main;
            if (name.isEmpty || LocationLocalizer.isBareNumber(name)) {
              if (secondary.isNotEmpty) {
                final street = secondary.split(',').first.trim();
                name = name.isNotEmpty && street.isNotEmpty ? '$name $street' : (street.isNotEmpty ? street : full);
              } else if (full.isNotEmpty) {
                name = full;
              }
            }
            if (name.isEmpty) name = full;

            return {
              'name': name,
              'full_name': full.isNotEmpty ? full : name,
              'placeId': p['placeId'],
              if (p['distanceMeters'] is num) 'distanceMeters': p['distanceMeters'],
            };
          })
          .toList());
    } catch (e) {
      debugPrint('Network error during Places Autocomplete: $e');
      return [];
    }
  }

  /// The one call per search that actually costs money -- see the class
  /// doc comment. Returns null on any failure so the caller can show a
  /// clear "couldn't get that location" message rather than silently
  /// producing a location with no coordinates.
  static Future<Map<String, double>?> getPlaceDetails(String placeId, String sessionToken) async {
    final place = await getPlace(placeId, sessionToken);
    return place == null ? null : {'lat': place.lat, 'lon': place.lon};
  }

  /// [getPlaceDetails] plus the place's name in [lang] ('en'/'ar'), from
  /// the same Essentials request. A place found by typing English in the
  /// Arabic app kept its English name in every header (QA 2026-10-22);
  /// asked in the app's language, "Mansheya" comes back "المنشية".
  /// [name] is null when Google has nothing better than a house number.
  static Future<({double lat, double lon, String? name})?> getPlace(
      String placeId, String sessionToken, {String? lang}) async {
    final key = '$placeId|${lang ?? ''}';
    final cached = _detailsCache[key];
    if (cached != null && cached.isFresh) return cached.value;
    final place = await _fetchPlaceDetails(placeId, sessionToken, lang);
    if (place != null) _remember(_detailsCache, key, place);
    return place;
  }

  /// The name to show from a Place Details body, or null.
  static String? displayNameOf(Map<String, dynamic> details) {
    final name = (details['displayName']?['text'] ?? '').toString().trim();
    if (name.isEmpty || LocationLocalizer.isBareNumber(name)) return null;
    return name;
  }

  static Future<({double lat, double lon, String? name})?> _fetchPlaceDetails(
      String placeId, String sessionToken, String? lang) async {
    if (_missingKey()) return null;
    try {
      final language = lang == null ? '' : '&languageCode=$lang';
      final response = await http.get(
        Uri.parse('$_placeDetailsBaseUrl/$placeId?sessionToken=$sessionToken$language'),
        headers: {
          'X-Goog-Api-Key': _apiKey,
          'X-Goog-FieldMask': _essentialsFieldMask,
          ..._androidIdentityHeaders,
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        debugPrint('Place Details error: ${response.statusCode} ${response.body}');
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final location = data['location'] as Map<String, dynamic>?;
      if (location == null) return null;

      final lat = location['latitude'] is num ? (location['latitude'] as num).toDouble() : double.tryParse(location['latitude']?.toString() ?? '');
      final lon = location['longitude'] is num ? (location['longitude'] as num).toDouble() : double.tryParse(location['longitude']?.toString() ?? '');
      if (lat == null || lon == null) return null;
      return (lat: lat, lon: lon, name: displayNameOf(data));
    } catch (e) {
      debugPrint('Network error fetching Place Details: $e');
      return null;
    }
  }
}

class _Cached<T> {
  _Cached(this.value) : storedAt = DateTime.now();

  final T value;
  final DateTime storedAt;

  bool get isFresh =>
      DateTime.now().difference(storedAt) < PlacesService._cacheTtl;
}
