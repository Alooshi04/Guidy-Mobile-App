/// How long coordinates that came from Google Places may be kept.
///
/// This is not a performance tuning knob. Google Maps Platform Service
/// Specific Terms §14.3:
///
///   "Customer may temporarily cache latitude and longitude values from
///    the Places API for up to 30 consecutive calendar days, after which
///    Customer must delete the cached latitude and longitude values."
///
/// Guidy stores such coordinates in two places -- saved places and recent
/// searches -- and stored both indefinitely until this existed. Both now
/// carry the timestamp this class reads.
///
/// Place IDs are the deliberate exception. §A.3 permits caching those
/// with no expiry ("Customer may cache the Google ID values..."), which
/// is why a saved place keeps its `placeId` forever and re-resolves its
/// coordinates from it rather than being deleted along with them. The
/// rule costs the rider nothing; it just means one Place Details call per
/// saved place per month, at most.
class PlacesCoordsPolicy {
  PlacesCoordsPolicy._();

  static const Duration maxAge = Duration(days: 30);

  /// [storedAtMillis] is epoch milliseconds, or null for entries written
  /// before this policy existed. Those are treated as expired: their real
  /// age is unknown, and "unknown" has to mean "too old" for a rule with
  /// a hard deadline in it.
  static bool isExpired(Object? storedAtMillis) {
    if (storedAtMillis is! int) return true;
    final storedAt = DateTime.fromMillisecondsSinceEpoch(storedAtMillis);
    return DateTime.now().difference(storedAt) >= maxAge;
  }

  static int get now => DateTime.now().millisecondsSinceEpoch;
}
