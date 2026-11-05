import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/SignInScreen.dart';
import 'package:guidy_app/screens/SignUpScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guidy_app/theme/guidy_ui.dart';

/// The language switch sits in the same place on every screen: its centre
/// GuidyLanguageToggle.centerY below the top of the safe area (an AppBar's
/// centre line) and its end GuidyLanguageToggle.edgeInset from the edge,
/// whatever the header around it has (a subtitle, no back arrow, extra
/// buttons) -- it used to shift up or down from screen to screen.
const _width = 400.0;

Widget _app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: home,
    );

Rect _toggle(WidgetTester tester) => tester.getRect(find.byKey(const ValueKey('guidy-language-toggle')));

void _expectStandardPlace(WidgetTester tester, {bool rtl = false}) {
  final r = _toggle(tester);
  expect(r.center.dy, moreOrLessEquals(GuidyLanguageToggle.centerY, epsilon: 0.5));
  if (rtl) {
    expect(r.left, moreOrLessEquals(GuidyLanguageToggle.edgeInset, epsilon: 0.5));
  } else {
    expect(_width - r.right, moreOrLessEquals(GuidyLanguageToggle.edgeInset, epsilon: 0.5));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester, Widget home, {Locale locale = const Locale('en')}) async {
    tester.view.physicalSize = const Size(_width * 2, 800 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_app(home, locale: locale));
    await tester.pump();
  }

  final headers = <String, Widget>{
    'title only': const GuidyHeader(title: 'Trips', showBack: false),
    'with back': GuidyHeader(title: 'Trips', onBack: () {}),
    'with subtitle': GuidyHeader(title: 'Metro', subtitle: 'Plan a ride between any two stations', onBack: () {}),
    'with two-line subtitle': GuidyHeader(
      title: 'Route options',
      subtitle: 'From a very long starting place name to an equally long destination name here',
      onBack: () {},
    ),
    'with trailing buttons': GuidyHeader(
      title: 'Recap',
      trailing: IconButton(icon: const Icon(Icons.share), onPressed: () {}),
      onBack: () {},
    ),
  };

  for (final e in headers.entries) {
    testWidgets('GuidyHeader ${e.key}', (tester) async {
      await pump(tester, Scaffold(body: SafeArea(child: Column(children: [e.value]))));
      _expectStandardPlace(tester);
    });
  }

  testWidgets('GuidyHeader in Arabic mirrors to the left edge', (tester) async {
    await pump(
      tester,
      Scaffold(body: SafeArea(child: Column(children: [headers['with subtitle']!]))),
      locale: const Locale('ar'),
    );
    _expectStandardPlace(tester, rtl: true);
  });

  testWidgets('an AppBar puts it in the same place', (tester) async {
    await pump(
      tester,
      Scaffold(appBar: AppBar(title: const Text('Saved places'), actions: GuidyLanguageToggle.appBarActions)),
    );
    _expectStandardPlace(tester);
  });

  testWidgets('sign-in puts it in the same place', (tester) async {
    await pump(tester, const SignInScreen());
    _expectStandardPlace(tester);
  });

  testWidgets('sign-up puts it in the same place', (tester) async {
    await pump(tester, const SignUpScreen());
    _expectStandardPlace(tester);
  });

  testWidgets('a header can leave it out', (tester) async {
    await pump(tester, const Scaffold(body: GuidyHeader(title: 'Settings', showLanguageToggle: false)));
    expect(find.byKey(const ValueKey('guidy-language-toggle')), findsNothing);
  });
}
