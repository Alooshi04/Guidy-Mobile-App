/// When an interstitial may follow a finished trip. Pure, so the caps can be
/// tested with a fake clock; [InterstitialAdService] feeds it the stored times.
///
/// AdMob wants interstitials only at a break in the content. The end of a
/// trip is one; these limits keep it from becoming a toll on every ride.
class InterstitialPolicy {
  InterstitialPolicy._();

  /// Least time between two interstitials.
  static const Duration minGap = Duration(hours: 2);

  /// Most interstitials in one calendar day (device-local).
  static const int maxPerDay = 2;

  /// An app open ad this recent means the rider has just seen a full-screen ad.
  static const Duration appOpenQuietWindow = Duration(minutes: 5);

  /// Whether one may show now.
  ///
  /// [completedTripsBefore] counts trips finished before this one: the first
  /// trip after install never gets an ad. [shownAt] are earlier interstitial
  /// times; [lastAppOpenShownAt] is when the app open ad last showed, if known.
  static bool canShow({
    required DateTime now,
    required Iterable<DateTime> shownAt,
    required int completedTripsBefore,
    DateTime? lastAppOpenShownAt,
  }) {
    if (completedTripsBefore < 1) return false;

    if (lastAppOpenShownAt != null) {
      final sinceAppOpen = now.difference(lastAppOpenShownAt);
      if (!sinceAppOpen.isNegative && sinceAppOpen < appOpenQuietWindow) return false;
    }

    var today = 0;
    for (final t in shownAt) {
      final since = now.difference(t);
      // A time in the future means the clock was set back: count it as recent,
      // so changing the date cannot lift the caps.
      if (since.isNegative || since < minGap) return false;
      if (t.year == now.year && t.month == now.month && t.day == now.day) today++;
    }
    return today < maxPerDay;
  }
}
