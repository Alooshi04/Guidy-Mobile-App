import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/RailNetworkMapScreen.dart';

import 'support/fake_google_maps_platform.dart';

// Crashlytics, 1.0.2: "GoogleMapController for map ID 41 was used after the
// associated GoogleMap widget had already been disposed", from
// _RailNetworkMapScreenState. Opening the Station Directory tab threw the
// map tab away; "View on Real Map" switched back and moved the camera of
// that discarded map.

void main() {
  late FakeGoogleMapsPlatform maps;

  setUp(() {
    maps = FakeGoogleMapsPlatform();
    GoogleMapsFlutterPlatform.instance = maps;
  });

  testWidgets('"View on Real Map" from the directory centres the map on that station', (tester) async {
    // A typical phone.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: RailNetworkMapScreen(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Station Directory'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, 'Sadat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View on Real Map'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      maps.cameraUpdates[maps.lastMapId]!.last.toJson(),
      CameraUpdate.newLatLngZoom(const LatLng(30.04392, 31.23566), 14.5).toJson(),
    );
  });
}
