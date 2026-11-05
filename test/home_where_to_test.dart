import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/HomeScreen.dart';
import 'package:guidy_app/services/simple_mode.dart';
import 'package:guidy_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The home "Where to?" button is the main action: taller than the cards
// under it, an edge in the brand's blue and amber (existing palette only),
// and it fits a 360 dp phone at large text in both languages.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    simpleMode.value = false;
  });

  Future<void> pump(WidgetTester tester, {Locale locale = const Locale('en'), double scale = 1.0, bool dark = false}) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(
      locale: locale,
      theme: AppTheme.light(locale),
      darkTheme: AppTheme.dark(locale),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
      home: const HomeScreen(),
    ));
    await tester.pumpAndSettle();
  }

  for (final (locale, dark) in [(const Locale('en'), false), (const Locale('ar'), true)]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('${locale.languageCode} ${dark ? 'dark' : 'light'} x$scale: tall, fits, no overflow', (tester) async {
        await pump(tester, locale: locale, scale: scale, dark: dark);
        expect(tester.takeException(), isNull);
        final box = tester.getSize(find.byKey(const ValueKey('home_where_to')));
        expect(box.height, greaterThanOrEqualTo(80), reason: 'taller than a normal card');
        expect(box.width, lessThanOrEqualTo(360));
        final text = tester.widget<Text>(find.descendant(
            of: find.byKey(const ValueKey('home_where_to')),
            matching: find.byType(Text)));
        expect(text.style!.fontSize!, greaterThanOrEqualTo(20));
      });
    }
  }

  testWidgets('its edge is the brand blue to amber, no navy', (tester) async {
    await pump(tester, dark: true);
    final edge = tester.widget<DecoratedBox>(find.ancestor(
        of: find.byKey(const ValueKey('home_where_to')), matching: find.byType(DecoratedBox)).first);
    final gradient = (edge.decoration as BoxDecoration).gradient as LinearGradient;
    expect(gradient.colors, [AppColors.brandBlue, AppColors.brandAmber]);
  });
}
