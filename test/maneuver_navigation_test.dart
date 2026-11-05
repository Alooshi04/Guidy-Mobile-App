import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/services/instruction_formatter.dart';

void main() {
  group('Pedestrian Maneuvers & Egyptian Arabic Localization Tests', () {
    testWidgets('Arabic locale returns authentic Egyptian Arabic pedestrian cues',
        (WidgetTester tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context);
              return Container();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify authentic Egyptian Arabic maneuver strings
      expect(l10n.walkManeuverRight, 'ادخل يمين');
      expect(l10n.walkManeuverLeft, 'ادخل شمال');
      expect(l10n.walkManeuverUTurn, 'لف وارجع');
      expect(l10n.walkInDistance('50م', 'ادخل يمين'), 'بعد 50م ادخل يمين');
      expect(l10n.metroNetworkMapButton, 'خريطة الشبكة');
    });

    testWidgets('English locale returns proper English navigation cues',
        (WidgetTester tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context);
              return Container();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(l10n.walkManeuverRight, 'Turn right');
      expect(l10n.walkManeuverLeft, 'Turn left');
      expect(l10n.walkManeuverUTurn, 'Make a U-turn');
      expect(l10n.walkInDistance('50m', 'Turn right'), 'In 50m Turn right');
    });

    testWidgets('InstructionFormatter.optionSummary displays corridor description for unnumbered microbuses',
        (WidgetTester tester) async {
      late AppLocalizations arL10n;
      late AppLocalizations enL10n;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              arL10n = AppLocalizations.of(context);
              return Container();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              enL10n = AppLocalizations.of(context);
              return Container();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Microbus with corridor description in Arabic
      final arSummary = InstructionFormatter.optionSummary(arL10n, {
        'vehicle_type': 'microbus',
        'route_number': null,
        'route_description': 'مؤسسة - مساكن النهضة',
      });
      expect(arSummary, 'ميكروباص مؤسسة - مساكن النهضة');

      // Microbus with corridor description in English
      final enSummary = InstructionFormatter.optionSummary(enL10n, {
        'vehicle_type': 'microbus',
        'route_number': null,
        'route_description': 'Moassasa - Nahda City',
      });
      expect(enSummary, 'Microbus Moassasa - Nahda City');

      // Numbered bus still uses number template
      final busSummary = InstructionFormatter.optionSummary(enL10n, {
        'vehicle_type': 'bus',
        'route_number': '1073',
        'route_description': 'Adly Mansour - Ramses',
      });
      expect(busSummary, 'Bus 1073');

      // Recommended route tier label
      expect(InstructionFormatter.routeTierLabel(arL10n, 'Recommended'), 'الموصى به');
      expect(InstructionFormatter.routeTierLabel(enL10n, 'Recommended'), 'Recommended');
    });
  });
}
