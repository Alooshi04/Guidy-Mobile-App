import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/theme/app_theme.dart';
import 'package:guidy_app/widgets/banner_ad_placeholder.dart';

void main() {
  Future<Color?> stripColor(WidgetTester tester, ThemeData theme) async {
    await tester.pumpWidget(MaterialApp(
      theme: theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: AdPlaceholderStrip(bottomMargin: 0)),
    ));
    await tester.pumpAndSettle();
    final box = tester.widget<Container>(find.byKey(const ValueKey('ad_placeholder_strip')));
    return (box.decoration as BoxDecoration).color;
  }

  testWidgets('the ad strip is white in light mode and the app\'s own card colour in dark mode', (tester) async {
    expect(await stripColor(tester, AppTheme.light(const Locale('en'))), Colors.white);
    expect(await stripColor(tester, AppTheme.dark(const Locale('en'))), AppColors.darkSurface);
  });
}
