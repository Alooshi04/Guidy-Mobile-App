import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guidy_app/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ApiService Automatic IP & Fallback Tests', () {
    test('defaultCandidates contains LAN IP, ADB loopback, and Emulator alias', () {
      expect(ApiService.defaultCandidates, contains('http://192.168.1.9:8000/api'));
      expect(ApiService.defaultCandidates, contains('http://127.0.0.1:8000/api'));
      expect(ApiService.defaultCandidates, contains('http://10.0.2.2:8000/api'));
      expect(ApiService.defaultCandidates, contains('http://192.168.137.1:8000/api'));
    });

    test('baseUrl getter reflects active URL dynamically', () {
      ApiService.setBaseUrlForTesting('http://192.168.1.9:8000/api');
      expect(ApiService.baseUrl, equals('http://192.168.1.9:8000/api'));

      ApiService.setBaseUrlForTesting('http://127.0.0.1:8000/api');
      expect(ApiService.baseUrl, equals('http://127.0.0.1:8000/api'));
    });

    test('init restores previously persisted working base URL from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'active_api_base_url': 'http://192.168.1.9:8000/api',
      });

      await ApiService.init();
      expect(ApiService.baseUrl, equals('http://192.168.1.9:8000/api'));
    });
    test('the domain comes first and the old address still counts', () {
      expect(ApiService.defaultCandidates.first, 'https://api.guidyapp.com/api');
      expect(ApiService.isAcceptableSavedUrl('https://api.202.61.197.114.nip.io/api', release: true), isTrue);
      expect(ApiService.isAcceptableSavedUrl('https://api.guidyapp.com/api', release: true), isTrue);
    });
  });
}
