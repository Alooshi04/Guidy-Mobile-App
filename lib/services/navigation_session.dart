/// Whether the rider is in active turn-by-turn navigation (MapScreen).
///
/// A counter rather than a bool, so a MapScreen pushed on top of another
/// one (re-routing, opening a saved trip mid-trip) can't clear the flag the
/// first one set.
///
/// Read by AppOpenAdService: a full-screen ad must never cover the
/// navigation screen. A rider who locks the phone for a long bus ride and
/// unlocks it near their stop needs the next instruction, not an ad.
class NavigationSession {
  NavigationSession._();

  static int _active = 0;

  static bool get isActive => _active > 0;

  static void begin() => _active++;

  static void end() {
    if (_active > 0) _active--;
  }
}
