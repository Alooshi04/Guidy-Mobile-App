import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Render proposed high-quality transit map markers with icons to preview', () async {
    const double pixelRatio = 3.0;
    const double canvasW = 600 * pixelRatio;
    const double canvasH = 340 * pixelRatio;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, canvasW, canvasH));

    // Fill background with realistic Google Maps light tone
    final bgPaint = Paint()..color = const Color(0xFFF1F3F4);
    canvas.drawRect(Rect.fromLTWH(0, 0, canvasW, canvasH), bgPaint);

    // Grid roads
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 18 * pixelRatio;
    canvas.drawLine(Offset(0, 90 * pixelRatio), Offset(canvasW, 90 * pixelRatio), roadPaint);
    canvas.drawLine(Offset(0, 240 * pixelRatio), Offset(canvasW, 240 * pixelRatio), roadPaint);
    canvas.drawLine(Offset(300 * pixelRatio, 0), Offset(300 * pixelRatio, canvasH), roadPaint);

    // Labels for the two rows
    _drawLabel(canvas, 'Option 1: Modern Minimalist Bullet & Teardrop (Citymapper/Apple Maps)', Offset(20 * pixelRatio, 22 * pixelRatio), pixelRatio);
    _drawLabel(canvas, 'Option 2: Mode-Identified Pins with Transit Icons (Google Maps 2026)', Offset(20 * pixelRatio, 172 * pixelRatio), pixelRatio);

    // --- ROW 1: Minimalist Bullets ---
    final routePaint1 = Paint()
      ..color = const Color(0xFF2DA3E3)
      ..strokeWidth = 8 * pixelRatio
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(70 * pixelRatio, 90 * pixelRatio), Offset(530 * pixelRatio, 90 * pixelRatio), routePaint1);

    _drawOriginBeacon(canvas, Offset(70 * pixelRatio, 90 * pixelRatio), pixelRatio);
    _drawStationStop(canvas, Offset(180 * pixelRatio, 90 * pixelRatio), const Color(0xFFE53935), pixelRatio);
    _drawTransferNode(canvas, Offset(300 * pixelRatio, 90 * pixelRatio), pixelRatio);
    _drawStationStop(canvas, Offset(420 * pixelRatio, 90 * pixelRatio), const Color(0xFF00ACC1), pixelRatio);
    _drawDestinationPin(canvas, Offset(530 * pixelRatio, 90 * pixelRatio), pixelRatio, hasFlagIcon: false);

    // --- ROW 2: With Mode Icons ---
    final routePaint2 = Paint()
      ..color = const Color(0xFF0B3D71)
      ..strokeWidth = 8 * pixelRatio
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(70 * pixelRatio, 240 * pixelRatio), Offset(530 * pixelRatio, 240 * pixelRatio), routePaint2);

    _drawOriginPinWithIcon(canvas, Offset(70 * pixelRatio, 240 * pixelRatio), pixelRatio);
    _drawStationPillWithIcon(canvas, Offset(180 * pixelRatio, 240 * pixelRatio), const Color(0xFFE53935), Icons.subway_rounded, pixelRatio);
    _drawTransferNodeWithIcon(canvas, Offset(300 * pixelRatio, 240 * pixelRatio), pixelRatio);
    _drawStationPillWithIcon(canvas, Offset(420 * pixelRatio, 240 * pixelRatio), const Color(0xFF00ACC1), Icons.directions_bus_rounded, pixelRatio);
    _drawDestinationPin(canvas, Offset(530 * pixelRatio, 240 * pixelRatio), pixelRatio, hasFlagIcon: true);

    final picture = recorder.endRecording();
    final img = await picture.toImage(canvasW.toInt(), canvasH.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    // Was a hardcoded absolute path onto one specific Windows machine's
    // Antigravity data folder -- fails with PathNotFoundException anywhere
    // else, CI included, since there is no assertion in this "test" to
    // catch: it only ever existed to render a PNG for a human to look at
    // and compare two marker-design options. build/ is gitignored and
    // always exists relative to the project root, so this now writes
    // somewhere that exists on every machine without leaving anything to
    // accidentally commit.
    final outDir = Directory('build/marker_previews')..createSync(recursive: true);
    final file = File('${outDir.path}/markers_comparison.png');
    await file.writeAsBytes(byteData!.buffer.asUint8List());
    debugPrint('Comparison rendered: ${file.path}');
  });
}

void _drawLabel(Canvas canvas, String text, Offset offset, double pr) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: const Color(0xFF37474F),
        fontSize: 13 * pr,
        fontWeight: FontWeight.bold,
      ),
    ),
    textDirection: TextDirection.ltr,
  );
  tp.layout();
  tp.paint(canvas, offset);
}

void _drawOriginBeacon(Canvas canvas, Offset center, double pr) {
  canvas.drawCircle(center, 22 * pr, Paint()..color = const Color(0xFF2ECC71).withValues(alpha: 0.22));
  canvas.drawCircle(center.translate(0, 2 * pr), 13 * pr, Paint()..color = Colors.black38..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 * pr));
  canvas.drawCircle(center, 13 * pr, Paint()..color = Colors.white);
  canvas.drawCircle(center, 9.5 * pr, Paint()..color = const Color(0xFF2ECC71));
  canvas.drawCircle(center, 3.5 * pr, Paint()..color = Colors.white);
}

void _drawOriginPinWithIcon(Canvas canvas, Offset groundAnchor, double pr) {
  final pinHeight = 38 * pr;
  final bulbRadius = 13 * pr;
  final bulbCenter = Offset(groundAnchor.dx, groundAnchor.dy - pinHeight + bulbRadius);

  canvas.drawOval(
    Rect.fromCenter(center: groundAnchor.translate(0, 1.5 * pr), width: 14 * pr, height: 6 * pr),
    Paint()..color = Colors.black26..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * pr),
  );

  final path = _getTeardropPath(groundAnchor, bulbCenter, bulbRadius, pinHeight);
  canvas.drawPath(path, Paint()..color = const Color(0xFF2ECC71));
  canvas.drawPath(path, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2 * pr);

  canvas.drawCircle(bulbCenter, 7 * pr, Paint()..color = Colors.white);
  _drawIcon(canvas, Icons.directions_walk_rounded, bulbCenter, 10 * pr, const Color(0xFF2ECC71));
}

void _drawStationStop(Canvas canvas, Offset center, Color lineColor, double pr) {
  canvas.drawCircle(center.translate(0, 1.5 * pr), 10 * pr, Paint()..color = Colors.black38..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * pr));
  canvas.drawCircle(center, 10 * pr, Paint()..color = Colors.white);
  canvas.drawCircle(center, 7.5 * pr, Paint()..color = lineColor);
  canvas.drawCircle(center, 3 * pr, Paint()..color = Colors.white);
}

void _drawStationPillWithIcon(Canvas canvas, Offset center, Color lineColor, IconData icon, double pr) {
  final radius = 13 * pr;
  canvas.drawCircle(center.translate(0, 2 * pr), radius, Paint()..color = Colors.black38..maskFilter = MaskFilter.blur(BlurStyle.normal, 3.5 * pr));
  canvas.drawCircle(center, radius, Paint()..color = Colors.white);
  canvas.drawCircle(center, radius - (2 * pr), Paint()..color = lineColor);
  _drawIcon(canvas, icon, center, 13 * pr, Colors.white);
}

void _drawTransferNode(Canvas canvas, Offset center, double pr) {
  canvas.drawCircle(center.translate(0, 1.5 * pr), 12 * pr, Paint()..color = Colors.black38..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * pr));
  canvas.drawCircle(center, 12 * pr, Paint()..color = const Color(0xFF0B3D71));
  canvas.drawCircle(center, 9 * pr, Paint()..color = Colors.white);
  canvas.drawCircle(center, 6.5 * pr, Paint()..color = const Color(0xFF2DA3E3));
  canvas.drawCircle(center, 2.5 * pr, Paint()..color = Colors.white);
}

void _drawTransferNodeWithIcon(Canvas canvas, Offset center, double pr) {
  final radius = 14 * pr;
  canvas.drawCircle(center.translate(0, 2 * pr), radius, Paint()..color = Colors.black38..maskFilter = MaskFilter.blur(BlurStyle.normal, 3.5 * pr));
  canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF0B3D71));
  canvas.drawCircle(center, radius - (2.5 * pr), Paint()..color = Colors.white);
  _drawIcon(canvas, Icons.sync_alt_rounded, center, 13 * pr, const Color(0xFF0B3D71));
}

void _drawDestinationPin(Canvas canvas, Offset groundAnchor, double pr, {required bool hasFlagIcon}) {
  final pinHeight = 40 * pr;
  final bulbRadius = 14 * pr;
  final bulbCenter = Offset(groundAnchor.dx, groundAnchor.dy - pinHeight + bulbRadius);

  canvas.drawOval(
    Rect.fromCenter(center: groundAnchor.translate(0, 1.5 * pr), width: 16 * pr, height: 7 * pr),
    Paint()..color = Colors.black26..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * pr),
  );

  final path = _getTeardropPath(groundAnchor, bulbCenter, bulbRadius, pinHeight);
  final gradientPaint = Paint()
    ..shader = ui.Gradient.linear(
      Offset(bulbCenter.dx, bulbCenter.dy - bulbRadius),
      groundAnchor,
      [const Color(0xFFE53935), const Color(0xFFC62828)],
    );
  canvas.drawPath(path, gradientPaint);

  final borderPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2 * pr;
  canvas.drawPath(path, borderPaint);

  canvas.drawCircle(bulbCenter, 7 * pr, Paint()..color = Colors.white);

  if (hasFlagIcon) {
    _drawIcon(canvas, Icons.flag_rounded, bulbCenter, 10 * pr, const Color(0xFFE53935));
  } else {
    canvas.drawCircle(bulbCenter, 3.5 * pr, Paint()..color = const Color(0xFFE53935));
  }
}

Path _getTeardropPath(Offset groundAnchor, Offset bulbCenter, double bulbRadius, double pinHeight) {
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

void _drawIcon(Canvas canvas, IconData icon, Offset center, double size, Color color) {
  final tp = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: size,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: color,
      ),
    ),
    textDirection: TextDirection.ltr,
  );
  tp.layout();
  tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
}
