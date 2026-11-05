import 'package:shared_preferences/shared_preferences.dart';

/// What is left of saved trips. Their screens are gone, so nothing is saved,
/// cached or synced any more; this only clears what older versions stored on
/// the phone. Account deletion removes the cloud copy (users/{uid}/saved_trips,
/// see AccountService).
class SavedTripsService {
  SavedTripsService._();

  static const String _storageKey = 'saved_commute_trips';
  static const String _activeCacheKey = 'active_commute_trip_cache';

  /// Removes the saved trips (and the last-trip cache) older versions left
  /// on THIS DEVICE. Called on sign-out, so the next person to sign in on
  /// this phone never sees someone else's trips.
  static Future<void> clearLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    await prefs.remove(_activeCacheKey);
  }
}
