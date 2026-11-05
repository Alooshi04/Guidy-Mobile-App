import '../l10n/app_localizations.dart';
import '../services/instruction_formatter.dart';

/// How a ride is named in a sentence: the one place that picks the article.
///
/// A road vehicle that isn't a particular numbered line is "a bus", "a
/// microbus", "a minibus" (there are many; any will do). A numbered line is
/// "bus 1064", "microbus 24", no article. Rail and other fixed lines keep
/// "the": "the metro", "the monorail", "the LRT", and a metro line is named
/// as it is: "Metro Line 2". Arabic has no indefinite article, so a road
/// vehicle is the bare noun ("ميكروباص") and a fixed line already carries its
/// own "ال" ("المترو"); only the verb and word order differ.
///
/// Before this, sentences glued the capitalised label in ("Ride the Bus",
/// "Then take Microbus"), which is wrong for every road vehicle.
abstract final class RideWords {
  /// Lines that run on their own track or fixed lane: always "the ...".
  static const Set<String> fixedLine = {'metro', 'monorail', 'lrt', 'tram', 'apm', 'brt'};

  static bool _isFixed(Map m) => fixedLine.contains((m['vehicle_type'] ?? '').toString().toLowerCase());

  /// "a microbus", "bus 1064", "the metro", "Metro Line 2": a ride as the
  /// object of a sentence ("Wave down ... on", "On ...").
  static String thing(AppLocalizations l10n, Map<dynamic, dynamic> step) {
    final isAr = l10n.localeName.startsWith('ar');
    final full = InstructionFormatter.lineLabelFull(l10n, step);
    if (isAr) return full;
    final core = InstructionFormatter.lineLabel(l10n, step);
    final unnumbered = core == InstructionFormatter.vehicleLabelFor(l10n, step);
    final metroLine = (step['vehicle_type'] ?? '').toString().toLowerCase() == 'metro' && !unnumbered;
    if (metroLine) return full; // "Metro Line 2" is a name.
    final lower = _lowerWords(full);
    if (!unnumbered) return lower; // "bus 1064"
    if (_isFixed(step)) return 'the $lower';
    return '${_startsWithVowel(lower) ? 'an' : 'a'} $lower';
  }

  /// "Take a bus", "Take bus 1064", "Take Metro Line 2", "Ride the metro":
  /// the instruction for boarding it. [lowerFirst] for use mid-sentence
  /// ("Then take a microbus").
  static String action(AppLocalizations l10n, Map<dynamic, dynamic> step, {bool lowerFirst = false}) {
    final thing = RideWords.thing(l10n, step);
    final core = InstructionFormatter.lineLabel(l10n, step);
    final unnumbered = core == InstructionFormatter.vehicleLabelFor(l10n, step);
    final ride = _isFixed(step) && unnumbered;
    final text = ride ? l10n.rideRideThing(thing) : l10n.rideTakeThing(thing);
    if (!lowerFirst || l10n.localeName.startsWith('ar') || text.isEmpty) return text;
    return text[0].toLowerCase() + text.substring(1);
  }

  /// Lower-cases each word except acronyms ("LRT", "BRT", "M1") and keeps
  /// numbers and names with a capital after the first letter as they are.
  static String _lowerWords(String s) => s.split(' ').map((w) {
        if (w.length > 1 && w[1] == w[1].toUpperCase() && w[1] != w[1].toLowerCase()) return w; // LRT, BRT
        if (w.contains('(')) return w;
        return w.toLowerCase();
      }).join(' ');

  static bool _startsWithVowel(String s) => s.isNotEmpty && 'aeiou'.contains(s[0]);
}
