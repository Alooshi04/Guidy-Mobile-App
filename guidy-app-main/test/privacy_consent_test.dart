import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/services/ad_service.dart';
import 'package:guidy_app/services/consent_service.dart';
import 'package:guidy_app/services/telemetry_consent.dart';
import 'package:guidy_app/services/trip_sharing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Sink implements TelemetrySink {
  final log = <String>[];
  @override
  Future<void> setAnalytics(bool on) async => log.add('analytics:$on');
  @override
  Future<void> setCrashlytics(bool on) async => log.add('crash:$on');
}

class _Gateway implements ConsentGateway {
  _Gateway(this.can);
  bool can;
  @override
  Future<void> requestUpdate() async {}
  @override
  Future<void> showFormIfRequired() async {}
  @override
  Future<bool> canRequestAds() async => can;
  @override
  Future<bool> privacyOptionsRequired() async => false;
  @override
  Future<void> showPrivacyOptions() async {}
  @override
  Future<void> initializeAds() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('telemetry follows consent', () {
    late _Sink sink;
    setUp(() {
      sink = _Sink();
      TelemetryConsent.sink = sink;
      TelemetryConsent.applied = null;
      AdService.adsReady.value = false;
    });

    test('consent given turns analytics on (Crashlytics stays off in debug)', () async {
      await ConsentService(gateway: _Gateway(true)).gather();
      expect(sink.log, contains('analytics:true'));
      expect(TelemetryConsent.applied, isTrue);
    });

    test('consent refused keeps both off', () async {
      await ConsentService(gateway: _Gateway(false)).gather();
      expect(sink.log, ['analytics:false', 'crash:false']);
    });

    test('withdrawing consent in privacy options switches collection off', () async {
      final g = _Gateway(true);
      final c = ConsentService(gateway: g);
      await c.gather();
      g.can = false;
      await c.showPrivacyOptions();
      expect(TelemetryConsent.applied, isFalse);
      expect(sink.log.last, 'crash:false');
    });

    test('no consent form (NoAds build): off unless built with GUIDY_TELEMETRY', () async {
      await TelemetryConsent.applyWithoutConsentForm();
      expect(TelemetryConsent.applied, TelemetryConsent.noAdsOptIn);
    });
  });

  group('trip-share ask', () {
    Future<void> pumpHost(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) => TextButton(onPressed: () => TripSharing.askIfNeeded(ctx), child: const Text('go')),
        ),
      ));
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await TripSharing.load();
    });

    test('off by default for someone who never answered', () {
      expect(TripSharing.enabled.value, isFalse);
      expect(TripSharing.asked, isFalse);
    });

    test('someone who already used the Settings switch is not asked', () async {
      SharedPreferences.setMockInitialValues({'trip_sharing': false});
      await TripSharing.load();
      expect(TripSharing.asked, isTrue);
      expect(TripSharing.enabled.value, isFalse);
    });

    testWidgets('Share turns it on, is remembered and not asked again', (tester) async {
      await pumpHost(tester);
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text("Share this trip's path to help fix bus routes and missing footpaths?"), findsOneWidget);
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      expect(TripSharing.enabled.value, isTrue);
      await TripSharing.load();
      expect(TripSharing.asked, isTrue);
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('trip-share-ask')), findsNothing);
    });

    testWidgets('Not now leaves it off, remembered, and Settings can still turn it on', (tester) async {
      await pumpHost(tester);
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(TripSharing.enabled.value, isFalse);
      await TripSharing.load();
      expect(TripSharing.asked, isTrue);
      await TripSharing.set(true);
      expect(TripSharing.enabled.value, isTrue);
    });
  });
}
