import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/BetterRouteBuilderScreen.dart';
import 'package:guidy_app/screens/RouteOptionsScreen.dart';
import 'package:guidy_app/services/api_service.dart';
import 'package:guidy_app/services/better_route.dart';
import 'package:guidy_app/services/route_report_service.dart';
import 'package:guidy_app/services/simple_mode.dart';
import 'package:guidy_app/theme/guidy_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

// "Know a better route?" (beta reviewer, 2026-11): a clearly visible
// button under the filters opens a sheet with two ways to tell us: write
// it, or build it leg by leg from the transport network.

/// Serves a small network and records what was asked.
class _FakeApi extends ApiService {
  final queries = <(String, String?)>[];

  static final network = <Map<String, dynamic>>[
    {'route_id': 'MB_66', 'number': '66', 'vehicle_type': 'minibus', 'description': 'Abbas El Akkad to Ramses',
      'from': 'Abbas El Akkad', 'to': 'Ramses'},
    {'route_id': 'MB_67', 'number': '67', 'vehicle_type': 'minibus', 'description': 'Nasr City to Tahrir'},
    {'route_id': 'NAT_L3', 'number': '3', 'vehicle_type': 'metro', 'from': 'Adly Mansour', 'to': 'Rod El Farag'},
    {'route_id': 'MC_9', 'number': null, 'vehicle_type': 'microbus', 'description': 'Gesr El Suez'},
  ];

  @override
  Future<List<Map<String, dynamic>>> searchRoutes({
    String query = '',
    String? vehicleType,
    String lang = 'en',
    int limit = 40,
  }) async {
    queries.add((query, vehicleType));
    final q = query.toLowerCase();
    return network.where((r) {
      if (vehicleType != null && r['vehicle_type'] != vehicleType) return false;
      return q.isEmpty || '${r['number']} ${r['description']}'.toLowerCase().contains(q);
    }).toList();
  }
}

/// Records each report and answers with [outcome].
class _Reports {
  _Reports([this.outcome = RouteReportOutcome.sent]);
  RouteReportOutcome outcome;
  final sent = <BetterRouteReport>[];
  Future<RouteReportOutcome> call(BetterRouteReport r) async {
    sent.add(r);
    return outcome;
  }
}

Map<String, dynamic> _option(String type, num time, String lineId, String number) => {
      'type': type,
      'time': '$time',
      'fare_total_egp': 12.5,
      'segments': [],
      'instructions': [
        {'action': 'walk_to_station', 'station': 'A', 'distance_m': 350},
        {'action': 'board', 'station': 'A', 'route_id': lineId, 'route_number': number, 'vehicle_type': 'bus',
          'fare_egp': 12.5, 'boarding_options': [
            {'route_id': lineId, 'route_number': number, 'vehicle_type': 'bus', 'is_primary': true},
          ]},
        {'action': 'arrive', 'station': 'B'},
      ],
    };

final _options = [_option('Recommended', 78, 'CTA_871', '871'), _option('Cheapest', 95, 'CTA_45', '45')];

void _bigScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(() => tester.view.resetPhysicalSize());
}

Future<AppLocalizations> _pumpOptions(WidgetTester tester, _Reports reports,
    {Locale locale = const Locale('en'), ThemeMode theme = ThemeMode.light, _FakeApi? api}) async {
  _bigScreen(tester);
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    theme: ThemeData(brightness: Brightness.light),
    darkTheme: ThemeData(brightness: Brightness.dark),
    themeMode: theme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: RouteOptionsScreen(
      startLat: 30.05, startLon: 31.33, startName: 'Nasr City', endLat: 30.05, endLon: 31.25, endName: 'Attaba',
      initialData: {'success': true, 'options': _options},
      showMap: false,
      api: api ?? _FakeApi(),
      submitBetterRoute: reports.call,
    ),
  ));
  await tester.pumpAndSettle();
  return AppLocalizations.of(tester.element(find.byType(RouteOptionsScreen)));
}

const _button = ValueKey('better-route-button');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the button', () {
    testWidgets('sits under the filter pills and above the list/compare switch', (tester) async {
      final l10n = await _pumpOptions(tester, _Reports());
      expect(find.byKey(_button), findsOneWidget);
      expect(find.text(l10n.betterRouteButton), findsOneWidget);
      final button = tester.getRect(find.byKey(_button));
      final filters = tester.getRect(find.text(l10n.filterMinWalk));
      final viewSwitch = tester.getRect(find.text(l10n.routeListTab));
      expect(button.top, greaterThan(filters.bottom));
      expect(button.bottom, lessThan(viewSwitch.top));
      // Full width, unlike the pills.
      expect(button.width, greaterThan(tester.getSize(find.byType(RouteOptionsScreen)).width - 40));
    });

    for (final (locale, theme) in [
      (const Locale('en'), ThemeMode.light),
      (const Locale('en'), ThemeMode.dark),
      (const Locale('ar'), ThemeMode.light),
      (const Locale('ar'), ThemeMode.dark),
    ]) {
      testWidgets('reads cleanly (${locale.languageCode}, ${theme.name})', (tester) async {
        final l10n = await _pumpOptions(tester, _Reports(), locale: locale, theme: theme);
        expect(tester.takeException(), isNull);
        final icon = tester.getCenter(find.descendant(of: find.byKey(_button), matching: find.byIcon(Icons.tips_and_updates_outlined)));
        final text = tester.getCenter(find.text(l10n.betterRouteButton));
        // The icon leads in the reading direction.
        expect(locale.languageCode == 'ar' ? icon.dx > text.dx : icon.dx < text.dx, isTrue);
      });
    }

    testWidgets('Simple Mode has it too, after the routes', (tester) async {
      simpleMode.value = true;
      addTearDown(() => simpleMode.value = false);
      final reports = _Reports();
      final l10n = await _pumpOptions(tester, reports);
      final simple = find.byKey(const ValueKey('simple-better-route'));
      await tester.scrollUntilVisible(simple, 200, scrollable: find.byType(Scrollable).first);
      expect(simple, findsOneWidget);
      expect(tester.getTopLeft(simple).dy, lessThan(tester.getTopLeft(find.byKey(const ValueKey('simple_home_button'))).dy));
      await tester.tap(simple);
      await tester.pumpAndSettle();
      expect(find.text(l10n.betterRouteWriteTitle), findsOneWidget);
    });
  });

  group('the sheet', () {
    testWidgets('offers writing it or building it', (tester) async {
      final l10n = await _pumpOptions(tester, _Reports());
      await tester.tap(find.byKey(_button));
      await tester.pumpAndSettle();
      expect(find.text(l10n.betterRouteWriteTitle), findsOneWidget);
      expect(find.text(l10n.betterRouteBuildTitle), findsOneWidget);
    });

    testWidgets('a written route is sent with both ends and the routes shown', (tester) async {
      final reports = _Reports();
      final l10n = await _pumpOptions(tester, reports);
      await tester.tap(find.byKey(_button));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('better-route-write')));
      await tester.pumpAndSettle();
      final send = find.byKey(const ValueKey('better-route-send'));
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(reports.sent, isEmpty, reason: 'nothing written, nothing sent');
      await tester.enterText(find.byKey(const ValueKey('better-route-text')), '  Minibus 66 to Ramses, then the metro ');
      await tester.pumpAndSettle();
      await tester.tap(send);
      await tester.pumpAndSettle();

      final r = reports.sent.single;
      expect(r.comment, '  Minibus 66 to Ramses, then the metro ');
      expect(r.legs, isEmpty);
      expect(r.locale, 'en');
      final fields = r.toFields();
      expect(fields['comment'], 'Minibus 66 to Ramses, then the metro');
      expect(fields.containsKey('legs'), isFalse);
      expect(fields['trip'], {
        'start_name': 'Nasr City', 'end_name': 'Attaba',
        'start_lat': 30.05, 'start_lon': 31.33, 'end_lat': 30.05, 'end_lon': 31.25,
      });
      expect(r.shownOptions.map((o) => o['type']), ['Recommended', 'Cheapest']);
      expect(r.shownOptions.first['time_min'], 78);
      expect(r.shownOptions.first['legs'], [
        {'mode': 'walk', 'distance_m': 350},
        {'mode': 'bus', 'route_id': 'CTA_871', 'route_number': '871'},
      ]);
      expect(find.text(l10n.reportSent), findsOneWidget);
    });

    for (final (outcome, message) in [
      (RouteReportOutcome.queuedOffline, (AppLocalizations l) => l.reportQueued),
      (RouteReportOutcome.notSignedIn, (AppLocalizations l) => l.reportSignInRequired),
      (RouteReportOutcome.failed, (AppLocalizations l) => l.reportFailed),
    ]) {
      testWidgets('says so when the report is ${outcome.name}', (tester) async {
        final l10n = await _pumpOptions(tester, _Reports(outcome));
        await tester.tap(find.byKey(_button));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('better-route-write')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const ValueKey('better-route-text')), 'Minibus 66');
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('better-route-send')));
        await tester.pumpAndSettle();
        expect(find.text(message(l10n)), findsOneWidget);
      });
    }

    testWidgets('building it opens the builder, and a sent route comes back as sent', (tester) async {
      final reports = _Reports();
      final l10n = await _pumpOptions(tester, reports);
      await tester.tap(find.byKey(_button));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('better-route-build')));
      await tester.pumpAndSettle();
      expect(find.byType(BetterRouteBuilderScreen), findsOneWidget);
      await _addNetworkRide(tester, '66', 'MB_66');
      await tester.tap(find.byKey(const ValueKey('better-route-submit')));
      await tester.pumpAndSettle();
      expect(find.byType(BetterRouteBuilderScreen), findsNothing);
      expect(find.text(l10n.reportSent), findsOneWidget);
      expect(reports.sent.single.shownOptions, hasLength(2));
      expect(reports.sent.single.legs.single['route_id'], 'MB_66');
    });
  });

  group('the builder', () {
    Future<(AppLocalizations, _Reports, _FakeApi)> pumpBuilder(WidgetTester tester,
        {Locale locale = const Locale('en'), RouteReportOutcome outcome = RouteReportOutcome.sent}) async {
      _bigScreen(tester);
      final reports = _Reports(outcome);
      final api = _FakeApi();
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  final result = await Navigator.push<RouteReportOutcome>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BetterRouteBuilderScreen(
                        startLat: 30.05, startLon: 31.33, startName: 'Nasr City',
                        endLat: 30.05, endLon: 31.25, endName: 'Attaba',
                        shownOptions: BetterRouteReport.summarize(_options),
                        submit: reports.call,
                        api: api,
                      ),
                    ),
                  );
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('popped $result')));
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return (AppLocalizations.of(tester.element(find.byType(BetterRouteBuilderScreen))), reports, api);
    }

    Finder field(String prefix, int n) =>
        find.byWidgetPredicate((w) => w is TextField && '${w.key}'.contains("'better-route-$prefix-")).at(n);

    testWidgets('sends the legs in order, with what the rider said about each', (tester) async {
      final (l10n, reports, api) = await pumpBuilder(tester);
      expect(find.text(l10n.betterRouteNeedRide), findsOneWidget);
      GuidyGradientButton submit() => tester.widget(find.byKey(const ValueKey('better-route-submit')));
      expect(submit().onPressed, isNull, reason: 'no ride, nothing to send');

      // A walk of 300 m.
      await tester.tap(find.byKey(const ValueKey('better-route-add-walk')));
      await tester.pumpAndSettle();
      await tester.enterText(field('meters', 0), '300');

      // Minibus 66 from the network, picked by searching its number.
      await _addNetworkRide(tester, '66', 'MB_66');
      expect(api.queries.last, ('66', null));
      expect(find.text('Minibus 66'), findsOneWidget, reason: 'named like the route cards name it');
      await tester.enterText(field('board', 0), 'Abbas El Akkad');
      await tester.enterText(field('alight', 0), 'Ramses');
      await tester.enterText(field('fare', 0), '7.5');

      // A microbus the app doesn't have.
      await tester.tap(find.byKey(const ValueKey('better-route-add-ride')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('better-route-not-in-app')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('better-route-typed-mode-microbus')));
      await tester.enterText(find.byKey(const ValueKey('better-route-typed-name')), 'Gesr El Suez microbus');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('better-route-typed-add')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.betterRouteTypedBadge), findsOneWidget);
      await tester.enterText(field('fare', 1), '10');

      // The metro, found under its mode, then removed again.
      await tester.tap(find.byKey(const ValueKey('better-route-add-ride')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('better-route-mode-metro')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('better-route-mode-metro')));
      await tester.pumpAndSettle();
      expect(api.queries.last, ('', 'metro'));
      await tester.tap(find.byKey(const ValueKey('better-route-line-NAT_L3')));
      await tester.pumpAndSettle();
      expect(find.text('M3'), findsOneWidget);
      await tester.tap(find.byTooltip(l10n.betterRouteRemoveLeg).last);
      await tester.pumpAndSettle();
      expect(find.text('M3'), findsNothing);

      await tester.enterText(find.byKey(const ValueKey('better-route-note')), 'Faster at rush hour');
      await tester.pumpAndSettle();
      expect(find.text(l10n.betterRouteNeedRide), findsNothing);
      expect(submit().onPressed, isNotNull);
      await tester.tap(find.byKey(const ValueKey('better-route-submit')));
      await tester.pumpAndSettle();

      final r = reports.sent.single;
      expect(r.legs, [
        {'kind': 'walk', 'distance_m': 300},
        {
          'kind': 'ride', 'source': 'network', 'vehicle_type': 'minibus', 'route_id': 'MB_66', 'route_number': '66',
          'route_description': 'Abbas El Akkad to Ramses', 'board_at': 'Abbas El Akkad', 'alight_at': 'Ramses',
          'fare_egp': 7.5,
        },
        {'kind': 'ride', 'source': 'typed', 'vehicle_type': 'microbus', 'typed_name': 'Gesr El Suez microbus', 'fare_egp': 10},
      ]);
      expect((r.legs[1]['fare_egp'] as num), isA<double>(), reason: 'a decimal fare stays decimal');
      expect(r.comment, 'Faster at rush hour');
      expect(r.startName, 'Nasr City');
      expect(r.endLon, 31.25);
      expect(r.shownOptions, hasLength(2));
      expect(r.toFields()['legs'], r.legs);
      // Sent: the builder closes and says so.
      expect(find.byType(BetterRouteBuilderScreen), findsNothing);
      expect(find.text('popped ${RouteReportOutcome.sent}'), findsOneWidget);
    });

    testWidgets('legs move up and down with their buttons', (tester) async {
      final (l10n, reports, _) = await pumpBuilder(tester);
      await tester.tap(find.byKey(const ValueKey('better-route-add-walk')));
      await tester.pumpAndSettle();
      await _addNetworkRide(tester, '66', 'MB_66');
      // The first leg can't go up, the last can't go down.
      IconButton rail(String tip, int n) =>
          tester.widget<IconButton>(find.ancestor(of: find.byTooltip(tip), matching: find.byType(IconButton)).at(n));
      expect(rail(l10n.betterRouteMoveUp, 0).onPressed, isNull);
      expect(rail(l10n.betterRouteMoveDown, 1).onPressed, isNull);
      await tester.tap(find.byTooltip(l10n.betterRouteMoveUp).at(1));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Minibus 66')).dy, lessThan(tester.getTopLeft(find.text(l10n.vehicleWalk)).dy));
      await tester.tap(find.byKey(const ValueKey('better-route-submit')));
      await tester.pumpAndSettle();
      expect([for (final l in reports.sent.single.legs) l['kind']], ['ride', 'walk']);
    });

    testWidgets('legs can be dragged into another order', (tester) async {
      final (_, reports, _) = await pumpBuilder(tester);
      for (var n = 0; n < 2; n++) {
        await tester.tap(find.byKey(const ValueKey('better-route-add-walk')));
        await tester.pumpAndSettle();
      }
      await tester.enterText(field('meters', 0), '100');
      await tester.enterText(field('meters', 1), '200');
      await _addNetworkRide(tester, '66', 'MB_66');
      // Drag the second walk above the first.
      final handles = find.byIcon(Icons.drag_indicator_rounded);
      final from = tester.getCenter(handles.at(1));
      final drag = await tester.startGesture(from);
      await tester.pump(const Duration(milliseconds: 100));
      final by = tester.getCenter(handles.at(1)).dy - tester.getCenter(handles.at(0)).dy;
      for (var k = 1; k <= 10; k++) {
        await drag.moveTo(from - Offset(0, by * k / 10));
        await tester.pump(const Duration(milliseconds: 30));
      }
      await drag.up();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('better-route-submit')));
      await tester.pumpAndSettle();
      expect([for (final l in reports.sent.single.legs) l['distance_m'] ?? l['route_id']], [200, 100, 'MB_66']);
    });

    testWidgets('a line can be changed and keeps what was said about the ride', (tester) async {
      final (l10n, reports, _) = await pumpBuilder(tester);
      await _addNetworkRide(tester, '66', 'MB_66');
      await tester.enterText(field('board', 0), 'Abbas El Akkad');
      await tester.tap(find.byTooltip(l10n.betterRouteChangeLine));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('better-route-line-search')), '67');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('better-route-line-MB_67')));
      await tester.pumpAndSettle();
      expect(find.text('Minibus 67'), findsOneWidget);
      expect(find.text('Abbas El Akkad'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('better-route-submit')));
      await tester.pumpAndSettle();
      expect(reports.sent.single.legs.single, containsPair('route_id', 'MB_67'));
      expect(reports.sent.single.legs.single, containsPair('board_at', 'Abbas El Akkad'));
    });

    testWidgets('Arabic digits and the Arabic decimal mark are read as numbers', (tester) async {
      final (_, reports, _) = await pumpBuilder(tester, locale: const Locale('ar'));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('better-route-add-walk')));
      await tester.pumpAndSettle();
      await tester.enterText(field('meters', 0), '٣٥٠');
      await _addNetworkRide(tester, '66', 'MB_66');
      expect(find.text('ميني باص 66'), findsOneWidget);
      await tester.enterText(field('fare', 0), '٧٫٥');
      await tester.tap(find.byKey(const ValueKey('better-route-submit')));
      await tester.pumpAndSettle();
      final r = reports.sent.single;
      expect(r.locale, 'ar');
      expect(r.legs[0]['distance_m'], 350);
      expect(r.legs[1]['fare_egp'], 7.5);
    });

    testWidgets("a report that couldn't go stays, with everything the rider built", (tester) async {
      final (l10n, reports, _) = await pumpBuilder(tester, outcome: RouteReportOutcome.notSignedIn);
      await _addNetworkRide(tester, '66', 'MB_66');
      await tester.tap(find.byKey(const ValueKey('better-route-submit')));
      await tester.pumpAndSettle();
      expect(reports.sent, hasLength(1));
      expect(find.byType(BetterRouteBuilderScreen), findsOneWidget);
      expect(find.text(l10n.reportSignInRequired), findsOneWidget);
      expect(find.text('Minibus 66'), findsOneWidget);
    });

    testWidgets('leaving with a route half built asks first', (tester) async {
      final (l10n, _, _) = await pumpBuilder(tester);
      await tester.tap(find.byKey(const ValueKey('better-route-add-walk')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(MaterialLocalizations.of(tester.element(find.byType(BetterRouteBuilderScreen))).backButtonTooltip));
      await tester.pumpAndSettle();
      expect(find.text(l10n.betterRouteDiscardTitle), findsOneWidget);
      await tester.tap(find.text(l10n.betterRouteDiscardStay));
      await tester.pumpAndSettle();
      expect(find.byType(BetterRouteBuilderScreen), findsOneWidget);
      await tester.tap(find.byTooltip(MaterialLocalizations.of(tester.element(find.byType(BetterRouteBuilderScreen))).backButtonTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('better-route-leave')));
      await tester.pumpAndSettle();
      expect(find.byType(BetterRouteBuilderScreen), findsNothing);
    });
  });

  group('the report', () {
    test('a leg keeps only what was said, and GTFS keys for a network line', () {
      final walk = BetterRouteLeg.walk();
      expect(walk.toReport(), {'kind': 'walk'});
      final line = BetterRouteLeg.line(_FakeApi.network.first)..boardAt = '  ';
      expect(line.toReport(), {
        'kind': 'ride', 'source': 'network', 'vehicle_type': 'minibus', 'route_id': 'MB_66', 'route_number': '66',
        'route_description': 'Abbas El Akkad to Ramses',
      });
      final typed = BetterRouteLeg.typed(vehicleType: 'microbus', name: ' Gesr El Suez ');
      expect(typed.toReport(), {'kind': 'ride', 'source': 'typed', 'vehicle_type': 'microbus', 'typed_name': 'Gesr El Suez'});
    });

    test('numbers in any digits', () {
      expect(BetterRouteLeg.parseNumber('12.5'), 12.5);
      expect(BetterRouteLeg.parseNumber('١٢٫٥'), 12.5);
      expect(BetterRouteLeg.parseNumber('۱۲,۵'), 12.5);
      expect(BetterRouteLeg.parseNumber('300'), 300);
      expect(BetterRouteLeg.parseNumber(''), isNull);
      expect(BetterRouteLeg.parseNumber('abc'), isNull);
    });

    test('the shown routes are capped', () {
      final many = [for (var i = 0; i < 12; i++) _option('Alternative', 40 + i, 'L$i', '$i')];
      expect(BetterRouteReport.summarize(many), hasLength(BetterRouteReport.maxShownOptions));
    });
  });
}

/// Adds a ride on a network line, found by searching [query].
Future<void> _addNetworkRide(WidgetTester tester, String query, String routeId) async {
  await tester.tap(find.byKey(const ValueKey('better-route-add-ride')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('better-route-line-search')), query);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('better-route-line-$routeId')));
  await tester.pumpAndSettle();
}
