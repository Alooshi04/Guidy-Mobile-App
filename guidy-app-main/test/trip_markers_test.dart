import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:guidy_app/screens/trip/trip_markers.dart';

const _steps = [
  {'action': 'walk_to_station', 'station': 'Ramses', 'lat': 30.06, 'lon': 31.24},
  {'action': 'board', 'station': 'Ramses', 'lat': 30.06, 'lon': 31.24},
  {'action': 'transfer', 'station': 'Sadat', 'lat': 30.044, 'lon': 31.235},
  {'action': 'board', 'station': 'Sadat', 'station_ar': 'السادات', 'lat': 30.044, 'lon': 31.235},
  {'action': 'arrive', 'station': 'Tahrir', 'lat': 30.03, 'lon': 31.23},
];

Set<String> ids(Set<Marker> m) => {for (final x in m) x.markerId.value};

void main() {
  const icon = BitmapDescriptor.defaultMarker;
  const route = [LatLng(30.06, 31.24), LatLng(30.03, 31.23)];

  test('start, destination, transfers and named stops in between', () {
    final m = tripMarkers(
      route: route,
      instructions: _steps,
      destinationTitle: 'Tahrir',
      isArabic: false,
      icons: (start: icon, end: icon, transfer: icon, station: icon),
    );
    expect(ids(m), {'origin_pin', 'destination_pin', 'station_1', 'transfer_2', 'station_3'});
    expect(m.firstWhere((x) => x.markerId.value == 'destination_pin').infoWindow.title, 'Tahrir');
  });

  test('a kind whose icon has not loaded is left out', () {
    final m = tripMarkers(
      route: route,
      instructions: _steps,
      destinationTitle: '',
      isArabic: false,
      icons: (start: icon, end: null, transfer: null, station: null),
    );
    expect(ids(m), {'origin_pin'});
  });

  test('station names in Arabic when the app is', () {
    final m = tripMarkers(
      route: route,
      instructions: _steps,
      destinationTitle: '',
      isArabic: true,
      icons: (start: null, end: null, transfer: null, station: icon),
    );
    expect(m.firstWhere((x) => x.markerId.value == 'station_3').infoWindow.title, 'السادات');
  });

  test('no route: no markers', () {
    expect(
      tripMarkers(
          route: const [], instructions: _steps, destinationTitle: '', isArabic: false,
          icons: (start: icon, end: icon, transfer: icon, station: icon)),
      isEmpty,
    );
  });
}
