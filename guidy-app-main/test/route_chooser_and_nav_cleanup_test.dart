import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/services/instruction_formatter.dart';
import 'package:guidy_app/services/trip_history_service.dart';
import 'package:guidy_app/utils/minutes_text.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Arabic minutes are pluralised', () {
    test('uses the right form for each count', () async {
      final ar = await AppLocalizations.delegate.load(const Locale('ar'));
      expect(ar.minutes(1), 'دقيقة');
      expect(ar.minutes(2), 'دقيقتين');
      expect(ar.minutes(6), '6 دقائق');
      expect(ar.minutes(10), '10 دقائق');
      expect(ar.minutes(11), '11 دقيقة');
      expect(ar.minutes(45), '45 دقيقة');
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      expect(en.minutes(6), '6 min');
    });
  });

  group('History only holds finished trips', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await TripHistoryService.clearHistory();
    });

    test('a trip that was started but never finished is not listed', () async {
      await TripHistoryService.recordTrip(
        startName: 'A',
        endName: 'B',
        pathData: const {},
        option: const {'time': 20, 'fare_egp': 10},
        isCompleted: false,
      );
      expect(await TripHistoryService.getHistory(), isEmpty);
    });

    test('a finished trip is listed', () async {
      await TripHistoryService.recordTrip(
        startName: 'C',
        endName: 'D',
        pathData: const {},
        option: const {'time': 20, 'fare_egp': 10},
        isCompleted: true,
      );
      final history = await TripHistoryService.getHistory();
      expect(history, hasLength(1));
      expect(history.first.endName, 'D');
    });
  });

  group('Savings are real comparisons, never invented', () {
    Map<String, dynamic> offered(List<List<num>> opts) => {
          'compared_options': [
            for (final o in opts) {'type': 'X', 'time': o[0], 'fare_total_egp': o[1]},
          ],
        };

    test('fastest counts the gap to the next-slower route, not the slowest', () {
      final pd = offered([[30, 20], [40, 10], [90, 5]])..['chosen_index'] = 0;
      final s = TripHistoryService.computeSavings(duration: 30, fare: 20, pathData: pd);
      expect(s.minutes, 10);
      expect(s.egp, 0);
    });

    test('cheapest counts the gap to the next pricier route', () {
      final pd = offered([[30, 20], [40, 10], [90, 5]])..['chosen_index'] = 2;
      final s = TripHistoryService.computeSavings(duration: 90, fare: 5, pathData: pd);
      expect(s.minutes, 0);
      expect(s.egp, 5);
    });

    test('a single route saves nothing (used to be 12 min + 8 EGP)', () {
      final pd = offered([[30, 20]])..['chosen_index'] = 0;
      final s = TripHistoryService.computeSavings(duration: 30, fare: 20, pathData: pd);
      expect(s.minutes, 0);
      expect(s.egp, 0);
      final none = TripHistoryService.computeSavings(duration: 30, fare: 20, pathData: const {});
      expect(none.minutes, 0);
      expect(none.egp, 0);
    });

    test('a slower, pricier choice saves nothing', () {
      final pd = offered([[20, 10], [45, 10]])..['chosen_index'] = 1;
      final s = TripHistoryService.computeSavings(duration: 45, fare: 10, pathData: pd);
      expect(s.minutes, 0);
      expect(s.egp, 0);
    });

    test('old stored trips have their savings worked out again', () {
      final e = TripHistoryEntry.fromJson({
        'id': '1', 'start_name': 'A', 'end_name': 'B',
        'transit_duration_min': 55, 'transit_fare_egp': 10,
        'money_saved_egp': 20, 'time_saved_min': 4,
        'option': {'type': 'Recommended', 'time': 55, 'fare_total_egp': 10},
        'path_data': {
          'options': [
            {'type': 'Recommended', 'time': 55, 'fare_total_egp': 10},
            {'type': 'Alternative', 'time': 23, 'fare_total_egp': 10},
          ],
        },
      });
      expect(e.moneySavedEgp, 0);
      expect(e.timeSavedMin, 0);
    });
  });

  group('Lines sharing a number are told apart', () {
    test('the variant is shown with the number where there is room', () async {
      final ar = await AppLocalizations.delegate.load(const Locale('ar'));
      final a = {'vehicle_type': 'bus', 'route_number': '69', 'route_variant': 'التجمع الاول - العتبة'};
      final b = {'vehicle_type': 'bus', 'route_number': '69', 'route_variant': 'الحي الثامن (مدينة نصر) - التبة - العتبة'};
      expect(InstructionFormatter.lineLabelFull(ar, a), isNot(InstructionFormatter.lineLabelFull(ar, b)));
      expect(InstructionFormatter.lineLabelFull(ar, a), contains('69'));
      expect(InstructionFormatter.lineLabelFull(ar, {'vehicle_type': 'bus', 'route_number': '910'}),
          InstructionFormatter.lineLabel(ar, {'vehicle_type': 'bus', 'route_number': '910'}));
    });
  });
}
