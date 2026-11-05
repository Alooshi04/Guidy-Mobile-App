import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_service.dart';
import 'telemetry_consent.dart';

/// The pieces of Google's User Messaging Platform (UMP) the app uses, so the
/// order of calls can be tested without a phone.
abstract class ConsentGateway {
  /// Asks Google whether this user (EEA, UK, ...) must be asked for consent.
  Future<void> requestUpdate();

  /// Shows Google's consent form if one is required and not yet answered.
  Future<void> showFormIfRequired();

  /// True once consent is obtained or not required.
  Future<bool> canRequestAds();

  /// True where the user must be able to reopen their choice later.
  Future<bool> privacyOptionsRequired();

  Future<void> showPrivacyOptions();

  /// Starts the ads SDK. Called only after [canRequestAds].
  Future<void> initializeAds();
}

class UmpConsentGateway implements ConsentGateway {
  const UmpConsentGateway();

  @override
  Future<void> requestUpdate() {
    final c = _Done();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      c.complete,
      (FormError e) => c.fail(StateError('UMP ${e.errorCode}: ${e.message}')),
    );
    return c.future;
  }

  @override
  Future<void> showFormIfRequired() {
    final c = _Done();
    ConsentForm.loadAndShowConsentFormIfRequired((FormError? e) {
      if (e == null) {
        c.complete();
      } else {
        c.fail(StateError('UMP ${e.errorCode}: ${e.message}'));
      }
    });
    return c.future;
  }

  @override
  Future<bool> canRequestAds() => ConsentInformation.instance.canRequestAds();

  @override
  Future<bool> privacyOptionsRequired() async =>
      await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
      PrivacyOptionsRequirementStatus.required;

  @override
  Future<void> showPrivacyOptions() {
    final c = _Done();
    ConsentForm.showPrivacyOptionsForm((FormError? e) {
      if (e == null) {
        c.complete();
      } else {
        c.fail(StateError('UMP ${e.errorCode}: ${e.message}'));
      }
    });
    return c.future;
  }

  @override
  Future<void> initializeAds() => MobileAds.instance.initialize();
}

class _Done {
  final _c = Completer<void>();
  Future<void> get future => _c.future;
  void complete() {
    if (!_c.isCompleted) _c.complete();
  }

  void fail(Object e) {
    if (!_c.isCompleted) _c.completeError(e);
  }
}

/// Collects the user's consent before any ad is requested.
///
/// Google's EU User Consent Policy (and the UK's) require a certified consent
/// message before ads load for users in the EEA and UK. The order, which
/// AdMob checks for in review:
///   1. ask UMP for the current consent state,
///   2. show the form if one is required,
///   3. start the ads SDK and let ads load only if UMP says [canRequestAds].
/// A user who declines still gets no ads at all rather than unconsented ones.
class ConsentService {
  ConsentService({ConsentGateway gateway = const UmpConsentGateway()}) : _gateway = gateway;

  static final ConsentService instance = ConsentService();

  final ConsentGateway _gateway;

  /// True where Settings must offer "Ad privacy settings".
  final ValueNotifier<bool> privacyOptionsRequired = ValueNotifier<bool>(false);

  bool _adsStarted = false;
  Future<bool>? _running;

  /// Runs the consent flow once per launch. [beforeAdsInit] runs between
  /// consent and the SDK starting (iOS App Tracking Transparency goes there,
  /// after Google's form). Returns whether ads may be requested.
  Future<bool> gather({Future<void> Function()? beforeAdsInit}) =>
      _running ??= _gather(beforeAdsInit);

  /// Done once this launch's consent flow (and Google's form, if shown)
  /// is over, or right away when it never started. Other system prompts
  /// wait for it so two never show at once.
  Future<void> get settled => _running ?? Future<void>.value();

  Future<bool> _gather(Future<void> Function()? beforeAdsInit) async {
    if (!AdService.adsEnabled) {
      await TelemetryConsent.applyWithoutConsentForm();
      return false;
    }
    try {
      await _gateway.requestUpdate();
      await _gateway.showFormIfRequired();
    } catch (e) {
      // Offline or a Google-side failure. A cached earlier answer can still
      // allow ads, so fall through to the real check rather than assuming.
      debugPrint('Consent flow error: $e');
    }

    bool can = false;
    try {
      can = await _gateway.canRequestAds();
    } catch (e) {
      debugPrint('canRequestAds error: $e');
    }
    try {
      privacyOptionsRequired.value = await _gateway.privacyOptionsRequired();
    } catch (_) {}
    // Analytics and Crashlytics follow the same answer as ads.
    await TelemetryConsent.apply(can);
    if (!can) return false;

    if (!_adsStarted) {
      try {
        await beforeAdsInit?.call();
        await _gateway.initializeAds();
        _adsStarted = true;
      } catch (e) {
        debugPrint('MobileAds initialization error: $e');
        return false;
      }
    }
    AdService.adsReady.value = true;
    return true;
  }

  /// Settings entry: reopens Google's privacy options form. If the user
  /// withdraws consent, ads stop being requested.
  Future<void> showPrivacyOptions() async {
    try {
      await _gateway.showPrivacyOptions();
      final can = await _gateway.canRequestAds();
      await TelemetryConsent.apply(can);
      if (!can) AdService.adsReady.value = false;
    } catch (e) {
      debugPrint('Privacy options error: $e');
    }
  }
}
