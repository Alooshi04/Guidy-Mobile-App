import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/services/route_report_service.dart';
import 'package:guidy_app/widgets/line_report_sheet.dart';
import 'package:guidy_app/widgets/metro_report_sheet.dart';
import 'package:guidy_app/screens/TripRecapScreen.dart';
import 'package:guidy_app/screens/HistoryScreen.dart';
import 'package:guidy_app/screens/RouteOptionsScreen.dart';
import 'package:guidy_app/services/trip_history_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('RouteReportReason & Metro/Line Enum Tests', () {
    test('LineReportReason has valid IDs and readable English labels', () {
      for (final reason in LineReportReason.values) {
        expect(reason.id, isNotEmpty);
        expect(reason.englishLabel, isNotEmpty);
      }
      expect(LineReportReason.routeDoesNotExist.id, 'route_does_not_exist');
      expect(LineReportReason.wrongPath.id, 'wrong_path');
      expect(LineReportReason.wrongStop.id, 'wrong_stop');
      expect(LineReportReason.wrongFare.id, 'wrong_fare');
      expect(LineReportReason.badTiming.id, 'bad_timing');
      expect(LineReportReason.other.id, 'other');
    });

    test('MetroReportReason has valid IDs and readable English labels', () {
      for (final reason in MetroReportReason.values) {
        expect(reason.id, isNotEmpty);
        expect(reason.englishLabel, isNotEmpty);
      }
      expect(MetroReportReason.stationClosed.id, 'station_closed');
      expect(MetroReportReason.wrongTransfer.id, 'wrong_transfer');
      expect(MetroReportReason.wrongFare.id, 'wrong_fare');
      expect(MetroReportReason.delayOrDisruption.id, 'delay_or_disruption');
      expect(MetroReportReason.other.id, 'other');
    });
  });

  group('LineReportSheet Widget Tests', () {
    testWidgets('renders route information, reason chips, and stop dropdown',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: LineReportSheet(
              routeId: 'cta_1073',
              routeNumber: '1073',
              routeDescription: 'Abbassiya to New Cairo',
              vehicleType: 'bus',
              directionIndex: 0,
              directionTerminus: 'New Cairo AUC',
              stops: const [
                {'name': 'Abbassiya', 'name_en': 'Abbassiya'},
                {'name': 'Ramses', 'name_en': 'Ramses'},
                {'name': 'Nasr City', 'name_en': 'Nasr City'},
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Report Line Issue'), findsOneWidget);
      expect(find.text('1073'), findsOneWidget);
      expect(find.text('New Cairo AUC'), findsOneWidget);
      expect(find.text('Select affected stop (optional)'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsWidgets);
      expect(find.text('Submit Report'), findsOneWidget);
    });
  });

  group('MetroReportSheet Widget Tests', () {
    testWidgets('renders metro plan info and reason chips',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MetroReportSheet(
              metroPlan: const {
                'from': 'Sadat',
                'to': 'Dokki',
                'fare_egp': 10,
                'stops_count': 3,
                'interchanges': [],
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Report Metro Issue'), findsOneWidget);
      expect(find.text('Sadat ➔ Dokki'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsWidgets);
      expect(find.text('Submit Report'), findsOneWidget);
    });

    testWidgets('renders station info when opened from station sheet',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: MetroReportSheet(
              station: {
                'name': 'الشهداء',
                'lines': ['L1', 'L2'],
                'is_interchange': true,
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('بلّغ عن مشكلة في المترو'), findsOneWidget);
      expect(find.text('الشهداء'), findsOneWidget);
      expect(find.text('ابعت البلاغ'), findsOneWidget);
    });
  });

  group('TripRecapScreen Timeline Tests', () {
    testWidgets('renders connected vertical timeline with mode icons and instructions',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dummyOption = {
        'type': 'Recommended',
        'time': 25,
        'fare_total_egp': 12,
        'distance_m': 6200,
        'vehicle_type': 'metro',
        'metro_stops': 5,
        'instructions': [
          {
            'action': 'walk_to_station',
            'distance_m': 200,
            'station': 'Dokki',
            'vehicle_type': 'walk',
          },
          {
            'action': 'board',
            'vehicle_type': 'metro',
            'route_number': 'L2',
            'station': 'Dokki',
            'fare_egp': 10,
          },
          {
            'action': 'arrive',
            'station': 'Sadat',
          },
          {
            'action': 'walk_to_destination',
            'distance_m': 150,
            'vehicle_type': 'walk',
          },
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TripRecapScreen(
            option: dummyOption,
            pathData: dummyOption,
            startName: 'Dokki Square',
            endName: 'Tahrir Square',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dokki Square'), findsWidgets);
      expect(find.text('Tahrir Square'), findsWidgets);
      expect(find.text('Start Navigation'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  group('Smart Route Customizer & History Polish Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await TripHistoryService.clearHistory();
    });

    testWidgets('HistoryScreen displays top savings pills and extensive trip details without sample seeding buttons',
        (WidgetTester tester) async {
      await TripHistoryService.recordTrip(
        startName: 'Maadi Station',
        endName: 'Tahrir Square',
        pathData: {'distance_km': 14.2},
        option: {
          'time': 32,
          'fare_egp': 12,
          'mode': 'metro',
          'route': 'Line 1',
          'ride_hail_comparison': {'fare_egp': 95, 'duration_min': 55},
        },
        chosenProfile: 'fastest',
      );

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HistoryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify top savings pills are rendered
      expect(find.text('Money Saved'), findsOneWidget);
      expect(find.text('Time Saved'), findsOneWidget);

      // Verify sample demo buttons are completely removed
      expect(find.text('Load Demo Trips'), findsNothing);
      expect(find.text('عرض نموذج توفير تجريبي'), findsNothing);

      // Verify extensive details in trip card
      expect(find.text('Maadi Station'), findsOneWidget);
      expect(find.text('Tahrir Square'), findsOneWidget);
      expect(find.text('Duration'), findsOneWidget);
      expect(find.text('Distance'), findsOneWidget);
      expect(find.text('Fare Paid'), findsOneWidget);
      expect(find.text('View Trip Details'), findsOneWidget);
    });

    testWidgets('Route chooser lists every route, marks the best one and has no customizer',
        (WidgetTester tester) async {
      final mockPathData = {
        'distance_km': 15.0,
        'options': [
          {
            'type': 'Fastest',
            'time': 35,
            'fare_total_egp': 10,
            'vehicle_type': 'metro',
            'instructions': [
              {'action': 'board', 'vehicle_type': 'metro', 'route_number': '2', 'route_id': 'M2', 'station': 'Giza'},
              {'action': 'arrive', 'station': 'Ramses'},
            ],
          },
          {
            'type': 'Cheapest',
            'time': 50,
            'fare_total_egp': 8,
            'vehicle_type': 'bus',
            'instructions': [
              {
                'action': 'board',
                'vehicle_type': 'bus',
                'route_number': '102',
                'route_id': 'CTA_102',
                'agency': 'CTA',
                'station': 'Giza',
                'boarding_options': [
                  {'route_id': 'CTA_102', 'route_number': '102', 'vehicle_type': 'bus', 'is_primary': true, 'fare_egp': 8},
                  {'route_id': 'CTA_103', 'route_number': '103', 'vehicle_type': 'bus', 'fare_egp': 9},
                ],
              },
              {'action': 'arrive', 'station': 'Ramses'},
            ],
          },
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RouteOptionsScreen(
            startLat: 30.01,
            startLon: 31.21,
            startName: 'Giza Square',
            endLat: 30.06,
            endLon: 31.24,
            endName: 'Ramses Station',
            initialData: mockPathData,
            showMap: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Customize Your Route'), findsNothing);
      expect(find.text('Alternative'), findsNothing);
      // Each route carries its one tier tag.
      expect(find.text('Fastest'), findsOneWidget);
      expect(find.text('Cheapest'), findsOneWidget);
      expect(find.text('35 min'), findsWidgets);
      expect(find.text('50 min'), findsWidgets);

      // Choosing the second route opens its detail page: its legs, each
      // listing its lines, and Start.
      await tester.tap(find.text('50 min').first);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('timeline-lines-0')), findsOneWidget);
      expect(find.text('Start trip'), findsOneWidget);
    });
  });
}
