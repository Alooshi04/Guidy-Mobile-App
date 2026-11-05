import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/RailNetworkMapScreen.dart';
import 'package:guidy_app/theme/app_theme.dart';

void main() {
  Widget createTestWidget() {
    return MaterialApp(
      locale: const Locale('ar'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const RailNetworkMapScreen(),
    );
  }

  group('RailNetworkMapScreen Widget Tests', () {
    testWidgets('shows the real map only: no schematic, no reset-view button',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('خريطة شبكة قطارات ومترو القاهرة'), findsOneWidget);
      expect(find.text('الخريطة'), findsOneWidget);
      expect(find.text('دليل المحطات'), findsOneWidget);
      expect(find.text('مخطط تخطيطي'), findsNothing);
      expect(find.text('مخطط الشبكة التخطيطي'), findsNothing);
      expect(find.byType(InteractiveViewer), findsNothing);
      expect(find.byIcon(Icons.center_focus_strong_rounded), findsNothing);

      await tester.tap(find.text('دليل المحطات'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.text('السادات'), findsWidgets);
    });

    testWidgets('the map takes the dark style in dark mode and none in light mode', (WidgetTester tester) async {
      Future<String?> mapStyle(ThemeData theme) async {
        await tester.pumpWidget(MaterialApp(
          theme: theme,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const RailNetworkMapScreen(),
        ));
        await tester.pumpAndSettle();
        return tester.widget<GoogleMap>(find.byType(GoogleMap)).style;
      }

      expect(await mapStyle(ThemeData.light()), isNull);
      expect(await mapStyle(ThemeData.dark()), darkMapStyleJson);
    });

    testWidgets('filtering stations by query in directory view',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Switch to directory tab
      await tester.tap(find.text('دليل المحطات'));
      await tester.pumpAndSettle();

      // Enter search query
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'حلوان');
      await tester.pumpAndSettle();

      // Verify Helwan station is present in results
      expect(find.text('حلوان'), findsWidgets);
    });

    testWidgets('the Fares & Pass Guide chip opens the official guide sheet, and the header has no duplicate button',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // The header used to carry a second receipt button doing the same thing.
      expect(find.widgetWithIcon(IconButton, Icons.receipt_long_rounded), findsNothing);

      final chip = find.text('دليل الأسعار والاشتراكات');
      expect(chip, findsOneWidget);
      await tester.tap(chip);
      await tester.pumpAndSettle();

      // Verify Fares & Pass Guide modal title and stage fares
      expect(find.text('دليل تذاكر واشتراكات النقل السككي'), findsOneWidget);
      expect(find.text('10 ج.م'), findsWidgets);
      expect(find.text('12 ج.م'), findsWidgets);
      expect(find.text('15 ج.م'), findsWidgets);
      expect(find.text('20 ج.م'), findsWidgets);
      expect(find.text('فتح حاسبة الاشتراكات'), findsNothing); // the calculator was removed
    });
  });
}
