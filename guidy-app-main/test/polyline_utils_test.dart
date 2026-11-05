import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/utils/polyline_utils.dart';

void main() {
  group('PolylineUtils', () {
    test('matches Google reference example', () {
      // The worked example from Google's polyline algorithm documentation
      final pts = [
        {'lat': 38.5, 'lon': -120.2},
        {'lat': 40.7, 'lon': -120.95},
        {'lat': 43.252, 'lon': -126.453},
      ];
      const encoded = '_p~iF~ps|U_ulLnnqC_mqNvxq`@';

      expect(PolylineUtils.encode(pts), encoded);

      final decoded = PolylineUtils.decode(encoded);
      expect(decoded.length, 3);
      expect(decoded[0]['lat'], closeTo(38.5, 1e-5));
      expect(decoded[0]['lon'], closeTo(-120.2, 1e-5));
      expect(decoded[1]['lat'], closeTo(40.7, 1e-5));
      expect(decoded[1]['lon'], closeTo(-120.95, 1e-5));
      expect(decoded[2]['lat'], closeTo(43.252, 1e-5));
      expect(decoded[2]['lon'], closeTo(-126.453, 1e-5));
    });

    test('round trip Cairo coordinates', () {
      final pts = [
        {'lat': 30.0626, 'lon': 31.3219},
        {'lat': 30.0385, 'lon': 31.2122},
        {'lat': 29.9711, 'lon': 31.1013},
      ];

      final encoded = PolylineUtils.encode(pts);
      final decoded = PolylineUtils.decode(encoded);

      expect(decoded.length, pts.length);
      for (int i = 0; i < pts.length; i++) {
        expect(decoded[i]['lat'], closeTo(pts[i]['lat']!, 1e-4));
        expect(decoded[i]['lon'], closeTo(pts[i]['lon']!, 1e-4));
      }
    });

    test('handles empty inputs gracefully', () {
      expect(PolylineUtils.encode([]), '');
      expect(PolylineUtils.decode(''), isEmpty);
    });

    test('handles malformed encoded strings without crashing', () {
      expect(PolylineUtils.decode('???invalid'), isNotNull);
      expect(PolylineUtils.decode('_p~iF~ps'), isNotNull);
    });
  });
}
