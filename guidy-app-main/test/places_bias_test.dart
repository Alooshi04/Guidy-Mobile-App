import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/services/places_service.dart';

/// Search must work the same from Cairo, Giza and Alexandria: biased toward
/// the rider when we know where they are, and toward both cities equally
/// when we don't. A bias never restricts, so a Cairo rider can still find
/// "محطة الرمل" in Alexandria.
void main() {
  group('PlacesService.locationBias', () {
    test('no known location: one rectangle covering Greater Cairo and Alexandria', () {
      final bias = PlacesService.locationBias(null, null);
      final rect = bias['rectangle'] as Map<String, dynamic>;
      final low = rect['low'] as Map<String, double>;
      final high = rect['high'] as Map<String, double>;
      // Alexandria + Borg El Arab ...
      expect(low['latitude']!, lessThanOrEqualTo(30.80));
      expect(low['longitude']!, lessThanOrEqualTo(29.40));
      expect(high['latitude']!, greaterThanOrEqualTo(31.35));
      // ... and Greater Cairo out to New Cairo / the New Capital.
      expect(low['latitude']!, lessThanOrEqualTo(29.70));
      expect(high['longitude']!, greaterThanOrEqualTo(31.85));
    });

    test('rider in Alexandria: biased around them, not around Cairo', () {
      final bias = PlacesService.locationBias(31.2010, 29.9010);
      final circle = bias['circle'] as Map<String, dynamic>;
      expect(circle['center'], {'latitude': 31.2010, 'longitude': 29.9010});
      expect(circle['radius'], 50000);
    });

    test('rider in Giza: biased around them', () {
      final bias = PlacesService.locationBias(30.0131, 31.2089);
      expect((bias['circle'] as Map)['center'], {'latitude': 30.0131, 'longitude': 31.2089});
    });

    test('a location outside Egypt (emulator default, VPN) is ignored', () {
      expect(PlacesService.locationBias(37.4219, -122.0840).containsKey('rectangle'), isTrue);
    });

    test('rememberRiderLocation feeds the bias used by later searches', () {
      PlacesService.rememberRiderLocation(31.2565, 29.9885);
      final bias = PlacesService.currentLocationBias();
      expect((bias['circle'] as Map)['center'], {'latitude': 31.2565, 'longitude': 29.9885});
      expect(PlacesService.riderLocation, (lat: 31.2565, lon: 29.9885));
      PlacesService.rememberRiderLocation(null, null);
      expect(PlacesService.currentLocationBias().containsKey('rectangle'), isTrue);
      expect(PlacesService.riderLocation, isNull);
    });
  });

  group('PlacesService.rankByRiderCity', () {
    test("places in the rider's city come first, each group in Google's order", () {
      final ranked = PlacesService.rankByRiderCity([
        {'name': 'Mansheya, Egypt', 'distanceMeters': 180000},
        {'name': 'Mansheya, Cairo', 'distanceMeters': 190000},
        {'name': 'El Mansheya, Alexandria', 'distanceMeters': 4200},
        {'name': 'Mansheya Square', 'distanceMeters': 4500},
        {'name': 'Mansheya (no distance)'},
      ]);
      expect(ranked.map((p) => p['name']), [
        'El Mansheya, Alexandria',
        'Mansheya Square',
        'Mansheya, Egypt',
        'Mansheya, Cairo',
        'Mansheya (no distance)',
      ]);
    });
  });

  group('PlacesService.displayNameOf', () {
    test('the Place Details name, in the language asked', () {
      expect(PlacesService.displayNameOf({'displayName': {'text': 'المنشية', 'languageCode': 'ar'}}), 'المنشية');
    });

    test('a bare house number or no name: null, the typed name stays', () {
      expect(PlacesService.displayNameOf({'displayName': {'text': '17'}}), isNull);
      expect(PlacesService.displayNameOf({}), isNull);
    });
  });
}
