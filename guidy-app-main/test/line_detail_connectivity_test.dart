import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:guidy_app/screens/LineDetailScreen.dart';

void main() {
  group('LineDetailScreen Coordinate & Endpoint Connectivity Tests', () {
    test('extractCoords guarantees line start connects to origin stop', () {
      final direction = {
        'stops': [
          {'name': 'Origin Stop', 'lat': 30.0500, 'lon': 31.2300},
          {'name': 'Intermediate Stop', 'lat': 30.0600, 'lon': 31.2400},
          {'name': 'Destination Stop', 'lat': 30.0700, 'lon': 31.2500},
        ],
        'points': [
          {'lat': 30.0520, 'lon': 31.2310}, // Gap from origin!
          {'lat': 30.0600, 'lon': 31.2400},
          {'lat': 30.0680, 'lon': 31.2490}, // Gap from destination!
        ],
      };

      final coords = LineDetailScreen.extractCoords(direction);

      expect(coords.length, 5);
      // Origin stop must be first point
      expect(coords.first.latitude, 30.0500);
      expect(coords.first.longitude, 31.2300);
      // Destination stop must be last point
      expect(coords.last.latitude, 30.0700);
      expect(coords.last.longitude, 31.2500);
    });

    test('extractCoords does not duplicate endpoints if already exact', () {
      final direction = {
        'stops': [
          {'name': 'Origin', 'lat': 30.0500, 'lon': 31.2300},
          {'name': 'Destination', 'lat': 30.0700, 'lon': 31.2500},
        ],
        'points': [
          {'lat': 30.0500, 'lon': 31.2300},
          {'lat': 30.0600, 'lon': 31.2400},
          {'lat': 30.0700, 'lon': 31.2500},
        ],
      };

      final coords = LineDetailScreen.extractCoords(direction);
      expect(coords.length, 3);
      expect(coords[0], const LatLng(30.0500, 31.2300));
      expect(coords[1], const LatLng(30.0600, 31.2400));
      expect(coords[2], const LatLng(30.0700, 31.2500));
    });

    test('extractCoords falls back cleanly to stops if points are empty', () {
      final direction = {
        'stops': [
          {'name': 'Stop 1', 'lat': 30.01, 'lon': 31.01},
          {'name': 'Stop 2', 'lat': 30.02, 'lon': 31.02},
          {'name': 'Stop 3', 'lat': 30.03, 'lon': 31.03},
        ],
        'points': <dynamic>[],
      };

      final coords = LineDetailScreen.extractCoords(direction);
      expect(coords.length, 3);
      expect(coords[0], const LatLng(30.01, 31.01));
      expect(coords[1], const LatLng(30.02, 31.02));
      expect(coords[2], const LatLng(30.03, 31.03));
    });
  });
}
