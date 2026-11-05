import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/LocationSearchScreen.dart';
import 'package:guidy_app/screens/MapScreen.dart';
import 'package:guidy_app/screens/RouteOptionsScreen.dart';
import 'package:guidy_app/screens/TripRecapScreen.dart';
import 'package:guidy_app/widgets/trip/trip_now_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Long start and destination names (a pinned street with its district, a
// mall gate) used to be cut off: the route options squeezed "A to B" into a
// two-line subtitle that overflowed its fixed-height header, so the
// destination never showed at all, and the trip overview cut each name to
// one line.
const _longA = 'Mostafa El Nahas Street, Seventh District, Nasr City, Cairo Governorate';
const _longB = 'Cairo Festival City Mall Food Court Entrance Gate 3, New Cairo';

Widget _app(Widget home, Locale locale) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
}

/// The Text showing [name] lets it run onto a second line.
void _shownOnTwoLines(WidgetTester tester, String name) {
  final text = tester.widget<Text>(find.text(name));
  // An ellipsis with no maxLines still cuts the text after one line.
  final lines = text.maxLines ?? (text.overflow == TextOverflow.ellipsis ? 1 : null);
  expect(lines == null || lines >= 2, isTrue, reason: '$name is cut to $lines line');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('short names share one line, so the header stays as short as before', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(
      const RouteOptionsScreen(
        startLat: 30.05,
        startLon: 31.33,
        startName: 'Giza',
        endLat: 30.03,
        endLon: 31.40,
        endName: 'Maadi',
        showMap: false,
        initialData: {'success': true, 'options': []},
      ),
      const Locale('en'),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getCenter(find.text('Giza')).dy, tester.getCenter(find.text('Maadi')).dy);
  });

  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets('route options shows both long names without overflowing (${locale.languageCode})', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(
        const RouteOptionsScreen(
          startLat: 30.05,
          startLon: 31.33,
          startName: _longA,
          endLat: 30.03,
          endLon: 31.40,
          endName: _longB,
          showMap: false,
          initialData: {'success': true, 'options': []},
        ),
        locale,
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      _shownOnTwoLines(tester, _longA);
      _shownOnTwoLines(tester, _longB);
    });

    testWidgets('the trip overview gives each long name two lines (${locale.languageCode})', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(
        const TripRecapScreen(
          option: {'time': 22, 'fare_egp': 10, 'instructions': []},
          pathData: {'instructions': []},
          startName: _longA,
          endName: _longB,
        ),
        locale,
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      _shownOnTwoLines(tester, _longA);
      _shownOnTwoLines(tester, _longB);
    });

    testWidgets('the search fields show long chosen places on two lines (${locale.languageCode})', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(
        const LocationSearchScreen(
          initialStartLocation: {'name': _longA, 'lat': 30.05, 'lon': 31.33},
          initialEndLocation: {'name': _longB, 'lat': 30.03, 'lon': 31.40},
        ),
        locale,
      ));
      await tester.pumpAndSettle();
      _shownOnTwoLines(tester, _longA);
      _shownOnTwoLines(tester, _longB);
    });

    testWidgets('the trip screen names a long next stop on two lines (${locale.languageCode})', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(
        MapScreen(pathData: {
          'instructions': [
            {'action': 'walk_to_station', 'station': _longB, 'lat': 30.05, 'lon': 31.24, 'distance_m': 1400},
            {'action': 'board', 'station': _longB, 'route_id': 'R1', 'route_number': '66', 'vehicle_type': 'minibus', 'lat': 30.05, 'lon': 31.24},
            {'action': 'arrive', 'station': 'B', 'lat': 30.06, 'lon': 31.25},
          ],
          'option': {'type': 'Recommended', 'time': '30', 'fare_egp': 10},
          'segments': [],
        }),
        locale,
      ));
      await tester.pump(const Duration(milliseconds: 500));
      // The step card's title names it ("Walk to ..."); the separate "to X"
      // row is gone (beta feedback, 2026-11).
      final title = find.descendant(of: find.byType(TripNowCard), matching: find.textContaining(_longB));
      expect(title, findsOneWidget);
      final text = tester.widget<Text>(title);
      expect(text.maxLines == null || text.maxLines! >= 2, isTrue);
      expect(text.overflow, isNot(TextOverflow.ellipsis));
    });
  }
}
