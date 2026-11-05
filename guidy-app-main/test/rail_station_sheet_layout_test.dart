import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/RailNetworkMapScreen.dart';

import 'support/fake_google_maps_platform.dart';

// The station sheet from the directory was capped at 9/16 of the screen, so
// on a short phone its bottom was cut off: "A RenderFlex overflowed by 32
// pixels on the bottom" at the default 800x600 test window.

void main() {
  late FakeGoogleMapsPlatform maps;

  setUp(() {
    maps = FakeGoogleMapsPlatform();
    GoogleMapsFlutterPlatform.instance = maps;
  });

  Future<void> openSadatSheet(WidgetTester tester, Size physicalSize) async {
    tester.view.physicalSize = physicalSize;
    tester.view.devicePixelRatio = 2.0;
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
  }

  testWidgets('on a 360x640 phone the station sheet fits and "View on Real Map" works', (tester) async {
    await openSadatSheet(tester, const Size(720, 1280));

    expect(tester.takeException(), isNull);
    final viewOnMap = find.text('View on Real Map');
    expect(viewOnMap.hitTestable(), findsOneWidget);
    expect(find.text('Report an issue with this station').hitTestable(), findsOneWidget);

    await tester.tap(viewOnMap);
    await tester.pumpAndSettle();
    expect(
      maps.cameraUpdates[maps.lastMapId]!.last.toJson(),
      CameraUpdate.newLatLngZoom(const LatLng(30.04392, 31.23566), 14.5).toJson(),
    );
  });

  testWidgets('on a phone held sideways the station sheet scrolls to its last action', (tester) async {
    await openSadatSheet(tester, const Size(1280, 720));

    expect(tester.takeException(), isNull);
    final report = find.text('Report an issue with this station');
    await tester.ensureVisible(report);
    await tester.pumpAndSettle();
    expect(report.hitTestable(), findsOneWidget);
  });
}
