import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/MapScreen.dart';
import 'package:guidy_app/screens/RouteOptionsScreen.dart';
import 'package:guidy_app/screens/TripRecapScreen.dart';
import 'package:guidy_app/services/locale_controller.dart';
import 'package:guidy_app/widgets/route_card_skeleton.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The language is switched the way the app does it: localeController,
// which main.dart's MaterialApp listens to.
// Switching language mid-trip changes every station and line name on the
// trip screen at once: the backend sends both languages (station_en /
// station_ar, ...), and the screen picks one as it draws. Some places read
// the one-language `station` and kept the old names until a restart.
Map<String, dynamic> _step(String action, String en, String ar, {Map<String, dynamic> extra = const {}}) =>
    <String, dynamic>{
      'action': action, 'station': en, 'station_en': en, 'station_ar': ar,
      'lat': 30.05, 'lon': 31.24, ...extra,
    };

Map<String, dynamic> _trip() => <String, dynamic>{
      'instructions': [
        _step('walk_to_station', 'Al Tabba', 'الطبة', extra: {'distance_m': 300}),
        _step('board', 'Al Tabba', 'الطبة', extra: {
          'route_id': 'R66', 'route_number': '66', 'vehicle_type': 'minibus',
          'route_description': 'Nasr City - Imbaba', 'route_description_en': 'Nasr City - Imbaba',
          'route_description_ar': 'مدينة نصر - إمبابة',
          'towards': 'Imbaba', 'towards_en': 'Imbaba', 'towards_ar': 'إمبابة',
          'route_variant': '8th District - Madinat Al Talaba', 'route_variant_en': '8th District - Madinat Al Talaba',
          'route_variant_ar': 'الحي الثامن - مدينة الطلبة',
        }),
        _step('arrive', 'Ghamra', 'غمرة'),
      ],
      'option': <String, dynamic>{'type': 'Recommended', 'time': '40', 'fare_egp': 10},
      'segments': [],
    };

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('switching to Arabic mid-trip leaves no English station or line name', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    await localeController.setLocale(LocaleController.english);
    addTearDown(() => localeController.setLocale(LocaleController.english));
    final trip = _trip();
    await tester.pumpWidget(ValueListenableBuilder<Locale>(
      valueListenable: localeController,
      builder: (_, l, _) => MaterialApp(
        locale: l,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MapScreen(pathData: trip),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Al Tabba'), findsWidgets);

    await localeController.setLocale(LocaleController.egyptianArabic);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    for (final en in ['Al Tabba', 'Ghamra', 'Imbaba', 'Nasr City', '8th District']) {
      expect(find.textContaining(en), findsNothing, reason: '"$en" still shown in Arabic');
    }
    expect(find.textContaining('الطبة'), findsWidgets);
  });

  testWidgets('switching language on the route options leaves no English station or line name', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    await localeController.setLocale(LocaleController.english);
    addTearDown(() => localeController.setLocale(LocaleController.english));
    final option = <String, dynamic>{
      'type': 'Recommended', 'time': '40', 'fare_egp': 10, 'fare_total_egp': 10,
      'route_description': 'Nasr City - Imbaba', 'route_description_en': 'Nasr City - Imbaba',
      'route_description_ar': 'مدينة نصر - إمبابة', ..._trip(),
    };
    await tester.pumpWidget(ValueListenableBuilder<Locale>(
      valueListenable: localeController,
      builder: (_, l, _) => MaterialApp(
        locale: l,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RouteOptionsScreen(
          startLat: 30.06, startLon: 31.38, startName: 'Home', endLat: 30.10, endLon: 31.25, endName: 'Work',
          initialData: {'success': true, 'options': [option]},
          showMap: false,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    // The card names the ride's line, not its stop (beta reviewer, 2026-11).
    expect(find.text('Minibus 66'), findsOneWidget);

    await localeController.setLocale(LocaleController.egyptianArabic);
    await tester.pumpAndSettle();
    for (final en in ['Al Tabba', 'Ghamra', 'Imbaba', 'Nasr City', '8th District', 'Minibus']) {
      expect(find.textContaining(en), findsNothing, reason: '"$en" still shown in Arabic');
    }
    expect(find.text('ميني باص 66'), findsOneWidget);
  });

  // The options screen's own EN/عربي button redraws the same cards in the
  // other language; it used to search again, losing the selected card.
  testWidgets("the options screen's language button keeps the same cards", (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    await localeController.setLocale(LocaleController.english);
    addTearDown(() => localeController.setLocale(LocaleController.english));
    final option = <String, dynamic>{'type': 'Recommended', 'time': '40', 'fare_egp': 10, 'fare_total_egp': 10, ..._trip()};
    await tester.pumpWidget(ValueListenableBuilder<Locale>(
      valueListenable: localeController,
      builder: (_, l, _) => MaterialApp(
        locale: l,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RouteOptionsScreen(
          startLat: 30.06, startLon: 31.38, startName: 'Home', endLat: 30.10, endLon: 31.25, endName: 'Work',
          initialData: {'success': true, 'options': [option]},
          showMap: false,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('عربي'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('ميني باص 66'), findsOneWidget, reason: 'the same card, now in Arabic');
    expect(find.byType(RouteCardSkeletonList), findsNothing, reason: 'no new search');
  });

  // Past trips are opened from Home and History in whatever language the
  // app is in now, not the one they were searched in.
  testWidgets('a trip searched in English shows Arabic stops on its recap in Arabic', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    await localeController.setLocale(LocaleController.egyptianArabic);
    addTearDown(() => localeController.setLocale(LocaleController.english));
    final option = <String, dynamic>{'type': 'Recommended', 'time': '40', 'fare_total_egp': 10, ..._trip()};
    await tester.pumpWidget(MaterialApp(
      locale: localeController.value,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TripRecapScreen(option: option, pathData: option, startName: 'Home', endName: 'Work'),
    ));
    await tester.pumpAndSettle();
    for (final en in ['Al Tabba', 'Ghamra']) {
      expect(find.textContaining(en), findsNothing, reason: '"$en" shown in Arabic');
    }
    expect(find.textContaining('الطبة'), findsWidgets);
  });
}
