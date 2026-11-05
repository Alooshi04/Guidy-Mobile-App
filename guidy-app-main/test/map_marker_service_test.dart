import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/services/map_marker_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MapMarkerService Tests', () {
    setUp(() {
      MapMarkerService.clearCache();
    });

    test('getOriginMarker generates valid descriptor and caches it', () async {
      final marker1 = await MapMarkerService.getOriginMarker();
      expect(marker1, isNotNull);

      // Verify cached hit
      final marker2 = await MapMarkerService.getOriginMarker();
      expect(identical(marker1, marker2), isTrue);
    });

    test('getDestinationMarker generates valid descriptor and caches it', () async {
      final marker1 = await MapMarkerService.getDestinationMarker();
      expect(marker1, isNotNull);

      final marker2 = await MapMarkerService.getDestinationMarker();
      expect(identical(marker1, marker2), isTrue);

      final markerCustom = await MapMarkerService.getDestinationMarker(color: Colors.purple);
      expect(markerCustom, isNotNull);
      expect(identical(marker1, markerCustom), isFalse);
    });

    test('getStationStopMarker generates normal and selected markers with caching', () async {
      final normal = await MapMarkerService.getStationStopMarker(color: Colors.blue, isSelected: false);
      final selected = await MapMarkerService.getStationStopMarker(color: Colors.blue, isSelected: true);
      expect(normal, isNotNull);
      expect(selected, isNotNull);
      expect(identical(normal, selected), isFalse);

      final normalCached = await MapMarkerService.getStationStopMarker(color: Colors.blue, isSelected: false);
      expect(identical(normal, normalCached), isTrue);
    });

    test('getTransferMarker generates valid descriptor and caches it', () async {
      final transfer1 = await MapMarkerService.getTransferMarker();
      expect(transfer1, isNotNull);

      final transfer2 = await MapMarkerService.getTransferMarker();
      expect(identical(transfer1, transfer2), isTrue);
    });

    test('getLocationPinMarker generates valid descriptor', () async {
      final pin = await MapMarkerService.getLocationPinMarker();
      expect(pin, isNotNull);
    });

    test('Anchors are correctly configured for cartography standards', () {
      expect(MapMarkerService.centerAnchor.dx, 0.5);
      expect(MapMarkerService.centerAnchor.dy, 0.5);
      expect(MapMarkerService.pinAnchor.dx, 0.5);
      expect(MapMarkerService.pinAnchor.dy, greaterThan(0.9));
    });
  });
}
