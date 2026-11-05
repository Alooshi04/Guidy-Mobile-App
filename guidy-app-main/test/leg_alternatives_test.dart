import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/MapScreen.dart';
import 'package:guidy_app/screens/RouteDetailScreen.dart';
import 'package:guidy_app/screens/RouteOptionsScreen.dart';
import 'package:guidy_app/services/instruction_formatter.dart';
import 'package:guidy_app/services/step_copy.dart';
import 'package:guidy_app/services/trip_sharing.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Steps are typed as decoded JSON is (Map<String, dynamic>).
// A leg lists lines that board a short walk away (the backend's
// EQUIVALENT_MAX_WALK_M). The list says where each one boards, and taking
// one makes that stop the leg's boarding stop.
Map<String, dynamic> _trip() => {
      'instructions': [
        <String, dynamic>{'action': 'walk_to_station', 'station': 'Al Tabba', 'lat': 30.058, 'lon': 31.380, 'distance_m': 900},
        <String, dynamic>{
          'action': 'board', 'station': 'Al Tabba', 'route_id': 'MB', 'vehicle_type': 'microbus',
          'lat': 30.058, 'lon': 31.380, 'fare_egp': 10,
          'boarding_options': [
            <String, dynamic>{'route_id': 'MB', 'vehicle_type': 'microbus', 'is_primary': true, 'fare_egp': 10,
             'board_stop_name': 'Al Tabba', 'walk_to_board_m': 0, 'board_lat': 30.058, 'board_lon': 31.380,
             'alight_stop_name': 'Alf Maskan', 'walk_from_alight_m': 0, 'alight_lat': 30.119, 'alight_lon': 31.340},
            <String, dynamic>{'route_id': 'GOV_MIN_140', 'route_number': '140', 'vehicle_type': 'minibus', 'is_primary': false,
             'fare_egp': 12, 'board_stop_name': 'Ragab Sons', 'walk_to_board_m': 180,
             'board_lat': 30.0595, 'board_lon': 31.3815,
             'alight_stop_name': 'Shams Club', 'walk_from_alight_m': 250, 'alight_lat': 30.1214, 'alight_lon': 31.3428},
          ],
        },
        <String, dynamic>{'action': 'arrive', 'station': 'Alf Maskan', 'lat': 30.119, 'lon': 31.340},
      ],
      'option': {'type': 'Cheapest', 'time': '60', 'fare_egp': 10},
      'segments': [],
    };

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // A rider who already answered the one-time trip-sharing ask, so Start
    // goes straight to the trip.
    TripSharing.asked = true;
  });

  testWidgets('a line a short walk away says where it boards, and taking it moves the boarding stop',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    final trip = _trip();
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MapScreen(pathData: trip),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    final l10n = AppLocalizations.of(tester.element(find.byType(MapScreen)));

    final legTitle = StepCopy.of(l10n, trip['instructions'] as List, 1).title;
    await tester.ensureVisible(find.text(legTitle).last);
    await tester.tap(find.text(legTitle).last);
    await tester.pump(const Duration(milliseconds: 300));

    final walkNote = l10n.navWalkToStop('180', 'Ragab Sons');
    expect(find.textContaining(walkNote), findsOneWidget);

    await tester.tap(find.textContaining(walkNote));
    await tester.pump(const Duration(milliseconds: 300));
    final steps = (tester.widget<MapScreen>(find.byType(MapScreen)).pathData['instructions']) as List;
    expect(steps[1]['route_id'], 'GOV_MIN_140');
    expect(steps[1]['station'], 'Ragab Sons');
    expect((steps[1]['lat'], steps[1]['lon']), (30.0595, 31.3815), reason: 'the leg moves to the new stop');
    // The leg itself says how to get to it and from it, on every leg.
    expect(find.text(l10n.navWalkToStopFirst('180', 'Ragab Sons')), findsWidgets);
    expect(find.text(l10n.navGetOffThenWalk('Shams Club', '250')), findsWidgets);

    // Back to the microbus: all as before.
    await tester.tap(find.textContaining(InstructionFormatter.optionSummary(
        l10n, Map<String, dynamic>.from(((trip['instructions'] as List)[1]['boarding_options'] as List)[0]))).last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(steps[1]['station'], 'Al Tabba');
    expect((steps[1]['lat'], steps[1]['lon']), (30.058, 31.380));
    expect(find.text(l10n.navWalkToStopFirst('180', 'Ragab Sons')), findsNothing);
  });

  // The same on the route options screen, before the trip starts.
  testWidgets('the route options line list says how far a line boards and starts the trip from there',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    final option = <String, dynamic>{'type': 'Cheapest', 'time': '60', 'fare_egp': 10, 'fare_total_egp': 10,
        ..._trip()};
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: RouteOptionsScreen(
        startLat: 30.06, startLon: 31.38, startName: 'Home', endLat: 30.12, endLon: 31.34, endName: 'Alf Maskan',
        initialData: {'success': true, 'options': [option]},
        showMap: false,
      ),
    ));
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.byType(RouteOptionsScreen)));

    // The route's detail page lists every line on the leg; the one boarding
    // a walk away says so.
    await tester.tap(find.byKey(const ValueKey('route-card-0')));
    await tester.pumpAndSettle();
    expect(find.textContaining(l10n.navWalkToStop('180', 'Ragab Sons')), findsWidgets);
    await tester.tap(find.bySemanticsLabel(RegExp('^line 140')));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.plannerStart));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    final map = tester.widget<MapScreen>(find.byType(MapScreen));
    final steps = map.pathData['instructions'] as List;
    expect(steps[1]['route_id'], 'GOV_MIN_140');
    expect(steps[1]['station'], 'Ragab Sons');
    expect((steps[1]['lat'], steps[1]['lon']), (30.0595, 31.3815));
    expect((steps[1]['walk_to_board_m'], steps[1]['walk_from_alight_m']), (180, 250));
    expect(steps[0]['station'], 'Ragab Sons', reason: 'the walk leads to where the chosen line boards');
  });

  // What the trip screen changes is its own copy: back on the route
  // options, the cards are as they were, and Start begins the same trip.
  testWidgets('a vehicle switch mid-trip does not change the route options underneath', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    final option = <String, dynamic>{'type': 'Cheapest', 'time': '60', 'fare_egp': 10, 'fare_total_egp': 10,
        ..._trip()};
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: RouteOptionsScreen(
        startLat: 30.06, startLon: 31.38, startName: 'Home', endLat: 30.12, endLon: 31.34, endName: 'Alf Maskan',
        initialData: {'success': true, 'options': [option]},
        showMap: false,
      ),
    ));
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.byType(RouteOptionsScreen)));

    Future<MapScreen> start() async {
      if (find.byType(RouteDetailScreen).evaluate().isEmpty) {
        await tester.tap(find.byKey(const ValueKey('route-card-0')));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text(l10n.plannerStart));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      return tester.widget<MapScreen>(find.byType(MapScreen));
    }

    await start();
    final legTitle = StepCopy.of(l10n, option['instructions'] as List, 1).title;
    await tester.ensureVisible(find.text(legTitle).last);
    await tester.tap(find.text(legTitle).last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.textContaining(l10n.navWalkToStop('180', 'Ragab Sons')));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(RouteDetailScreen), findsOneWidget, reason: 'back on the route the trip came from');

    final again = await start();
    final leg = (again.pathData['instructions'] as List)[1] as Map;
    expect(leg['route_id'], 'MB');
    expect(leg['station'], 'Al Tabba');
    final opts = leg['boarding_options'] as List;
    expect([for (final o in opts) o['is_primary']], [true, false]);
  });
}
