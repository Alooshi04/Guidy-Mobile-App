import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/RouteOptionsScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// A route doesn't single out one line for a leg: it lists every line that
// covers it, in the order the backend sends (most frequent first), with the
// ones as good as the leg's own marked recommended (owner, 2026-10-14).
Map<String, dynamic> _line(String id, String number, {bool primary = false, bool rec = true, num every = 5, num fare = 10}) =>
    <String, dynamic>{
      'route_id': id, 'route_number': number, 'vehicle_type': 'microbus', 'is_primary': primary,
      'recommended': rec, 'typical_headway_min': every, 'fare_egp': fare,
      'board_stop_name': 'On the road to Wadi Hof Metro', 'walk_to_board_m': 0,
      'board_lat': 29.874, 'board_lon': 31.317,
      'alight_stop_name': 'Maasara Autostrad', 'walk_from_alight_m': 0, 'alight_lat': 29.913, 'alight_lon': 31.298,
    };

Map<String, dynamic> _option({bool ask = false}) => {
      'type': 'Recommended', 'time': '15', 'fare_egp': 10, 'fare_total_egp': 10, 'segments': [],
      'instructions': [
        <String, dynamic>{'action': 'walk_to_station', 'station': 'On the road to Wadi Hof Metro',
          'lat': 29.874, 'lon': 31.317, 'distance_m': 27},
        <String, dynamic>{
          'action': 'board', 'hail': true, 'station': 'On the road to Wadi Hof Metro', 'route_id': 'B',
          'route_number': '24', 'vehicle_type': 'microbus', 'lat': 29.874, 'lon': 31.317, 'fare_egp': 10,
          if (ask) ...{'ask_driver_en': 'Icon', 'ask_driver_ar': 'ايكون'},
          'boarding_options': [
            _line('A', '11', every: 3),
            _line('B', '24', primary: true, every: 5),
            _line('C', '37', every: 8),
            _line('D', '52', rec: false, every: 12, fare: 20),
          ],
        },
        <String, dynamic>{'action': 'arrive', 'hail': true, 'station': 'On the road after Icon',
          'lat': 29.913, 'lon': 31.298},
      ],
    };

Future<AppLocalizations> _pump(WidgetTester tester, {bool ask = false}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(() => tester.view.resetPhysicalSize());
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: RouteOptionsScreen(
      startLat: 29.874, startLon: 31.317, startName: 'Home', endLat: 29.913, endLon: 31.298, endName: 'Maasara',
      initialData: {'success': true, 'options': [_option(ask: ask)]},
      showMap: false,
    ),
  ));
  await tester.pumpAndSettle();
  return AppLocalizations.of(tester.element(find.byType(RouteOptionsScreen)));
}

Future<void> _openDetail(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('route-card-0')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // 1.0.11 (18) said "Microbus ×4": too vague (owner, 2026-10-14). Every
  // line in one chip (2026-10-16) got cut off; the card names the one the
  // route was planned with, the starred one on the detail page (2026-11).
  testWidgets('a card names the line the route was planned with', (tester) async {
    await _pump(tester);
    expect(find.text('Microbus 24'), findsOneWidget);
    expect(find.text('11 / 24 / 37 / 52'), findsNothing);
    expect(find.text('27 m'), findsOneWidget, reason: 'the walk to the stop, in metres');
  });

  testWidgets('the detail page lists every line in the order sent, recommended ones marked', (tester) async {
    final l10n = await _pump(tester);
    await _openDetail(tester);
    final chips = find.byKey(const ValueKey('timeline-lines-1'));
    expect(chips, findsOneWidget);
    final labels = tester
        .widgetList<Semantics>(find.descendant(of: chips, matching: find.byType(Semantics)))
        .map((s) => s.properties.label)
        .whereType<String>()
        .where((l) => l.startsWith('line '))
        .toList();
    expect(labels, [
      'line 11 ${l10n.lineRecommended}',
      'line 24 ${l10n.lineRecommended}',
      'line 37 ${l10n.lineRecommended}',
      'line 52',
    ]);
    // The star says what it means (QA 2026-10-22).
    expect(find.byKey(const ValueKey('timeline-star-legend-1')), findsOneWidget);
    expect(find.text(l10n.lineRecommendedLegend), findsOneWidget);
  });

  testWidgets('waving it down and asking to stop are said as such', (tester) async {
    final l10n = await _pump(tester);
    await _openDetail(tester);
    expect(find.text(l10n.actWaveDownAny), findsOneWidget);
    expect(find.text('On the road to Wadi Hof Metro'), findsOneWidget);
    expect(find.text('On the road after Icon'), findsOneWidget);
    expect(find.text(l10n.routeAskDriverStop), findsOneWidget);
  });

  testWidgets('the leg starts on its own line, and tapping another takes that one', (tester) async {
    await _pump(tester);
    await _openDetail(tester);
    Finder line(String n) => find.bySemanticsLabel(RegExp('^line $n'));
    expect(tester.getSemantics(line('24')), isSemantics(isSelected: true));
    await tester.tap(line('52'));
    await tester.pumpAndSettle();
    expect(tester.getSemantics(line('52')), isSemantics(isSelected: true));
    expect(tester.getSemantics(line('24')), isSemantics(isSelected: false));
    // Line 52 costs 20 instead of 10: the trip's fare follows.
    expect(find.textContaining('20 EGP'), findsWidgets);
  });

  testWidgets('a road leg is asked about; the detail page still lists every line, no toggle', (tester) async {
    await _pump(tester, ask: true);
    expect(find.text('11 / 24 / 37 / 52'), findsNothing);
    expect(find.text('Microbus'), findsWidgets);
    await _openDetail(tester);
    expect(find.text('Ask the driver: going to Icon?'), findsOneWidget);
    expect(find.byKey(const ValueKey('timeline-lines-1')), findsOneWidget);
    expect(find.text('Which microbuses?'), findsNothing);
    await tester.tap(find.bySemanticsLabel(RegExp('^line 52')));
    await tester.pumpAndSettle();
    expect(find.textContaining('20 EGP'), findsWidgets);
  });

  testWidgets('a long list of lines is never cut: all chips on the detail page, the planned one on the card', (tester) async {
    final opt = _option();
    final board = (opt['instructions'] as List)[1] as Map<String, dynamic>;
    board['boarding_options'] = [
      for (var n = 0; n < 9; n++) _line('L$n', '${100 + n}', primary: n == 1, every: 3 + n),
    ];
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: RouteOptionsScreen(
        startLat: 29.874, startLon: 31.317, startName: 'Home', endLat: 29.913, endLon: 31.298, endName: 'Maasara',
        initialData: {'success': true, 'options': [opt]},
        showMap: false,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Microbus 24'), findsOneWidget, reason: "the ride's own line");
    expect(find.textContaining('100 / 101'), findsNothing);
    expect(tester.takeException(), isNull);
    await _openDetail(tester);
    final chips = find.byKey(const ValueKey('timeline-lines-1'));
    for (var n = 0; n < 9; n++) {
      expect(find.descendant(of: chips, matching: find.bySemanticsLabel(RegExp('^line ${100 + n}'))), findsOneWidget);
    }
    expect(find.textContaining('more'), findsNothing);
  });
}
