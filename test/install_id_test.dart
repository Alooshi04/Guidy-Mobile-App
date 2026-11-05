import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The server rate-limits per install (X-Guidy-Install) rather than per IP,
// because mobile carriers put many phones behind one IP. See the backend's
// test_rate_limit_keys.py.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final pattern = RegExp(r'^[0-9a-f]{32}$');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService.resetInstallIdForTesting();
  });

  test('new install IDs are 32 hex chars and random', () {
    final a = ApiService.newInstallId();
    final b = ApiService.newInstallId();
    expect(a, matches(pattern));
    expect(b, matches(pattern));
    expect(a, isNot(b));
  });

  test('no header until the ID is loaded', () {
    expect(ApiService.clientHeaders, isEmpty);
    expect(ApiService.jsonHeaders, {'Content-Type': 'application/json'});
  });

  test('the ID is made once and then kept', () async {
    await ApiService.loadInstallIdForTesting();
    final first = ApiService.clientHeaders['X-Guidy-Install'];
    expect(first, matches(pattern));
    expect(ApiService.jsonHeaders['X-Guidy-Install'], first);

    ApiService.resetInstallIdForTesting();
    await ApiService.loadInstallIdForTesting();
    expect(ApiService.clientHeaders['X-Guidy-Install'], first);
  });

  test('a corrupted stored ID is replaced', () async {
    SharedPreferences.setMockInitialValues({'guidy_install_id': 'not-an-id'});
    await ApiService.loadInstallIdForTesting();
    expect(ApiService.clientHeaders['X-Guidy-Install'], matches(pattern));
  });

  test('the ID is still sent when it cannot be saved', () async {
    await ApiService.loadInstallIdForTesting(prefs: _UnsavablePrefs());
    expect(ApiService.clientHeaders['X-Guidy-Install'], matches(pattern));
  });

  // Requests made at startup, while the new ID is still being saved, must
  // already carry it.
  test('the ID is sent while it is still being saved', () {
    unawaited(ApiService.loadInstallIdForTesting(prefs: _SlowPrefs()));
    expect(ApiService.clientHeaders['X-Guidy-Install'], matches(pattern));
  });

  group('requests to our backend carry the ID', () {
    late List<http.BaseRequest> sent;

    Future<T> withServer<T>(Future<T> Function() body) => http.runWithClient(
          body,
          () => MockClient((req) async {
            sent.add(req);
            return http.Response('{}', 200);
          }),
        );

    setUp(() async {
      sent = [];
      await ApiService.loadInstallIdForTesting();
    });

    // The health probe runs at every launch and on every network fallback;
    // the server limits it per install like everything else.
    test('the health probe', () async {
      await withServer(() => ApiService.discoverWorkingBaseUrl());
      final probes = sent.where((r) => r.url.path.endsWith('/health')).toList();
      expect(probes, isNotEmpty);
      for (final r in probes) {
        expect(r.headers['X-Guidy-Install'], matches(pattern), reason: '${r.url}');
      }
    });

    test('a live position report (a JSON POST)', () async {
      ApiService.setBaseUrlForTesting('https://api.guidyapp.com/api');
      await withServer(() => ApiService().reportLivePosition(
          sessionId: 's', routeId: 'r', directionId: '0', lat: 30.0, lon: 31.2));
      expect(sent, hasLength(1));
      expect(sent.first.url.path, '/api/live/position');
      expect(sent.first.headers['X-Guidy-Install'], matches(pattern));
      expect(sent.first.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode((sent.first as http.Request).body)['route_id'], 'r');
    });

    test('a line lookup', () async {
      ApiService.setBaseUrlForTesting('https://api.guidyapp.com/api');
      await withServer(() => ApiService().fetchRouteDetail('X${DateTime.now().microsecondsSinceEpoch}'));
      expect(sent, isNotEmpty);
      expect(sent.first.headers['X-Guidy-Install'], matches(pattern));
    });
  });
}

/// Reads find nothing and a write never finishes.
class _SlowPrefs implements SharedPreferences {
  @override
  String? getString(String key) => null;

  @override
  Future<bool> setString(String key, String value) => Completer<bool>().future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Reads find nothing and every write fails, like a full or broken store.
class _UnsavablePrefs implements SharedPreferences {
  @override
  String? getString(String key) => null;

  @override
  Future<bool> setString(String key, String value) async => throw Exception('disk full');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
