import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guidy_app/services/saved_places_service.dart';
import 'package:guidy_app/screens/SavedPlacesScreen.dart';
import 'package:guidy_app/screens/LocationSearchScreen.dart';
import 'package:guidy_app/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SavedPlace Model Tests', () {
    test('round-trip serialization to and from JSON', () {
      final place = SavedPlace(
        id: 'place_123',
        label: 'Gym',
        name: 'Smart Club, Dokki, Giza',
        lat: 30.0384,
        lon: 31.2112,
        placeId: 'ChIJ123456789',
        coordsAt: 1710000000000,
      );

      final jsonMap = place.toJson();
      expect(jsonMap['id'], equals('place_123'));
      expect(jsonMap['label'], equals('Gym'));
      expect(jsonMap['name'], equals('Smart Club, Dokki, Giza'));
      expect(jsonMap['lat'], equals(30.0384));
      expect(jsonMap['lon'], equals(31.2112));
      expect(jsonMap['placeId'], equals('ChIJ123456789'));
      expect(jsonMap['coordsAt'], equals(1710000000000));

      final restored = SavedPlace.fromJson(jsonMap);
      expect(restored.id, equals(place.id));
      expect(restored.label, equals(place.label));
      expect(restored.name, equals(place.name));
      expect(restored.lat, equals(place.lat));
      expect(restored.lon, equals(place.lon));
      expect(restored.placeId, equals(place.placeId));
      expect(restored.coordsAt, equals(place.coordsAt));
    });

    test('fromJson gracefully handles string representation of coordinates', () {
      final jsonMap = {
        'id': 'place_str',
        'label': 'Work',
        'name': 'Smart Village, Cairo',
        'lat': '30.0755',
        'lon': '31.0211',
        'placeId': null,
        'coordsAt': null,
      };

      final restored = SavedPlace.fromJson(jsonMap);
      expect(restored.lat, closeTo(30.0755, 0.0001));
      expect(restored.lon, closeTo(31.0211, 0.0001));
      expect(restored.placeId, isNull);
      expect(restored.coordsAt, isNull);
    });

    test('copyWith properly updates specified fields while keeping others', () {
      final original = SavedPlace(
        id: 'p1',
        label: 'Home',
        name: 'Zamalek, Cairo',
        lat: 30.06,
        lon: 31.22,
        placeId: 'place_zamalek',
        coordsAt: 1000,
      );

      final modified = original.copyWith(
        lat: 30.07,
        lon: 31.23,
        coordsAt: 2000,
      );

      expect(modified.id, equals('p1'));
      expect(modified.label, equals('Home'));
      expect(modified.name, equals('Zamalek, Cairo'));
      expect(modified.placeId, equals('place_zamalek'));
      expect(modified.lat, equals(30.07));
      expect(modified.lon, equals(31.23));
      expect(modified.coordsAt, equals(2000));
    });
  });

  group('SavedPlacesService Storage & Expiration Policy Tests', () {
    test('getAll returns empty list when preferences are empty or corrupted', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await SavedPlacesService.getAll(), isEmpty);

      SharedPreferences.setMockInitialValues({'guidy_saved_places': 'invalid json{{'});
      expect(await SavedPlacesService.getAll(), isEmpty);
    });

    test('add and remove persist correctly in SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});

      final home = SavedPlace(
        id: 'h1',
        label: 'Home',
        name: 'Heliopolis, Cairo',
        lat: 30.09,
        lon: 31.33,
      );
      final work = SavedPlace(
        id: 'w1',
        label: 'Work',
        name: 'New Cairo AUC',
        lat: 30.02,
        lon: 31.49,
      );

      await SavedPlacesService.add(home);
      await SavedPlacesService.add(work);

      var list = await SavedPlacesService.getAll();
      expect(list.length, equals(2));
      expect(list.map((p) => p.label), containsAll(['Home', 'Work']));

      await SavedPlacesService.remove('h1');
      list = await SavedPlacesService.getAll();
      expect(list.length, equals(1));
      expect(list.first.label, equals('Work'));
    });

    test('map-tap places without placeId never expire and are always kept', () async {
      SharedPreferences.setMockInitialValues({});

      final mapTapPlace = SavedPlace(
        id: 'm1',
        label: 'Secret Fishing Spot',
        name: 'Nile Corniche, Maadi',
        lat: 29.96,
        lon: 31.25,
        placeId: null,
        coordsAt: null,
      );

      await SavedPlacesService.add(mapTapPlace);
      final list = await SavedPlacesService.getAll();
      expect(list.length, equals(1));
      expect(list.first.label, equals('Secret Fishing Spot'));
    });

    test('fresh Google Places places within 30 days are retained', () async {
      SharedPreferences.setMockInitialValues({});

      final freshTimestamp = DateTime.now()
          .subtract(const Duration(days: 5))
          .millisecondsSinceEpoch;

      final freshPlace = SavedPlace(
        id: 'g1',
        label: 'Fresh Place',
        name: 'Mall of Arabia, 6th of October',
        lat: 30.00,
        lon: 30.97,
        placeId: 'ChIJ_fresh_place',
        coordsAt: freshTimestamp,
      );

      await SavedPlacesService.add(freshPlace);
      final list = await SavedPlacesService.getAll();
      expect(list.length, equals(1));
      expect(list.first.id, equals('g1'));
    });

    test('expired Google Places (>30 days) are evicted when refresh fails', () async {
      SharedPreferences.setMockInitialValues({});

      final expiredTimestamp = DateTime.now()
          .subtract(const Duration(days: 35))
          .millisecondsSinceEpoch;

      final expiredPlace = SavedPlace(
        id: 'exp1',
        label: 'Old Gym',
        name: 'Dokki, Giza',
        lat: 30.04,
        lon: 31.21,
        placeId: 'ChIJ_expired_mock',
        coordsAt: expiredTimestamp,
      );

      final mapTapPlace = SavedPlace(
        id: 'keep1',
        label: 'Permanent Spot',
        name: 'Tahrir Square',
        lat: 30.044,
        lon: 31.235,
        placeId: null,
        coordsAt: null,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'guidy_saved_places',
        json.encode([expiredPlace.toJson(), mapTapPlace.toJson()]),
      );

      final results = await SavedPlacesService.getAll();
      expect(results.length, equals(1));
      expect(results.first.id, equals('keep1'));
      expect(results.first.label, equals('Permanent Spot'));
    });
  });

  group('SavedPlacesScreen Widget Tests', () {
    Widget buildScreen({Locale locale = const Locale('en')}) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: const SavedPlacesScreen(),
      );
    }

    testWidgets('renders empty state when no saved places exist', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Saved Places'), findsOneWidget);
      expect(find.text('No saved places yet. Tap below to add one.'), findsOneWidget);
      expect(find.text('Add a place'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('renders list of saved places with icons and titles', (tester) async {
      final home = SavedPlace(
        id: 'p_home',
        label: 'Home',
        name: 'Zamalek, 26th July Street',
        lat: 30.06,
        lon: 31.22,
      );
      final work = SavedPlace(
        id: 'p_work',
        label: 'Office',
        name: 'New Cairo 5th Settlement',
        lat: 30.01,
        lon: 31.44,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'guidy_saved_places',
        json.encode([home.toJson(), work.toJson()]),
      );

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Zamalek, 26th July Street'), findsOneWidget);
      expect(find.text('Office'), findsOneWidget);
      expect(find.text('New Cairo 5th Settlement'), findsOneWidget);
      expect(find.byIcon(Icons.place_outlined), findsNWidgets(2));
      expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));
    });

    testWidgets('canceling delete confirmation retains the place', (tester) async {
      final place = SavedPlace(
        id: 'p_del1',
        label: 'University',
        name: 'Cairo University, Giza',
        lat: 30.02,
        lon: 31.21,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('guidy_saved_places', json.encode([place.toJson()]));

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('University'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Remove this place?'), findsOneWidget);
      expect(find.text('You can always add it again later.'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('University'), findsOneWidget);
    });

    testWidgets('confirming delete removes the place and updates list', (tester) async {
      final place = SavedPlace(
        id: 'p_del2',
        label: 'Old Office',
        name: 'Maadi Degla',
        lat: 29.96,
        lon: 31.27,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('guidy_saved_places', json.encode([place.toJson()]));

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Old Office'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(find.text('Old Office'), findsNothing);
      expect(find.text('No saved places yet. Tap below to add one.'), findsOneWidget);
    });

    testWidgets('tapping saved place navigates to LocationSearchScreen', (tester) async {
      final place = SavedPlace(
        id: 'p_nav',
        label: 'My Gym',
        name: 'Dokki Club',
        lat: 30.04,
        lon: 31.21,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('guidy_saved_places', json.encode([place.toJson()]));

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('My Gym'));
      await tester.pumpAndSettle();

      expect(find.byType(LocationSearchScreen), findsOneWidget);
    });

    testWidgets('renders cleanly in Arabic locale without layout overflow', (tester) async {
      tester.view.physicalSize = const Size(390 * 2.5, 844 * 2.5);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);

      final place = SavedPlace(
        id: 'p_ar',
        label: 'المنزل',
        name: 'ميدان التحرير، وسط البلد',
        lat: 30.044,
        lon: 31.235,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('guidy_saved_places', json.encode([place.toJson()]));

      await tester.pumpWidget(buildScreen(locale: const Locale('ar')));
      await tester.pumpAndSettle();

      expect(find.text('الأماكن المحفوظة'), findsOneWidget);
      expect(find.text('المنزل'), findsOneWidget);
      expect(find.text('ميدان التحرير، وسط البلد'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
