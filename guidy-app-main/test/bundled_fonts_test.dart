import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:guidy_app/theme/app_theme.dart';

// Crashlytics, 1.0.2 - 1.0.5: "Failed to load font with url
// https://fonts.gstatic.com/... Failed host lookup: 'fonts.gstatic.com'".
// The brand faces were downloaded on first use, so a first launch with no
// signal -- common on the metro -- threw, and was recorded as a crash.
//
// With runtime fetching switched off, google_fonts can only find a face
// in the app bundle; any face the app asks for that is not bundled fails
// to load here instead of on a rider's phone.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDown(() => GoogleFonts.config.allowRuntimeFetching = true);

  test('every brand face the app draws loads from the app bundle, with no download', () async {
    // The theme's text styles for both scripts...
    for (final locale in const [Locale('en'), Locale('ar')]) {
      AppTheme.light(locale);
      AppTheme.dark(locale);
    }
    // ...and the weights screens set on top of them: 400 to 800, with
    // Nunito Sans italic for display text (GuidyUi.display). Almarai has
    // no italic.
    for (final weight in const [FontWeight.w400, FontWeight.w500, FontWeight.w600, FontWeight.w700, FontWeight.w800]) {
      GoogleFonts.nunitoSans(fontWeight: weight);
      GoogleFonts.nunitoSans(fontWeight: weight, fontStyle: FontStyle.italic);
      GoogleFonts.almarai(fontWeight: weight);
    }

    await expectLater(GoogleFonts.pendingFonts(), completes);
  });

  test('the bundled faces carry their OFL licences onto the licence page', () async {
    registerBrandFontLicenses();

    final byPackage = <String, String>{};
    await for (final entry in LicenseRegistry.licenses) {
      for (final package in entry.packages) {
        byPackage[package] = entry.paragraphs.map((p) => p.text).join('\n');
      }
    }

    expect(byPackage['Almarai'], contains('Copyright 2019 The Almarai Project Authors'));
    expect(byPackage['Almarai'], contains('SIL OPEN FONT LICENSE Version 1.1'));
    expect(byPackage['Nunito Sans'], contains('Copyright 2016 The Nunito Sans Project Authors'));
    expect(byPackage['Nunito Sans'], contains('SIL OPEN FONT LICENSE Version 1.1'));
  });
}
