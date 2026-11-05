import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:guidy_app/services/trip_pip.dart';
import 'package:guidy_app/theme/app_theme.dart';
import 'package:guidy_app/utils/route_line_style.dart';
import 'package:guidy_app/widgets/app_banner_shell.dart';

void main() {
  test('a ride is a coloured line over a darker outline of the same hue', () {
    const c = Color(0xFF489CB5);
    final lines = RouteLineStyle.ride('r', const [LatLng(30, 31), LatLng(30.01, 31)], c);
    expect(lines, hasLength(2));
    expect(lines.first.width, greaterThan(lines.last.width));
    expect(lines.last.color, c);
    expect(lines.first.zIndex, lessThan(lines.last.zIndex));
  });

  test('walks are dotted and not teal', () {
    final w = RouteLineStyle.walk('w', const [LatLng(30, 31), LatLng(30.01, 31)], dark: false);
    expect(w.patterns.first, PatternItem.dot);
    expect(w.color, isNot(const Color(0xFF2A9D8F)));
  });

  // Google Maps' walking directions: a row of round blue dots, about one
  // dot apart, drawn over the ride lines.
  test('walks look like Google Maps walking dots', () {
    const pts = [LatLng(30, 31), LatLng(30.01, 31)];
    final light = RouteLineStyle.walk('w', pts, dark: false);
    final dark = RouteLineStyle.walk('w', pts, dark: true);
    expect(light.color, const Color(0xFF1A73E8));
    expect(dark.color, const Color(0xFF8AB4F8));
    expect(light.width, greaterThanOrEqualTo(8));
    expect(light.patterns, hasLength(2));
    expect(light.patterns.first, PatternItem.dot);
    final gap = (light.patterns.last.toJson() as List).last as double;
    // Android draws the width in dp but the gap in raw pixels: on the
    // usual 2.6-3.5x screens, 3x the width is about one dot of space.
    expect(gap, inInclusiveRange(light.width * 2.5, light.width * 3.5));
    final ride = RouteLineStyle.ride('r', pts, const Color(0xFF489CB5));
    expect(light.zIndex, greaterThan(ride.last.zIndex));
  });

  test('screen changes are quick', () {
    const b = QuickSlidePageTransitionsBuilder();
    expect(b.transitionDuration.inMilliseconds, lessThanOrEqualTo(250));
  });

  testWidgets('the app-wide banner slot hides while the keyboard is open', (tester) async {
    appBannerEnabled.value = true;
    Widget app(double keyboard) => MediaQuery(
          data: MediaQueryData(viewInsets: EdgeInsets.only(bottom: keyboard)),
          child: const MaterialApp(home: AppBannerShell(child: SizedBox.expand())),
        );
    await tester.pumpWidget(app(0));
    expect(find.byType(Offstage), findsWidgets);
    final shown = tester.widget<Offstage>(find.byType(Offstage).last);
    expect(shown.offstage, isFalse);
    await tester.pumpWidget(app(300));
    expect(tester.widget<Offstage>(find.byType(Offstage).last).offstage, isTrue);
    appBannerEnabled.value = false;
  });

  // The floating window is the whole Flutter view: a 320 dp banner under a
  // trip in a window about 200 dp wide was cropped and took a quarter of it.
  testWidgets('the app-wide banner slot hides while the trip is in the floating window', (tester) async {
    appBannerEnabled.value = true;
    addTearDown(() {
      appBannerEnabled.value = false;
      TripPip.active.value = false;
    });
    await tester.pumpWidget(const MaterialApp(home: AppBannerShell(child: SizedBox.expand())));
    expect(tester.widget<Offstage>(find.byType(Offstage).last).offstage, isFalse);

    TripPip.active.value = true;
    await tester.pump();
    expect(tester.widget<Offstage>(find.byType(Offstage).last).offstage, isTrue);

    TripPip.active.value = false;
    await tester.pump();
    expect(tester.widget<Offstage>(find.byType(Offstage).last).offstage, isFalse);
  });
}
