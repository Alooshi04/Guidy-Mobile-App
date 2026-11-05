import 'maps_link_parser.dart';

typedef PlaceNameResolver = Future<String> Function(
  double lat,
  double lon, {
  required String fallbackLabel,
  String lang,
});

/// "My current location" as the street or place the rider is at, in the
/// app's language ("Mostafa El Nahas St." / "شارع مصطفى النحاس"). Uses the
/// free reverse geocode MapsLinkParser already has (cached, Nominatim).
///
/// The place map carries `is_current: true` so screens know it's the
/// rider's own position without comparing label text.
class CurrentPlaceNamer {
  CurrentPlaceNamer._();

  static const String flag = 'is_current';

  /// Swappable for tests.
  static PlaceNameResolver resolve = MapsLinkParser.reverseGeocodeName;

  static Map<String, dynamic> place({required double lat, required double lon, required String fallbackLabel}) =>
      {'name': fallbackLabel, 'lat': lat, 'lon': lon, flag: true};

  static bool isCurrent(Map<dynamic, dynamic>? place) => place != null && place[flag] == true;

  /// [place] renamed after what is there; unchanged if the lookup fails.
  static Future<Map<String, dynamic>> named(Map<String, dynamic> place, {required String lang}) async {
    final lat = place['lat'], lon = place['lon'];
    if (lat is! num || lon is! num) return place;
    final fallback = (place['name'] ?? '').toString();
    try {
      final name = (await resolve(lat.toDouble(), lon.toDouble(), fallbackLabel: fallback, lang: lang)).trim();
      if (name.isEmpty || name == fallback) return place;
      return {...place, 'name': name};
    } catch (_) {
      return place;
    }
  }
}
