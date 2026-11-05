import '../l10n/app_localizations.dart';

/// "6 دقائق" / "11 دقيقة" / "6 min": a number of minutes with the plural
/// form the language needs. Arabic has separate forms for 1, 2, 3-10 and
/// 11+; the app used to print "6 دقيقة" everywhere.
extension MinutesText on AppLocalizations {
  String minutes(num? value) => minutesCount((value ?? 0).round());
}
