/// Google Polyline5 algorithm encoder/decoder matching backend `polyline_codec.py`.
///
/// Designed to be fast, allocation-light, and usable inside background isolates
/// without UI or plugin dependencies.
class PolylineUtils {
  /// Decodes a Google encoded polyline (precision 5) string into a list of
  /// `{'lat': double, 'lon': double}` maps.
  ///
  /// Returns an empty list if [encoded] is empty or malformed.
  static List<Map<String, double>> decode(String encoded) {
    if (encoded.isEmpty) return const [];

    final List<Map<String, double>> points = [];
    int index = 0;
    int lat = 0;
    int lon = 0;
    final int len = encoded.length;

    try {
      while (index < len) {
        // Latitude delta
        int shift = 0;
        int result = 0;
        int b;
        do {
          if (index >= len) return points;
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1F) << shift;
          shift += 5;
        } while (b >= 0x20);
        final int deltaLat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
        lat += deltaLat;

        // Longitude delta
        shift = 0;
        result = 0;
        do {
          if (index >= len) return points;
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1F) << shift;
          shift += 5;
        } while (b >= 0x20);
        final int deltaLon = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
        lon += deltaLon;

        points.add({'lat': lat / 1e5, 'lon': lon / 1e5});
      }
    } catch (_) {
      // In case of unexpected truncation or malformed characters, return whatever was parsed
    }
    return points;
  }

  /// Encodes a list of `{'lat': double, 'lon': double}` points into a polyline5 string.
  static String encode(List<Map<String, double>> points) {
    if (points.isEmpty) return '';

    final buffer = StringBuffer();
    int prevLat = 0;
    int prevLon = 0;

    for (final p in points) {
      final lat = p['lat'] ?? 0.0;
      final lon = p['lon'] ?? 0.0;
      final int ilat = (lat * 1e5 + 0.5).floor();
      final int ilon = (lon * 1e5 + 0.5).floor();

      _encodeValue(ilat - prevLat, buffer);
      _encodeValue(ilon - prevLon, buffer);

      prevLat = ilat;
      prevLon = ilon;
    }
    return buffer.toString();
  }

  /// A copy of [data] fit for long-term storage: every map that carries
  /// both `points_encoded` and a decoded `points` list keeps only the
  /// compact string. ApiService expands each segment's polyline into a list
  /// of {lat, lon} maps for drawing, and saved trips / trip history used to
  /// store that expansion verbatim -- thousands of map entries per trip, in
  /// SharedPreferences (decoded on the UI thread every time the History or
  /// Home screen loads) and in Firestore documents (1 MB cap). Readers
  /// already prefer `points_encoded` (MapScreen._pointsOfSegment).
  ///
  /// A `points` list with no encoded twin (an older save) is encoded here
  /// too, so existing entries shrink on their next write.
  static dynamic compactForStorage(dynamic data) {
    if (data is Map) {
      final out = <String, dynamic>{};
      data.forEach((k, v) => out[k.toString()] = compactForStorage(v));
      final pts = out['points'];
      if (pts is List && pts.isNotEmpty && pts.every(_isLatLonMap)) {
        final existing = out['points_encoded'];
        if (existing is! String || existing.isEmpty) {
          out['points_encoded'] = encode([
            for (final p in pts)
              {'lat': (p['lat'] as num).toDouble(), 'lon': (p['lon'] as num).toDouble()}
          ]);
        }
        out.remove('points');
      }
      return out;
    }
    if (data is List) return [for (final v in data) compactForStorage(v)];
    return data;
  }

  static bool _isLatLonMap(dynamic p) => p is Map && p['lat'] is num && p['lon'] is num;

  static void _encodeValue(int value, StringBuffer out) {
    int v = value < 0 ? ~(value << 1) : (value << 1);
    while (v >= 0x20) {
      out.writeCharCode((0x20 | (v & 0x1F)) + 63);
      v >>= 5;
    }
    out.writeCharCode(v + 63);
  }
}
