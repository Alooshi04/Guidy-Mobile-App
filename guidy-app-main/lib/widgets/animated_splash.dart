import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The launch animation, shown while StartupGate holds the launch.
///
/// That slot used to be `Scaffold(body: SizedBox.shrink())` -- a blank
/// screen held for however long SharedPreferences took. This fills it with
/// something deliberate instead.
///
/// The motion is a transit line rather than a generic fade: the wordmark
/// settles, a route draws itself left to right, three stations appear as the
/// line reaches them, and a vehicle runs along behind it. It reads as what
/// the app does in about a second and a half, without a word of copy.
///
/// The logo comes from the same two assets every other screen uses, so
/// replacing assets/images/logo_light.png and logo_dark.png updates the
/// splash, Settings, Sign-in and Sign-up together.
class AnimatedSplash extends StatefulWidget {
  const AnimatedSplash({super.key});

  /// How long the whole sequence runs. StartupGate holds the splash for at
  /// least this long so it never flashes half-played on a fast device.
  static const Duration duration = Duration(milliseconds: 1750);

  @override
  State<AnimatedSplash> createState() => _AnimatedSplashState();
}

class _AnimatedSplashState extends State<AnimatedSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: AnimatedSplash.duration)..forward();

  // Overlapping intervals, not a sequence. Each element starts before the
  // previous one finishes, so the whole thing reads as one movement rather
  // than three things taking turns.
  late final Animation<double> _logoFade = CurvedAnimation(
      parent: _c, curve: const Interval(0.00, 0.45, curve: Curves.easeOut));
  late final Animation<double> _logoScale = CurvedAnimation(
      parent: _c, curve: const Interval(0.00, 0.55, curve: Curves.easeOutCubic));
  late final Animation<double> _line = CurvedAnimation(
      parent: _c, curve: const Interval(0.28, 0.82, curve: Curves.easeInOutCubic));
  late final Animation<double> _vehicle = CurvedAnimation(
      parent: _c, curve: const Interval(0.34, 1.00, curve: Curves.easeInOut));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    // The STACKED lockup, not the horizontal one the other screens use.
    // This is a portrait screen with a route line running underneath the
    // mark; a 2.9:1 wordmark leaves the composition wide and flat, while the
    // vertical version sits over the line the way a station name sits over
    // a track.
    final logo = isDark
        ? 'assets/images/logo_vertical_dark.png'
        : 'assets/images/logo_vertical_light.png';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _c,
              builder: (context, child) => Opacity(
                opacity: _logoFade.value,
                // Settles down onto the line rather than just growing: the
                // small upward offset resolving to zero is what makes it
                // feel like arrival instead of a zoom.
                child: Transform.translate(
                  offset: Offset(0, 12 * (1 - _logoScale.value)),
                  child: Transform.scale(
                    scale: 0.88 + (0.12 * _logoScale.value),
                    child: child,
                  ),
                ),
              ),
              child: Image.asset(logo, width: 168, fit: BoxFit.contain),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: 210,
              height: 22,
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) => CustomPaint(
                  painter: _RoutePainter(
                    progress: _line.value,
                    vehicle: _vehicle.value,
                    track: isDark
                        ? Colors.white.withValues(alpha: 0.14)
                        : AppColors.deepPetrol.withValues(alpha: 0.12),
                    line: AppColors.primaryTeal,
                    vehicleColor: AppColors.brandAmber,
                    // Matches the Scaffold behind it, so the station dots
                    // punch a hole and read as rings rather than blobs.
                    hole: isDark
                        ? AppColors.darkBackground
                        : AppColors.lightBackground,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  const _RoutePainter({
    required this.progress,
    required this.vehicle,
    required this.track,
    required this.line,
    required this.vehicleColor,
    required this.hole,
  });

  final double progress;
  final double vehicle;
  final Color track;
  final Color line;
  final Color vehicleColor;
  final Color hole;

  /// Where the interchange dots sit along the line, as fractions of its
  /// length. Deliberately uneven -- evenly spaced dots read as a loading
  /// bar, which is the one thing this is trying not to look like.
  static const List<double> _stops = [0.14, 0.47, 0.86];

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final stroke = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke;

    // The unfilled route, so the line has something to travel along rather
    // than appearing out of nothing.
    canvas.drawLine(Offset(0, y), Offset(size.width, y), stroke..color = track);

    if (progress > 0) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width * progress, y),
        stroke..color = line,
      );
    }

    // Stations appear as the line reaches them, easing up over the short
    // stretch just past each one so they pop rather than fade.
    for (final at in _stops) {
      final t = ((progress - at) / 0.10).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final cx = size.width * at;
      canvas.drawCircle(Offset(cx, y), 4.6 * t, Paint()..color = line);
      canvas.drawCircle(Offset(cx, y), 2.2 * t, Paint()..color = hole);
    }

    // The vehicle, with a short trail so the motion has direction.
    if (vehicle > 0) {
      final vx = size.width * vehicle;
      canvas.drawLine(
        Offset((vx - 16).clamp(0.0, size.width), y),
        Offset(vx, y),
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 3.2
          ..color = vehicleColor.withValues(alpha: 0.35),
      );
      canvas.drawCircle(Offset(vx, y), 5.4, Paint()..color = vehicleColor);
    }
  }

  @override
  bool shouldRepaint(_RoutePainter old) =>
      old.progress != progress || old.vehicle != vehicle;
}
