import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/MapScreen.dart';
import 'package:guidy_app/screens/TripRecapScreen.dart';
import 'package:guidy_app/services/trip_sharing.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Every "back" during a trip goes exactly one screen back, to the screen the
// trip was started from, showing what it showed -- it used to jump straight
// to the home screen.
Map<String, dynamic> _trip() => {
      'instructions': [
        {'action': 'walk_to_station', 'station': 'A', 'lat': 30.05, 'lon': 31.24, 'distance_m': 200},
        {'action': 'board', 'station': 'A', 'route_id': 'R1', 'route_number': '66', 'vehicle_type': 'minibus', 'lat': 30.05, 'lon': 31.24},
        {'action': 'arrive', 'station': 'B', 'lat': 30.06, 'lon': 31.25},
      ],
      'option': {'type': 'Recommended', 'time': '30', 'fare_egp': 10},
      'segments': [],
    };

Widget _app() => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => Scaffold(
                    body: Column(children: [
                      const Text('route options: 3 cards, card 2 selected'),
                      ElevatedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => MapScreen(pathData: _trip())),
                        ),
                        child: const Text('start'),
                      ),
                    ]),
                  ),
                ),
              ),
              child: const Text('home: plan a trip'),
            ),
          ),
        ),
      ),
    );

Future<void> _openTrip(WidgetTester tester) async {
  await tester.pumpWidget(_app());
  await tester.tap(find.text('home: plan a trip'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('start'));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
  expect(find.byType(MapScreen), findsOneWidget);
}

void main() {
  // The trip-share question is asked before the first trip; it was answered.
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TripSharing.asked = true;
  });

  testWidgets('the back arrow goes back to the route options', (tester) async {
    await _openTrip(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(MapScreen)));
    await tester.tap(find.byTooltip(l10n.closeMapTooltip));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(MapScreen), findsNothing);
    expect(find.text('route options: 3 cards, card 2 selected'), findsOneWidget);
    expect(find.text('home: plan a trip'), findsNothing);
  });

  testWidgets("the phone's back goes back to the route options", (tester) async {
    await _openTrip(tester);
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(MapScreen), findsNothing);
    expect(find.text('route options: 3 cards, card 2 selected'), findsOneWidget);
  });

  // A trip started again from a past trip's recap: back returns to that
  // recap, not past it.
  testWidgets('back from a trip started on a recap returns to the recap', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    final option = {'type': 'Recommended', 'time': '30', 'fare_total_egp': 10, ..._trip()};
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TripRecapScreen(
                    option: option, pathData: option, startName: 'Dokki Square', endName: 'Tahrir Square'),
              ),
            ),
            child: const Text('history'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('history'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Navigation'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(MapScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(MapScreen), findsNothing);
    expect(find.byType(TripRecapScreen), findsOneWidget);
  });
}
