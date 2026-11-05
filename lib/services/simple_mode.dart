import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple mode: an easier Guidy for older riders and anyone who is not
/// comfortable with technology, in the spirit of Uber's Simple mode.
///
/// One clear path: "Where do you want to go?" -> pick a place -> the one to
/// three easiest routes (fewest changes first) -> start -> one step at a
/// time. When on:
///  * text is at least 30% larger and every button is at least 56 dp tall,
///    each with a word next to its icon (main.dart, AppTheme, [SimpleUi]);
///  * the bottom bar keeps only Home, History and Settings, and there is no
///    tour or tooltip;
///  * Home is one big "Where do you want to go?" button, Go home, Go to
///    work and My saved places, and the last couple of trips;
///  * search shows only the destination (the start is the rider's location,
///    changeable with one labelled button);
///  * route options are a short list of big cards in plain words, with no
///    filters, comparison table, map sheet to drag or language switch;
///  * the trip shows the current step only, in plain words, with the one
///    thing to tell the driver; the faint alternative routes, tool rail and
///    sheet are gone, and leaving the trip asks first;
///  * nothing needs a swipe or a long press, and clearing or ending
///    anything asks for confirmation.
class SimpleModeController extends ValueNotifier<bool> {
  SimpleModeController() : super(false);

  static const String _prefKey = 'simple_mode';

  /// Smallest tap target in simple mode, in dp (Material asks 48).
  static const double minTarget = 56;

  /// How many routes simple mode offers.
  static const int maxRoutes = 3;

  /// Indexes of the routes simple mode shows: the easiest first. Easiest
  /// is the fewest vehicles to change between, then the shortest trip. A
  /// route with no instructions, or one that stops short of the
  /// destination, is never offered.
  static List<int> easiest(List<Map<String, dynamic>> options, {int max = maxRoutes}) {
    int rides(Map<String, dynamic> o) => [
          for (final i in (o['instructions'] as List? ?? const []))
            if (i is Map && (i['action'] == 'board' || i['action'] == 'transfer')) i,
        ].length;
    num minutes(Map<String, dynamic> o) {
      final t = o['time'];
      return t is num ? t : num.tryParse('$t') ?? 1 << 30;
    }

    final usable = [
      for (var i = 0; i < options.length; i++)
        if (options[i]['partial'] != true && (options[i]['instructions'] as List? ?? const []).isNotEmpty) i,
    ];
    usable.sort((a, b) {
      final byRides = rides(options[a]).compareTo(rides(options[b]));
      if (byRides != 0) return byRides;
      final byTime = minutes(options[a]).compareTo(minutes(options[b]));
      return byTime != 0 ? byTime : a.compareTo(b);
    });
    return usable.take(max).toList();
  }

  /// Minimum text scale while simple mode is on.
  static const double textScale = 1.3;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      value = prefs.getBool(_prefKey) ?? false;
    } catch (_) {}
  }

  Future<void> set(bool on) async {
    value = on;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, on);
    } catch (_) {}
  }
}

final SimpleModeController simpleMode = SimpleModeController();
