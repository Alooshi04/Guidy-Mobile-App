import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/services/trip_history_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Home and Trips both read the whole stored history, and every tap on
// "Recent Trips" asks both to read it again. Each read parsed every trip with
// its full route data on the UI thread, which is what froze the app for a
// moment. A read of unchanged data now reuses the parsed trips.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TripHistoryService.resetCacheForTesting();
  });

  Future<TripHistoryEntry?> recordEntry(String end) => TripHistoryService.recordTrip(
        startName: 'Helwan',
        endName: end,
        chosenProfile: 'Fastest',
        pathData: {
          'options': [
            {'time': 35, 'fare_total_egp': 15, 'type': 'Fastest'},
            {'time': 55, 'fare_total_egp': 10, 'type': 'Cheapest'},
          ],
        },
        option: {'time': 35, 'fare_total_egp': 15, 'type': 'Fastest', 'distance_m': 28000},
      );

  Future<void> record(String end) async {
    final trip = await recordEntry(end);
    await TripHistoryService.markCompleted(trip!.id);
  }

  test('reading unchanged history again reuses the parsed trips', () async {
    await record('Sadat');
    final first = await TripHistoryService.getHistory();
    final second = await TripHistoryService.getHistory();
    expect(first, hasLength(1));
    expect(identical(first.first, second.first), isTrue);
  });

  test('a changed history is read afresh', () async {
    await record('Giza');
    final before = await TripHistoryService.getHistory();
    await record('Maadi');
    final after = await TripHistoryService.getHistory();
    expect(before, hasLength(1));
    expect(after, hasLength(2));
  });

  test('callers can reorder the list they get without affecting the next reader', () async {
    await record('Ramses');
    await record('Nasr City');
    final a = await TripHistoryService.getHistory();
    final firstEnd = a.first.endName;
    a.clear();
    final b = await TripHistoryService.getHistory();
    expect(b, hasLength(2));
    expect(b.first.endName, firstEnd);
  });

  test('clearLocal invalidates in-memory cache and returns empty list', () async {
    await record('Dokki');
    final before = await TripHistoryService.getHistory();
    expect(before, hasLength(1));

    await TripHistoryService.clearLocal();
    final after = await TripHistoryService.getHistory();
    expect(after, isEmpty);
  });
}
