import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'location_localizer.dart';

/// Result of parsing pasted text as a Google Maps link or raw coordinates.
/// [name] is null when all we have is a coordinate pair with no place
/// name attached (a bare pasted "lat,lng" or a Maps link with no place
/// label) -- callers should reverse-geocode or show a generic label.
class ParsedMapsLocation {
  final double lat;
  final double lon;
  final String? name;
  const ParsedMapsLocation({required this.lat, required this.lon, this.name});
}

/// Recognizes and resolves:
/// - Full Google Maps URLs with embedded coordinates (several formats --
///   see the regexes below, Google has changed this URL shape more than
///   once over the years and old links still float around)
/// - Short maps.app.goo.gl / goo.gl/maps links, which contain no
///   coordinates at all and have to be resolved via their HTTP redirect
///   to the real URL first
/// - A bare pasted "lat,lng" pair with no URL at all
///
/// This deliberately does NOT go through Places Autocomplete/Details --
/// a pasted link is already a precise, resolved location, not a text
/// query that benefits from (or should be billed as) a places search.
class MapsLinkParser {
  static final RegExp _shortLinkPattern = RegExp(
    r'^https?://(maps\.app\.goo\.gl|goo\.gl/maps)/\S+',
    caseSensitive: false,
  );

  static final RegExp _mapsUrlPattern = RegExp(
    r'^https?://(www\.)?(google\.[a-z.]+/maps|maps\.google\.[a-z.]+)',
    caseSensitive: false,
  );

  /// Android's standard "geo:" URI scheme for map coordinates -- e.g.
  /// geo:30.0444,31.2357 or geo:0,0?q=30.0444,31.2357(Some+Place). Several
  /// apps (and Android's own share/open-with mechanism) hand these off
  /// instead of a full Google Maps URL.
  static final RegExp _geoUriPattern = RegExp(r'^geo:', caseSensitive: false);

  /// A bare "30.0444, 31.2357" with no surrounding URL. Deliberately
  /// requires a decimal point on both numbers and a sensible lat/lon
  /// range check afterward, so it doesn't misfire on things like phone
  /// numbers or arbitrary "12, 34" text someone happens to type.
  static final RegExp _bareCoordPattern = RegExp(
    r'^\s*(-?\d{1,3}\.\d+)\s*,\s*(-?\d{1,3}\.\d+)\s*$',
  );

  /// The maps link or coordinates inside a longer text, or null. What
  /// WhatsApp and Google Maps' Share button send is rarely just a link:
  /// "Cairo Tower\nhttps://maps.app.goo.gl/abc" or a sentence around it.
  static String? findInText(String text) {
    final t = text.trim();
    if (looksLikeMapsInput(t)) return t;
    for (final m in RegExp(r'(https?://\S+|geo:\S+)', caseSensitive: false).allMatches(t)) {
      final candidate = m.group(0)!.replaceAll(RegExp(r'[)\].,;!?]+$'), '');
      if (looksLikeMapsInput(candidate)) return candidate;
    }
    for (final line in t.split('\n')) {
      if (_bareCoordPattern.hasMatch(line)) return line.trim();
    }
    final inline = RegExp(r'(-?\d{1,2}\.\d{3,})\s*,\s*(-?\d{1,3}\.\d{3,})').firstMatch(t);
    if (inline != null) return '${inline.group(1)},${inline.group(2)}';
    return null;
  }

  /// A place name given by a link that carries only a search, no
  /// coordinates (shared places often resolve to maps.google.com/?q=Name,
  /// +Address&ftid=...). Null when the link has one.
  static String? placeQueryOf(String url) {
    try {
      final uri = Uri.parse(url);
      final q = uri.queryParameters['q'] ?? uri.queryParameters['query'];
      if (q == null || q.trim().isEmpty) return null;
      if (RegExp(r'^\s*-?\d+\.\d+\s*,\s*-?\d+\.\d+\s*$').hasMatch(q)) return null;
      return q.trim();
    } catch (_) {
      return null;
    }
  }

  /// Like [parse], and when the link names a place but carries no
  /// coordinates, finds that place by name with [lookup] (the app passes
  /// a Places search).
  static Future<ParsedMapsLocation?> parseOrLookup(
    String text,
    Future<ParsedMapsLocation?> Function(String query) lookup,
  ) async {
    final found = findInText(text);
    if (found == null) return null;
    final direct = await parse(found);
    if (direct != null) return direct;
    var url = found;
    if (_shortLinkPattern.hasMatch(found)) {
      url = await _resolveRedirect(found) ?? found;
    }
    final q = placeQueryOf(url) ?? _extractPlaceName(url);
    if (q == null) return null;
    return lookup(q);
  }

  static bool looksLikeMapsInput(String text) {
    final t = text.trim();
    return _shortLinkPattern.hasMatch(t) || _mapsUrlPattern.hasMatch(t) ||
        _bareCoordPattern.hasMatch(t) || _geoUriPattern.hasMatch(t);
  }

  /// Returns null if [text] doesn't look like a Maps link/coordinate pair
  /// at all, or if it does but resolving it fails (bad short link,
  /// network error, or a long link with no coordinates we recognize --
  /// e.g. a "search by place name" link with no lat/lng in it).
  static Future<ParsedMapsLocation?> parse(String text) async {
    final t = text.trim();

    final bareMatch = _bareCoordPattern.firstMatch(t);
    if (bareMatch != null) {
      final lat = double.tryParse(bareMatch.group(1)!);
      final lon = double.tryParse(bareMatch.group(2)!);
      if (lat != null && lon != null && _isPlausibleLatLon(lat, lon)) {
        return ParsedMapsLocation(lat: lat, lon: lon);
      }
      return null;
    }

    if (_geoUriPattern.hasMatch(t)) {
      return _extractFromGeoUri(t);
    }

    if (_shortLinkPattern.hasMatch(t)) {
      final resolved = await _resolveRedirect(t);
      if (resolved == null) return null;
      return _extractFromLongUrl(resolved);
    }

    if (_mapsUrlPattern.hasMatch(t)) {
      return _extractFromLongUrl(t);
    }

    return null;
  }

  static bool _isPlausibleLatLon(double lat, double lon) {
    return lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180;
  }

  /// geo:lat,lng or geo:0,0?q=lat,lng(Label) or geo:0,0?q=lat,lng --
  /// prefer the q= pair when present (geo:0,0 is a common placeholder
  /// some apps use for "no viewport center, just show this query point").
  static ParsedMapsLocation? _extractFromGeoUri(String uri) {
    final qMatch = RegExp(r'[?&]q=(-?\d+\.?\d*),(-?\d+\.?\d*)(?:\(([^)]+)\))?').firstMatch(uri);
    if (qMatch != null) {
      final lat = double.tryParse(qMatch.group(1)!);
      final lon = double.tryParse(qMatch.group(2)!);
      if (lat != null && lon != null && _isPlausibleLatLon(lat, lon)) {
        final label = qMatch.group(3);
        return ParsedMapsLocation(lat: lat, lon: lon, name: label != null ? Uri.decodeComponent(label) : null);
      }
    }
    final plain = RegExp(r'^geo:(-?\d+\.?\d*),(-?\d+\.?\d*)').firstMatch(uri);
    if (plain != null) {
      final lat = double.tryParse(plain.group(1)!);
      final lon = double.tryParse(plain.group(2)!);
      if (lat != null && lon != null && _isPlausibleLatLon(lat, lon) && !(lat == 0 && lon == 0)) {
        return ParsedMapsLocation(lat: lat, lon: lon);
      }
    }
    return null;
  }

  static ParsedMapsLocation? _extractFromLongUrl(String url) {
    // Prefer !3d<lat>!4d<lng> -- this is the actual pinned place.
    // @lat,lng is only the map viewport center/zoom, which is close but
    // not necessarily the same point (e.g. if the link was panned after
    // the place was selected).
    final pin = RegExp(r'!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)').firstMatch(url);
    if (pin != null) {
      final lat = double.tryParse(pin.group(1)!);
      final lon = double.tryParse(pin.group(2)!);
      if (lat != null && lon != null) {
        return ParsedMapsLocation(lat: lat, lon: lon, name: _extractPlaceName(url));
      }
    }

    final viewport = RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)').firstMatch(url);
    if (viewport != null) {
      final lat = double.tryParse(viewport.group(1)!);
      final lon = double.tryParse(viewport.group(2)!);
      if (lat != null && lon != null) {
        return ParsedMapsLocation(lat: lat, lon: lon, name: _extractPlaceName(url));
      }
    }

    // ?q=lat,lng / ?query=lat,lng / ?ll=lat,lng query-parameter forms
    try {
      final uri = Uri.parse(url);
      for (final key in ['query', 'q', 'll']) {
        final value = uri.queryParameters[key];
        if (value == null) continue;
        final m = RegExp(r'^(-?\d+\.\d+),(-?\d+\.\d+)$').firstMatch(value);
        if (m != null) {
          final lat = double.tryParse(m.group(1)!);
          final lon = double.tryParse(m.group(2)!);
          if (lat != null && lon != null) return ParsedMapsLocation(lat: lat, lon: lon);
        }
      }
    } catch (_) {
      // malformed URL -- fall through to null
    }

    return null;
  }

  /// Google Maps place URLs put a human-readable (if URL-encoded, +-for-
  /// space) name right after /maps/place/ -- worth grabbing when present
  /// so the search field shows something better than raw coordinates.
  static String? _extractPlaceName(String url) {
    final m = RegExp(r'/maps/place/([^/@]+)').firstMatch(url);
    if (m == null) return null;
    try {
      return Uri.decodeComponent(m.group(1)!.replaceAll('+', ' '));
    } catch (_) {
      return null;
    }
  }

  /// Manually follows redirects (rather than relying on package:http's
  /// implicit redirect-following, which doesn't expose the final
  /// resolved URL through the simple .get()/.head() shorthand) so we
  /// reliably land on the real, coordinate-bearing URL a short link
  /// points to. Capped at 5 hops as a sane loop guard.
  static Future<String?> _resolveRedirect(String shortUrl) async {
    final client = HttpClient();
    try {
      Uri current = Uri.parse(shortUrl);
      for (int i = 0; i < 5; i++) {
        final request = await client.headUrl(current).timeout(const Duration(seconds: 5));
        request.followRedirects = false;
        final response = await request.close().timeout(const Duration(seconds: 5));
        if (response.statusCode >= 300 && response.statusCode < 400) {
          final location = response.headers.value('location');
          if (location == null) return null;
          current = current.resolve(location);
          continue;
        }
        return current.toString();
      }
      return current.toString(); // hit the hop cap -- use whatever we last landed on
    } catch (e) {
      debugPrint('Error resolving Maps short link: $e');
      return null;
    } finally {
      client.close();
    }
  }

  /// Free reverse-geocode (Nominatim, same as the existing tap-on-map
  /// picker) for when we've resolved coordinates but have no place name
  /// -- a bare pasted "lat,lng" or a Maps link Google didn't embed a
  /// name into. Deliberately NOT a Places API call: reverse geocoding a
  /// single already-known point isn't part of the Autocomplete session
  /// model this app optimizes for, and Nominatim is free for this.
  /// [lang] is passed to Nominatim as Accept-Language, so an Arabic build
  /// gets the Arabic name of the place rather than the English one. Without
  /// it, pasting a pin into an Arabic app produced an English place name.
  ///
  /// [fallbackLabel] is what to call the place when the lookup finds
  /// nothing. It's a parameter rather than a constant because this class
  /// has no BuildContext and so cannot reach the localizations itself --
  /// callers pass l10n.pinnedLocation.
  static Future<String> reverseGeocodeName(
    double lat,
    double lon, {
    required String fallbackLabel,
    String lang = 'en',
  }) async {
    // Nominatim asks for at most one request per second and Guidy is a
    // guest on it. Two taps a few metres apart, or the same pasted link
    // opened twice, resolve to the same street anyway -- so answer those
    // from memory instead of asking again.
    //
    // Four decimals is about 11m at this latitude, which is finer than
    // the precision of the answer being cached: Nominatim returns a
    // street or POI name, not a doorway. Language is part of the key
    // because the same point has a different name in each.
    final cacheKey = '${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}|$lang';
    final cached = _reverseCache[cacheKey];
    if (cached != null) return cached;

    try {
      final url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Guidy_Transit_Capstone_Project/1.0',
          'Accept-Language': lang,
        },
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final resolved = data is Map<String, dynamic> ? placeNameFromReverse(data, lang: lang) : null;
        if (resolved != null && resolved.isNotEmpty) {
          // Only successes are cached. Caching the fallback would pin a
          // generic label to a real place for the rest of the session.
          if (_reverseCache.length >= _maxReverseCacheEntries) {
            _reverseCache.remove(_reverseCache.keys.first);
          }
          _reverseCache[cacheKey] = resolved;
          return resolved;
        }
      }
    } catch (_) {
      // fall through to the generic label below
    }
    return fallbackLabel;
  }

  /// Resolves a coordinate into bilingual names (both English and Arabic).
  /// Sanitizes bare numbers and utilizes LocationLocalizer.
  static Future<Map<String, String>> resolveLocationBilingual(double lat, double lon) async {
    final results = await Future.wait([
      reverseGeocodeName(lat, lon, lang: 'ar', fallbackLabel: ''),
      reverseGeocodeName(lat, lon, lang: 'en', fallbackLabel: ''),
    ]);

    String ar = results[0];
    String en = results[1];

    if (ar.isEmpty && en.isNotEmpty) {
      ar = LocationLocalizer.localize(en, isArabic: true, lat: lat, lon: lon);
    } else if (en.isEmpty && ar.isNotEmpty) {
      en = LocationLocalizer.localize(ar, isArabic: false, lat: lat, lon: lon);
    }

    return {'ar': ar, 'en': en};
  }

  /// Address parts that name a place, most specific first. A dropped pin
  /// lands on a building, and Nominatim names buildings by house number --
  /// so the number is never the answer: the landmark, street or area is.
  static const List<String> _landmarkKeys = [
    'station', 'subway', 'amenity', 'tourism', 'shop', 'leisure', 'public_building', 'building',
  ];
  static const List<String> _roadKeys = ['road', 'pedestrian', 'footway', 'street'];
  static const List<String> _areaKeys = [
    'neighbourhood', 'quarter', 'suburb', 'residential', 'city_district', 'village', 'town', 'city',
  ];

  /// A house number, range or postcode rather than a name: "17", "١٧",
  /// "12/3", "12-14", "12A", "12 B", "11511".
  static bool _isNumberish(String text) =>
      RegExp('^[\\d٠-٩]+([\\s\\-/]*([A-Za-zء-ي]|[\\d٠-٩]+))?\$').hasMatch(text.trim());

  /// The name to show for a reverse-geocode answer; null when it has none
  /// that isn't a number.
  ///
  /// With [lang], a name in the app's script wins over a more specific one
  /// in the other: a street OpenStreetMap only names in Arabic ("المنار")
  /// came back as the English app's "current location" (QA 2026-10-22);
  /// the area's English name reads better there. With none in the right
  /// script, the most specific name is kept.
  static String? placeNameFromReverse(Map<String, dynamic> data, {String? lang}) {
    String? usable(Object? v) {
      final t = v?.toString().trim() ?? '';
      return t.isEmpty || _isNumberish(t) ? null : t;
    }

    // Only names of where the rider is compete on script: a whole city
    // ("Alexandria") or the display name's tail ("Egypt") is no answer.
    final local = <String>[];
    void add(Object? v) {
      final u = usable(v);
      if (u != null) local.add(u);
    }

    add(data['name']);
    final address = data['address'];
    if (address is Map) {
      for (final k in [..._landmarkKeys, ..._roadKeys, ..._areaKeys]) {
        if (k != 'city' && k != 'town') add(address[k]);
      }
    }
    if (lang != null && local.isNotEmpty) {
      final arabic = RegExp('[؀-ۿ]');
      final wantArabic = lang == 'ar';
      return local.firstWhere((c) => arabic.hasMatch(c) == wantArabic, orElse: () => local.first);
    }
    if (local.isNotEmpty) return local.first;
    if (address is Map) {
      for (final k in ['town', 'city']) {
        final v = usable(address[k]);
        if (v != null) return v;
      }
    }
    final display = data['display_name'];
    if (display is String) {
      for (final part in display.split(',')) {
        final v = usable(part);
        if (v != null) return v;
      }
    }
    return null;
  }

  static final Map<String, String> _reverseCache = {};
  static const int _maxReverseCacheEntries = 100;
}
