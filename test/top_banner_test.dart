import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/services/simple_mode.dart';
import 'package:guidy_app/services/trip_pip.dart';
import 'package:guidy_app/widgets/app_banner_shell.dart';
import 'package:guidy_app/widgets/banner_ad_placeholder.dart';

// The banner sits at the top of every screen, under the status bar, the way
// Moovit does it. At the bottom it was right over the Android back and home
// buttons, and riders tapped it by mistake.
const double _statusBar = 30;
const double _navBar = 20;
const Size _screen = Size(400, 800);

final GlobalKey _childKey = GlobalKey();
EdgeInsets? _seenPadding;

Widget _app({Widget? home}) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // The slot as the real banner fills it: 50 dp, under the status bar.
      builder: (context, page) => AppBannerShell(
        bannerBuilder: (_) => const AdPlaceholderStrip(bottomMargin: 0),
        child: page!,
      ),
      home: home ??
          Builder(builder: (context) {
            _seenPadding = MediaQuery.of(context).padding;
            return Scaffold(
              key: _childKey,
              body: const SizedBox.expand(),
              floatingActionButton: FloatingActionButton(onPressed: () {}, child: const Icon(Icons.my_location)),
            );
          }),
    );

/// A 400 x 800 phone with a 30 dp status bar and a 20 dp navigation bar.
void _phone(WidgetTester tester, {double keyboard = 0}) {
  tester.view.physicalSize = _screen;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: _statusBar, bottom: _navBar);
  tester.view.viewPadding = const FakeViewPadding(top: _statusBar, bottom: _navBar);
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);
}

Finder get _strip => find.byKey(const ValueKey('ad_placeholder_strip'));

/// The shell's own slot, not one of the Navigator's.
Finder get _slot => find.descendant(of: find.byType(AppBannerShell), matching: find.byType(Offstage)).first;

void main() {
  setUp(() {
    appBannerEnabled.value = true;
    _seenPadding = null;
  });
  tearDown(() {
    appBannerEnabled.value = false;
    TripPip.active.value = false;
    simpleMode.value = false;
  });

  testWidgets('the ad is the first thing under the status bar and the screen starts under it', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app());
    final strip = tester.getRect(_strip);
    expect(strip.top, _statusBar, reason: 'right under the status bar, never over it');
    expect(strip.height, 50);
    expect(strip.width, _screen.width);
    expect(tester.getTopLeft(find.byKey(_childKey)).dy, strip.bottom, reason: 'the screen begins where the ad ends');
  });

  testWidgets('nothing sits at the bottom, over the system buttons', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app());
    expect(tester.getRect(_strip).bottom, lessThan(_screen.height / 2));
    // The screen reaches the bottom of the display and keeps its safe area.
    expect(tester.getBottomLeft(find.byKey(_childKey)).dy, _screen.height);
    expect(_seenPadding!.bottom, _navBar, reason: 'the nav-bar inset is not swallowed any more');
    expect(_seenPadding!.top, 0, reason: 'the ad already covers the status bar');
  });

  testWidgets('map controls and buttons end up below the ad, never under it', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app());
    final fab = tester.getRect(find.byType(FloatingActionButton));
    expect(fab.top, greaterThan(tester.getRect(_strip).bottom));
    expect(fab.bottom, lessThanOrEqualTo(_screen.height - _navBar), reason: 'above the nav-bar inset');
  });

  testWidgets("a screen's own top bar starts under the ad", (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(
      home: Scaffold(appBar: AppBar(title: const Text('Lines')), body: const SizedBox.expand()),
    ));
    expect(tester.getTopLeft(find.byType(AppBar)).dy, _statusBar + 50);
    // The app bar adds no status-bar padding of its own on top of that.
    expect(tester.getSize(find.byType(AppBar)).height, kToolbarHeight);
  });

  testWidgets('the ad goes away, and the status-bar space returns to the screen, in the floating trip window', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app());
    expect(tester.widget<Offstage>(_slot).offstage, isFalse);

    TripPip.active.value = true;
    await tester.pump();
    expect(tester.widget<Offstage>(_slot).offstage, isTrue);
    expect(_seenPadding!.top, _statusBar);
    expect(tester.getTopLeft(find.byKey(_childKey)).dy, 0);

    TripPip.active.value = false;
    await tester.pump();
    expect(tester.widget<Offstage>(_slot).offstage, isFalse);
    expect(_seenPadding!.top, 0);
  });

  testWidgets('it steps aside for the keyboard and comes back', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app());
    _phone(tester, keyboard: 300);
    await tester.pumpWidget(_app());
    expect(tester.widget<Offstage>(_slot).offstage, isTrue);
    expect(_seenPadding!.top, _statusBar);
    _phone(tester);
    await tester.pumpWidget(_app());
    expect(tester.widget<Offstage>(_slot).offstage, isFalse);
  });

  testWidgets('simple mode keeps the ad in the same place', (tester) async {
    simpleMode.value = true;
    _phone(tester);
    await tester.pumpWidget(_app());
    expect(tester.getRect(_strip).top, _statusBar);
    expect(tester.getTopLeft(find.byKey(_childKey)).dy, _statusBar + 50);
  });

  testWidgets('with ads off, the screen has the whole display', (tester) async {
    appBannerEnabled.value = false;
    _phone(tester);
    await tester.pumpWidget(_app());
    expect(_strip, findsNothing);
    expect(_seenPadding!.top, _statusBar);
  });
}
