import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/RouteOptionsScreen.dart';
import 'package:guidy_app/services/instruction_formatter.dart';

void main() {
  group('InstructionFormatter.asNum tests', () {
    test('converts ints and doubles', () {
      expect(InstructionFormatter.asNum(42), equals(42));
      expect(InstructionFormatter.asNum(3.14), equals(3.14));
      expect(InstructionFormatter.asNum(0), equals(0));
    });

    test('converts numeric strings from backend', () {
      expect(InstructionFormatter.asNum('59'), equals(59));
      expect(InstructionFormatter.asNum('13670'), equals(13670));
      expect(InstructionFormatter.asNum(' 20 '), equals(20));
      expect(InstructionFormatter.asNum('12.5'), equals(12.5));
    });

    test('returns null for non-numeric or null inputs', () {
      expect(InstructionFormatter.asNum(null), isNull);
      expect(InstructionFormatter.asNum(''), isNull);
      expect(InstructionFormatter.asNum('invalid'), isNull);
      expect(InstructionFormatter.asNum([]), isNull);
    });
  });

  group('RouteOptionsScreen with string-encoded backend response', () {
    testWidgets('renders route options cleanly when time and distance are strings', (WidgetTester tester) async {
      final mockData = {
        'success': true,
        'options': [
          {
            'type': 'Recommended',
            'time': '59',
            'distance_m': '13670',
            'fare_egp': '20',
            'fare_total_egp': '20',
            'vehicle_type': 'bus',
            'instructions': [
              {
                'action': 'walk_to_station',
                'distance_m': '250',
                'vehicle_type': 'walk',
              },
              {
                'action': 'board',
                'route_number': '1073',
                'vehicle_type': 'bus',
                'distance_m': '13000',
              },
            ],
          },
          {
            'type': 'Cheapest',
            'time': '141',
            'distance_m': '14256',
            'fare_egp': '10',
            'fare_total_egp': '10',
            'vehicle_type': 'microbus',
            'instructions': [],
          },
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ar'),
          home: RouteOptionsScreen(
            startLat: 30.038,
            startLon: 31.21,
            startName: 'موقعي الحالي',
            endLat: 29.98,
            endLon: 31.13,
            endName: 'حدائق الأهرام',
            initialData: mockData,
            showMap: false,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('59 دقيقة'), findsWidgets);
      expect(find.byType(RouteOptionsScreen), findsOneWidget);
      // The trip starts from the route's detail page.
      await tester.tap(find.byKey(const ValueKey('route-card-0')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('يلا نبدأ'), findsOneWidget);
    });

    testWidgets('a paid ride a short walk replaces says what it saves and costs', (WidgetTester tester) async {
      final mockData = {
        'success': true,
        'options': [
          {'type': 'Recommended', 'time': 45, 'fare_total_egp': 20, 'vehicle_type': 'minibus', 'instructions': []},
          {
            'type': 'Alternative', 'time': 30, 'fare_total_egp': 40, 'vehicle_type': 'minibus', 'instructions': [],
            'short_ride': {'saves_min': 15, 'extra_egp': 20},
          },
        ],
      };
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: RouteOptionsScreen(
            startLat: 30.038,
            startLon: 31.21,
            startName: 'A',
            endLat: 29.98,
            endLon: 31.13,
            endName: 'B',
            initialData: mockData,
            showMap: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('15 min faster for 20 EGP more'), findsOneWidget);
    });

    testWidgets('renders partial route notice cleanly when uncovered_m is string', (WidgetTester tester) async {
      final mockData = {
        'success': true,
        'options': [
          {
            'type': 'Partial',
            'partial': true,
            'uncovered_m': '1500',
            'last_covered_stop': 'محطة مشعل',
            'time': '45',
            'distance_m': '10000',
            'fare_egp': '15',
            'fare_total_egp': '15',
            'vehicle_type': 'bus',
            'instructions': [],
          }
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ar'),
          home: RouteOptionsScreen(
            startLat: 30.038,
            startLon: 31.21,
            startName: 'موقعي الحالي',
            endLat: 29.98,
            endLon: 31.13,
            endName: 'حدائق الأهرام',
            initialData: mockData,
            showMap: false,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(RouteOptionsScreen), findsOneWidget);
    });
  });
}
