import '../l10n/app_localizations.dart';
import 'minutes_text.dart';

/// A trip's door-to-door time as riders say it: "44 min" under an hour,
/// "1 h 18 min" / "ساعة و18 دقيقة" over it, and whole hours with no
/// minutes part ("ساعتين"). "78 min" made the rider do the sum
/// (reviewer, 2026-11). The minutes keep [MinutesText]'s plural forms.
extension DurationText on AppLocalizations {
  /// On one line: "1 h 18 min", "ساعتين و5 دقائق", "3 ساعات".
  String duration(num? minutes) => durationLines(minutes).join(' ');

  /// The same in its two parts, for a narrow column that shows the hours
  /// over the minutes: ["ساعة", "و18 دقيقة"], ["1 h", "18 min"]. One part
  /// under an hour or on the hour.
  List<String> durationLines(num? minutes) {
    final total = (minutes ?? 0).round();
    if (total < 60) return [this.minutes(total)];
    final hours = durationHours(total ~/ 60);
    final rest = total % 60;
    return rest == 0 ? [hours] : [hours, durationAndMinutes(this.minutes(rest))];
  }
}
