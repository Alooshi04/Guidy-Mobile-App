import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../theme/app_theme.dart';

/// Centralized factory and memory cache for modern, high-DPI (3x retina) vector
/// transit markers and cartography pins across Guidy.
///
/// Eliminates cheap, pixelated 1x bitmaps and dated stock balloon pushpins.
/// Inspired by modern transit cartography (Citymapper, Apple Maps, Mapbox Maki).
class MapMarkerService {
  MapMarkerService._();

  // Anchors
  /// Anchor for circular beacons, transit bullets, and transfer nodes.
  static const Offset centerAnchor = Offset(0.5, 0.5);

  /// Anchor for teardrop needle pins so the tip points directly to the ground coordinate.
  static const Offset pinAnchor = Offset(0.5, 0.94);

  // In-memory cache to prevent redundant rasterization
  static final Map<String, BitmapDescriptor> _cache = {};

  /// Clears the marker bitmap cache (useful for theme or configuration switches).
  static void clearCache() {
    _cache.clear();
  }

  /// Modern Glowing Origin Beacon (Start Point)
  /// Features a radiant emerald halo, crisp white border, and deep ambient shadow.
  static Future<BitmapDescriptor> getOriginMarker({
    Color color = AppColors.supportingGreen,
    double pixelRatio = 3.0,
  }) async {
    final cacheKey = 'origin_${color.toARGB32()}_$pixelRatio';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    const double logicalSize = 34.0;
    final int px = (logicalSize * pixelRatio).round();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, px.toDouble(), px.toDouble()));
    final center = Offset(px / 2, px / 2);

    // 1. Soft pulse/glow halo
    final haloPaint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 16.0 * pixelRatio, haloPaint);

    // 2. Ambient drop shadow
    final shadowPaint = Paint()
      ..color = Colors.black38
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3.5 * pixelRatio);
    canvas.drawCircle(center.translate(0, 1.5 * pixelRatio), 11.0 * pixelRatio, shadowPaint);

    // 3. Crisp white outer rim
    final whiteRimPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 11.0 * pixelRatio, whiteRimPaint);

    // 4. Emerald core
    final corePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 8.0 * pixelRatio, corePaint);

    // 5. White center pip
    final centerPipPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 3.0 * pixelRatio, centerPipPaint);

    final descriptor = await _finalizeBitmap(recorder, px, px, pixelRatio);
    _cache[cacheKey] = descriptor;
    return descriptor;
  }

  /// Modern Precision Teardrop Needle Pin (Destination Point)
  /// Features a ground contact shadow, elegant curved needle pointing to the exact coordinate,
  /// rich gradient fill, and crisp white inner target disc.
  static Future<BitmapDescriptor> getDestinationMarker({
    Color color = const Color(0xFFE53935),
    double pixelRatio = 3.0,
  }) async {
    final cacheKey = 'destination_${color.toARGB32()}_$pixelRatio';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    const double logicalWidth = 32.0;
    const double logicalHeight = 44.0;
    final int pxW = (logicalWidth * pixelRatio).round();
    final int pxH = (logicalHeight * pixelRatio).round();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, pxW.toDouble(), pxH.toDouble()));

    // Ground anchor point: tip touches near bottom, with ground contact shadow
    final groundAnchor = Offset(pxW / 2, pxH - (3.0 * pixelRatio));
    final pinHeight = 35.0 * pixelRatio;
    final bulbRadius = 13.0 * pixelRatio;
    final bulbCenter = Offset(groundAnchor.dx, groundAnchor.dy - pinHeight + bulbRadius);

    // 1. Ground contact shadow
    final groundShadowPaint = Paint()
      ..color = Colors.black26
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.5 * pixelRatio);
    canvas.drawOval(
      Rect.fromCenter(
        center: groundAnchor.translate(0, 1.0 * pixelRatio),
        width: 13.0 * pixelRatio,
        height: 5.5 * pixelRatio,
      ),
      groundShadowPaint,
    );

    // 2. Teardrop needle path
    final path = _getTeardropPath(groundAnchor, bulbCenter, bulbRadius, pinHeight);

    // 3. Pin body gradient fill
    final HSLColor hsl = HSLColor.fromColor(color);
    final Color darkerShade = hsl.withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0)).toColor();
    final bodyPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(bulbCenter.dx, bulbCenter.dy - bulbRadius),
        groundAnchor,
        [color, darkerShade],
      );
    canvas.drawPath(path, bodyPaint);

    // 4. Crisp white border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * pixelRatio;
    canvas.drawPath(path, borderPaint);

    // 5. White inner target disc
    final innerDiscPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(bulbCenter, 6.0 * pixelRatio, innerDiscPaint);

    // 6. Center target pip
    final centerPipPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(bulbCenter, 2.8 * pixelRatio, centerPipPaint);

    final descriptor = await _finalizeBitmap(recorder, pxW, pxH, pixelRatio);
    _cache[cacheKey] = descriptor;
    return descriptor;
  }

  /// Modern Transit Station / Stop Bullet
  /// Mimics Apple Maps and Citymapper transit line bullets.
  /// Line-colored core, crisp white rim, ambient shadow, and high contrast.
  static Future<BitmapDescriptor> getStationStopMarker({
    required Color color,
    bool isSelected = false,
    double pixelRatio = 3.0,
  }) async {
    final cacheKey = 'stop_${color.toARGB32()}_${isSelected}_$pixelRatio';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    final double logicalSize = isSelected ? 22.0 : 14.0;
    final int px = (logicalSize * pixelRatio).round();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, px.toDouble(), px.toDouble()));
    final center = Offset(px / 2, px / 2);
    final radius = (px / 2) - (2.0 * pixelRatio);

    // 1. Drop shadow
    final shadowPaint = Paint()
      ..color = Colors.black38
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.5 * pixelRatio);
    canvas.drawCircle(center.translate(0, 1.2 * pixelRatio), radius, shadowPaint);

    // 2. White outer rim
    final whiteRimPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, whiteRimPaint);

    // 3. Line-colored core
    final corePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - (isSelected ? 2.5 * pixelRatio : 2.0 * pixelRatio), corePaint);

    // 4. White center pip (always on selected, subtle on standard)
    if (isSelected) {
      final pipPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 4.0 * pixelRatio, pipPaint);
    } else {
      final pipPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 2.2 * pixelRatio, pipPaint);
    }

    final descriptor = await _finalizeBitmap(recorder, px, px, pixelRatio);
    _cache[cacheKey] = descriptor;
    return descriptor;
  }

  /// Modern Transfer / Interchange Node Marker
  /// Multi-layered concentric rings (navy outer ring, white separator, teal core, white pip)
  /// providing instant visual hierarchy for transit transfer points.
  static Future<BitmapDescriptor> getTransferMarker({
    double pixelRatio = 3.0,
  }) async {
    final cacheKey = 'transfer_$pixelRatio';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    const double logicalSize = 22.0;
    final int px = (logicalSize * pixelRatio).round();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, px.toDouble(), px.toDouble()));
    final center = Offset(px / 2, px / 2);

    // 1. Drop shadow
    final shadowPaint = Paint()
      ..color = Colors.black38
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.5 * pixelRatio);
    canvas.drawCircle(center.translate(0, 1.2 * pixelRatio), 9.5 * pixelRatio, shadowPaint);

    // 2. Deep Navy casing
    final navyPaint = Paint()
      ..color = AppColors.brandNavy
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 9.5 * pixelRatio, navyPaint);

    // 3. White separator ring
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 7.2 * pixelRatio, whitePaint);

    // 4. Transit Sky Blue core
    final tealPaint = Paint()
      ..color = AppColors.brandBlue
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 5.0 * pixelRatio, tealPaint);

    // 5. White center pip
    final centerPipPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 2.0 * pixelRatio, centerPipPaint);

    final descriptor = await _finalizeBitmap(recorder, px, px, pixelRatio);
    _cache[cacheKey] = descriptor;
    return descriptor;
  }

  /// General Location Pin Marker (e.g. for LocationPickerScreen or Points of Interest)
  static Future<BitmapDescriptor> getLocationPinMarker({
    Color color = const Color(0xFFE53935),
    double pixelRatio = 3.0,
  }) async {
    return getDestinationMarker(color: color, pixelRatio: pixelRatio);
  }

  /// The rider's arrow on the trip map, about the size of Google Maps' blue
  /// navigation arrow: a bold arrowhead in the brand blue with a white
  /// outline and a soft shadow, so it reads on the dark map style as well as
  /// the light one. It points UP; the map marker turns it (flat, so it lies
  /// on the street and turns with the map).
  ///
  /// It replaced a 24 dp dot with a small white chevron inside, which
  /// riders lost on the map at a walk.
  static Future<BitmapDescriptor> getUserPuckMarker({
    Color color = AppColors.primaryTeal,
    double pixelRatio = 3.0,
  }) async {
    final cacheKey = 'user_puck_arrow_${color.toARGB32()}_$pixelRatio';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    final int px = (userPuckSize * pixelRatio).round();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, px.toDouble(), px.toDouble()));
    final arrow = navArrowPath(pixelRatio).shift(Offset(px / 2, px / 2));

    // 1. Soft shadow, a little below, as if the arrow sat just above the map.
    canvas.drawPath(
      arrow.shift(Offset(0, 1.5 * pixelRatio)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.38)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3.5 * pixelRatio),
    );

    // 2. White outline: a wide white stroke under the fill shows as a rim
    // outside it.
    canvas.drawPath(
      arrow,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * userPuckOutline * pixelRatio
        ..strokeJoin = StrokeJoin.round,
    );

    // 3. The arrow, its rounded corners from a thin stroke of its own colour.
    canvas.drawPath(arrow, Paint()..color = color);
    canvas.drawPath(
      arrow,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 * pixelRatio
        ..strokeJoin = StrokeJoin.round,
    );

    final descriptor = await _finalizeBitmap(recorder, px, px, pixelRatio);
    _cache[cacheKey] = descriptor;
    return descriptor;
  }

  /// The arrow's bitmap, in dp: the arrow with its outline and shadow.
  static const double userPuckSize = 64;

  /// The arrow itself, tip to tail and side to side, in dp.
  static const double userPuckArrowLength = 42;
  static const double userPuckArrowWidth = 34;

  /// Its white outline, in dp.
  static const double userPuckOutline = 3.5;

  /// The arrowhead pointing up, centred on (0, 0), at [scale] pixels per
  /// dp: a tip, two back corners and a notch between them. Centred on its
  /// box, so it turns about its middle without wobbling.
  @visibleForTesting
  static Path navArrowPath(double scale) {
    const halfL = userPuckArrowLength / 2, halfW = userPuckArrowWidth / 2;
    return Path()
      ..moveTo(0, -halfL * scale) // tip
      ..lineTo(halfW * scale, halfL * scale) // right back corner
      ..lineTo(0, halfL * 0.45 * scale) // notch
      ..lineTo(-halfW * scale, halfL * scale) // left back corner
      ..close();
  }

  // --- Internal Helpers ---

  static Path _getTeardropPath(
    Offset groundAnchor,
    Offset bulbCenter,
    double bulbRadius,
    double pinHeight,
  ) {
    final path = Path();
    path.moveTo(groundAnchor.dx, groundAnchor.dy);
    path.cubicTo(
      groundAnchor.dx - bulbRadius * 0.45,
      groundAnchor.dy - pinHeight * 0.45,
      bulbCenter.dx - bulbRadius,
      bulbCenter.dy + bulbRadius * 0.7,
      bulbCenter.dx - bulbRadius,
      bulbCenter.dy,
    );
    path.arcToPoint(
      Offset(bulbCenter.dx + bulbRadius, bulbCenter.dy),
      radius: Radius.circular(bulbRadius),
      clockwise: true,
    );
    path.cubicTo(
      bulbCenter.dx + bulbRadius,
      bulbCenter.dy + bulbRadius * 0.7,
      groundAnchor.dx + bulbRadius * 0.45,
      groundAnchor.dy - pinHeight * 0.45,
      groundAnchor.dx,
      groundAnchor.dy,
    );
    path.close();
    return path;
  }

  static Future<BitmapDescriptor> _finalizeBitmap(
    ui.PictureRecorder recorder,
    int width,
    int height,
    double pixelRatio,
  ) async {
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Failed to generate marker image byte data.');
    }
    return BitmapDescriptor.bytes(
      byteData.buffer.asUint8List(),
      imagePixelRatio: pixelRatio,
    );
  }
}
