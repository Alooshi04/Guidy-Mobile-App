import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ApiService.clearRouteCache();
  });

  group('ApiService Client-Side Route Cache Tests', () {
    test('makeRouteCacheKey rounds coordinates to 4 decimal places', () {
      final key1 = ApiService.makeRouteCacheKey(
        startLat: 30.0444111,
        startLon: 31.2357222,
        endLat: 30.0600333,
        endLon: 31.2500444,
      );
      final key2 = ApiService.makeRouteCacheKey(
        startLat: 30.0444199,
        startLon: 31.2357299,
        endLat: 30.0600399,
        endLon: 31.2500499,
      );
      expect(key1, equals(key2));
    });

    test('cacheRoute stores and getCachedRoute retrieves route data', () {
      final mockData = {
        'success': true,
        'options': [
          {'type': 'Fastest', 'time': 25, 'fare_total_egp': 12},
        ],
      };

      ApiService.cacheRoute(
        startLat: 30.0444,
        startLon: 31.2357,
        endLat: 30.0600,
        endLon: 31.2500,
        data: mockData,
      );

      final cached = ApiService.getCachedRoute(
        startLat: 30.0444,
        startLon: 31.2357,
        endLat: 30.0600,
        endLon: 31.2500,
      );

      expect(cached, isNotNull);
      expect(cached!['success'], isTrue);
      expect((cached['options'] as List).first['time'], equals(25));
    });

    test('cacheRoute does not store failed route responses', () {
      final mockFailData = {
        'success': false,
        'error_code': 'no_route_found',
      };

      ApiService.cacheRoute(
        startLat: 30.0444,
        startLon: 31.2357,
        endLat: 30.0600,
        endLon: 31.2500,
        data: mockFailData,
      );

      final cached = ApiService.getCachedRoute(
        startLat: 30.0444,
        startLon: 31.2357,
        endLat: 30.0600,
        endLon: 31.2500,
      );

      expect(cached, isNull);
    });

    test('getCachedRoute differentiates filter parameters', () {
      final mockData = {'success': true, 'options': []};

      ApiService.cacheRoute(
        startLat: 30.0444,
        startLon: 31.2357,
        endLat: 30.0600,
        endLon: 31.2500,
        excludeMetro: false,
        data: mockData,
      );

      final cachedWithMetro = ApiService.getCachedRoute(
        startLat: 30.0444,
        startLon: 31.2357,
        endLat: 30.0600,
        endLon: 31.2500,
        excludeMetro: false,
      );
      final cachedWithoutMetro = ApiService.getCachedRoute(
        startLat: 30.0444,
        startLon: 31.2357,
        endLat: 30.0600,
        endLon: 31.2500,
        excludeMetro: true,
      );

      expect(cachedWithMetro, isNotNull);
      expect(cachedWithoutMetro, isNull);
    });
  });
}
