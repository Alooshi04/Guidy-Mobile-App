import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/RouteOptionsScreen.dart';
import 'package:guidy_app/widgets/route_options/route_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The beta reviewer on the route card (2026-11): "instead of 78 mins make
// it 1 hour 18 minutes"; drop the "every 12 min from X" line; "show how
// many metres I'll walk and the recommended minibus number"; and make the
// modes bigger with the room that frees.
Map<String, dynamic> _walk(String action, num m) => {'action': action, 'distance_m': m};

Map<String, dynamic> _ride(String vt, String id, String? number, {String action = 'board'}) => {
      'action': action,
      'hail': true,
      'station': 'Stop $id',
      'route_id': id,
      'route_number': number,
      'vehicle_type': vt,
      'fare_egp': 7.5,
      'ride_min': 20,
      'typical_headway_min': 12,
      'boarding_options': [
        {'route_id': id, 'route_number': number, 'vehicle_type': vt, 'is_primary': true, 'typical_headway_min': 12},
        {'route_id': '${id}_2', 'route_number': '9$number', 'vehicle_type': vt, 'typical_headway_min': 5},
      ],
    };

/// Walk 376 m, minibus 66, walk 120 m, metro line 3, a few steps (hidden).
Map<String, dynamic> _option({num time = 78, Map<String, dynamic>? extra}) => {
      'type': 'Recommended',
      'time': '$time',
      'fare_total_egp': 17.5,
      'segments': [],
      'instructions': <Map<String, dynamic>>[
        _walk('walk_to_station', 376),
        _ride('minibus', 'MB_66', '66'),
        _walk('walk_to_transfer', 120),
        _ride('metro', 'NAT_L3', '3', action: 'transfer'),
        {'action': 'arrive', 'station': 'Attaba'},
        _walk('walk_to_destination', 10),
      ],
      ...?extra,
    };

Future<AppLocalizations> _pump(WidgetTester tester,
    {required Map<String, dynamic> option, Locale locale = const Locale('en'), double width = 540, double scale = 1}) async {
  tester.view.physicalSize = Size(width * 2, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(() => tester.view.resetPhysicalSize());
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) =>
        MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
    home: RouteOptionsScreen(
      startLat: 30.05, startLon: 31.33, startName: 'Nasr City', endLat: 30.05, endLon: 31.25, endName: 'Attaba',
      initialData: {'success': true, 'options': [option]},
      showMap: false,
    ),
  ));
  await tester.pumpAndSettle();
  return AppLocalizations.of(tester.element(find.byType(RouteOptionsScreen)));
}

Finder _onCard(Finder f) => find.descendant(of: find.byKey(const ValueKey('route-card-0')), matching: f);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the total time', () {
    for (final (locale, minutes, lines, spoken) in [
      (const Locale('en'), 78, ['1 h', '18 min'], '1 h 18 min'),
      (const Locale('ar'), 78, ['ساعة', 'و18 دقيقة'], 'ساعة و18 دقيقة'),
      (const Locale('ar'), 125, ['ساعتين', 'و5 دقائق'], 'ساعتين و5 دقائق'),
      (const Locale('ar'), 190, ['3 ساعات', 'و10 دقائق'], '3 ساعات و10 دقائق'),
      (const Locale('ar'), 120, ['ساعتين'], 'ساعتين'),
      (const Locale('en'), 44, ['44 min'], '44 min'),
    ]) {
      testWidgets('$minutes min reads "$spoken" (${locale.languageCode})', (tester) async {
        await _pump(tester, option: _option(time: minutes), locale: locale, width: 360);
        expect(tester.takeException(), isNull);
        for (final l in lines) {
          expect(_onCard(find.text(l)), findsOneWidget, reason: l);
        }
        expect(_onCard(find.text('$minutes min')), minutes < 60 ? findsOneWidget : findsNothing);
        // Read out in one go (the card merges it into its own label).
        expect(tester.widget<Semantics>(find.byKey(const ValueKey('route-card-time'))).properties.label, spoken);
        if (lines.length == 2) {
          expect(tester.getTopLeft(_onCard(find.text(lines[1]))).dy,
              greaterThan(tester.getTopLeft(_onCard(find.text(lines[0]))).dy),
              reason: 'the minutes under the hours');
        }
      });
    }

    testWidgets('the detail page header says it the same way', (tester) async {
      await _pump(tester, option: _option(time: 78));
      await tester.tap(find.byKey(const ValueKey('route-card-0')));
      await tester.pumpAndSettle();
      final header = tester.widget<Text>(find.byKey(const ValueKey('route-detail-header')));
      expect(header.textSpan!.toPlainText(), startsWith('1 h 18 min'));
    });

    testWidgets('the quick-compare table says it the same way', (tester) async {
      await _pump(tester, option: _option(time: 78));
      // The table only shows with more than one route.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RouteOptionsScreen(
          startLat: 30.05, startLon: 31.33, startName: 'Nasr City', endLat: 30.05, endLon: 31.25, endName: 'Attaba',
          initialData: {'success': true, 'options': [_option(time: 78), {..._option(time: 50), 'type': 'Cheapest'}]},
          showMap: false,
        ),
      ));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(tester.element(find.byType(RouteOptionsScreen)));
      await tester.tap(find.text(l10n.quickCompareTab));
      await tester.pumpAndSettle();
      expect(find.text('1 h\n18 min'), findsOneWidget);
      expect(find.text('50 min'), findsWidgets);
    });
  });

  group('the modes', () {
    testWidgets('every walk shows its metres and every ride its planned line; a few steps show nothing', (tester) async {
      final l10n = await _pump(tester, option: _option());
      expect(_onCard(find.text('376 m')), findsOneWidget);
      expect(_onCard(find.text('Minibus 66')), findsOneWidget);
      expect(_onCard(find.text('120 m')), findsOneWidget);
      expect(_onCard(find.text('M3')), findsOneWidget);
      expect(_onCard(find.text('10 m')), findsNothing, reason: 'a negligible walk stays hidden');
      expect(_onCard(find.textContaining('966')), findsNothing, reason: 'only the planned line');
      expect(_onCard(find.byType(RouteWalkChip)), findsNWidgets(2));
      expect(_onCard(find.byType(RouteLineChip)), findsNWidgets(2));
      expect(tester.widgetList<Semantics>(_onCard(find.byType(Semantics))).map((s) => s.properties.label),
          contains('${l10n.vehicleWalk} 376 m, Minibus 66, ${l10n.vehicleWalk} 120 m, Metro M3'));
    });

    testWidgets('no "every X min from Y" line under the modes', (tester) async {
      final l10n = await _pump(tester, option: _option());
      expect(_onCard(find.textContaining('Stop MB_66')), findsNothing);
      expect(_onCard(find.textContaining('12 min')), findsNothing);
      expect(find.text(l10n.routeTierRecommended), findsOneWidget, reason: 'the one tag stays');
    });

    testWidgets('the chips are bigger than before', (tester) async {
      await _pump(tester, option: _option());
      for (final icon in tester.widgetList<Icon>(_onCard(find.descendant(
          of: find.byType(RouteLineChip), matching: find.byType(Icon))))) {
        expect(icon.size, greaterThanOrEqualTo(22));
      }
      final line = tester.widget<Text>(_onCard(find.text('Minibus 66')));
      expect(line.style!.fontSize, greaterThanOrEqualTo(15));
      expect(line.maxLines, isNull, reason: 'never cut');
      expect(line.overflow, isNot(TextOverflow.ellipsis));
    });

    testWidgets('in Arabic the modes read right to left', (tester) async {
      await _pump(tester, option: _option(), locale: const Locale('ar'));
      final walk = tester.getCenter(_onCard(find.text('376 م')));
      final minibus = tester.getCenter(_onCard(find.text('ميني باص 66')));
      expect(walk.dy, moreOrLessEquals(minibus.dy, epsilon: 8), reason: 'same line on a wide phone');
      expect(walk.dx, greaterThan(minibus.dx), reason: 'the first leg on the right');
    });

    testWidgets('in English left to right', (tester) async {
      await _pump(tester, option: _option());
      expect(tester.getCenter(_onCard(find.text('376 m'))).dx, lessThan(tester.getCenter(_onCard(find.text('Minibus 66'))).dx));
    });

    for (final locale in const [Locale('en'), Locale('ar')]) {
      testWidgets('a long route wraps onto another line instead of being cut (${locale.languageCode})', (tester) async {
        final long = _option(time: 140);
        (long['instructions'] as List<Map<String, dynamic>>).insertAll(4, [
          _walk('walk_to_transfer', 640),
          _ride('microbus', 'MC_1', null, action: 'transfer'),
          _walk('walk_to_transfer', 90),
          _ride('bus', 'CTA_871', '871', action: 'transfer'),
        ]);
        await _pump(tester, option: long, locale: locale, width: 360, scale: 1.3);
        expect(tester.takeException(), isNull);
        final chips = _onCard(find.byWidgetPredicate((w) => w is RouteWalkChip || w is RouteLineChip));
        expect(chips, findsNWidgets(8));
        final first = tester.getTopLeft(chips.first).dy;
        final last = tester.getTopLeft(chips.last).dy;
        expect(last, greaterThan(first + 10), reason: 'onto a second line');
      });
    }
  });

  testWidgets('nothing on the card uses a middle dot or a tilde', (tester) async {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      await _pump(tester,
          option: _option(extra: {
            'short_ride': {'saves_min': 15, 'extra_egp': 20},
          }),
          locale: locale);
      final texts = [
        for (final t in tester.widgetList<Text>(_onCard(find.byType(Text)))) t.data ?? t.textSpan?.toPlainText() ?? '',
      ];
      expect(texts, isNotEmpty);
      for (final s in texts) {
        expect(s, isNot(contains('·')), reason: s);
        expect(s, isNot(contains('~')), reason: s);
      }
    }
  });
}
