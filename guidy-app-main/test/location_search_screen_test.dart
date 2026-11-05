import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guidy_app/screens/LocationSearchScreen.dart';
import 'package:guidy_app/screens/RouteOptionsScreen.dart';
import 'package:guidy_app/services/search_history_service.dart';
import 'package:guidy_app/services/saved_places_service.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/services/current_place_namer.dart';
import 'package:guidy_app/services/maps_link_parser.dart';

// The route options screen animates while it loads, so it never settles.
Future<void> _pumpFor(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}


/// A phone that is now somewhere other than where the app first looked.
class _MovedGeolocator extends GeolocatorPlatform {
  _MovedGeolocator(this.lat, this.lon);
  final double lat, lon;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async => LocationPermission.whileInUse;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async => Position(
        latitude: lat,
        longitude: lon,
        timestamp: DateTime(2026, 10, 22),
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
}

/// A GPS that answers only when the test says so (a permission dialog, a slow fix).
class _SlowGeolocator extends _MovedGeolocator {
  _SlowGeolocator() : super(30.06, 31.379);
  final gate = Completer<void>();
  bool fail = false;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async {
    await gate.future;
    if (fail) throw Exception('no fix');
    return super.getCurrentPosition(locationSettings: locationSettings);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SearchHistoryService.clear();
  });

  Widget buildSearchScreen({
    Map<String, dynamic>? initialStart,
    Map<String, dynamic>? initialEnd,
    Locale locale = const Locale('en'),
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: LocationSearchScreen(
        initialStartLocation: initialStart,
        initialEndLocation: initialEnd,
      ),
    );
  }

  group('LocationSearchScreen Widget Tests', () {
    for (final fail in [false, true]) {
      testWidgets('leaving while the GPS is still working is harmless (${fail ? 'fix fails' : 'fix arrives'})',
          (tester) async {
        final original = GeolocatorPlatform.instance;
        final slow = _SlowGeolocator()..fail = fail;
        GeolocatorPlatform.instance = slow;
        addTearDown(() => GeolocatorPlatform.instance = original);
        await tester.pumpWidget(buildSearchScreen());
        await tester.pump();
        await tester.tap(find.byIcon(Icons.my_location).first);
        await tester.pump();
        // Back out of the screen while the fix is pending.
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        slow.gate.complete();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a current-location start shows the street name', (tester) async {
      CurrentPlaceNamer.resolve = (lat, lon, {required fallbackLabel, lang = 'en'}) async => 'Mostafa El Nahas St.';
      addTearDown(() => CurrentPlaceNamer.resolve = MapsLinkParser.reverseGeocodeName);
      await tester.pumpWidget(buildSearchScreen(
        initialStart: CurrentPlaceNamer.place(lat: 30.06, lon: 31.379, fallbackLabel: 'My Current Location'),
      ));
      await tester.pump();
      await tester.pump();
      expect(find.text('Mostafa El Nahas St.'), findsOneWidget);
      expect(find.text('My Current Location'), findsNothing);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('a current-location start from earlier is refreshed to where the rider is now', (tester) async {
      // Home looked once, at launch; the rider has since travelled to Sidi Gaber.
      final original = GeolocatorPlatform.instance;
      GeolocatorPlatform.instance = _MovedGeolocator(31.2196, 29.9422);
      CurrentPlaceNamer.resolve = (lat, lon, {required fallbackLabel, lang = 'en'}) async =>
          lat > 31.21 ? 'Sidi Gaber St.' : 'Bacos St.';
      addTearDown(() {
        GeolocatorPlatform.instance = original;
        CurrentPlaceNamer.resolve = MapsLinkParser.reverseGeocodeName;
      });
      await tester.pumpWidget(buildSearchScreen(
        initialStart: CurrentPlaceNamer.place(lat: 31.2000, lon: 29.9000, fallbackLabel: 'My Current Location'),
      ));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Sidi Gaber St.'), findsOneWidget);
      expect(find.text('Bacos St.'), findsNothing);
    });

    testWidgets('both fields can drop a pin; there is no separate drop-pin row', (tester) async {
      await tester.pumpWidget(buildSearchScreen());
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.byIcon(Icons.my_location), findsOneWidget);
      expect(find.byKey(const ValueKey('pin_start')), findsOneWidget);
      expect(find.byKey(const ValueKey('pin_end')), findsOneWidget);

      for (final field in [find.byType(TextField).first, find.byType(TextField).last]) {
        await tester.tap(field);
        await tester.pumpAndSettle();
        expect(find.text('Drop pin for destination'), findsNothing);
        expect(find.byIcon(Icons.pin_drop), findsNothing);
      }
    });

    testWidgets('quick destinations fill whichever field is being edited', (tester) async {
      SharedPreferences.setMockInitialValues({'Home': 'Nasr City Flat|30.05|31.33'});
      await SavedPlacesService.add(SavedPlace(id: '1', label: 'Gym', name: 'Gold Gym Maadi', lat: 29.96, lon: 31.25));

      await tester.pumpWidget(buildSearchScreen());
      await tester.pumpAndSettle();

      // The start field has focus first: Home becomes the start.
      await tester.tap(find.byKey(const ValueKey('quick_Home')));
      await tester.pumpAndSettle();
      expect(find.text('Nasr City Flat'), findsOneWidget);

      // Then the destination is being edited: a saved place becomes it.
      await tester.tap(find.byKey(const ValueKey('quick_saved_1')));
      await tester.pumpAndSettle();
      expect(find.text('Gold Gym Maadi'), findsOneWidget);
      expect(find.text('Find Routes'), findsOneWidget);
    });

    testWidgets('populates initial locations when provided and displays Find Routes button', (tester) async {
      final start = {'name': 'Ramses Station', 'lat': 30.06, 'lon': 31.25};
      final end = {'name': 'Tahrir Square', 'lat': 30.04, 'lon': 31.23};

      await tester.pumpWidget(buildSearchScreen(initialStart: start, initialEnd: end));
      await tester.pumpAndSettle();

      // Displayed as hint text in the fields
      expect(find.text('Ramses Station'), findsOneWidget);
      expect(find.text('Tahrir Square'), findsOneWidget);

      // Find Routes button should be visible when both endpoints are selected
      expect(find.text('Find Routes'), findsOneWidget);
    });

    // Back from the route options returns here with both places still
    // filled in -- this screen used to replace itself, so back went home.
    testWidgets('back from the route options returns to the search as it was', (tester) async {
      final start = {'name': 'Ramses Station', 'lat': 30.06, 'lon': 31.25};
      final end = {'name': 'Tahrir Square', 'lat': 30.04, 'lon': 31.23};
      await tester.pumpWidget(buildSearchScreen(initialStart: start, initialEnd: end));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Find Routes'));
      await _pumpFor(tester);
      expect(find.byType(RouteOptionsScreen), findsOneWidget);

      await tester.binding.handlePopRoute();
      await _pumpFor(tester);
      expect(find.byType(RouteOptionsScreen), findsNothing);
      expect(find.byType(LocationSearchScreen), findsOneWidget);
      expect(find.text('Ramses Station'), findsOneWidget);
      expect(find.text('Tahrir Square'), findsOneWidget);

      // And a new search can be started again.
      await tester.tap(find.text('Find Routes'));
      await _pumpFor(tester);
      expect(find.byType(RouteOptionsScreen), findsOneWidget);
    });

    testWidgets('clearing destination resets end location and hides Find Routes button', (tester) async {
      final start = {'name': 'Ramses Station', 'lat': 30.06, 'lon': 31.25};
      final end = {'name': 'Tahrir Square', 'lat': 30.04, 'lon': 31.23};

      await tester.pumpWidget(buildSearchScreen(initialStart: start, initialEnd: end));
      await tester.pumpAndSettle();

      expect(find.text('Find Routes'), findsOneWidget);

      final closeButton = find.byIcon(Icons.close);
      expect(closeButton, findsOneWidget);

      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      // With end cleared, Find Routes button is removed
      expect(find.text('Find Routes'), findsNothing);
      expect(find.text('Tahrir Square'), findsNothing);
    });

    testWidgets('shows recent searches from SearchHistoryService and clears on demand', (tester) async {
      await SearchHistoryService.addSearch('Cairo Festival City', 30.02, 31.40);
      await SearchHistoryService.addSearch('Maadi Grand Mall', 29.96, 31.28);

      await tester.pumpWidget(buildSearchScreen());
      await tester.pumpAndSettle();

      expect(find.text('RECENT'), findsOneWidget);
      expect(find.text('Cairo Festival City'), findsOneWidget);
      expect(find.text('Maadi Grand Mall'), findsOneWidget);

      // Clear history button works
      final clearBtn = find.text('Clear');
      expect(clearBtn, findsOneWidget);

      await tester.tap(clearBtn);
      await tester.pumpAndSettle();

      expect(find.text('Cairo Festival City'), findsNothing);
      expect(find.text('RECENT'), findsNothing);
    });

    testWidgets('pasting bare coordinates into search field handles resolution', (tester) async {
      await tester.pumpWidget(buildSearchScreen());
      await tester.pumpAndSettle();

      final firstTextField = find.byType(TextField).first;
      await tester.enterText(firstTextField, '30.0444, 31.2357');
      await tester.pumpAndSettle();

      // MapsLinkParser recognizes it as coordinates and handles it safely without crashing
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders properly in Arabic locale without layout overflow', (tester) async {
      tester.view.physicalSize = const Size(390 * 2.5, 844 * 2.5);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildSearchScreen(locale: const Locale('ar')));
      await tester.pumpAndSettle();

      expect(find.byType(LocationSearchScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
