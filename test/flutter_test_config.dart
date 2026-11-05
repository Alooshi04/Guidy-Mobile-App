import 'dart:async';

import 'package:guidy_app/theme/guidy_ui.dart';
import 'package:guidy_app/widgets/guidy_tour.dart';
import 'package:guidy_app/widgets/marquee_text.dart';

/// Runs before every test file. Widget tests have no network, so the
/// redesign's display text must not ask Google Fonts to download a face.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GuidyUi.useGoogleFonts = false;
  // First-launch tours would cover every screen a test opens; the tour
  // tests turn this back on.
  GuidyTour.autoStart = false;
  // An endless marquee never lets pumpAndSettle settle; its test turns it on.
  MarqueeText.animate = false;
  await testMain();
}
