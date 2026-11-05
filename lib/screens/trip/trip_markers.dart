import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../services/instruction_formatter.dart';
import '../../services/map_marker_service.dart';

/// The trip's marker icons, each null until it has loaded.
typedef TripMarkerIcons = ({
  BitmapDescriptor? start,
  BitmapDescriptor? end,
  BitmapDescriptor? transfer,
  BitmapDescriptor? station,
});

/// The trip's fixed markers: start, destination, transfers, and the named
/// stops in between. Each kind is left out until its icon has loaded.
Set<Marker> tripMarkers({
  required List<LatLng> route,
  required List<dynamic> instructions,
  required String destinationTitle,
  required bool isArabic,
  required TripMarkerIcons icons,
}) {
  final markers = <Marker>{};
  if (route.isEmpty) return markers;

  // Start Marker (Origin Beacon)
  if (icons.start != null) {
    markers.add(
      Marker(
        markerId: const MarkerId('origin_pin'),
        position: route.first,
        icon: icons.start!,
        anchor: MapMarkerService.centerAnchor,
        zIndexInt: 10,
        infoWindow: const InfoWindow(title: 'نقطة الانطلاق / Start'),
      ),
    );
  }

  // Destination Marker (Precision Teardrop Pin)
  if (icons.end != null && route.length > 1) {
    markers.add(
      Marker(
        markerId: const MarkerId('destination_pin'),
        position: route.last,
        icon: icons.end!,
        anchor: MapMarkerService.pinAnchor,
        zIndexInt: 10,
        infoWindow: InfoWindow(title: destinationTitle.isNotEmpty ? destinationTitle : 'الوصول / Destination'),
      ),
    );
  }

  // Transfer and key station stop markers from instructions
  for (int i = 0; i < instructions.length; i++) {
    final step = instructions[i];
    if (step is! Map) continue;
    final lat = step['lat'], lon = step['lon'];
    if (lat is! num || lon is! num) continue;
    final pos = LatLng(lat.toDouble(), lon.toDouble());
    final action = step['action'];
    final station = (InstructionFormatter.localized(step, 'station', isAr: isArabic) ?? '');

    if (action == 'transfer' && icons.transfer != null) {
      markers.add(
        Marker(
          markerId: MarkerId('transfer_$i'),
          position: pos,
          icon: icons.transfer!,
          anchor: MapMarkerService.centerAnchor,
          zIndexInt: 8,
          infoWindow: InfoWindow(title: 'محطة تحويل / Transfer', snippet: station),
        ),
      );
    } else if (station.isNotEmpty && icons.station != null && i > 0 && i < instructions.length - 1) {
      markers.add(
        Marker(
          markerId: MarkerId('station_$i'),
          position: pos,
          icon: icons.station!,
          anchor: MapMarkerService.centerAnchor,
          zIndexInt: 5,
          infoWindow: InfoWindow(title: station),
        ),
      );
    }
  }
  return markers;
}
