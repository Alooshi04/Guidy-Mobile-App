import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the app's current locale (English or Egyptian Arabic) and keeps it
/// in sync with SharedPreferences so the choice survives app restarts.
///
/// Egyptian Arabic doesn't have its own ISO 639-1 code that Flutter's
/// localization tooling resolves against region-neutral 'ar', so we use the
/// standard 'ar' language tag with the 'EG' country code (ar_EG) and write
/// the actual ARB string values in Egyptian colloquial Arabic (Masri)
/// rather than Modern Standard Arabic.
class LocaleController extends ValueNotifier<Locale> {
  LocaleController() : super(const Locale('en'));

  static const String _prefsKey = 'guidy_language_code';

  static const Locale english = Locale('en');
  static const Locale egyptianArabic = Locale('ar', 'EG');

  Future<void> loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved == 'ar') {
      value = egyptianArabic;
    } else {
      value = english;
    }
  }

  Future<void> setLocale(Locale locale) async {
    value = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, locale.languageCode);
  }

  bool get isArabic => value.languageCode == 'ar';
}

/// Single app-wide instance so any screen can read or change the language
/// without threading a provider through the widget tree.
final LocaleController localeController = LocaleController();
