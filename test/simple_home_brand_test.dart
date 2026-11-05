import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/HomeScreen.dart';
import 'package:guidy_app/services/simple_mode.dart';
import 'package:guidy_app/theme/app_theme.dart';
import 'package:guidy_app/widgets/app_banner_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Simple Mode wears the brand (logo, display face, blue-to-amber rule, the
// existing palette) and still shows the app's one top banner, with clear
// space between it and the big "Where do you want to go?" button.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    simpleMode.value = true;
    appBannerEnabled.value = true;
  });
  tearDown(() {
    simpleMode.value = false;
    appBannerEnabled.value = false;
  });

  for (final (locale, dark) in [(const Locale('en'), false), (const Locale('ar'), true)]) {
    testWidgets('${locale.languageCode} ${dark ? 'dark' : 'light'}: logo, brand rule, banner clear of the main button',
        (tester) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        theme: AppTheme.light(locale, simple: true),
        darkTheme: AppTheme.dark(locale, simple: true),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => AppBannerShell(
          bannerBuilder: (_) => const SizedBox(key: ValueKey('banner'), height: 50, width: double.infinity),
          child: child!,
        ),
        home: const HomeScreen(),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(find.byKey(const ValueKey('banner')), findsOneWidget, reason: 'Simple Mode shows the banner too');
      expect(find.byKey(const ValueKey('simple_logo')), findsOneWidget);
      final rule = tester.widget<Container>(find.byKey(const ValueKey('simple_brand_rule')));
      final gradient = (rule.decoration as BoxDecoration).gradient as LinearGradient;
      expect(gradient.colors, [AppColors.brandBlue, AppColors.brandAmber]);

      final banner = tester.getRect(find.byKey(const ValueKey('banner')));
      final main = tester.getRect(find.byKey(const ValueKey('simple_where_to')));
      expect(main.top - banner.bottom, greaterThanOrEqualTo(48), reason: 'room so nobody taps the ad by mistake');
    });
  }
}
