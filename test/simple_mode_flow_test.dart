import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/HomeScreen.dart';
import 'package:guidy_app/screens/LocationSearchScreen.dart';
import 'package:guidy_app/screens/MainNavigator.dart';
import 'package:guidy_app/screens/MapScreen.dart';
import 'package:guidy_app/screens/RouteOptionsScreen.dart';
import 'package:guidy_app/screens/SettingsScreen.dart';
import 'package:guidy_app/services/notification_permission.dart';
import 'package:guidy_app/services/simple_mode.dart';
import 'package:guidy_app/services/trip_sharing.dart';
import 'package:guidy_app/theme/app_theme.dart';
import 'package:guidy_app/widgets/guidy_tour.dart';
import 'package:guidy_app/widgets/simple/simple_step_panel.dart';
import 'package:guidy_app/widgets/simple/simple_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Simple mode is one clear path for riders who are not comfortable with
// technology: "Where do you want to go?" -> pick a place -> the one to three
// easiest routes -> start -> one step at a time. Every control is at least
// 56 dp, has a word beside its icon and needs no swipe or long press.

Map<String, dynamic> _ride(String route, String vehicle, String from, String to, {bool ask = false}) => {
      'action': 'board',
      'station': from,
      'lat': 30.05,
      'lon': 31.24,
      'route_id': 'R$route',
      'route_number': route,
      'vehicle_type': vehicle,
      'fare_egp': 5,
      'ride_min': 12,
      'stops_count': 6,
      'alight_station': to,
      if (ask) 'ask_driver_en': 'Cine Plex',
      if (ask) 'ask_driver_ar': 'سينما بلكس',
      if (ask) 'hail': true,
    };

Map<String, dynamic> _option(String type, num time, List<Map<String, dynamic>> rides) => {
      'type': type,
      'time': '$time',
      'fare_egp': 5.0 * rides.length,
      'fare_total_egp': 5.0 * rides.length,
      'segments': [],
      'instructions': [
        {'action': 'walk_to_station', 'station': 'Stop A', 'lat': 30.05, 'lon': 31.24, 'distance_m': 200},
        ...rides,
        {'action': 'arrive', 'station': 'Stop Z', 'lat': 30.06, 'lon': 31.25},
        {'action': 'walk_to_destination', 'distance_m': 120},
      ],
    };

// Three changes, one change, none, two changes, and one that stops short.
List<Map<String, dynamic>> _options() => [
      _option('Fastest', 20, [_ride('1', 'bus', 'A', 'B'), _ride('2', 'metro', 'B', 'C'), _ride('3', 'bus', 'C', 'D')]),
      _option('Cheapest', 45, [_ride('4', 'minibus', 'A', 'B'), _ride('5', 'bus', 'B', 'C')]),
      _option('Recommended', 60, [_ride('6', 'microbus', 'A', 'Z', ask: true)]),
      _option('Alternative', 35, [_ride('7', 'bus', 'A', 'B'), _ride('8', 'bus', 'B', 'C')]),
      {..._option('Alternative', 5, [_ride('9', 'bus', 'A', 'B')]), 'partial': true},
    ];

Widget _app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

void _bigPhone(WidgetTester tester, {double height = 2400}) {
  tester.view.physicalSize = Size(1080, height);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.resetPhysicalSize);
}

/// Every SimpleButton on screen is a big, labelled target.
void _expectBigLabelledButtons(WidgetTester tester) {
  final buttons = find.byType(SimpleButton);
  expect(buttons, findsWidgets);
  for (final e in buttons.evaluate()) {
    final b = e.widget as SimpleButton;
    expect(b.label.trim(), isNotEmpty, reason: 'a button must have a word, not only an icon');
    final box = tester.getSize(find.byWidget(b));
    expect(box.height, greaterThanOrEqualTo(SimpleModeController.minTarget), reason: b.label);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // A rider who already answered the one-time trip-sharing ask; the
    // first-trip test below turns it back on.
    TripSharing.asked = true;
    MainNavigator.activeTabNotifier.value = 2;
    simpleMode.value = true;
    PackageInfo.setMockInitialValues(
      appName: 'Guidy',
      packageName: 'app.guidy',
      version: '1.1.0',
      buildNumber: '23',
      buildSignature: '',
    );
  });
  tearDown(() => simpleMode.value = false);

  group('the easiest routes', () {
    test('fewest vehicles first, then shortest, at most three, never an incomplete one', () {
      final order = SimpleModeController.easiest(_options());
      // none (60 min), then one change (35, 45); the three-vehicle route and
      // the partial route are left out.
      expect(order, [2, 3, 1]);
    });

    test('a route with nothing to follow is never offered', () {
      expect(SimpleModeController.easiest([{'type': 'x', 'time': '5', 'instructions': []}]), isEmpty);
    });
  });

  group('Home', () {
    testWidgets('one big question, Go home, Go to work and saved places', (tester) async {
      _bigPhone(tester);
      await tester.pumpWidget(_app(const HomeScreen()));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(tester.element(find.byType(HomeScreen)));

      expect(find.byKey(const ValueKey('simple_home')), findsOneWidget);
      expect(find.text(l10n.simpleWhereToGo), findsOneWidget);
      expect(find.text(l10n.simpleGoHome), findsOneWidget);
      expect(find.text(l10n.simpleGoWork), findsOneWidget);
      expect(find.text(l10n.simpleSavedPlaces), findsOneWidget);
      // Nothing set yet: the button says what to do instead of failing.
      expect(find.text(l10n.simpleTapToChoose), findsNWidgets(2));
      _expectBigLabelledButtons(tester);
    });

    testWidgets('the main button opens the search, which asks only for the destination', (tester) async {
      _bigPhone(tester);
      await tester.pumpWidget(_app(const HomeScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('simple_where_to')));
      await tester.pumpAndSettle();
      expect(find.byType(LocationSearchScreen), findsOneWidget);
    });

    testWidgets('a saved Home gets a Change button, not a long press', (tester) async {
      SharedPreferences.setMockInitialValues({'Home': 'Mom|30.05|31.24'});
      _bigPhone(tester);
      await tester.pumpWidget(_app(const HomeScreen()));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('simple_change_Home')), findsOneWidget);
      expect(find.byKey(const ValueKey('simple_change_Work')), findsNothing);
      expect(tester.getSize(find.byKey(const ValueKey('simple_change_Home'))).height,
          greaterThanOrEqualTo(SimpleModeController.minTarget));
    });

    testWidgets('normal mode keeps its own Home', (tester) async {
      simpleMode.value = false;
      _bigPhone(tester);
      await tester.pumpWidget(_app(const HomeScreen()));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('simple_home')), findsNothing);
      expect(find.byType(SimpleButton), findsNothing);
    });

    testWidgets('the bottom bar keeps Home, Trips and Settings, each with a word', (tester) async {
      _bigPhone(tester);
      await tester.pumpWidget(_app(const MainNavigator()));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationDestination), findsNWidgets(3));
      expect(find.widgetWithText(NavigationDestination, 'Home'), findsOneWidget);
      expect(find.widgetWithText(NavigationDestination, 'Trips'), findsOneWidget);
      expect(find.widgetWithText(NavigationDestination, 'Settings'), findsOneWidget);
    });
  });

  group('Search', () {
    Future<void> openSearch(WidgetTester tester, {bool withEnd = true}) async {
      _bigPhone(tester);
      await tester.pumpWidget(_app(LocationSearchScreen(
        key: UniqueKey(),
        initialStartLocation: const {'name': 'My Current Location', 'lat': 30.05, 'lon': 31.24},
        initialEndLocation: withEnd ? const {'name': 'Cine Plex', 'lat': 30.06, 'lon': 31.25} : null,
      )));
      await tester.pumpAndSettle();
    }

    testWidgets('asks "Where do you want to go?", shows the start as a sentence and hides the pin buttons', (tester) async {
      await openSearch(tester);
      final l10n = AppLocalizations.of(tester.element(find.byType(LocationSearchScreen)));
      expect(find.text(l10n.simpleWhereToGo), findsOneWidget);
      expect(find.byKey(const ValueKey('simple_from')), findsOneWidget);
      expect(find.byKey(const ValueKey('simple_start_field')), findsNothing);
      expect(find.byKey(const ValueKey('pin_start')), findsNothing);
      expect(find.byKey(const ValueKey('pin_end')), findsNothing);
      _expectBigLabelledButtons(tester);
    });

    testWidgets('Change starting point reveals the start box and a Use my location button', (tester) async {
      await openSearch(tester);
      await tester.tap(find.byKey(const ValueKey('simple_change_start')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('simple_start_field')), findsOneWidget);
      expect(find.byKey(const ValueKey('simple_use_my_location')), findsOneWidget);
    });

    testWidgets('Find routes appears once both places are chosen', (tester) async {
      await openSearch(tester);
      expect(find.byKey(const ValueKey('simple_find_routes')), findsOneWidget);
      await openSearch(tester, withEnd: false);
      expect(find.byKey(const ValueKey('simple_find_routes')), findsNothing);
    });
  });

  group('Route options', () {
    Future<AppLocalizations> openRoutes(WidgetTester tester) async {
      // Tall enough to build all three cards and the Home button at once.
      _bigPhone(tester, height: 5600);
      await tester.pumpWidget(_app(RouteOptionsScreen(
        startLat: 30.05,
        startLon: 31.24,
        startName: 'Home',
        endLat: 30.06,
        endLon: 31.25,
        endName: 'Cine Plex',
        initialData: {'success': true, 'options': _options()},
      )));
      await tester.pumpAndSettle();
      return AppLocalizations.of(tester.element(find.byType(RouteOptionsScreen)));
    }

    testWidgets('at most three big cards, fewest changes first, no filters, map sheet or share button', (tester) async {
      final l10n = await openRoutes(tester);

      expect(find.byKey(const ValueKey('simple_route_list')), findsOneWidget);
      for (final n in [1, 2, 3]) {
        expect(find.byKey(ValueKey('simple_start_$n')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('simple_start_4')), findsNothing);
      expect(find.text(l10n.simpleEasiest), findsOneWidget);
      // Plain words, in order: no changes, then one change twice.
      final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList();
      expect(texts.indexOf(l10n.simpleChanges(0)), lessThan(texts.indexOf(l10n.simpleChanges(1))));
      expect(find.text(l10n.simpleChanges(1)), findsNWidgets(2));
      expect(find.text(l10n.simpleChanges(2)), findsNothing);
      expect(find.text('Take microbus 6'), findsOneWidget);
      // Normal mode's chrome is gone.
      expect(find.byType(DraggableScrollableSheet), findsNothing);
      expect(find.byType(FilterChip), findsNothing);
      expect(find.byTooltip(l10n.shareRouteTooltip), findsNothing);
      expect(find.byType(SimpleHomeButton), findsOneWidget);
      _expectBigLabelledButtons(tester);
    });

    testWidgets('Start this trip opens the trip with no faint alternative routes', (tester) async {
      await openRoutes(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('simple_start_1')));
      await tester.tap(find.byKey(const ValueKey('simple_start_1')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      final trip = tester.widget<MapScreen>(find.byType(MapScreen));
      expect(trip.alternatives, isEmpty);
      expect(trip.endName, 'Cine Plex');
    });

    testWidgets('a first trip asks about sharing once, then opens', (tester) async {
      TripSharing.asked = false;
      await openRoutes(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('simple_start_1')));
      await tester.tap(find.byKey(const ValueKey('simple_start_1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('trip-share-ask')), findsOneWidget);
      expect(find.byType(MapScreen), findsNothing, reason: 'the trip waits for the answer');
      await tester.tap(find.byKey(const ValueKey('trip-share-ask-no')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.widget<MapScreen>(find.byType(MapScreen)).endName, 'Cine Plex');
      expect(TripSharing.asked, isTrue);
    });

    testWidgets('the same list in Arabic reads in Arabic', (tester) async {
      _bigPhone(tester);
      await tester.pumpWidget(_app(
        RouteOptionsScreen(
          startLat: 30.05,
          startLon: 31.24,
          startName: 'البيت',
          endLat: 30.06,
          endLon: 31.25,
          endName: 'سينما',
          initialData: {'success': true, 'options': _options()},
        ),
        locale: const Locale('ar'),
      ));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(tester.element(find.byType(RouteOptionsScreen)));
      expect(l10n.localeName, startsWith('ar'));
      expect(find.text(l10n.simpleStartTrip), findsAtLeastNWidgets(2));
      expect(l10n.simpleStartTrip, isNot(AppLocalizations.of(tester.element(find.byType(RouteOptionsScreen))).simpleBackHome));
      expect(find.text(l10n.simpleEasiest), findsOneWidget);
    });
  });

  group('Trip', () {
    MapScreen trip() => MapScreen(
          pathData: {
            'instructions': _option('Recommended', 30, [_ride('6', 'microbus', 'Stop A', 'Stop Z', ask: true)])['instructions'],
            'option': {'type': 'Recommended', 'time': '30', 'fare_egp': 5},
            'segments': [],
          },
          endName: 'Cine Plex',
        );

    Future<void> openTrip(WidgetTester tester) async {
      _bigPhone(tester);
      await tester.pumpWidget(_app(Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => trip())),
            child: const Text('go'),
          ),
        ),
      )));
      await tester.tap(find.text('go'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('shows one step at a time in plain words, with what to tell the driver', (tester) async {
      await openTrip(tester);
      final l10n = AppLocalizations.of(tester.element(find.byType(MapScreen)));
      expect(find.byKey(const ValueKey('simple_step_panel')), findsOneWidget);
      expect(find.byKey(const ValueKey('sheet_body')), findsNothing, reason: 'no sheet to drag');
      expect(find.text(l10n.simpleStepOf(1, 4)), findsOneWidget);
      expect(find.text(l10n.stepWalkToStreet), findsOneWidget, reason: 'the ride is waved down on the street');

      await tester.tap(find.byKey(const ValueKey('simple_next_step')));
      await tester.pump();
      expect(find.text(l10n.simpleStepOf(2, 4)), findsOneWidget);
      expect(find.text(l10n.simpleRideTo('Take microbus 6', 'Stop Z')), findsOneWidget);
      expect(find.text(l10n.simpleTellDriver('Cine Plex')), findsOneWidget);
      _expectBigLabelledButtons(tester);
    });

    testWidgets('Previous step goes back one step, and Next goes on again', (tester) async {
      await openTrip(tester);
      final l10n = AppLocalizations.of(tester.element(find.byType(MapScreen)));
      expect(find.byKey(const ValueKey('simple_prev_step')), findsNothing, reason: 'nothing before the first step');

      await tester.tap(find.byKey(const ValueKey('simple_next_step')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('simple_next_step')));
      await tester.pump();
      expect(find.text(l10n.simpleStepOf(3, 4)), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('simple_prev_step')));
      await tester.pump();
      expect(find.text(l10n.simpleStepOf(2, 4)), findsOneWidget);
      expect(find.text(l10n.simpleTellDriver('Cine Plex')), findsOneWidget, reason: 'the step reads as before');
      await tester.tap(find.byKey(const ValueKey('simple_prev_step')));
      await tester.pump();
      expect(find.text(l10n.simpleStepOf(1, 4)), findsOneWidget);
      expect(find.byKey(const ValueKey('simple_prev_step')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('simple_next_step')));
      await tester.pump();
      expect(find.text(l10n.simpleStepOf(2, 4)), findsOneWidget);
      _expectBigLabelledButtons(tester);
    });

    testWidgets('ending the trip, or pressing back, asks first and "keep going" stays', (tester) async {
      await openTrip(tester);
      final l10n = AppLocalizations.of(tester.element(find.byType(MapScreen)));

      await tester.tap(find.byKey(const ValueKey('simple_end_trip')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.simpleEndTripTitle), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('simple_confirm_no')));
      await tester.pumpAndSettle();
      expect(find.byType(MapScreen), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text(l10n.simpleEndTripTitle), findsOneWidget, reason: 'the phone back button asks too');
      await tester.tap(find.byKey(const ValueKey('simple_confirm_yes')));
      await tester.pumpAndSettle();
      expect(find.byType(MapScreen), findsNothing);
    });
  });

  group('Settings', () {
    testWidgets('a clear way out, and no advanced rows', (tester) async {
      _bigPhone(tester);
      await tester.pumpWidget(_app(const SettingsScreen()));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(tester.element(find.byType(SettingsScreen)));
      expect(find.text(l10n.simpleSettingsOn), findsOneWidget);
      expect(find.text(l10n.settingsReplayTutorial.toUpperCase()), findsNothing);
      // Deleting your data stays reachable (Play's data-deletion rule).
      expect(find.text(l10n.deleteGuestDataButton.toUpperCase()), findsOneWidget);
      expect(find.text(l10n.simpleModeLabel.toUpperCase()), findsNothing, reason: 'the switch is replaced by the big button');

      await tester.tap(find.byKey(const ValueKey('simple_turn_off')));
      await tester.pumpAndSettle();
      expect(simpleMode.value, isFalse);
      expect(find.text(l10n.simpleModeLabel.toUpperCase()), findsOneWidget);
    });
  });

  // Owner, 2026-10-30: simple mode is not offered on first launch; riders
  // turn it on in Settings. The launch asks for notifications instead.
  group('first launch', () {
    late int asked;
    setUp(() {
      asked = 0;
      NotificationPermission.debugRequest = () async => asked++;
    });
    tearDown(() => NotificationPermission.debugRequest = null);

    Future<void> launch(WidgetTester tester) async {
      simpleMode.value = false;
      GuidyTour.autoStart = true;
      addTearDown(() => GuidyTour.autoStart = false);
      _bigPhone(tester);
      await tester.pumpWidget(_app(const MainNavigator()));
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();
    }

    testWidgets('a new rider is not offered simple mode and gets the normal app and tour', (tester) async {
      await launch(tester);
      final l10n = AppLocalizations.of(tester.element(find.byType(MainNavigator)));
      expect(find.byType(AlertDialog), findsNothing);
      expect(simpleMode.value, isFalse);
      expect(find.byType(NavigationDestination), findsNWidgets(5));
      expect(find.text(l10n.tourWelcomeTitle), findsOneWidget);
    });

    testWidgets('notifications are asked for once, on the first launch only', (tester) async {
      await launch(tester);
      expect(asked, 1);
      expect((await SharedPreferences.getInstance()).getBool(NotificationPermission.askedKey), isTrue);

      // The next launch: not asked again.
      await tester.pumpWidget(const SizedBox());
      await launch(tester);
      expect(asked, 1);
    });
  });

  group('theme', () {
    test('buttons are at least 56 dp tall and read clearly', () {
      for (final theme in [AppTheme.light(const Locale('en'), simple: true), AppTheme.dark(const Locale('en'), simple: true)]) {
        for (final style in [
          theme.elevatedButtonTheme.style,
          theme.textButtonTheme.style,
          theme.outlinedButtonTheme.style,
        ]) {
          expect(style!.minimumSize!.resolve({})!.height, greaterThanOrEqualTo(56));
        }
      }
      // White on the brand navy, dark on the brand blue: both well past 4.5:1.
      double contrast(Color a, Color b) {
        final la = a.computeLuminance(), lb = b.computeLuminance();
        return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
      }

      expect(contrast(AppColors.brandNavy, Colors.white), greaterThan(7));
      expect(contrast(AppColors.brandBlue, AppColors.darkBackground), greaterThan(4.5));
    });

    test('normal mode is untouched', () {
      final theme = AppTheme.light(const Locale('en'));
      expect(theme.elevatedButtonTheme.style!.backgroundColor!.resolve({}), AppColors.brandBlue);
      expect(theme.textButtonTheme.style, isNull);
    });
  });

  group('SimpleStepText', () {
    test('walks to the street are not given a made-up place name', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final steps = [
        {'action': 'walk_to_station', 'station': 'Stop A', 'distance_m': 100},
        {'action': 'board', 'hail': true, 'station': 'Stop A', 'vehicle_type': 'microbus', 'route_number': '1'},
      ];
      expect(SimpleStepText.of(l10n, steps, 0).title, l10n.stepWalkToStreet);
    });
  });
}
