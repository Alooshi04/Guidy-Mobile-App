import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/MapScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The compass, re-centre and stop-alarm buttons continue the tool rail's
// column of icons. They used to hang from the rail's START edge while the
// rail hugs the END edge, and came in two sizes, so they zig-zagged.
Map<String, dynamic> _trip() => {
      'instructions': [
        {'action': 'walk_to_station', 'station': 'A', 'lat': 30.05, 'lon': 31.24, 'distance_m': 200},
        {'action': 'board', 'station': 'A', 'route_id': 'R1', 'route_number': '66', 'vehicle_type': 'minibus', 'lat': 30.05, 'lon': 31.24},
        {'action': 'arrive', 'station': 'B', 'lat': 30.06, 'lon': 31.25},
      ],
      'option': {'type': 'Recommended', 'time': '30', 'fare_egp': 10},
      'segments': [],
    };

Future<AppLocalizations> _open(WidgetTester tester, Locale locale) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MapScreen(pathData: _trip()),
  ));
  await tester.pump(const Duration(milliseconds: 500));
  return AppLocalizations.of(tester.element(find.byType(MapScreen)));
}

Rect _button(WidgetTester tester, String tooltip) =>
    tester.getRect(find.ancestor(of: find.byTooltip(tooltip), matching: find.byType(Material)).first);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets('compass, re-centre and stop alarm line up under the rail (${locale.languageCode})', (tester) async {
      final l10n = await _open(tester, locale);
      final menu = tester.getRect(find.byKey(const ValueKey('guidy-tool-rail-menu')));
      final compass = _button(tester, l10n.navCompassTooltip);
      final recenter = _button(tester, l10n.centerOnMyLocationTooltip);
      final alarm = _button(tester, l10n.navStopAlarmOn);

      for (final b in [compass, recenter, alarm]) {
        expect(b.center.dx, closeTo(menu.center.dx, 0.5));
        expect(b.size, compass.size);
      }
      expect(compass.width, compass.height);
    });
  }
}
