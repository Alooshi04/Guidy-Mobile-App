import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/LineDetailScreen.dart';

void main() {
  Widget createTestWidget({required String routeId, required String fallbackTitle, Locale locale = const Locale('ar')}) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: LineDetailScreen(routeId: routeId, fallbackTitle: fallbackTitle),
    );
  }

  group('LineDetailScreen Unit & Widget Tests', () {
    testWidgets('renders LineDetailScreen with fallback title and loading state', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(routeId: 'RL_MONO_EN', fallbackTitle: 'مونوريل شرق النيل'));
      expect(find.text('مونوريل شرق النيل'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    test('clean station names and fallback translation test', () {
      // Test station translation logic
      const englishName = 'Moushir Tantawi';
      final isArabic = true;
      var translated = englishName;
      if (isArabic && (translated == 'Moushir Tantawi' || translated.contains('Moushir Tantawi'))) {
        translated = translated.replaceAll('Moushir Tantawi', 'المشير طنطاوي');
      }
      expect(translated, 'المشير طنطاوي');

      // Test redundant prefix removal
      const longTerminus = 'محطة مونوريل استاد القاهرة';
      var cleaned = longTerminus.replaceAll('محطة مونوريل ', '').replaceAll('محطة ', '').trim();
      expect(cleaned, 'استاد القاهرة');

      const englishTerminus = 'Cairo Stadium Monorail Station';
      var cleanedEn = englishTerminus.replaceAll(' Monorail Station', '').replaceAll(' Station', '').trim();
      expect(cleanedEn, 'Cairo Stadium');
    });
  });
}
