import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/services/ad_service.dart';
import 'package:guidy_app/services/consent_service.dart';
import 'package:guidy_app/widgets/banner_ad_placeholder.dart';

class _FakeGateway implements ConsentGateway {
  _FakeGateway({this.canRequest = true, this.updateFails = false, this.optionsRequired = false});

  final bool canRequest;
  final bool updateFails;
  final bool optionsRequired;
  final calls = <String>[];

  @override
  Future<void> requestUpdate() async {
    calls.add('update');
    if (updateFails) throw StateError('offline');
  }

  @override
  Future<void> showFormIfRequired() async => calls.add('form');

  @override
  Future<bool> canRequestAds() async {
    calls.add('can');
    return canRequest;
  }

  @override
  Future<bool> privacyOptionsRequired() async => optionsRequired;

  @override
  Future<void> showPrivacyOptions() async => calls.add('options');

  @override
  Future<void> initializeAds() async => calls.add('init');
}

void main() {
  setUp(() => AdService.adsReady.value = false);

  test('consent is requested and the form shown before the ads SDK starts', () async {
    final g = _FakeGateway();
    final ok = await ConsentService(gateway: g).gather(beforeAdsInit: () async => g.calls.add('att'));
    expect(ok, isTrue);
    expect(g.calls, ['update', 'form', 'can', 'att', 'init']);
    expect(AdService.adsReady.value, isTrue);
  });

  test('without consent the ads SDK never starts and ads stay off', () async {
    final g = _FakeGateway(canRequest: false);
    final ok = await ConsentService(gateway: g).gather();
    expect(ok, isFalse);
    expect(g.calls, isNot(contains('init')));
    expect(AdService.adsReady.value, isFalse);
  });

  test('a failed consent update falls back to the cached answer from canRequestAds', () async {
    final g = _FakeGateway(updateFails: true, canRequest: false);
    expect(await ConsentService(gateway: g).gather(), isFalse);
    expect(g.calls, contains('can'));
    expect(g.calls, isNot(contains('init')));
  });

  test('the privacy-options entry is offered only where UMP requires it', () async {
    final yes = ConsentService(gateway: _FakeGateway(optionsRequired: true));
    await yes.gather();
    expect(yes.privacyOptionsRequired.value, isTrue);
    final no = ConsentService(gateway: _FakeGateway());
    await no.gather();
    expect(no.privacyOptionsRequired.value, isFalse);
  });

  test('withdrawing consent in Settings switches ads off', () async {
    final svc = ConsentService(gateway: _FakeGateway());
    await svc.gather();
    expect(AdService.adsReady.value, isTrue);
    await ConsentService(gateway: _FakeGateway(canRequest: false)).showPrivacyOptions();
    expect(AdService.adsReady.value, isFalse);
  });

  group('banner retry backoff', () {
    test('a miss waits longer each time and stops at five minutes', () {
      expect(BannerAdPlaceholder.retryDelay(0), const Duration(seconds: 30));
      expect(BannerAdPlaceholder.retryDelay(1), const Duration(seconds: 60));
      expect(BannerAdPlaceholder.retryDelay(2), const Duration(seconds: 120));
      expect(BannerAdPlaceholder.retryDelay(10), const Duration(seconds: 300));
    });
  });
}
