import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/MapScreen.dart';
import 'package:guidy_app/screens/RouteDetailScreen.dart';
import 'package:guidy_app/screens/RouteOptionsScreen.dart';
import 'package:guidy_app/services/simple_mode.dart';
import 'package:guidy_app/utils/minutes_text.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Route Options, Moovit style (owner's pick, 2026-10-16): compact cards
// with the time on the left, the modes with each walk's distance and each
// ride's planned line (beta reviewer, 2026-11), and at most one tag.
// Tapping a card opens the route detail page, a timeline where the trip is
// started.
Map<String, dynamic> _line(String number, {bool primary = false, bool rec = true, num every = 5, num fare = 7.5}) => {
      'route_id': 'BUS_$number',
      'route_number': number,
      'vehicle_type': 'bus',
      'is_primary': primary,
      'recommended': rec,
      'typical_headway_min': every,
      'fare_egp': fare,
      'walk_to_board_m': 0,
      'board_stop_name': 'Sidi Gaber',
      'alight_stop_name': 'Mahattet Masr',
      'walk_from_alight_m': 0,
    };

Map<String, dynamic> _option({String type = 'Recommended', num time = 75, num fare = 7.5}) => {
      'type': type,
      'also_qualifies_as': ['Cheapest', 'Fastest'],
      'time': '$time',
      'fare_egp': fare,
      'fare_total_egp': fare,
      'distance_m': 15900,
      'segments': [],
      'instructions': [
        {'action': 'walk_to_station', 'station': 'Sidi Gaber', 'lat': 31.21, 'lon': 29.94, 'distance_m': 350},
        {
          'action': 'board',
          'hail': true,
          'station': 'Sidi Gaber',
          'lat': 31.21,
          'lon': 29.94,
          'route_id': 'BUS_871',
          'route_number': '871',
          'vehicle_type': 'bus',
          'fare_egp': 7.5,
          'stops_count': 30,
          'ride_min': 49,
          'alight_station': 'Mahattet Masr',
          'boarding_options': [
            _line('871', primary: true),
            _line('45', every: 8),
            _line('290', rec: false, every: 12, fare: 9),
            _line('221', every: 15),
          ],
        },
        {'action': 'arrive', 'hail': true, 'station': 'Mahattet Masr', 'lat': 31.19, 'lon': 29.90},
        {'action': 'walk_to_destination', 'distance_m': 200},
      ],
    };

Future<AppLocalizations> _pump(WidgetTester tester, {List<Map<String, dynamic>>? options, Locale? locale}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(() => tester.view.resetPhysicalSize());
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: RouteOptionsScreen(
      startLat: 31.24, startLon: 29.98, startName: 'Victoria', endLat: 31.19, endLon: 29.90, endName: 'Mahattet Masr',
      initialData: {'success': true, 'options': options ?? [_option()]},
      showMap: false,
    ),
  ));
  await tester.pumpAndSettle();
  return AppLocalizations.of(tester.element(find.byType(RouteOptionsScreen)));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a card is compact: time, walk metres, the planned line, one tag', (tester) async {
    final l10n = await _pump(tester);
    expect(find.text('350 m'), findsOneWidget);
    expect(find.text('Bus 871'), findsOneWidget, reason: 'the line the route was planned with');
    expect(find.text('200 m'), findsOneWidget);
    expect(find.text('871 / 45 / 290 / 221'), findsNothing, reason: 'one line, not every one that covers it');
    expect(find.textContaining('Every'), findsNothing, reason: 'no frequency line under the modes');
    expect(find.textContaining('Sidi Gaber'), findsNothing);
    expect(find.byKey(const ValueKey('route-card-fare')), findsOneWidget, reason: 'the fare has its own spot');
    expect(find.text(l10n.routeTierRecommended), findsOneWidget);
    expect(find.text(l10n.routeTierCheapest), findsNothing, reason: 'one tag, not three');
    expect(find.text(l10n.routeTierFastest), findsNothing);
    // The step list no longer sits under the cards, cut off from its card.
    expect(find.text(l10n.plannerSteps), findsNothing);
  });

  testWidgets('Start trip lives on the detail page a card opens', (tester) async {
    final l10n = await _pump(tester);
    expect(find.text(l10n.plannerStart), findsNothing);
    await tester.tap(find.byKey(const ValueKey('route-card-0')));
    await tester.pumpAndSettle();
    expect(find.byType(RouteDetailScreen), findsOneWidget);
    expect(find.text(l10n.plannerStart), findsOneWidget);
  });

  Future<void> openDetail(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('route-card-0')));
    await tester.pumpAndSettle();
  }

  List<String> lineChips(WidgetTester tester) => tester
      .widgetList<Semantics>(find.descendant(of: find.byKey(const ValueKey('timeline-lines-1')), matching: find.byType(Semantics)))
      .map((s) => s.properties.label)
      .whereType<String>()
      .where((l) => l.startsWith('line '))
      .toList();

  testWidgets('the detail timeline says where to wave it down, every line, the ride and its fare', (tester) async {
    final l10n = await _pump(tester);
    await openDetail(tester);
    expect(find.text(l10n.actWaveDownAny), findsOneWidget, reason: "the live trip pager's words");
    expect(find.text('Sidi Gaber'), findsOneWidget);
    final rec = l10n.lineRecommended;
    expect(lineChips(tester), ['line 871 $rec', 'line 45 $rec', 'line 290', 'line 221 $rec'],
        reason: 'in the order sent; the ones as good as the planned line marked');
    expect(find.text('Ride 30 stops  |  49 min'), findsOneWidget);
    expect(find.text('7.5 EGP'), findsOneWidget, reason: 'the leg fare, decimal');
    expect(find.text('Mahattet Masr'), findsWidgets);
    expect(find.text(l10n.routeAskDriverStop), findsOneWidget, reason: 'got off on the street');
    expect(find.text(l10n.routeWalkLeg(l10n.minutes(5), '350 m')), findsOneWidget);
  });

  testWidgets('a ride says no frequency, direction or wait; expanding it lists the stops, first and last emphasised', (tester) async {
    final opt = _option();
    final ride = (opt['instructions'] as List)[1] as Map;
    // What the backend sends: {name_en, name_ar, lat, lon} between boarding and getting off.
    ride['intermediate_stops'] = [
      {'name_en': 'Gleem', 'name_ar': 'جليم', 'lat': 31.2, 'lon': 29.9},
      {'name_en': 'Zizinia', 'name_ar': 'زيزينيا', 'lat': 31.2, 'lon': 29.9},
    ];
    ride['towards'] = 'Raml Station';
    ride['wait_min'] = 6;
    final l10n = await _pump(tester, options: [opt]);
    await openDetail(tester);
    // Beta feedback (2026-11): "every 5 min", "towards X" and "wait about
    // 6 min" took room and confused; the header, lines and fold stay.
    expect(find.textContaining(l10n.navEveryMinutes(l10n.minutes(5))), findsNothing);
    expect(find.textContaining(l10n.plannerTowards('Raml Station')), findsNothing);
    expect(find.textContaining(l10n.stepWaitHint(l10n.minutes(6))), findsNothing);
    expect(find.text(l10n.actWaveDownAny), findsOneWidget);
    expect(find.text('7.5 EGP'), findsOneWidget);
    expect(find.text('Ride 30 stops  |  49 min'), findsOneWidget);
    expect(find.text('Gleem'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('ride-fold-1')));
    await tester.pumpAndSettle();
    expect(find.text('Gleem'), findsOneWidget);
    expect(find.text('Zizinia'), findsOneWidget);
    FontWeight? weight(String key) =>
        tester.widget<Text>(find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(Text))).style?.fontWeight;
    expect(find.descendant(of: find.byKey(const ValueKey('ride-stop-first-1')), matching: find.text('Sidi Gaber')),
        findsOneWidget, reason: 'the list starts where you board');
    expect(find.descendant(of: find.byKey(const ValueKey('ride-stop-last-1')), matching: find.text('Mahattet Masr')),
        findsOneWidget, reason: 'and ends where you get off');
    expect(weight('ride-stop-first-1'), FontWeight.w800);
    expect(weight('ride-stop-last-1'), FontWeight.w800);
    expect(weight('ride-stop-1-0'), isNot(FontWeight.w800), reason: 'stops in between are plain');

    await tester.tap(find.byKey(const ValueKey('ride-fold-1')));
    await tester.pumpAndSettle();
    expect(find.text('Gleem'), findsNothing, reason: 'collapsible');
  });

  testWidgets('the stops come in Arabic for an Arabic rider', (tester) async {
    final opt = _option();
    ((opt['instructions'] as List)[1] as Map)['intermediate_stops'] = [
      {'name_en': 'Gleem', 'name_ar': 'جليم', 'lat': 31.2, 'lon': 29.9},
    ];
    await _pump(tester, options: [opt], locale: const Locale('ar'));
    await openDetail(tester);
    await tester.tap(find.byKey(const ValueKey('ride-fold-1')));
    await tester.pumpAndSettle();
    expect(find.text('جليم'), findsOneWidget);
    expect(find.text('Gleem'), findsNothing);
  });

  testWidgets('a route that does not name its stops has nothing to expand', (tester) async {
    await _pump(tester);
    await openDetail(tester);
    expect(find.text('Ride 30 stops  |  49 min'), findsOneWidget);
    expect(find.byIcon(Icons.expand_more_rounded), findsNothing);
  });

  testWidgets('picking a line on the detail page moves the fare, and the card behind follows', (tester) async {
    await _pump(tester);
    await openDetail(tester);
    await tester.tap(find.bySemanticsLabel('line 290'));
    await tester.pumpAndSettle();
    expect(tester.getSemantics(find.bySemanticsLabel('line 290')), isSemantics(isSelected: true));
    expect(tester.getSemantics(find.bySemanticsLabel(RegExp('^line 871'))), isSemantics(isSelected: false));
    expect(find.textContaining('9 EGP'), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Bus 290'), findsOneWidget, reason: 'the card names the line picked');
    expect(find.text('Bus 871'), findsNothing);
    expect(find.descendant(of: find.byKey(const ValueKey('route-card-0')), matching: find.text('9 EGP')), findsOneWidget);
  });

  testWidgets('Start trip starts the route on the line picked', (tester) async {
    final l10n = await _pump(tester);
    await openDetail(tester);
    await tester.tap(find.bySemanticsLabel(RegExp('^line 45')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.plannerStart));
    await tester.pumpAndSettle();
    // The one-time trip-share ask comes first.
    await tester.tap(find.text(l10n.tripShareAskNo));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final map = tester.widget<MapScreen>(find.byType(MapScreen));
    final ride = (map.pathData['instructions'] as List)[1] as Map;
    expect(ride['route_id'], 'BUS_45');
  });

  testWidgets('in Arabic the card and the detail page lay out right to left', (tester) async {
    final l10n = await _pump(tester, locale: const Locale('ar'));
    expect(find.text('أتوبيس 871'), findsOneWidget);
    expect(find.text('350 م'), findsOneWidget);
    expect(find.textContaining('Sidi Gaber'), findsNothing, reason: 'no "every X min from Y" line');
    await openDetail(tester);
    expect(find.text(l10n.routeDetailsTitle), findsOneWidget);
    expect(find.text('${l10n.routeRideFold(l10n.stepStops(30))}  |  ${l10n.minutes(49)}'), findsOneWidget);
  });

  testWidgets('Simple Mode: time and fare are big and bold; Fastest/Cheapest/Recommended are marked', (tester) async {
    simpleMode.value = true;
    addTearDown(() => simpleMode.value = false);
    await _pump(tester, options: [_option(time: 61, fare: 70)]);
    final time = tester.widget<Text>(find.byKey(const ValueKey('simple-total-time')));
    final fare = tester.widget<Text>(find.byKey(const ValueKey('simple-total-fare')));
    expect(time.data, '61 min');
    expect(fare.data, '70 EGP');
    for (final t in [time, fare]) {
      expect(t.style!.fontWeight, FontWeight.w800);
      expect(t.style!.fontSize!, greaterThanOrEqualTo(28));
    }
    for (final tier in ['Recommended', 'Fastest', 'Cheapest']) {
      expect(find.byKey(ValueKey('simple-tier-$tier')), findsOneWidget, reason: tier);
    }
    expect(find.text('Recommended'), findsOneWidget);
  });

  testWidgets('Simple Mode, Arabic: the badges and the total read in Arabic without overflow', (tester) async {
    simpleMode.value = true;
    addTearDown(() => simpleMode.value = false);
    await _pump(tester, options: [_option(time: 116, fare: 20)], locale: const Locale('ar'));
    expect(tester.takeException(), isNull);
    expect(find.text('116 دقيقة'), findsOneWidget);
    expect(find.text('20 جنيه'), findsOneWidget);
    expect(find.byKey(const ValueKey('simple-tier-Fastest')), findsOneWidget);
  });

  group('the total fare stands out next to the duration', () {
    Future<void> pumpAt(WidgetTester tester, {required Locale locale, double width = 360, double scale = 1.0}) async {
      tester.view.physicalSize = Size(width * 2, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(() => tester.view.resetPhysicalSize());
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
        home: RouteOptionsScreen(
          startLat: 31.24, startLon: 29.98, startName: 'Victoria', endLat: 31.19, endLon: 29.90, endName: 'Mahattet Masr',
          initialData: {'success': true, 'options': [_option(time: 48, fare: 22)]},
          showMap: false,
        ),
      ));
      await tester.pumpAndSettle();
    }

    for (final (locale, fare, minutes) in [
      (const Locale('en'), '22 EGP', '48 min'),
      (const Locale('ar'), '22 جنيه', '48 دقيقة'),
    ]) {
      for (final (width, scale) in [(360.0, 1.0), (360.0, 1.3), (412.0, 1.0)]) {
        testWidgets('card: "$fare" under "$minutes", same weight, no overflow (${locale.languageCode}, ${width}dp, x$scale)',
            (tester) async {
          await pumpAt(tester, locale: locale, width: width, scale: scale);
          expect(tester.takeException(), isNull);
          final fareText = tester.widget<Text>(find.text(fare));
          final minText = tester.widget<Text>(find.text(minutes));
          expect(fareText.style!.fontWeight, minText.style!.fontWeight);
          expect(fareText.style!.fontSize!, greaterThanOrEqualTo(minText.style!.fontSize! * 0.8));
          expect(fareText.style!.fontSize!, greaterThan(14), reason: 'no longer the 12.5 grey line');
          expect(tester.getTopLeft(find.text(fare)).dy, greaterThan(tester.getTopLeft(find.text(minutes)).dy));
          expect(find.textContaining('· $fare'), findsNothing, reason: 'not repeated in the info line');
        });
      }
    }

    testWidgets('the detail header shows the fare big, in the fare colour', (tester) async {
      await pumpAt(tester, locale: const Locale('en'));
      await tester.tap(find.byKey(const ValueKey('route-card-0')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final header = tester.widget<Text>(find.byKey(const ValueKey('route-detail-header')));
      final spans = (header.textSpan! as TextSpan).children!.cast<TextSpan>();
      final fare = spans.firstWhere((s) => s.text == '22 EGP');
      expect(fare.style!.fontSize!, greaterThan(15));
      expect(fare.style!.fontWeight, FontWeight.w800);
    });
  });
}
