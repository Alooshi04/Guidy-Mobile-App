import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/MapScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Pulled down to its lowest stop, the bottom sheet must still show the whole
// "Now" step card. Its height was a fixed 24% of the screen, which cut the
// card off on shorter phones (it ran under the ad banner).
Map<String, dynamic> _trip() => {
      'instructions': [
        {'action': 'walk_to_station', 'station': 'Masaken Zobbat Almaza', 'lat': 30.05, 'lon': 31.24, 'distance_m': 2287},
        {'action': 'board', 'station': 'Masaken Zobbat Almaza', 'route_id': 'R1', 'route_number': '66', 'vehicle_type': 'microbus', 'lat': 30.05, 'lon': 31.24},
        {'action': 'arrive', 'station': 'B', 'lat': 30.06, 'lon': 31.25},
      ],
      'option': {'type': 'Recommended', 'time': '50', 'fare_egp': 10},
      'segments': [],
    };

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final size in const [Size(360, 740), Size(393, 800), Size(411, 891)]) {
    testWidgets('collapsed sheet shows the whole step card at ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MapScreen(pathData: _trip()),
      ));
      await tester.pump(const Duration(milliseconds: 500));
      final l10n = AppLocalizations.of(tester.element(find.byType(MapScreen)));

      // Pull the sheet all the way down.
      await tester.fling(find.text(l10n.navNowLabel), const Offset(0, 900), 3000);
      await tester.pumpAndSettle();

      final card = find.ancestor(
        of: find.text(l10n.navNowLabel),
        matching: find.byWidgetPredicate((w) => w is Container && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).gradient != null),
      );
      expect(card, findsOneWidget);
      final rect = tester.getRect(card);
      expect(rect.bottom, lessThanOrEqualTo(size.height), reason: 'card bottom ${rect.bottom} is below the screen/ad edge ${size.height}');
    });
  }
}
