import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/theme/app_theme.dart';
import 'package:guidy_app/widgets/app_banner_shell.dart';
import 'package:guidy_app/widgets/system_bars_style.dart';

void main() {
  SystemUiOverlayStyle? navBarStyle(WidgetTester tester) =>
      tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(find.byType(AnnotatedRegion<SystemUiOverlayStyle>)).value;

  Future<void> pump(WidgetTester tester, ThemeMode mode) => tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(const Locale('en')),
        darkTheme: AppTheme.dark(const Locale('en')),
        themeMode: mode,
        builder: (context, child) => SystemBarsStyle(child: child!),
        home: const Scaffold(),
      ));

  testWidgets('dark theme: the Android nav bar is the app\'s dark background with light icons', (tester) async {
    await pump(tester, ThemeMode.dark);
    final s = navBarStyle(tester)!;
    expect(s.systemNavigationBarColor, AppColors.darkBackground);
    expect(s.systemNavigationBarIconBrightness, Brightness.light);
    expect(s.statusBarIconBrightness, Brightness.light);
  });

  testWidgets('light theme: the nav bar is the app\'s light background with dark icons', (tester) async {
    await pump(tester, ThemeMode.light);
    final s = navBarStyle(tester)!;
    expect(s.systemNavigationBarColor, AppColors.lightBackground);
    expect(s.systemNavigationBarIconBrightness, Brightness.dark);
    // Over the banner's white strip: white icons were invisible.
    expect(s.statusBarIconBrightness, Brightness.dark);
  });

  // Android 15 draws edge to edge: the 3-button bar (~48 dp) or the gesture
  // pill (~24 dp) is reported as bottom padding and nothing pads for it
  // unless the app does.
  for (final inset in [48.0, 24.0]) {
    testWidgets('screens stop above the system bar (bottom inset $inset), in both themes', (tester) async {
      for (final mode in [ThemeMode.dark, ThemeMode.light]) {
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.light(const Locale('en')),
          darkTheme: AppTheme.dark(const Locale('en')),
          themeMode: mode,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: EdgeInsets.only(bottom: inset),
              viewPadding: EdgeInsets.only(bottom: inset),
            ),
            child: SystemBarsStyle(child: child!),
          ),
          home: Scaffold(body: Column(children: [const Expanded(child: SizedBox.expand()), Text('footer', key: const ValueKey('footer'))])),
        ));
        final screenBottom = tester.view.physicalSize.height / tester.view.devicePixelRatio;
        expect(tester.getBottomLeft(find.byKey(const ValueKey('footer'))).dy, lessThanOrEqualTo(screenBottom - inset),
            reason: 'the footer is not behind the nav buttons');
        final inner = MediaQuery.of(tester.element(find.byKey(const ValueKey('footer'))));
        expect(inner.padding.bottom, 0, reason: 'no screen pads a second time');
        expect(inner.viewPadding.bottom, 0);
      }
    });
  }

  testWidgets('no inset (older phones, keyboard open): nothing changes', (tester) async {
    await pump(tester, ThemeMode.dark);
    final screen = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(tester.getSize(find.byType(Scaffold)).height, screen);
  });

  testWidgets('with the top banner showing and the nav bar inset, nothing overlaps either', (tester) async {
    appBannerEnabled.value = true;
    addTearDown(() => appBannerEnabled.value = false);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(const Locale('en')),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: const EdgeInsets.only(top: 24, bottom: 48),
          viewPadding: const EdgeInsets.only(top: 24, bottom: 48),
        ),
        child: SystemBarsStyle(
          child: AppBannerShell(
            bannerBuilder: (_) => const SizedBox(key: ValueKey('banner'), height: 50, width: double.infinity),
            child: child!,
          ),
        ),
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('title', key: ValueKey('title'))),
        body: const Column(children: [Expanded(child: SizedBox.expand()), Text('footer', key: ValueKey('footer'))]),
      ),
    ));
    await tester.pump();
    final screenBottom = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final banner = tester.getRect(find.byKey(const ValueKey('banner')));
    expect(banner.bottom, lessThanOrEqualTo(tester.getTopLeft(find.byKey(const ValueKey('title'))).dy),
        reason: 'the page starts under the banner');
    expect(tester.getBottomLeft(find.byKey(const ValueKey('footer'))).dy, lessThanOrEqualTo(screenBottom - 48),
        reason: 'the footer is above the nav bar');
  });
}
