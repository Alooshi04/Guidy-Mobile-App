import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

/// Stands in for the native Google Maps plugin in widget tests, so a
/// [GoogleMap] actually reports in through `onMapCreated` and a test can
/// see which map every camera move went to.
///
/// One thing it does on purpose the way a phone does: the native view
/// for a map is created [viewCreationDelay] *after* the frame that built
/// the widget, so `onMapCreated` arrives frames later. That gap is
/// exactly where a screen can still be holding the controller of a map
/// it has already thrown away. `tester.pump(viewCreationDelay)` lets
/// every map built so far report in.
///
/// Install with `GoogleMapsFlutterPlatform.instance = FakeGoogleMapsPlatform();`
class FakeGoogleMapsPlatform extends GoogleMapsFlutterPlatform {
  static const Duration viewCreationDelay = Duration(milliseconds: 50);

  /// IDs of every map built so far, oldest first.
  final List<int> createdMapIds = [];

  /// Every camera move each map was asked for, by map ID, in order.
  final Map<int, List<CameraUpdate>> cameraUpdates = {};

  int get lastMapId => createdMapIds.last;

  @override
  Widget buildViewWithConfiguration(
    int creationId,
    PlatformViewCreatedCallback onPlatformViewCreated, {
    required MapWidgetConfiguration widgetConfiguration,
    MapObjects mapObjects = const MapObjects(),
    MapConfiguration mapConfiguration = const MapConfiguration(),
  }) {
    if (!createdMapIds.contains(creationId)) {
      createdMapIds.add(creationId);
      cameraUpdates[creationId] = [];
      Timer(viewCreationDelay, () => onPlatformViewCreated(creationId));
    }
    return const SizedBox.expand();
  }

  @override
  Future<void> animateCamera(CameraUpdate cameraUpdate, {required int mapId}) async {
    cameraUpdates[mapId]?.add(cameraUpdate);
  }

  @override
  Future<void> animateCameraWithConfiguration(
    CameraUpdate cameraUpdate,
    CameraUpdateAnimationConfiguration configuration, {
    required int mapId,
  }) async {
    cameraUpdates[mapId]?.add(cameraUpdate);
  }

  @override
  Future<void> moveCamera(CameraUpdate cameraUpdate, {required int mapId}) async {
    cameraUpdates[mapId]?.add(cameraUpdate);
  }

  @override
  Future<void> init(int mapId) async {}

  @override
  void dispose({required int mapId}) {}

  @override
  Future<void> updateMapConfiguration(MapConfiguration update, {required int mapId}) async {}

  @override
  Future<void> updateMarkers(MarkerUpdates markerUpdates, {required int mapId}) async {}

  @override
  Future<void> updatePolygons(PolygonUpdates polygonUpdates, {required int mapId}) async {}

  @override
  Future<void> updatePolylines(PolylineUpdates polylineUpdates, {required int mapId}) async {}

  @override
  Future<void> updateCircles(CircleUpdates circleUpdates, {required int mapId}) async {}

  @override
  Future<void> updateHeatmaps(HeatmapUpdates heatmapUpdates, {required int mapId}) async {}

  @override
  Future<void> updateTileOverlays({required Set<TileOverlay> newTileOverlays, required int mapId}) async {}

  @override
  Future<void> updateClusterManagers(ClusterManagerUpdates clusterManagerUpdates, {required int mapId}) async {}

  @override
  Future<void> updateGroundOverlays(GroundOverlayUpdates groundOverlayUpdates, {required int mapId}) async {}

  @override
  Future<void> clearTileCache(TileOverlayId tileOverlayId, {required int mapId}) async {}

  @override
  Future<void> setMapStyle(String? mapStyle, {required int mapId}) async {}

  @override
  Future<String?> getStyleError({required int mapId}) async => null;

  @override
  Future<LatLngBounds> getVisibleRegion({required int mapId}) async =>
      LatLngBounds(southwest: const LatLng(0, 0), northeast: const LatLng(0, 0));

  @override
  Future<ScreenCoordinate> getScreenCoordinate(LatLng latLng, {required int mapId}) async =>
      const ScreenCoordinate(x: 0, y: 0);

  @override
  Future<LatLng> getLatLng(ScreenCoordinate screenCoordinate, {required int mapId}) async => const LatLng(0, 0);

  @override
  Future<void> showMarkerInfoWindow(MarkerId markerId, {required int mapId}) async {}

  @override
  Future<void> hideMarkerInfoWindow(MarkerId markerId, {required int mapId}) async {}

  @override
  Future<bool> isMarkerInfoWindowShown(MarkerId markerId, {required int mapId}) async => false;

  @override
  Future<double> getZoomLevel({required int mapId}) async => 0;

  @override
  Future<Uint8List?> takeSnapshot({required int mapId}) async => null;

  @override
  Stream<CameraMoveStartedEvent> onCameraMoveStarted({required int mapId}) => const Stream.empty();

  @override
  Stream<CameraMoveEvent> onCameraMove({required int mapId}) => const Stream.empty();

  @override
  Stream<CameraIdleEvent> onCameraIdle({required int mapId}) => const Stream.empty();

  @override
  Stream<MarkerTapEvent> onMarkerTap({required int mapId}) => const Stream.empty();

  @override
  Stream<InfoWindowTapEvent> onInfoWindowTap({required int mapId}) => const Stream.empty();

  @override
  Stream<MarkerDragStartEvent> onMarkerDragStart({required int mapId}) => const Stream.empty();

  @override
  Stream<MarkerDragEvent> onMarkerDrag({required int mapId}) => const Stream.empty();

  @override
  Stream<MarkerDragEndEvent> onMarkerDragEnd({required int mapId}) => const Stream.empty();

  @override
  Stream<PolylineTapEvent> onPolylineTap({required int mapId}) => const Stream.empty();

  @override
  Stream<PolygonTapEvent> onPolygonTap({required int mapId}) => const Stream.empty();

  @override
  Stream<CircleTapEvent> onCircleTap({required int mapId}) => const Stream.empty();

  @override
  Stream<MapTapEvent> onTap({required int mapId}) => const Stream.empty();

  @override
  Stream<MapLongPressEvent> onLongPress({required int mapId}) => const Stream.empty();

  @override
  Stream<ClusterTapEvent> onClusterTap({required int mapId}) => const Stream.empty();

  @override
  Stream<GroundOverlayTapEvent> onGroundOverlayTap({required int mapId}) => const Stream.empty();
}
