// Regression tests for the fixes from the 2026-09-22 full review.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:guidy_app/services/account_service.dart';
import 'package:guidy_app/services/api_service.dart';
import 'package:guidy_app/services/navigation_session.dart';
import 'package:guidy_app/services/places_service.dart';
import 'package:guidy_app/services/saved_places_service.dart';
import 'package:guidy_app/services/search_history_service.dart';
import 'package:guidy_app/services/trip_history_service.dart';
import 'package:guidy_app/utils/polyline_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Places certificate fingerprint', () {
    const release = '1817EF13606F405BFDFD7A14A8D07FE4FC0B6727';

    test('release builds ignore the per-machine debug fingerprint', () {
      // Every build script passes ANDROID_CERT_SHA1 (a DEBUG fingerprint)
      // from secrets.properties; a release APK must not send it.
      expect(PlacesService.certSha1For(release: true, debugEnv: 'DEBUGSHA'), release);
    });

    test('release override is honoured', () {
      expect(PlacesService.certSha1For(release: true, releaseEnv: 'NEWKEY'), 'NEWKEY');
    });

    test('debug builds use the machine fingerprint when given', () {
      expect(PlacesService.certSha1For(release: false, debugEnv: 'DEBUGSHA'), 'DEBUGSHA');
      expect(PlacesService.certSha1For(release: false), isNot(release));
    });
  });

  group('API base URL', () {
    test('release builds reject a saved LAN address', () {
      expect(ApiService.isAcceptableSavedUrl('http://10.1.2.3:8000/api', release: true), isFalse);
      expect(ApiService.isAcceptableSavedUrl(null, release: true), isFalse);
      expect(ApiService.isAcceptableSavedUrl(ApiService.defaultCandidates.first, release: true), isTrue);
    });

    test('debug builds accept any saved address', () {
      expect(ApiService.isAcceptableSavedUrl('http://192.168.1.9:8000/api', release: false), isTrue);
    });

    test('route cache is short-lived because answers carry live ETAs', () {
      expect(ApiService.routeCacheTtl, lessThanOrEqualTo(const Duration(minutes: 2)));
    });
  });

  group('NavigationSession', () {
    test('nested sessions keep the flag until the last one ends', () {
      expect(NavigationSession.isActive, isFalse);
      NavigationSession.begin();
      NavigationSession.begin();
      NavigationSession.end();
      expect(NavigationSession.isActive, isTrue);
      NavigationSession.end();
      expect(NavigationSession.isActive, isFalse);
      NavigationSession.end(); // extra end never goes negative
      NavigationSession.begin();
      expect(NavigationSession.isActive, isTrue);
      NavigationSession.end();
    });
  });

  group('Sign-out clears personal data from the device', () {
    test('trips, places, history and searches are all removed', () async {
      SharedPreferences.setMockInitialValues(
          {'user_display_name': 'Sara', 'saved_commute_trips': '[{"id":"t1"}]'});
      await SavedPlacesService.add(SavedPlace(
          id: 'p1', label: 'Home', name: 'Home', lat: 30.0, lon: 31.2));
      await TripHistoryService.recordTrip(
          startName: 'Home', endName: 'Work', startLat: 30.0, startLon: 31.2,
          endLat: 30.05, endLon: 31.25, pathData: const {});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('guidy_search_history', '[]');

      expect(await SavedPlacesService.getAll(), isNotEmpty);
      expect(await TripHistoryService.getHistory(), isNotEmpty);

      await AccountService.clearUserDataOnSignOut();

      expect(prefs.getString('saved_commute_trips'), isNull);
      expect(await SavedPlacesService.getAll(), isEmpty);
      expect(await TripHistoryService.getHistory(), isEmpty);
      expect(await SearchHistoryService.getRecent(), isEmpty);
      expect(prefs.getString('user_display_name'), isNull);
    });
  });

  group('Stored trips are compact', () {
    test('decoded points are dropped in favour of the encoded polyline', () {
      final pts = [for (var i = 0; i < 50; i++) {'lat': 30.0 + i * 1e-4, 'lon': 31.2}];
      final data = {
        'segments': [
          {'points_encoded': PolylineUtils.encode(pts), 'points': pts, 'color': '#fff'},
          {'points': pts},
        ],
      };
      final out = PolylineUtils.compactForStorage(data) as Map;
      final segs = out['segments'] as List;
      expect(segs[0].containsKey('points'), isFalse);
      expect(segs[0]['points_encoded'], PolylineUtils.encode(pts));
      expect(segs[0]['color'], '#fff');
      expect(segs[1].containsKey('points'), isFalse);
      expect(PolylineUtils.decode(segs[1]['points_encoded']).length, 50);
      expect((data['segments'] as List)[0].containsKey('points'), isTrue); // input untouched
    });
  });

  group('Trip completion', () {
    test('markCompleted flips the flag and notifies listeners', () async {
      SharedPreferences.setMockInitialValues({});
      final entry = await TripHistoryService.recordTrip(
        startName: 'A', endName: 'B', pathData: const {}, isCompleted: false);
      expect(entry, isNotNull);
      var notified = 0;
      void listener() => notified++;
      TripHistoryService.changeNotifier.addListener(listener);
      expect(await TripHistoryService.markCompleted(entry!.id), isTrue);
      TripHistoryService.changeNotifier.removeListener(listener);
      expect(notified, greaterThan(0));
      final h = await TripHistoryService.getHistory();
      expect(h.single.isCompleted, isTrue);
      expect(await TripHistoryService.markCompleted('nope'), isFalse);
    });
  });
}
