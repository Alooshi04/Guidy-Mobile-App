import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/services/ad_service.dart';
import 'package:guidy_app/services/app_open_ad_service.dart';
import 'package:guidy_app/services/places_service.dart';
import 'package:guidy_app/services/search_history_service.dart';
import 'package:guidy_app/widgets/banner_ad_placeholder.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('banner refresh gate', () {
    test('no refresh while hidden or while a request is outstanding', () {
      bool can(bool v, bool f, bool p) =>
          BannerAdPlaceholder.canSchedule(visible: v, inFlight: f, initialPending: p);
      expect(can(true, false, false), isTrue);
      expect(can(false, false, false), isFalse, reason: 'offstage');
      expect(can(true, true, false), isFalse, reason: 'resume during first load');
      expect(can(true, false, true), isFalse, reason: 'first request waiting for visibility');
    });
  });

  group('AppOpenAdService.initializeWhenReady', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/google_mobile_ads'), (_) async => null);
    });
    tearDown(() {
      AppOpenAdService.instance.dispose();
      AdService.adsReady.value = false;
    });

    test('waits for consent, then starts once ads become ready', () async {
      AdService.adsReady.value = false;
      AppOpenAdService.instance.initializeWhenReady();
      expect(AppOpenAdService.instance.started, isFalse);
      AdService.adsReady.value = true;
      expect(AppOpenAdService.instance.started, isTrue);
    });

    test('starts immediately when consent already resolved', () {
      AdService.adsReady.value = true;
      AppOpenAdService.instance.initializeWhenReady();
      expect(AppOpenAdService.instance.started, isTrue);
    });
  });

  group('Places key', () {
    test('no key means not configured and search fails soft', () async {
      expect(PlacesService.isKeyPresent(''), isFalse);
      expect(PlacesService.isKeyPresent('  '), isFalse);
      expect(PlacesService.isKeyPresent('abc'), isTrue);
      // The test run has no --dart-define key.
      expect(PlacesService.isConfigured, isFalse);
      expect(await PlacesService.autocomplete('cairo airport', 'tok'), isEmpty);
      expect(await PlacesService.getPlace('x', 'tok'), isNull);
    });
  });

  group('recent searches follow the locale', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('shows each language, falls back for old one-name entries', () {
      final both = {'name': 'Mansheya', 'nameEn': 'Mansheya', 'nameAr': 'المنشية'};
      expect(SearchHistoryService.nameFor(both, 'ar'), 'المنشية');
      expect(SearchHistoryService.nameFor(both, 'en'), 'Mansheya');
      final old = {'name': 'Mansheya'};
      expect(SearchHistoryService.nameFor(old, 'ar'), 'Mansheya');
      expect(SearchHistoryService.nameFor({'name': 'المنشية'}, 'en'), 'المنشية');
    });

    test('the same place found in both languages merges into one entry', () async {
      await SearchHistoryService.addSearch('Mansheya', 31.2, 29.9, placeId: 'p1', nameEn: 'Mansheya');
      await SearchHistoryService.addSearch('المنشية', 31.2, 29.9, placeId: 'p1', nameAr: 'المنشية');
      final recent = await SearchHistoryService.getRecent();
      expect(recent, hasLength(1));
      expect(SearchHistoryService.nameFor(recent.first, 'ar'), 'المنشية');
      expect(SearchHistoryService.nameFor(recent.first, 'en'), 'Mansheya');
    });
  });
}
