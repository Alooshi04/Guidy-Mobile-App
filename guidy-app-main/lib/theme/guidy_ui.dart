import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/locale_controller.dart';
import '../widgets/marquee_text.dart';
import 'app_theme.dart';

/// Building blocks of the Guidy Figma redesign ("Guidy ui" page), shared by
/// every screen so cards, headers, chips and buttons look the same
/// everywhere instead of each screen picking its own radius and shadow.
///
/// Light mode follows the Figma values. Dark mode keeps the app's own dark
/// palette (AppColors.darkBackground / darkSurface / darkSurfaceElevated),
/// not the navy the Figma dark frames use.
class GuidyUi {
  GuidyUi._();

  /// Off in widget tests (test/flutter_test_config.dart), which have no
  /// network to download font files from.
  static bool useGoogleFonts = true;

  /// Corner radius of cards, tiles and buttons in the design.
  static const double radius = 18;

  /// Muted blue-grey of the design, for dividers, quiet chips and icons.
  /// Too pale for text (about 1.9:1 on white): use [mutedText].
  static const Color mist = Color(0xFFAEBCD5);

  /// Darker shade of [mist] that is readable as text (about 5:1 on white).
  static const Color mistText = Color(0xFF5B6F96);

  /// Secondary text: [mistText] in light mode, the theme's own in dark.
  static Color mutedText(BuildContext context) => context.isDark ? context.textSecondary : mistText;

  /// Inactive tab-bar icon colour (light mode). Labels use [mutedText].
  static const Color tabInactive = Color(0xFFD3DBE8);

  /// Success / savings green used by "Recommended", fares and savings.
  /// Fine for fills and icons; small text uses [greenText].
  static const Color green = Color(0xFF00B277);

  /// [green] darkened to about 5:1 on white, for small text in light mode.
  static Color greenText(BuildContext context) => context.isDark ? green : const Color(0xFF00805A);

  /// Warm orange used for durations, "Fastest"/"Cheapest" tags, minibus.
  static const Color orange = Color(0xFFE07F0B);

  /// Card shadow: navy at 20%, blur 5.8, offset y 4 (Figma "Drop shadow").
  static List<BoxShadow> cardShadow(BuildContext context) => [
        BoxShadow(
          color: context.isDark ? Colors.black.withValues(alpha: 0.35) : AppColors.brandNavy.withValues(alpha: 0.16),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];

  /// Heading colour: brand navy in light mode, white in dark mode.
  static Color heading(BuildContext context) => context.isDark ? Colors.white : AppColors.brandNavy;

  /// Quiet chip / pill fill (mist at 20%, or the raised dark surface).
  static Color chipFill(BuildContext context) =>
      context.isDark ? AppColors.darkSurfaceElevated : mist.withValues(alpha: 0.20);

  /// The blue call-to-action gradient ("Start Navigation", "Calculate").
  static const LinearGradient ctaGradient = LinearGradient(
    colors: [AppColors.brandBlue, Color(0xFF6CC8F5)],
    begin: AlignmentDirectional.centerStart,
    end: AlignmentDirectional.centerEnd,
  );

  /// Screen title style: Nunito Sans ExtraBold Italic 24.
  static TextStyle titleStyle(BuildContext context) => display(context, size: 24, color: heading(context));

  /// Bold display text in the real ExtraBold (Italic) face rather than a
  /// synthesized bold of the regular weight. Arabic uses Almarai, which has
  /// no italic, so it stays upright there.
  static TextStyle display(BuildContext context, {required double size, Color? color, FontWeight weight = FontWeight.w800, List<Shadow>? shadows}) {
    final arabic = Localizations.maybeLocaleOf(context)?.languageCode == 'ar';
    if (!useGoogleFonts) {
      return TextStyle(fontSize: size, fontWeight: weight, fontStyle: arabic ? FontStyle.normal : FontStyle.italic, color: color, height: 1.15, shadows: shadows);
    }
    return arabic
        ? GoogleFonts.almarai(fontSize: size, fontWeight: weight, color: color, height: 1.2, shadows: shadows)
        : GoogleFonts.nunitoSans(fontSize: size, fontWeight: weight, fontStyle: FontStyle.italic, color: color, height: 1.15, shadows: shadows);
  }

  /// Upper-case section label ("QUICK DESTINATIONS", "ACCOUNT").
  static TextStyle sectionLabelStyle(BuildContext context) => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: mutedText(context),
      );
}

/// White (or dark-surface) rounded card with the design's navy shadow.
class GuidyCard extends StatelessWidget {
  const GuidyCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.borderColor,
    this.color,
    this.gradient,
    this.radius = GuidyUi.radius,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? color;
  final Gradient? gradient;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: borderColor == null ? BorderSide.none : BorderSide(color: borderColor!, width: 1),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: GuidyUi.cardShadow(context),
      ),
      child: Material(
        color: gradient == null ? (color ?? context.surfaceCard) : Colors.transparent,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: gradient == null ? null : BoxDecoration(gradient: gradient),
          child: InkWell(
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// One-tap EN / عربي switch, on every screen (in [GuidyHeader], app bars
/// and over the maps). The app rebuilds from main.dart when the locale
/// changes; [onChanged] is for screens that also have to redo something in
/// the new language (a toast, a localized destination name).
class GuidyLanguageToggle extends StatelessWidget {
  const GuidyLanguageToggle({super.key, this.onChanged, this.floating = false});

  /// Where the switch sits on every screen with a header or an app bar:
  /// its centre this far below the top of the safe area (an AppBar's
  /// centre line), and its end this far from the screen edge. GuidyHeader
  /// and [appBarActions] both put it there.
  static const double centerY = 28;
  static const double edgeInset = 16;

  /// For `AppBar(actions: ...)`: the switch, [edgeInset] from the edge.
  static const List<Widget> appBarActions = [GuidyLanguageToggle(), SizedBox(width: edgeInset)];

  /// On a screen without a header or app bar (sign-in, sign-up): [child]
  /// with the switch over it in the standard place. It stays put if
  /// [child] scrolls.
  static Widget over(Widget child) => Stack(
        children: [
          Positioned.fill(child: child),
          const PositionedDirectional(
            top: 0,
            end: edgeInset,
            height: centerY * 2,
            child: Center(child: GuidyLanguageToggle()),
          ),
        ],
      );

  /// Called after the switch with true when the app is now in Arabic.
  final ValueChanged<bool>? onChanged;

  /// Over a map: its own raised card, like the round map buttons.
  final bool floating;

  @override
  Widget build(BuildContext context) {
    final isAr = localeController.isArabic;
    final label = isAr ? 'EN' : 'عربي';
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: floating ? context.surfaceCard : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.brandBlue.withValues(alpha: 0.45), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.translate_rounded, size: 16, color: AppColors.brandBlue),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: GuidyUi.heading(context), fontWeight: FontWeight.bold, fontSize: 12.5)),
        ],
      ),
    );
    return Semantics(
      button: true,
      label: isAr ? 'Switch to English' : 'التحويل للعربي',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        elevation: floating ? 3 : 0,
        shadowColor: AppColors.brandNavy.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: const ValueKey('guidy-language-toggle'),
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            HapticFeedback.selectionClick();
            await localeController.setLocale(isAr ? LocaleController.english : LocaleController.egyptianArabic);
            onChanged?.call(!isAr);
          },
          // 44dp tall tap area around the smaller chip.
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            child: Center(widthFactor: 1, child: chip),
          ),
        ),
      ),
    );
  }
}

/// Screen header from the design: blue back arrow, ExtraBold Italic title,
/// optional one-line subtitle under it, an optional trailing widget and
/// the language toggle.
///
/// The back arrow, the trailing widget and the language toggle sit in a
/// fixed band at the top, so the toggle is in the same place on every
/// screen (see GuidyLanguageToggle.centerY) whatever is under the title.
/// They used to be centred against the title and subtitle together, which
/// moved the toggle down on every screen with a subtitle.
///
/// Uses Icons.arrow_back so it reads the same to screen readers and tests
/// as the AppBar back button it replaces.
class GuidyHeader extends StatelessWidget {
  const GuidyHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.below,
    this.onBack,
    this.showBack = true,
    this.trailing,
    this.titleColor,
    this.showLanguageToggle = true,
    this.onLanguageChanged,
    this.padding = const EdgeInsetsDirectional.fromSTEB(8, _bandTop, GuidyLanguageToggle.edgeInset, 8),
  });

  final String title;
  final String? subtitle;

  /// Shown under the title (and subtitle), as tall as it needs.
  final Widget? below;
  final VoidCallback? onBack;
  final bool showBack;
  final Widget? trailing;
  final Color? titleColor;
  final bool showLanguageToggle;
  final ValueChanged<bool>? onLanguageChanged;
  final EdgeInsetsGeometry padding;

  /// The band the back arrow, trailing widget and toggle sit in.
  static const double _band = 48;
  static const double _bandTop = GuidyLanguageToggle.centerY - _band / 2;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final back = showBack && (onBack != null || canPop);
    final titleStyle = GuidyUi.titleStyle(context).copyWith(color: titleColor);
    // The title's first line is centred in the band; the subtitle runs on
    // below it without moving anything in the band.
    final lineHeight = (TextPainter(
      text: TextSpan(text: title.isEmpty ? 'A' : title, style: titleStyle),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout()).height;
    final titleTop = math.max(0.0, (_band - lineHeight) / 2);
    Widget inBand(Widget child) => SizedBox(height: _band, child: Center(widthFactor: 1, child: child));
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (back)
            inBand(IconButton(
              icon: const Icon(Icons.arrow_back),
              color: titleColor ?? AppColors.brandBlue,
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            ))
          else
            const SizedBox(width: 8, height: _band),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: titleTop),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Long titles keep their size and slide through the
                  // header rather than shrink or lose their ending.
                  MarqueeText(title, style: titleStyle),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(fontSize: 12, color: context.isDark ? context.textSecondary : AppColors.brandNavy),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (below != null) ...[
                    const SizedBox(height: 4),
                    below!,
                  ],
                ],
              ),
            ),
          ),
          if (trailing != null) inBand(trailing!),
          if (showLanguageToggle) ...[
            const SizedBox(width: 4),
            inBand(GuidyLanguageToggle(onChanged: onLanguageChanged)),
          ],
        ],
      ),
    );
  }
}

/// Where a trip starts and ends, one under the other: a dot and the start,
/// a pin and the destination. Each name gets the full width and up to two
/// lines -- "A to B" in one line cut long names off, usually the
/// destination, which is the one that matters.
class GuidyTripEndpoints extends StatelessWidget {
  const GuidyTripEndpoints({super.key, required this.start, required this.end, this.color, this.fontSize = 12.5});

  final String start;
  final String end;
  final Color? color;
  final double fontSize;

  static const double _iconW = 16;
  static const double _gap = 6;
  static const double _arrowW = 14;

  @override
  Widget build(BuildContext context) {
    final c = color ?? (context.isDark ? context.textSecondary : AppColors.brandNavy);
    final style = TextStyle(fontSize: fontSize, height: 1.3, color: c);
    final dot = Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(color: AppColors.brandBlue, shape: BoxShape.circle),
    );
    const pin = Icon(Icons.place_rounded, size: 14, color: AppColors.brandBlue);
    Widget icon(Widget child) => SizedBox(width: _iconW, height: fontSize * 1.35, child: Center(child: child));
    Text name(String text) => Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: style);

    return LayoutBuilder(builder: (context, box) {
      // Measured in the font the Text will use: the theme's (Almarai or
      // Nunito Sans) merged under [style], not the platform default.
      final rendered = DefaultTextStyle.of(context).style.merge(style);
      double widthOf(String text) => (TextPainter(
            text: TextSpan(text: text, style: rendered),
            maxLines: 1,
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout())
              .width;
      // Short names (most trips) share one line, so the header is no
      // taller than a one-line subtitle; long ones get a line each.
      final oneLine = 2 * (_iconW + _gap) + widthOf(start) + _gap + _arrowW + _gap + widthOf(end);
      if (oneLine <= box.maxWidth) {
        return Row(
          children: [
            icon(dot),
            const SizedBox(width: _gap),
            Flexible(child: name(start)),
            const SizedBox(width: _gap),
            Icon(Directionality.of(context) == TextDirection.rtl ? Icons.arrow_back : Icons.arrow_forward,
                size: _arrowW, color: c),
            const SizedBox(width: _gap),
            icon(pin),
            const SizedBox(width: _gap),
            Flexible(child: name(end)),
          ],
        );
      }
      Widget row(Widget i, String text) => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [icon(i), const SizedBox(width: _gap), Expanded(child: name(text))],
          );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [row(dot, start), const SizedBox(height: 2), row(pin, end)],
      );
    });
  }
}

/// Small rounded pill: filter chips, fare badges, tags.
class GuidyPill extends StatelessWidget {
  const GuidyPill({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.fill,
    this.selected = false,
    this.onTap,
    this.outlined = false,
    this.fontSize = 12,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final Color? fill;
  final bool selected;
  final bool outlined;
  final VoidCallback? onTap;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.brandBlue : (color ?? (context.isDark ? context.textSecondary : AppColors.brandNavy));
    final bg = selected
        ? AppColors.brandBlue.withValues(alpha: context.isDark ? 0.22 : 0.10)
        : (fill ?? GuidyUi.chipFill(context));
    final pill = Material(
      color: bg,
      shape: StadiumBorder(
        side: selected || outlined ? BorderSide(color: fg, width: 1) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: fontSize + 3, color: fg),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                label,
                style: TextStyle(fontSize: fontSize, color: fg, fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
    if (onTap == null) return pill;
    // A tappable pill is a filter chip: it says whether it is selected and
    // keeps the 44dp tap height the chips it replaced had, while the
    // visible pill stays the design's size.
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(widthFactor: 1, child: pill),
        ),
      ),
    );
  }
}

/// Full-width call-to-action with the blue gradient (or a mode colour).
class GuidyGradientButton extends StatelessWidget {
  const GuidyGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.gradient = GuidyUi.ctaGradient,
    this.height = 49,
    this.loading = false,
    this.fontSize = 14,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Gradient gradient;
  final double height;

  /// Shows a spinner in place of the icon and ignores taps.
  final bool loading;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Semantics(
      button: true,
      enabled: enabled,
      child: Opacity(
      opacity: enabled || loading ? 1 : 0.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(GuidyUi.radius),
          boxShadow: [
            BoxShadow(color: gradient.colors.first.withValues(alpha: 0.25), blurRadius: 5.8, offset: const Offset(0, 4)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(GuidyUi.radius),
            onTap: enabled ? onPressed : null,
            child: SizedBox(
              height: height,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (loading) ...[
                      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                      const SizedBox(width: 8),
                    ] else if (icon != null) ...[
                      Icon(icon, color: Colors.white, size: fontSize + 4),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(color: Colors.white, fontSize: fontSize, fontWeight: fontSize > 14 ? FontWeight.bold : FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }
}

/// Upper-case section label with the design's spacing.
class GuidySectionLabel extends StatelessWidget {
  const GuidySectionLabel(this.text, {super.key, this.padding = const EdgeInsets.fromLTRB(4, 20, 4, 10)});

  final String text;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(text.toUpperCase(), style: GuidyUi.sectionLabelStyle(context)),
    );
  }
}

/// An icon exported from the Figma file (assets/icons). Pass [color] to tint
/// a single-colour icon, e.g. active and inactive tab-bar states.
class GuidySvgIcon extends StatelessWidget {
  const GuidySvgIcon(this.name, {super.key, this.size = 24, this.color, this.semanticLabel});

  final String name;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/$name.svg',
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticsLabel: semanticLabel,
      colorFilter: color == null ? null : ColorFilter.mode(color!, BlendMode.srcIn),
    );
  }
}

/// The one place a vehicle's colour comes from. Cards, the route detail,
/// every map line, the live trip, the recap, the Lines screen and the rail
/// map all ask here, so a ride is the same colour everywhere: metro Line 3
/// is green on the card, on the map and in the trip (owner, 2026-10-22).
/// Each metro line has its own colour; every other mode its mode colour.
class GuidyModeStyle {
  GuidyModeStyle._();

  /// The colour of a ride: a boarding instruction, a boarding option, a
  /// line, or a map segment carrying `vehicle_type` (and `route_id` /
  /// `route_number` for the metro line).
  static Color forRide(Map<dynamic, dynamic>? ride, {bool dark = false}) {
    final mode = ride?['vehicle_type']?.toString();
    if (mode == 'metro' && ride != null) {
      final line = metroLine(metroLineNumber(ride));
      if (line != null) return line;
    }
    return color(mode, dark: dark);
  }

  static const Color walkStep = Color(0xFF2A9D8F);
  static const Color arriveStep = Color(0xFF264653);
  static const Color changeStep = Color(0xFFE76F51);

  /// The colour of a trip step: a ride (boarding, or changing onto a line)
  /// in its line's colour, walks and the arrival in their own.
  static Color forStep(Map<dynamic, dynamic> step, {bool dark = false}) {
    switch (step['action']) {
      case 'walk_to_station':
      case 'walk_to_transfer':
      case 'continue_walk':
      case 'walk_to_destination':
        return walkStep;
      case 'arrive':
        return arriveStep;
      case 'transfer':
        return step['vehicle_type'] == null ? changeStep : forRide(step, dark: dark);
    }
    return forRide(step, dark: dark);
  }

  /// The colour of each of a route's map [segments], null for a walk.
  /// A segment names its line (`route_id`) on newer servers; on older ones
  /// the n-th ride segment is the n-th boarding in [instructions].
  static List<Color?> segmentColors(List<dynamic> segments, List<dynamic> instructions, {bool dark = false}) {
    final rides = [
      for (final i in instructions)
        if (i is Map && (i['action'] == 'board' || i['action'] == 'transfer') && i['route_id'] != null) i,
    ];
    bool isWalk(dynamic s) => s is! Map || s['is_walk'] == true || s['vehicle_type'] == 'walk';
    // Pair by order only when the counts agree; otherwise each segment
    // keeps its own mode colour.
    final paired = segments.where((s) => !isWalk(s)).length == rides.length;
    final out = <Color?>[];
    var k = 0;
    for (final s in segments) {
      if (isWalk(s)) {
        out.add(null);
        continue;
      }
      final seg = s as Map;
      final ride = seg['route_id'] == null && paired ? rides[k] : seg;
      out.add(forRide(ride, dark: dark));
      k++;
    }
    return out;
  }

  static Color color(String? mode, {bool dark = false}) {
    switch (mode) {
      case 'bus':
        return const Color(0xFFF0A04B);
      case 'microbus':
        // The design's deep blue is unreadable on the dark surface.
        return dark ? const Color(0xFF5B9BE0) : const Color(0xFF1662B1);
      case 'minibus':
        return GuidyUi.orange;
      case 'monorail':
        // Purple, not the design's green: that is metro Line 3's, and the
        // two meet at Cairo Stadium.
        return dark ? const Color(0xFFB48BDB) : const Color(0xFF9C6DC2);
      case 'metro':
        return AppColors.brandBlue;
      case 'lrt':
        return dark ? const Color(0xFFAEBCD5) : const Color(0xFF6A7FA8);
      case 'brt':
        return dark ? const Color(0xFFEF6B6B) : const Color(0xFFD62828);
      case 'tram':
        return const Color(0xFFC2A76D);
      case 'apm':
        return const Color(0xFF8895A0);
      case 'walk':
        return walkStep;
      default:
        return AppColors.brandBlue;
    }
  }

  /// Each Cairo Metro line has its own colour in the design:
  /// Line 1 blue, Line 2 salmon, Line 3 green.
  static Color? metroLine(String? number) {
    switch (number?.trim()) {
      case '1':
        return AppColors.brandBlue;
      case '2':
        return const Color(0xFFFF8870);
      case '3':
        return GuidyUi.green;
      default:
        return null;
    }
  }

  /// The metro line number ("1", "2", "3") of a route. Read from the
  /// route id (NAT_L1...) because the Arabic feed names the lines in words
  /// ("الخط الأول"), which can't go in an "M1" badge.
  static String? metroLineNumber(Map<dynamic, dynamic> route) {
    final id = RegExp(r'_L(\d+)$').firstMatch((route['route_id'] ?? '').toString());
    if (id != null) return id.group(1);
    return RegExp(r'\d+').firstMatch((route['number'] ?? route['route_number'] ?? '').toString())?.group(0);
  }

  /// `#rrggbb`, for the colours the app hands on (a shared live trip).
  static String hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  /// A line "number" short enough for the badge under a mode icon. Names
  /// with no digit in them (the BRT's "الأتوبيس الترددي", a bare vehicle
  /// word) are dropped: the icon already says what it is.
  static String badgeNumber(String? cleaned) {
    final s = (cleaned ?? '').trim();
    if (s.isEmpty || !RegExp(r'\d').hasMatch(s)) return '';
    return s;
  }

  /// Figma icon asset for the mode, or null when the design has none.
  static String? icon(String? mode) {
    switch (mode) {
      case 'bus':
      case 'brt':
        return 'mode_bus';
      case 'microbus':
        return 'mode_microbus';
      case 'minibus':
        return 'mode_minibus';
      case 'monorail':
        return 'mode_monorail';
      case 'metro':
        return 'mode_metro';
      case 'lrt':
        return 'mode_lrt';
      default:
        return null;
    }
  }
}
