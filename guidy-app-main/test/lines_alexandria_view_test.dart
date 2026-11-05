import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/LineDetailScreen.dart';
import 'package:guidy_app/screens/LinesScreen.dart';
import 'package:guidy_app/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Serves a small network: Cairo lines in several modes, and Alexandria
/// lines in tram, bus, microbus and the Cairo-Alexandria microbuses only.
class _FakeApi extends ApiService {
  final List<Map<String, dynamic>> network;

  _FakeApi(this.network);

  @override
  Future<List<Map<String, dynamic>>> searchRoutes({
    String query = '',
    String? vehicleType,
    String lang = 'en',
    int limit = 40,
  }) async {
    final q = query.toLowerCase();
    return network.where((r) {
      if (vehicleType != null && r['vehicle_type'] != vehicleType) return false;
      if (q.isEmpty) return true;
      return '${r['number']} ${r['description']}'.toLowerCase().contains(q);
    }).toList();
  }
}

Map<String, dynamic> _line(
  String id,
  String type,
  String number,
  String description, {
  String? agency,
  num? fare,
}) => {
  'route_id': id,
  'agency': ?agency,
  'vehicle_type': type,
  'number': number,
  'description': description,
  'stop_count': 12,
  'fare_egp': ?fare,
};

final _network = <Map<String, dynamic>>[
  _line('65', 'bus', '65', 'Cairo bus', fare: 10),
  _line('M1', 'metro', 'M1', 'Cairo metro'),
  _line('mono', 'monorail', 'MM', 'Cairo monorail'),
  _line('brt1', 'brt', 'BRT', 'Ring road'),
  _line(
    'ALX_290',
    'bus',
    '290',
    'Alexandria APTA bus',
    agency: 'ALX_APTA',
    fare: 8,
  ),
  _line(
    'ALX_TRAM_1',
    'tram',
    'T1',
    'Alexandria tram',
    agency: 'ALX_TRAM',
    fare: 3,
  ),
  _line(
    'ALX_MICRO_7',
    'microbus',
    '7',
    'Alexandria microbus',
    agency: 'ALX_MICRO',
    fare: 5,
  ),
  _line(
    'ALX_IC_1',
    'microbus',
    '',
    'Cairo to Alexandria',
    agency: 'ALX_INTERCITY',
    fare: 120,
  ),
];

Widget _app(
  ApiService api, {
  Locale locale = const Locale('en'),
  LinesBackController? back,
}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: locale,
  home: LinesScreen(api: api, backController: back),
);

Future<void> _open(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  LinesBackController? back,
}) async {
  // Tall enough for the whole tile grid, which scrolls on a real phone.
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(_FakeApi(_network), locale: locale, back: back));
  await tester.pumpAndSettle();
}

final _toggle = find.byKey(const ValueKey('lines-alexandria-toggle'));

Future<void> _enterAlexandria(WidgetTester tester) async {
  await tester.tap(_toggle);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LinesScreen.resetAlexandriaView();
  });

  testWidgets('the full grid shows every mode and the Alexandria view is off', (
    tester,
  ) async {
    await _open(tester);
    expect(tester.widget<FilterChip>(_toggle).selected, isFalse);
    expect(find.text('Metro'), findsOneWidget);
    expect(find.text('Monorail'), findsOneWidget);
    expect(find.text('Alexandria Lines'), findsNothing);
  });

  testWidgets(
    'entering the Alexandria view shows only the modes that run there',
    (tester) async {
      await _open(tester);
      await _enterAlexandria(tester);

      expect(tester.widget<FilterChip>(_toggle).selected, isTrue);
      expect(find.text('Alexandria Lines'), findsOneWidget);
      // Bus, microbus and tram have Alexandria lines; metro, monorail, BRT,
      // minibus and the rest do not and are hidden.
      expect(find.text('Bus'), findsOneWidget);
      expect(find.text('Microbus'), findsOneWidget);
      expect(find.text('Tram'), findsOneWidget);
      expect(find.text('Metro'), findsNothing);
      expect(find.text('Monorail'), findsNothing);
      expect(find.text('Minibus'), findsNothing);
    },
  );

  testWidgets('a mode inside the Alexandria view lists only Alexandria lines', (
    tester,
  ) async {
    await _open(tester);
    await _enterAlexandria(tester);

    await tester.tap(find.text('Bus'));
    await tester.pumpAndSettle();

    expect(find.text('Alexandria Bus Lines'), findsOneWidget);
    expect(find.text('ALEXANDRIA APTA BUS'), findsOneWidget);
    expect(find.text('CAIRO BUS'), findsNothing);

    // Back goes to the Alexandria grid, not the full one.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Alexandria Lines'), findsOneWidget);
    expect(tester.widget<FilterChip>(_toggle).selected, isTrue);
    expect(find.text('Metro'), findsNothing);
  });

  testWidgets('Cairo-Alexandria intercity microbuses appear under Microbus', (
    tester,
  ) async {
    await _open(tester);
    await _enterAlexandria(tester);
    await tester.tap(find.text('Microbus'));
    await tester.pumpAndSettle();

    expect(find.text('ALEXANDRIA MICROBUS'), findsOneWidget);
    expect(find.text('CAIRO TO ALEXANDRIA'), findsOneWidget);
    expect(find.text('120 EGP'), findsOneWidget);
  });

  testWidgets(
    'tapping the toggle again, or Back on the Alexandria grid, leaves the view',
    (tester) async {
      await _open(tester);

      await _enterAlexandria(tester);
      await _enterAlexandria(tester);
      expect(tester.widget<FilterChip>(_toggle).selected, isFalse);
      expect(find.text('Metro'), findsOneWidget);

      await _enterAlexandria(tester);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(tester.widget<FilterChip>(_toggle).selected, isFalse);
      expect(find.text('Metro'), findsOneWidget);
    },
  );

  testWidgets(
    'the system back button (LinesBackController) steps out level by level',
    (tester) async {
      final controller = LinesBackController();
      await _open(tester, back: controller);
      expect(controller.handleBack(), isFalse);

      await _enterAlexandria(tester);
      await tester.tap(find.text('Tram'));
      await tester.pumpAndSettle();
      expect(find.text('Alexandria Tram Lines'), findsOneWidget);

      expect(controller.handleBack(), isTrue); // list -> Alexandria grid
      await tester.pumpAndSettle();
      expect(find.text('Alexandria Lines'), findsOneWidget);
      expect(controller.handleBack(), isTrue); // Alexandria grid -> full grid
      await tester.pumpAndSettle();
      expect(tester.widget<FilterChip>(_toggle).selected, isFalse);
      expect(
        controller.handleBack(),
        isFalse,
      ); // full grid: leave to MainNavigator
    },
  );

  testWidgets(
    'search works inside the Alexandria view and only finds Alexandria lines',
    (tester) async {
      await _open(tester);
      await _enterAlexandria(tester);

      await tester.enterText(find.byType(TextField), 'bus');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // "Cairo bus" matches the query too, but is not an Alexandria line.
      expect(find.text('ALEXANDRIA APTA BUS'), findsOneWidget);
      expect(find.text('CAIRO BUS'), findsNothing);
      expect(find.text('Alexandria Lines'), findsOneWidget);
    },
  );

  testWidgets('opening a line works and Back returns to the Alexandria view', (
    tester,
  ) async {
    await _open(tester);
    await _enterAlexandria(tester);
    await tester.tap(find.text('Tram'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(LineDetailScreen), findsOneWidget);

    Navigator.of(tester.element(find.byType(LineDetailScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(LineDetailScreen), findsNothing);
    expect(find.text('Alexandria Tram Lines'), findsOneWidget);
    expect(find.text('ALEXANDRIA TRAM'), findsOneWidget);
  });

  testWidgets('the Alexandria view is remembered when the screen is rebuilt', (
    tester,
  ) async {
    await _open(tester);
    await _enterAlexandria(tester);

    await tester.pumpWidget(const SizedBox());
    await _open(tester);
    expect(tester.widget<FilterChip>(_toggle).selected, isTrue);
    expect(find.text('Alexandria Lines'), findsOneWidget);
    expect(find.text('Metro'), findsNothing);
  });

  testWidgets('Arabic: Arabic title and an RTL header', (tester) async {
    await _open(tester, locale: const Locale('ar'));
    await _enterAlexandria(tester);
    expect(find.text('خطوط الإسكندرية'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('خطوط الإسكندرية'))),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('no Alexandria lines in the data shows an empty message', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(_FakeApi([_line('65', 'bus', '65', 'Cairo bus')])),
    );
    await tester.pumpAndSettle();
    await _enterAlexandria(tester);
    expect(
      find.text('No Alexandria lines are available right now.'),
      findsOneWidget,
    );
  });
}
