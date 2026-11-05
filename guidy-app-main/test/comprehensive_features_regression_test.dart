import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/HistoryScreen.dart';
import 'package:guidy_app/screens/LinesScreen.dart';
import 'package:guidy_app/services/location_localizer.dart';
import 'package:guidy_app/services/trip_history_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. Localization Tests', () {
    test('LocationLocalizer resolves common Cairo hubs and transliterations cleanly', () {
      expect(LocationLocalizer.localize('Ramses Railway Station', isArabic: true), contains('رمسيس'));
      expect(LocationLocalizer.localize('Sadat Metro Station', isArabic: true), contains('السادات'));
      expect(LocationLocalizer.localize('Attaba', isArabic: true), contains('العتبة'));
      expect(LocationLocalizer.localize('Ghamra', isArabic: true), contains('غمرة'));
      expect(LocationLocalizer.localize('Alf Maskan', isArabic: true), contains('ألف مسكن'));
      expect(LocationLocalizer.localize('Helwan', isArabic: true), contains('حلوان'));
    });
  });

  group('2. TripHistoryService & HistoryScreen Regression Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await TripHistoryService.clearHistory();
    });

    testWidgets('HistoryScreen renders all profile badges and filter badges without overflow', (tester) async {
      tester.view.physicalSize = const Size(400 * 2.0, 1600 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Record trips with different profiles and filters
      await TripHistoryService.recordTrip(
        startName: 'س Salsa Tawagen',
        endName: 'FMI Helwan',
        pathData: {'distance_km': 35.0},
        option: {
          'time': 87,
          'fare_egp': 35,
          'mode': 'minibus',
          'type': 'Recommended',
          'exclude_metro': true,
          'min_walk': true,
        },
        chosenProfile: 'Recommended',
      );

      await TripHistoryService.recordTrip(
        startName: 'Tahrir',
        endName: 'Zamalek',
        pathData: {'distance_km': 4.5},
        option: {
          'time': 20,
          'fare_egp': 10,
          'mode': 'bus',
          'type': 'Fastest',
          'min_transfers': true,
        },
        chosenProfile: 'Fastest',
      );

      await TripHistoryService.recordTrip(
        startName: 'Giza',
        endName: 'Dokki',
        pathData: {'distance_km': 6.0},
        option: {'time': 25, 'fare_egp': 8, 'mode': 'metro', 'type': 'Cheapest'},
        chosenProfile: 'Cheapest',
      );

      await TripHistoryService.recordTrip(
        startName: 'Point A',
        endName: 'Point B',
        pathData: {'distance_km': 1.0},
        option: {'time': 12, 'fare_egp': 0, 'mode': 'walk', 'type': 'Walk'},
        chosenProfile: 'Walk',
      );

      // Pump HistoryScreen in Arabic
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('ar'),
          home: HistoryScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Verify profile pills exist
      expect(find.textContaining('ترشيحنا'), findsWidgets);
      expect(find.textContaining('أسرع سكة'), findsWidgets);
      expect(find.textContaining('أوفر سكة'), findsWidgets);
      expect(find.textContaining('مشي'), findsWidgets);

      // Verify filter badges exist
      expect(find.textContaining('بدون مترو'), findsWidgets);
      expect(find.textContaining('أقل مشي'), findsWidgets);
      expect(find.textContaining('أقل تحويلات'), findsWidgets);

      // Strict check: Alternative / سكة بديلة MUST NOT appear
      expect(find.textContaining('سكة بديلة'), findsNothing);
      expect(find.textContaining('Alternative'), findsNothing);

      expect(tester.takeException(), isNull);
    });

    testWidgets('HistoryScreen handles legacy trips with missing or null profile gracefully', (tester) async {
      await TripHistoryService.recordTrip(
        startName: 'Legacy Start',
        endName: 'Legacy End',
        pathData: {'distance_km': 10.0},
        option: {'time': 30, 'fare_egp': 20, 'mode': 'bus'},
        // null profile should default safely to Recommended
      );

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: HistoryScreen(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Recommended'), findsOneWidget);
      expect(find.textContaining('Alternative'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('3. LinesScreen Pagination & Fare Regression Tests', () {
    testWidgets('LinesScreen renders cleanly without errors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ar'),
          home: const LinesScreen(),
        ),
      );

      await tester.pump();
      expect(find.byType(LinesScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
