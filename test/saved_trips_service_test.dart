import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/TripRecapScreen.dart';
import 'package:guidy_app/services/saved_trips_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Saved trips have no screen any more, so nothing is saved, cached or
/// synced; sign-out still clears what older versions left on the phone.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('opening a trip recap stores nothing on the phone', (tester) async {
    final option = <String, dynamic>{'type': 'Recommended', 'time': '40', 'fare_total_egp': 10, 'instructions': []};
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TripRecapScreen(option: option, pathData: option, startName: 'Home', endName: 'Work'),
    ));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isNot(contains('active_commute_trip_cache')));
  });

  test('sign-out clears the saved trips older versions left on the phone', () async {
    SharedPreferences.setMockInitialValues({
      'saved_commute_trips': '[{"id":"t1"}]',
      'active_commute_trip_cache': '{"start_name":"Home"}',
    });
    await SavedTripsService.clearLocal();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isEmpty);
  });
}
