import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:guidy_app/services/simple_mode.dart';
import 'package:guidy_app/services/trip_recorder.dart';
import 'package:guidy_app/services/trip_sharing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Position fix(double lat, double lon, DateTime t, {double acc = 8}) => Position(
      latitude: lat,
      longitude: lon,
      timestamp: t,
      accuracy: acc,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TripSharing.enabled.value = true; // the default
  });

  group('"Share my trips" off', () {
    test('a trip records and sends nothing', () async {
      TripSharing.enabled.value = false;
      var posts = 0;
      final client = MockClient((_) async {
        posts++;
        return http.Response('{}', 200);
      });
      final r = TripRecorder(pathData: const {'start_lat': 30.0, 'start_lon': 31.0});
      final t0 = DateTime(2026, 10, 22, 8);
      for (var i = 0; i < 10; i++) {
        r.onFix(fix(30.0 + i * 0.001, 31.0, t0.add(Duration(seconds: 5 * i))), 0);
      }
      expect(r.debugPointCount, 0);
      await http.runWithClient(() => r.finish(completed: true, reason: 'arrived', instructions: const []), () => client);
      expect(posts, 0);
      expect((await SharedPreferences.getInstance()).getStringList('pending_trip_logs'), isNull);
    });

    test('trips queued before it was turned off are deleted, not sent', () async {
      SharedPreferences.setMockInitialValues({'pending_trip_logs': ['{"client_trip_id":"a"}']});
      var posts = 0;
      final client = MockClient((_) async {
        posts++;
        return http.Response('{}', 200);
      });
      await TripSharing.set(false);
      await http.runWithClient(TripRecorder.flushQueue, () => client);
      expect(posts, 0);
      expect((await SharedPreferences.getInstance()).getStringList('pending_trip_logs'), isNull);
    });
  });

  test('a standing rider is sampled every 4 s, not on every fix', () {
    final r = TripRecorder(pathData: const {'start_lat': 30.0, 'start_lon': 31.0});
    final t0 = DateTime(2026, 9, 24, 8);
    for (var i = 0; i < 40; i++) {
      r.onFix(fix(30.0, 31.0, t0.add(Duration(milliseconds: 500 * i))), 0);
    }
    // 20 s of fixes twice a second -> about one point per 4 s.
    expect(r.debugPointCount, inInclusiveRange(5, 6));
  });

  test('reaching a new step is always recorded, and bad fixes are dropped', () {
    final r = TripRecorder(pathData: const {});
    final t0 = DateTime(2026, 9, 24, 8);
    r.onFix(fix(30.0, 31.0, t0), 0);
    r.onFix(fix(30.0, 31.0, t0.add(const Duration(seconds: 1))), 1);
    r.onFix(fix(30.001, 31.0, t0.add(const Duration(seconds: 2)), acc: 150), 1);
    expect(r.debugPointCount, 2);
  });

  test('simple mode is remembered', () async {
    await simpleMode.set(true);
    simpleMode.value = false;
    await simpleMode.load();
    expect(simpleMode.value, isTrue);
    await simpleMode.set(false);
  });

  group('queued trips', () {
    const key = 'pending_trip_logs';
    String trip(String id, {String? uid, bool withUid = true}) =>
        jsonEncode({'client_trip_id': id, 'points': [], if (withUid) '_uid': uid});

    test('a trip queued while the queue is being sent is kept', () async {
      SharedPreferences.setMockInitialValues({key: [trip('a')]});
      final prefs = await SharedPreferences.getInstance();
      final client = MockClient((req) async {
        // Another trip ends, without signal, while this one is on its way.
        await prefs.setStringList(key, [...prefs.getStringList(key)!, trip('b')]);
        return http.Response('{}', 200);
      });
      await http.runWithClient(TripRecorder.flushQueue, () => client);
      expect(prefs.getStringList(key), [trip('b')]);
    });

    test('a trip that fails to send stays queued', () async {
      SharedPreferences.setMockInitialValues({key: [trip('a')]});
      final client = MockClient((_) async => http.Response('', 503));
      await http.runWithClient(TripRecorder.flushQueue, () => client);
      expect((await SharedPreferences.getInstance()).getStringList(key), [trip('a')]);
    });

    test('a trip ridden by another account is sent unattributed, without the uid', () async {
      SharedPreferences.setMockInitialValues({key: [trip('a', uid: 'someone-else')]});
      late http.Request sent;
      final client = MockClient((req) async {
        sent = req;
        return http.Response('{}', 200);
      });
      await http.runWithClient(TripRecorder.flushQueue, () => client);
      expect(sent.headers.containsKey('Authorization'), isFalse);
      expect(jsonDecode(sent.body), isNot(contains('_uid')));
      expect((await SharedPreferences.getInstance()).getStringList(key), isEmpty);
    });
  });
}
