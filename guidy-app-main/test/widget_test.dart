// This was still the default `flutter create` counter-app smoke test --
// it referenced a `MyApp` class that was never part of Guidy (the real
// root widget is `GuidyApp` in lib/main.dart) and asserted on counter UI
// ('0'/'1' text, a '+' icon) that doesn't exist here. It was failing
// analysis with `creation_with_non_type` and would fail `flutter test`
// outright. Replaced with a smoke test against the real widget.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:guidy_app/main.dart';
import 'package:guidy_app/screens/AuthGate.dart';
import 'package:guidy_app/widgets/animated_splash.dart';

void main() {
  testWidgets('GuidyApp shows the splash, then goes straight to the app',
      (WidgetTester tester) async {
    // StartupGate reads onboarding-seen state via SharedPreferences on
    // first build -- without a mock store, the plugin has no platform
    // channel in a test environment and this would throw instead of
    // resolving. Empty means onboarding has not been seen.
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const GuidyApp());
    await tester.pump();

    expect(find.byType(GuidyApp), findsOneWidget);
    expect(find.byType(AnimatedSplash), findsOneWidget);

    // Not optional politeness: StartupGate holds the splash for
    // AnimatedSplash.duration, and that floor is a real Timer. Ending the
    // test at the first frame leaves it pending, and flutter_test fails
    // teardown with "A Timer is still pending" -- which is exactly how
    // this test failed the first time CI ever got far enough to run it.
    // So run the clock past the splash instead of stopping in front of it.
    await tester.pump(AnimatedSplash.duration);
    await tester.pumpAndSettle();

    // No intro carousel: straight from the splash into the app.
    expect(find.byType(AuthGate), findsOneWidget);
  });
}
