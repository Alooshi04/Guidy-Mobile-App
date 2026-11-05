import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:guidy_app/theme/app_theme.dart';
import 'package:guidy_app/widgets/native_ad_card.dart';

// The native ad template's colours. Any colour left unset is filled in by
// Google's template on Android: a text background left unset shares the
// card's drawable, which painted the card in patches of white and navy.

void main() {
  Future<NativeAdPalette> paletteFor(WidgetTester tester, ThemeData theme) async {
    late NativeAdPalette palette;
    await tester.pumpWidget(MaterialApp(
      theme: theme,
      home: Builder(builder: (context) {
        palette = NativeAdPalette.of(context);
        return const SizedBox();
      }),
    ));
    return palette;
  }

  void expectEveryColourSet(NativeTemplateStyle style, NativeAdPalette palette) {
    expect(style.mainBackgroundColor, palette.card);
    final texts = [style.primaryTextStyle, style.secondaryTextStyle, style.tertiaryTextStyle];
    for (final text in texts) {
      expect(text, isNotNull);
      expect(text!.backgroundColor, palette.card, reason: 'each text sits on the card colour');
      expect(text.textColor, isNotNull);
    }
    expect(style.primaryTextStyle!.textColor, palette.primaryText);
    expect(style.secondaryTextStyle!.textColor, palette.secondaryText);
    expect(style.tertiaryTextStyle!.textColor, palette.secondaryText);
    expect(style.callToActionTextStyle!.backgroundColor, palette.ctaBackground);
    expect(style.callToActionTextStyle!.textColor, palette.ctaText);
  }

  testWidgets('light theme: a white card with every template colour set', (tester) async {
    final palette = await paletteFor(tester, AppTheme.light(const Locale('en')));
    expect(palette.card, Colors.white);
    for (final template in TemplateType.values) {
      expectEveryColourSet(nativeAdTemplateStyle(template, palette), palette);
    }
  });

  testWidgets('dark theme: the app\'s own card colour with every template colour set', (tester) async {
    final palette = await paletteFor(tester, AppTheme.dark(const Locale('en')));
    expect(palette.card, AppColors.darkSurface);
    expect(palette.primaryText, Colors.white);
    for (final template in TemplateType.values) {
      final style = nativeAdTemplateStyle(template, palette);
      expect(style.templateType, template);
      expectEveryColourSet(style, palette);
    }
  });
}
