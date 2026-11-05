import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Official Guidy brand palette, verified pixel-for-pixel against the source
/// assets in Guidy Assets (Horizontal Logo.svg, Vertical logo.svg, icon 1/2/3/4.svg,
/// and c1.ai / aaaaa.jpg).
///
/// Brand Color Specification:
/// - Brand Navy:  #0B3D71 (Primary corporate identity, "Guidy" wordmark, outer bus body)
/// - Brand Blue:  #2DA3E3 (Transit flow, bus window, navigation chevron, live routes)
/// - Brand Amber: #FFBC70 (Bus wheel, route light trails, warm savings accent)
///
/// Typography:
/// - Latin: Nunito Sans (Google Fonts)
/// - Arabic: Almarai (Google Fonts)
class AppColors {
  AppColors._();

  // Canonical Brand Triad
  static const Color brandNavy = Color(0xFF0B3D71);   // Brand Deep Navy (corporate anchor)
  static const Color brandBlue = Color(0xFF2DA3E3);   // Brand Sky Blue (transit movement)
  static const Color brandAmber = Color(0xFFFFBC70);  // Brand Golden Amber / Peach (warm accent, wheel)

  // Accessible warm accent variants for text / high-contrast icons
  static const Color brandAmberDark = Color(0xFFE88916);
  static const Color brandAmberLight = Color(0xFFFFF4E5);

  // Backward-compatible aliases for existing call sites
  static const Color primaryTeal = brandBlue;
  static const Color transitBlue = brandBlue;
  static const Color deepPetrol = brandNavy;
  static const Color gold = brandAmber;
  static const Color supportingPeach = brandAmber;

  // Additional supporting colors from brand guide
  static const Color supportingSlate = Color(0xFF5C7A99);
  static const Color supportingMint = Color(0xFFDCFCE7);
  static const Color supportingGreen = Color(0xFF2ECC71); // Clean on-time transit green
  static const Color errorRed = Color(0xFFE53935); // Clear status error / closed red


  // Surfaces: Light Mode (crisp neutral canvas eliminating murky blue cast)
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Colors.white;

  // Surfaces: Dark Mode (sophisticated obsidian slate with subtle navy undertone;
  // completely eliminates the blinding, oversaturated blue wash where cards were previously #0B3D71)
  static const Color darkBackground = Color(0xFF0F1722);
  static const Color darkSurface = Color(0xFF182230);
  static const Color darkSurfaceElevated = Color(0xFF223042);

  // Official Brand Gradient with harmonious blue-to-gold radiance
  static const LinearGradient brandGradient = LinearGradient(
    colors: [
      brandNavy,
      Color(0xFF14548E),
      Color(0xFF1C75B0),
      Color(0xFFDC973C),
      brandAmber,
    ],
    stops: [0.0, 0.28, 0.58, 0.80, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Elegant brand hero card gradient with tasteful, warm gold presence
  static const LinearGradient heroCardGradient = LinearGradient(
    colors: [
      brandNavy,
      Color(0xFF135086),
      Color(0xFF1C75B0),
      Color(0xFFD69339),
      Color(0xFFF9BD6C),
    ],
    stops: [0.0, 0.30, 0.60, 0.82, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // 2-Color Subtle Header Gradient
  static const LinearGradient headerGradient = LinearGradient(
    colors: [brandNavy, Color(0xFF19497D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Shows the bundled brand faces' licences on the app's licence page. The
/// SIL OFL lets the fonts ship inside the app on condition that their
/// licence goes with them.
void registerBrandFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (package, file) in const [('Almarai', 'OFL-Almarai.txt'), ('Nunito Sans', 'OFL-NunitoSans.txt')]) {
      yield LicenseEntryWithLineBreaks([package], await rootBundle.loadString('assets/google_fonts/$file'));
    }
  });
}

/// Nunito Sans for Latin script, Almarai for Arabic -- matching the brand
/// guide exactly. Both are bundled in assets/google_fonts/, where
/// google_fonts finds them before it would ever go to the network: a
/// first launch with no signal used to fail to fetch them.
TextTheme _brandTextTheme(Locale locale, TextTheme base) {
  return locale.languageCode == 'ar'
      ? GoogleFonts.almaraiTextTheme(base)
      : GoogleFonts.nunitoSansTextTheme(base);
}

class AppTheme {
  AppTheme._();

  /// Quick screen changes on every platform. Android's default
  /// (predictive-back fade-forwards) runs 450 ms and fades the whole page
  /// through the background, which made opening a screen feel slow even
  /// when the screen itself was ready at once.
  static const PageTransitionsTheme _pageTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: QuickSlidePageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.fuchsia: QuickSlidePageTransitionsBuilder(),
      TargetPlatform.linux: QuickSlidePageTransitionsBuilder(),
      TargetPlatform.windows: QuickSlidePageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    },
  );

  /// Simple mode: every text and outlined button is at least 56 dp tall.
  static final TextButtonThemeData _simpleTextButtons =
      TextButtonThemeData(style: TextButton.styleFrom(minimumSize: const Size(64, 56)));
  static final OutlinedButtonThemeData _simpleOutlinedButtons =
      OutlinedButtonThemeData(style: OutlinedButton.styleFrom(minimumSize: const Size(64, 56)));

  static ThemeData light(Locale locale, {bool simple = false}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.brandBlue,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.brandBlue,
      secondary: AppColors.brandAmberDark,
      tertiary: AppColors.brandNavy,
      surface: AppColors.lightSurface,
      error: Colors.redAccent,
    );

    final textTheme = _brandTextTheme(
      locale,
      ThemeData.light().textTheme.apply(bodyColor: const Color(0xFF0B1B2B), displayColor: const Color(0xFF0B1B2B)),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.lightBackground,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.lightSurface,
        foregroundColor: const Color(0xFF0B1B2B),
        iconTheme: const IconThemeData(color: Color(0xFF0B1B2B)),
        titleTextStyle: textTheme.titleLarge?.copyWith(color: const Color(0xFF0B1B2B), fontWeight: FontWeight.bold),
        elevation: 0,
      ),
      cardColor: AppColors.lightSurface,
      dividerColor: Colors.black12,
      iconTheme: const IconThemeData(color: Color(0xFF0B1B2B)),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          // Simple mode: the brand navy, for white text that reads (11:1).
          backgroundColor: simple ? AppColors.brandNavy : AppColors.brandBlue,
          foregroundColor: Colors.white,
          textStyle: textTheme.labelLarge,
          // Simple mode: taller buttons that are easy to hit.
          minimumSize: simple ? const Size(64, 58) : null,
        ),
      ),
      textButtonTheme: simple ? _simpleTextButtons : null,
      outlinedButtonTheme: simple ? _simpleOutlinedButtons : null,
      visualDensity: simple ? VisualDensity.comfortable : null,
      listTileTheme: simple ? const ListTileThemeData(minVerticalPadding: 14) : null,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        hintStyle: TextStyle(color: Colors.black45, fontFamily: textTheme.bodyMedium?.fontFamily),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.brandBlue),
      pageTransitionsTheme: _pageTransitions,
    );
  }

  static ThemeData dark(Locale locale, {bool simple = false}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.brandBlue,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.brandBlue,
      secondary: AppColors.brandAmber,
      tertiary: AppColors.brandNavy,
      surface: AppColors.darkSurface,
      error: Colors.redAccent.shade100,
    );

    final textTheme = _brandTextTheme(
      locale,
      ThemeData.dark().textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.darkBackground,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkBackground,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
        elevation: 0,
      ),
      cardColor: AppColors.darkSurface,
      dividerColor: Colors.white12,
      iconTheme: const IconThemeData(color: Colors.white70),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          // Simple mode: dark text on the brand blue (6:1), not white (2.9:1).
          backgroundColor: AppColors.brandBlue,
          foregroundColor: simple ? AppColors.darkBackground : Colors.white,
          textStyle: textTheme.labelLarge,
          // Simple mode: taller buttons that are easy to hit.
          minimumSize: simple ? const Size(64, 58) : null,
        ),
      ),
      textButtonTheme: simple ? _simpleTextButtons : null,
      outlinedButtonTheme: simple ? _simpleOutlinedButtons : null,
      visualDensity: simple ? VisualDensity.comfortable : null,
      listTileTheme: simple ? const ListTileThemeData(minVerticalPadding: 14) : null,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurfaceElevated,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        hintStyle: TextStyle(color: Colors.white38, fontFamily: textTheme.bodyMedium?.fontFamily),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.brandBlue),
      pageTransitionsTheme: _pageTransitions,
    );
  }
}

/// Google Maps' own "Night" style, applied via GoogleMap(style: ...) whenever
/// the app is in dark mode. Tuned to match the elegant obsidian slate
/// (AppColors.darkBackground, #0F1722) and card surfaces (#182230) rather than
/// the old oversaturated blue palette.
///
/// Icons are off by default (road-number shields and the like are clutter),
/// but back on for places and transit stations: with every icon hidden, shops,
/// cafes and supermarkets vanished from the map in dark mode while light mode
/// showed them -- riders find their stop by exactly those landmarks.
const String darkMapStyleJson = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#111823"}]},
  {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
  {"featureType": "poi", "elementType": "labels.icon", "stylers": [{"visibility": "on"}]},
  {"featureType": "transit.station", "elementType": "labels.icon", "stylers": [{"visibility": "on"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#8ea6be"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#0f1722"}]},
  {"featureType": "administrative", "elementType": "geometry", "stylers": [{"color": "#2c3b4e"}]},
  {"featureType": "administrative.locality", "elementType": "labels.text.fill", "stylers": [{"color": "#c5d5e6"}]},
  {"featureType": "poi", "elementType": "labels.text.fill", "stylers": [{"color": "#a9bfd4"}]},
  {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"color": "#13212b"}]},
  {"featureType": "poi.park", "elementType": "labels.text.fill", "stylers": [{"color": "#53796f"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#1c2635"}]},
  {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#8ea6be"}]},
  {"featureType": "road.arterial", "elementType": "geometry", "stylers": [{"color": "#223042"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#2a3d54"}]},
  {"featureType": "road.highway", "elementType": "labels.text.fill", "stylers": [{"color": "#d7e4f1"}]},
  {"featureType": "transit", "elementType": "geometry", "stylers": [{"color": "#223042"}]},
  {"featureType": "transit.station", "elementType": "labels.text.fill", "stylers": [{"color": "#c5d5e6"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#0d1d2e"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#3b587a"}]}
]
''';

/// Small helpers so screens don't have to repeat `Theme.of(context)...`
/// boilerplate everywhere they need to branch on light vs dark.
extension AppThemeX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  ColorScheme get colors => Theme.of(this).colorScheme;

  /// Primary body/heading text color for the current theme.
  Color get textPrimary => isDark ? Colors.white : const Color(0xFF0B1B2B);

  /// Secondary/caption text color for the current theme.
  Color get textSecondary => isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

  /// Fill color for search bars, input pills, and similar "sunken" containers.
  Color get fieldFill => isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF1F5F9);

  /// Card/sheet surface color that sits above the scaffold background.
  Color get surfaceCard => isDark ? AppColors.darkSurface : Colors.white;

  /// Accent amber for warm highlights, savings chips, and badges.
  Color get accentAmber => isDark ? AppColors.brandAmber : AppColors.brandAmberDark;
}



/// A short slide-and-fade: the new page moves in 6% of the width from the
/// reading side and fades in over 220 ms; the page underneath shifts back
/// slightly. Nothing is scaled, which keeps a page holding a Google map
/// cheap to animate.
class QuickSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const QuickSlidePageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 220);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 180);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    final double dir = rtl ? -1 : 1;
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    final behind = CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOutCubic);
    return SlideTransition(
      position: Tween<Offset>(begin: Offset.zero, end: Offset(-0.03 * dir, 0)).animate(behind),
      child: SlideTransition(
        position: Tween<Offset>(begin: Offset(0.06 * dir, 0), end: Offset.zero).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      ),
    );
  }
}
