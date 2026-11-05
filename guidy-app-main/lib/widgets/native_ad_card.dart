import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ad_service.dart';
import '../theme/app_theme.dart';
import '../theme/guidy_ui.dart';

/// An AdMob native ad drawn with Google's own template (it carries the "Ad"
/// badge and the AdChoices icon), in the app's card colours.
///
/// PLACEMENT
///
/// Only at the foot of a screen's content, never between steps of a route
/// or beside a control the rider is about to tap. AdMob rejects ads that
/// look like app content or sit where a tap meant for the app lands on
/// them; [_gap] keeps the card clear of whatever is above and below it.
///
/// One ad per visit: no refresh timer. The card is kept alive while it
/// scrolls off screen, so scrolling back does not request another.
///
/// Nothing is drawn until an ad has loaded, and nothing ever if it fails,
/// consent is missing, or the build has no native unit.
class NativeAdCard extends StatefulWidget {
  const NativeAdCard({super.key, this.template = TemplateType.medium});

  final TemplateType template;

  @override
  State<NativeAdCard> createState() => _NativeAdCardState();
}

class _NativeAdCardState extends State<NativeAdCard> with AutomaticKeepAliveClientMixin {
  static const double _gap = 24;
  static const double _smallHeight = 110;
  static const double _mediumHeight = 350;

  NativeAd? _ad;
  bool _requested = false;
  bool _loaded = false;
  bool _waitingForConsent = false;

  /// The theme the loaded ad was styled for. The template's colours are
  /// fixed at load time, so a theme switch needs a fresh ad.
  Brightness? _styledFor;

  bool get _supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS) && AdService.adsEnabled;

  @override
  bool get wantKeepAlive => _loaded;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Needs the theme for its colours, so not from initState.
    if (_loaded && _styledFor != Theme.of(context).brightness) {
      _reload();
      return;
    }
    if (!_supported) return;
    if (!_listening) {
      _listening = true;
      AdService.adsReady.addListener(_onAdsReady);
    }
    if (_requested || _waitingForConsent) return;
    if (AdService.adsReady.value) {
      _load();
    } else {
      _waitingForConsent = true;
    }
  }

  bool _listening = false;

  /// Consent arriving late starts the one request; consent withdrawn (Settings
  /// > Ad privacy) drops a loaded card at once and lets a later grant reload.
  void _onAdsReady() {
    if (!mounted) return;
    if (!AdService.adsReady.value) {
      if (_ad == null && !_loaded) return;
      _ad?.dispose();
      setState(() {
        _ad = null;
        _loaded = false;
        _requested = false;
        _waitingForConsent = true;
      });
      updateKeepAlive();
      return;
    }
    if (_requested) return;
    _waitingForConsent = false;
    _load();
  }

  /// Drops the shown ad for one in the new theme's colours. Only after a
  /// successful load, so a failing unit is never retried in a loop.
  void _reload() {
    _ad?.dispose();
    _ad = null;
    _loaded = false;
    updateKeepAlive();
    _load();
  }

  void _load() {
    // Once per visit, even after a miss: a theme change does not retry a
    // failed load (see [_reload] for a loaded one).
    _requested = true;
    _styledFor = Theme.of(context).brightness;
    final unit = AdService.nativeAdUnitId;
    if (unit == null) return;
    final ad = NativeAd(
      adUnitId: unit,
      request: const AdRequest(),
      nativeTemplateStyle: nativeAdTemplateStyle(widget.template, NativeAdPalette.of(context)),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          // The theme changed while this one loaded: it carries the old
          // colours, so fetch one in the new ones.
          if (_styledFor != Theme.of(context).brightness) {
            ad.dispose();
            _ad = null;
            _load();
            return;
          }
          setState(() => _loaded = true);
          updateKeepAlive();
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) setState(() => _ad = null);
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  @override
  void dispose() {
    AdService.adsReady.removeListener(_onAdsReady);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    final medium = widget.template == TemplateType.medium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: _gap),
      child: medium
          ? ConstrainedBox(
              // The medium template's ad view is a fixed 350 dp tall: any
              // more height is an empty, see-through band under the card.
              constraints: const BoxConstraints(minWidth: 320),
              child: SizedBox(
                height: _mediumHeight,
                child: AdWidget(key: const ValueKey('native_ad'), ad: ad),
              ),
            )
          // The ad view fills whatever height it is given, and the small
          // template's own content is one row: allowing Google's 200 dp
          // maximum left a blank band under it. Its height, grown with
          // the rider's text size.
          : SizedBox(
              height: MediaQuery.textScalerOf(context).scale(_smallHeight).clamp(_smallHeight, 200),
              child: AdWidget(key: const ValueKey('native_ad'), ad: ad),
            ),
    );
  }
}

/// The colours a native ad card is drawn in, from the app theme.
@immutable
class NativeAdPalette {
  const NativeAdPalette({
    required this.card,
    required this.primaryText,
    required this.secondaryText,
    required this.ctaBackground,
    required this.ctaText,
  });

  factory NativeAdPalette.of(BuildContext context) => NativeAdPalette(
        card: context.surfaceCard,
        primaryText: context.textPrimary,
        secondaryText: context.textSecondary,
        ctaBackground: AppColors.brandBlue,
        ctaText: Colors.white,
      );

  final Color card;
  final Color primaryText;
  final Color secondaryText;
  final Color ctaBackground;
  final Color ctaText;
}

/// Google's template style with every colour it takes set, so nothing is
/// left to the template's own defaults.
///
/// The text backgrounds are not optional. On Android, a text style without
/// one is given the main background's drawable, and the template then
/// shares that one drawable between the card and its three text views. A
/// drawable has one set of bounds, so whichever view last laid out sets
/// the size the others paint it at: the card's colour covered only part
/// of the card (Google's white showing round it), and which part changed
/// each time the view was laid out again, as on coming back to a screen.
/// Each text background here is its own colour, so its own drawable.
NativeTemplateStyle nativeAdTemplateStyle(TemplateType template, NativeAdPalette palette) {
  return NativeTemplateStyle(
    templateType: template,
    mainBackgroundColor: palette.card,
    cornerRadius: GuidyUi.radius,
    callToActionTextStyle: NativeTemplateTextStyle(
      textColor: palette.ctaText,
      backgroundColor: palette.ctaBackground,
      style: NativeTemplateFontStyle.bold,
      size: 15,
    ),
    primaryTextStyle: NativeTemplateTextStyle(
      textColor: palette.primaryText,
      backgroundColor: palette.card,
      style: NativeTemplateFontStyle.bold,
      size: 15,
    ),
    secondaryTextStyle: NativeTemplateTextStyle(
      textColor: palette.secondaryText,
      backgroundColor: palette.card,
      size: 13,
    ),
    tertiaryTextStyle: NativeTemplateTextStyle(
      textColor: palette.secondaryText,
      backgroundColor: palette.card,
      size: 13,
    ),
  );
}
