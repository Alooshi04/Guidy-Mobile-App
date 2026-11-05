import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show BytesMapBitmap;
import 'package:guidy_app/services/map_marker_service.dart';
import 'package:guidy_app/theme/app_theme.dart';
import 'package:guidy_app/utils/nav_math.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Compass Heading Math & Smoothing Tests', () {
    test('lerpHeading smoothly interpolates across the 0/360 boundary', () {
      // Interpolate halfway between 350 and 10 (shortest path through 0/360)
      final mid = NavMath.lerpHeading(350, 10, 0.5);
      expect(mid, closeTo(0.0, 0.001));

      // Interpolate from 10 to 350 halfway
      final midReverse = NavMath.lerpHeading(10, 350, 0.5);
      expect(midReverse, closeTo(0.0, 0.001));

      // Step from 358 towards 2 with alpha 0.25 (total span 4 degrees)
      final step = NavMath.lerpHeading(358, 2, 0.25);
      expect(step, closeTo(359.0, 0.001));
    });

    test('exponential smoothing filter converges smoothly without overshoot', () {
      double current = 0.0;
      const double target = 90.0;
      const double alpha = 0.28;

      // Simulate 10 frames of 60fps updates
      for (int i = 0; i < 10; i++) {
        current = NavMath.lerpHeading(current, target, alpha);
      }

      // After 10 frames with alpha=0.28, current should be > 80 degrees and <= 90
      expect(current, greaterThan(80.0));
      expect(current, lessThanOrEqualTo(90.0));
    });
  });

  group('Uber-Style User Puck Marker Generation', () {
    test('MapMarkerService.getUserPuckMarker generates high-DPI retina bitmap', () async {
      final markerDescriptor = await MapMarkerService.getUserPuckMarker(
        pixelRatio: 3.0,
      );
      expect(markerDescriptor, isNotNull);
    });
  });

  // Beta report: "make the arrow look like Google's: big and clear".
  group('the rider\'s arrow', () {
    test('about the size of Google Maps\' navigation arrow, centred so it turns in place', () {
      final b = MapMarkerService.navArrowPath(1).getBounds();
      expect(b.height, greaterThanOrEqualTo(40));
      expect(b.width, greaterThanOrEqualTo(32));
      expect(b.center.dx, closeTo(0, 0.01));
      expect(b.center.dy, closeTo(0, 0.01));
    });

    test('drawn in the brand blue with a white outline, all inside its bitmap', () async {
      final icon = await MapMarkerService.getUserPuckMarker(pixelRatio: 3.0) as BytesMapBitmap;
      expect(icon.imagePixelRatio, 3.0);
      final codec = await ui.instantiateImageCodec(icon.byteData);
      final image = (await codec.getNextFrame()).image;
      expect([image.width, image.height], [192, 192], reason: '64 dp at 3x');
      final px = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      var white = 0, blue = 0, edge = 0;
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          final i = (y * image.width + x) * 4;
          final r = px.getUint8(i), g = px.getUint8(i + 1), bl = px.getUint8(i + 2), a = px.getUint8(i + 3);
          if (a > 250 && r > 245 && g > 245 && bl > 245) white++;
          const brand = AppColors.primaryTeal;
          if (a > 250 && (r - brand.r * 255).abs() < 4 && (bl - brand.b * 255).abs() < 4) blue++;
          final onEdge = x == 0 || y == 0 || x == image.width - 1 || y == image.height - 1;
          if (onEdge && a > 40) edge++;
        }
      }
      // The arrow covers about 42 x 34 dp at 3x; its rim is 3.5 dp wide.
      expect(blue, greaterThan(5000));
      expect(white, greaterThan(2000));
      expect(edge, 0, reason: 'nothing cut off at the bitmap\'s edge');
    });
  });
}
