// Fixes from the review of the Figma redesign: what the Lines rows and the
// line header show, back navigation on the Lines grid, Arabic arrows, the
// language toggle on every header, the tool rail and the loading button.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/LineDetailScreen.dart';
import 'package:guidy_app/screens/LinesScreen.dart';
import 'package:guidy_app/services/locale_controller.dart';
import 'package:guidy_app/services/reference_cache.dart';
import 'package:guidy_app/services/transit_modes.dart';
import 'package:guidy_app/theme/guidy_ui.dart';
import 'package:guidy_app/widgets/guidy_tool_rail.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _greenBus = {
  'route_id': 'GRN_G1',
  'agency': 'GRN',
  'number': 'G1',
  'vehicle_type': 'bus',
  'from': 'Tahrir',
  'to': 'Maadi',
  'description': 'via Corniche',
  'stop_count': 12,
  'fare_egp': 45,
};

Widget _app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

void _bigScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(() => tester.view.resetPhysicalSize());
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ReferenceCache.clear();
  });

  group('Lines grid', () {
    testWidgets('shows seven mode tiles, the BRT one included', (tester) async {
      _bigScreen(tester);
      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.pumpWidget(_app(const LinesScreen()));
      await tester.pumpAndSettle();

      expect(find.text(l10n.navLines), findsOneWidget, reason: 'the grid is titled for every mode, not just buses');
      for (final m in ['bus', 'microbus', 'minibus', 'monorail', 'metro', 'lrt', 'brt']) {
        expect(find.text(TransitModes.label(l10n, m)), findsOneWidget, reason: '$m tile');
      }
    });

    testWidgets('a row keeps its variant and operator, and back returns to the grid', (tester) async {
      _bigScreen(tester);
      final l10n = lookupAppLocalizations(const Locale('en'));
      await ReferenceCache.write('routes_bus_en_2000', [_greenBus]);
      final back = LinesBackController();
      await tester.pumpWidget(_app(LinesScreen(backController: back)));
      await tester.pumpAndSettle();
      expect(back.handleBack(), isFalse, reason: 'already on the grid');

      await tester.tap(find.text(TransitModes.label(l10n, 'bus')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.linesOfMode(TransitModes.label(l10n, 'bus'))), findsOneWidget);
      expect(find.text('via Corniche'), findsOneWidget, reason: 'the variant tells same-number lines apart');
      expect(find.text('Green Bus'), findsOneWidget, reason: 'the operator is shown');

      // The system back button (through MainNavigator) goes to the grid.
      expect(back.handleBack(), isTrue);
      await tester.pumpAndSettle();
      expect(find.text(TransitModes.label(l10n, 'brt')), findsOneWidget);

      // So does the header arrow.
      await tester.tap(find.text(TransitModes.label(l10n, 'bus')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.navLines), findsOneWidget);
    });

    testWidgets("the header's language toggle redraws the lines in the new language", (tester) async {
      _bigScreen(tester);
      await localeController.setLocale(LocaleController.english);
      addTearDown(() => localeController.setLocale(LocaleController.english));
      final en = lookupAppLocalizations(const Locale('en'));
      await ReferenceCache.write('routes_bus_en_2000', [_greenBus]);
      await ReferenceCache.write('routes_bus_ar_2000', [
        {..._greenBus, 'from': 'التحرير', 'to': 'المعادي', 'description': 'عن طريق الكورنيش'},
      ]);
      await tester.pumpWidget(ValueListenableBuilder<Locale>(
        valueListenable: localeController,
        builder: (_, locale, _) => _app(const LinesScreen(), locale: locale),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text(TransitModes.label(en, 'bus')));
      await tester.pumpAndSettle();
      expect(find.text('TAHRIR'), findsOneWidget);

      await tester.tap(find.text('عربي'));
      await tester.pumpAndSettle();
      expect(find.text('التحرير'), findsOneWidget, reason: 'line names follow the language');
      expect(find.text('TAHRIR'), findsNothing);
    });

    testWidgets('direction arrows are not flipped twice in Arabic', (tester) async {
      _bigScreen(tester);
      final l10n = lookupAppLocalizations(const Locale('ar'));
      await ReferenceCache.write('routes_bus_ar_2000', [_greenBus]);
      await tester.pumpWidget(_app(const LinesScreen(), locale: const Locale('ar')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(TransitModes.label(l10n, 'bus')));
      await tester.pumpAndSettle();

      // arrow_forward/chevron_right already mirror in RTL (matchTextDirection).
      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
      expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsWidgets);
    });
  });

  testWidgets('line detail shows the fare by stage and the service hours', (tester) async {
    _bigScreen(tester);
    await ReferenceCache.write('route_detail_NAT_L1_en', {
      'route_id': 'NAT_L1',
      'number': '1',
      'vehicle_type': 'metro',
      'description': 'Helwan to New El Marg',
      'service_hours': '05:00 - 01:00',
      'directions': [
        {
          'from': 'Helwan',
          'towards': 'New El Marg',
          'stops': [
            {'name': 'Helwan', 'lat': 29.849, 'lon': 31.334},
            {'name': 'Sadat', 'lat': 30.044, 'lon': 31.235},
          ],
        },
      ],
    });
    await tester.pumpWidget(_app(const LineDetailScreen(routeId: 'NAT_L1', fallbackTitle: 'Line 1')));
    await tester.pumpAndSettle();

    expect(find.textContaining('1-9 stops: 10'), findsOneWidget, reason: 'the stage breakdown is back');
    expect(find.text('10 to 20 EGP'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('5:00 AM'), findsOneWidget);
    expect(find.text('Helwan to New El Marg'), findsOneWidget, reason: 'description shows beside the ends');
  });

  testWidgets("line detail's language toggle reloads the line in the new language", (tester) async {
    _bigScreen(tester);
    await localeController.setLocale(LocaleController.english);
    addTearDown(() => localeController.setLocale(LocaleController.english));
    Map<String, dynamic> detail(String a, String b) => {
          'route_id': 'NAT_L1',
          'number': '1',
          'vehicle_type': 'metro',
          'directions': [
            {
              'from': a,
              'towards': b,
              'stops': [
                {'name': a, 'lat': 29.849, 'lon': 31.334},
                {'name': b, 'lat': 30.044, 'lon': 31.235},
              ],
            },
          ],
        };
    await ReferenceCache.write('route_detail_NAT_L1_en', detail('Helwan', 'Sadat'));
    await ReferenceCache.write('route_detail_NAT_L1_ar', detail('حلوان', 'السادات'));
    await tester.pumpWidget(ValueListenableBuilder<Locale>(
      valueListenable: localeController,
      builder: (_, locale, _) => _app(const LineDetailScreen(routeId: 'NAT_L1', fallbackTitle: 'Line 1'), locale: locale),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Sadat'), findsWidgets);

    await tester.tap(find.text('عربي'));
    await tester.pumpAndSettle();
    expect(find.text('السادات'), findsWidgets, reason: 'stop names follow the language');
    expect(find.text('Sadat'), findsNothing);
  });

  testWidgets('every GuidyHeader has the language toggle, and it switches language', (tester) async {
    await localeController.setLocale(LocaleController.english);
    addTearDown(() => localeController.setLocale(LocaleController.english));
    await tester.pumpWidget(ValueListenableBuilder<Locale>(
      valueListenable: localeController,
      builder: (_, locale, _) => _app(const Scaffold(body: GuidyHeader(title: 'Trips')), locale: locale),
    ));
    await tester.tap(find.text('عربي'));
    await tester.pumpAndSettle();
    expect(localeController.isArabic, isTrue);
    expect(find.text('EN'), findsOneWidget);
  });

  group('tool rail', () {
    Widget rail(List<String> log, {Locale locale = const Locale('en')}) => _app(
          locale: locale,
          Scaffold(
            body: Align(
              alignment: AlignmentDirectional.topEnd,
              child: GuidyToolRail(
                showTooltip: 'Show tools',
                hideTooltip: 'Hide tools',
                lead: GuidyToolRailItem(icon: Icons.map_outlined, tooltip: 'Overview', onTap: () => log.add('overview')),
                items: [
                  GuidyToolRailItem(icon: Icons.calculate_outlined, tooltip: 'Calculator', onTap: () => log.add('calc')),
                  GuidyToolRailItem(
                    icon: Icons.bookmark_border_rounded,
                    activeIcon: Icons.bookmark_rounded,
                    tooltip: 'Save',
                    active: true,
                    onTap: () => log.add('save'),
                  ),
                ],
              ),
            ),
          ),
        );

    testWidgets('runs its tools and folds into the menu tab', (tester) async {
      final log = <String>[];
      await tester.pumpWidget(rail(log));
      await tester.tap(find.byTooltip('Overview'));
      await tester.tap(find.byTooltip('Calculator'));
      expect(log, ['overview', 'calc']);
      expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget, reason: 'active item shows its filled icon');

      await tester.tap(find.byTooltip('Hide tools'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Calculator'), findsNothing);
      expect(find.byTooltip('Show tools'), findsOneWidget);

      await tester.tap(find.byTooltip('Show tools'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Calculator'), findsOneWidget);
    });

    testWidgets('lays out in Arabic too', (tester) async {
      await tester.pumpWidget(rail([], locale: const Locale('ar')));
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Overview'), findsOneWidget);
    });

    testWidgets('the tools run left from the menu, which sits on the screen edge', (tester) async {
      await tester.pumpWidget(rail([]));
      final menu = tester.getCenter(find.byTooltip('Hide tools'));
      final calc = tester.getCenter(find.byTooltip('Calculator'));
      final lead = tester.getCenter(find.byTooltip('Overview'));
      expect(calc.dy, moreOrLessEquals(menu.dy, epsilon: 0.5), reason: 'one row, not a column');
      expect(lead.dy, moreOrLessEquals(menu.dy, epsilon: 0.5));
      expect(menu.dx, greaterThan(calc.dx), reason: 'LTR: the edge is on the right');
      expect(calc.dx, greaterThan(lead.dx));
    });

    testWidgets('is only one row tall, so what sits under it moves up', (tester) async {
      await tester.pumpWidget(rail([]));
      expect(tester.getSize(find.byKey(const ValueKey('open'))).height, 46);
    });

    testWidgets('mirrors in Arabic: the menu on the left edge, tools running right', (tester) async {
      await tester.pumpWidget(rail([], locale: const Locale('ar')));
      final menu = tester.getCenter(find.byTooltip('Hide tools'));
      final calc = tester.getCenter(find.byTooltip('Calculator'));
      final lead = tester.getCenter(find.byTooltip('Overview'));
      expect(calc.dy, moreOrLessEquals(menu.dy, epsilon: 0.5));
      expect(menu.dx, lessThan(calc.dx));
      expect(calc.dx, lessThan(lead.dx));
    });
  });

  testWidgets('a loading gradient button shows a spinner and ignores taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(Scaffold(
      body: GuidyGradientButton(label: 'PLAN', onPressed: () => taps++, loading: true),
    )));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('PLAN'));
    expect(taps, 0);
  });
}
