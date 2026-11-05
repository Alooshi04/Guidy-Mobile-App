import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guidy_app/services/reference_cache.dart';

void main() {
  group('ReferenceCache', () {
    setUp(() async {
      // Provide a mock SharedPreferences backing store
      SharedPreferences.setMockInitialValues({});
      // Clear all state between tests (ReferenceCache uses statics)
      await ReferenceCache.clear();
    });

    // ── write + read round-trip ────────────────────────────────────────
    test('write then read returns the stored value', () async {
      final data = {'stations': ['Sadat', 'Nasser', 'Attaba']};
      await ReferenceCache.write('metro_stations', data);
      final result = await ReferenceCache.read('metro_stations');
      expect(result, isNotNull);
      expect(result, isA<Map>());
      final map = result as Map;
      expect(map['stations'], equals(['Sadat', 'Nasser', 'Attaba']));
    });

    // ── read missing key ───────────────────────────────────────────────
    test('read returns null for a key that was never written', () async {
      final result = await ReferenceCache.read('nonexistent_key');
      expect(result, isNull);
    });

    // ── clear ──────────────────────────────────────────────────────────
    test('clear removes all cached entries', () async {
      await ReferenceCache.write('key1', 'value1');
      await ReferenceCache.write('key2', 'value2');
      await ReferenceCache.clear();
      expect(await ReferenceCache.read('key1'), isNull);
      expect(await ReferenceCache.read('key2'), isNull);
    });

    // ── readStale ──────────────────────────────────────────────────────
    test('readStale returns data that read also returns for fresh entries', () async {
      await ReferenceCache.write('fresh_key', [1, 2, 3]);
      final fresh = await ReferenceCache.read('fresh_key');
      final stale = await ReferenceCache.readStale('fresh_key');
      expect(fresh, isNotNull);
      expect(stale, isNotNull);
      expect(stale, equals(fresh));
    });

    test('readStale returns null for never-written keys', () async {
      final result = await ReferenceCache.readStale('ghost_key');
      expect(result, isNull);
    });

    // ── persist: false (memory-only) ──────────────────────────────────
    test('memory-only write is readable', () async {
      await ReferenceCache.write('mem_only', {'type': 'detail'}, persist: false);
      final result = await ReferenceCache.read('mem_only');
      expect(result, isNotNull);
      final map = result as Map;
      expect(map['type'], equals('detail'));
    });

    // ── string values ─────────────────────────────────────────────────
    test('stores and retrieves string values', () async {
      await ReferenceCache.write('simple', 'hello');
      final result = await ReferenceCache.read('simple');
      expect(result, equals('hello'));
    });

    // ── list values ───────────────────────────────────────────────────
    test('stores and retrieves list values', () async {
      await ReferenceCache.write('numbers', [10, 20, 30]);
      final result = await ReferenceCache.read('numbers');
      expect(result, equals([10, 20, 30]));
    });
  });
}
