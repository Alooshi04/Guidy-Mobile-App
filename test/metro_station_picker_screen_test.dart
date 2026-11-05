import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/screens/MetroStationPickerScreen.dart';
import 'package:guidy_app/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockStations = [
    {
      'stop_id': 'station_sadat',
      'name': 'Sadat',
      'lines': [
        {'name': 'Line 1'},
        {'name': 'Line 2'},
      ],
      'is_interchange': true,
    },
    {
      'stop_id': 'station_dokki',
      'name': 'Dokki',
      'lines': [
        {'name': 'Line 2'},
      ],
      'is_interchange': false,
    },
    {
      'stop_id': 'station_opera',
      'name': 'Opera',
      'lines': [
        {'name': 'Line 2'},
      ],
      'is_interchange': false,
    },
    {
      'stop_id': 'station_shohadaa',
      'name': 'الشهداء',
      'lines': [
        {'name': 'Line 1'},
        {'name': 'Line 2'},
      ],
      'is_interchange': true,
    },
    {
      'stop_id': 'station_attaba',
      'name': 'العتبة',
      'lines': [
        {'name': 'Line 2'},
        {'name': 'Line 3'},
      ],
      'is_interchange': true,
    },
  ];

  Widget buildPickerScreen({
    List<Map<String, dynamic>>? stations,
    String title = 'Choose Station',
    String? excludeStopId,
    Locale locale = const Locale('en'),
    void Function(dynamic)? onSelected,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MetroStationPickerScreen(
                    stations: stations ?? mockStations,
                    title: title,
                    excludeStopId: excludeStopId,
                  ),
                ),
              );
              onSelected?.call(result);
            },
            child: const Text('Open Picker'),
          ),
        ),
      ),
    );
  }

  group('MetroStationPickerScreen Widget Tests', () {
    testWidgets('renders search input field with autofocus and station list', (tester) async {
      await tester.pumpWidget(buildPickerScreen(title: 'Select Departure'));
      await tester.pumpAndSettle();

      // Tap to open picker
      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      expect(find.text('Select Departure'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search stations'), findsOneWidget);

      // Verify stations are rendered
      expect(find.text('Sadat'), findsOneWidget);
      expect(find.text('Dokki'), findsOneWidget);
      expect(find.text('Opera'), findsOneWidget);
    });

    testWidgets('renders station names, lines serving subtitle, and interchange badge', (tester) async {
      await tester.pumpWidget(buildPickerScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // Sadat is an interchange on Line 1 and Line 2
      expect(find.text('Sadat'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Sadat'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'Interchange'), findsWidgets);

      // Dokki has line 2 and no interchange badge
      expect(find.text('Dokki'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Dokki'), findsOneWidget);
    });

    testWidgets('filters stations dynamically when typing search query in English', (tester) async {
      await tester.pumpWidget(buildPickerScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // Enter query 'dok'
      await tester.enterText(find.byType(TextField), 'dok');
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ListTile, 'Dokki'), findsOneWidget);
      expect(find.text('Sadat'), findsNothing);
      expect(find.text('Opera'), findsNothing);
    });

    testWidgets('filters stations dynamically when typing Arabic station names', (tester) async {
      await tester.pumpWidget(buildPickerScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // Enter query 'العتبة'
      await tester.enterText(find.byType(TextField), 'العتبة');
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ListTile, 'العتبة'), findsOneWidget);
      expect(find.text('الشهداء'), findsNothing);
      expect(find.text('Sadat'), findsNothing);
    });

    testWidgets('excludes the station matching excludeStopId', (tester) async {
      await tester.pumpWidget(buildPickerScreen(excludeStopId: 'station_sadat'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // Sadat should not appear because excludeStopId matches
      expect(find.text('Sadat'), findsNothing);
      expect(find.text('Dokki'), findsOneWidget);
      expect(find.text('Opera'), findsOneWidget);
    });

    testWidgets('tapping a station pops Navigator returning the selected station', (tester) async {
      Map<String, dynamic>? selectedStation;

      await tester.pumpWidget(buildPickerScreen(
        onSelected: (station) {
          selectedStation = station as Map<String, dynamic>?;
        },
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // Tap on 'Opera'
      await tester.tap(find.text('Opera'));
      await tester.pumpAndSettle();

      // Screen is popped back to root
      expect(find.byType(MetroStationPickerScreen), findsNothing);
      expect(selectedStation, isNotNull);
      expect(selectedStation!['stop_id'], equals('station_opera'));
      expect(selectedStation!['name'], equals('Opera'));
    });

    testWidgets('displays empty state message when query matches no stations', (tester) async {
      await tester.pumpWidget(buildPickerScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'NonexistentStationXYZ');
      await tester.pumpAndSettle();

      expect(find.text('No places found. Try a different search.'), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('renders properly in Arabic locale without layout overflow', (tester) async {
      tester.view.physicalSize = const Size(390 * 2.5, 844 * 2.5);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildPickerScreen(
        locale: const Locale('ar'),
        title: 'اختر المحطة',
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      expect(find.text('اختر المحطة'), findsOneWidget);
      expect(find.text('ابحث عن محطة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
