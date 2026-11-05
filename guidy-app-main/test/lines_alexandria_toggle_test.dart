import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/LinesScreen.dart';
import 'package:guidy_app/widgets/line_city_pill.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The Lines "Alexandria" toggle keeps what lineCityOf() does not call Cairo:
// Alexandria's own lines and the Cairo-Alexandria microbuses.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Alexandria and intercity lines are the ones the toggle keeps', () {
    final routes = <Map<String, dynamic>>[
      {'route_id': '290', 'agency': 'CTA'},
      {'route_id': 'ALX_290', 'agency': 'ALX_APTA'},
      {'route_id': 'ALX_IC_1', 'agency': 'ALX_INTERCITY'},
      {'route_id': '65'},
    ];
    final kept = routes.where((r) => lineCityOf(r) != LineCity.cairo).map((r) => r['route_id']).toList();
    expect(kept, ['ALX_290', 'ALX_IC_1']);
  });

  testWidgets('Alexandria toggle switches view and back button restores landing grid', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LinesScreen(),
      ),
    );
    await tester.pump();

    final toggleFinder = find.byKey(const ValueKey('lines-alexandria-toggle'));
    expect(toggleFinder, findsOneWidget);

    FilterChip chip = tester.widget<FilterChip>(toggleFinder);
    expect(chip.selected, isFalse);

    // Tap toggle chip to enable Alexandria filter
    await tester.tap(toggleFinder);
    await tester.pump();

    chip = tester.widget<FilterChip>(toggleFinder);
    expect(chip.selected, isTrue);

    // Back button should now be visible to return to the grid
    final backFinder = find.byTooltip('Back');
    expect(backFinder, findsOneWidget);

    // Tapping back resets the filter and returns to the grid
    await tester.tap(backFinder);
    await tester.pump();

    chip = tester.widget<FilterChip>(toggleFinder);
    expect(chip.selected, isFalse);
  });
}
