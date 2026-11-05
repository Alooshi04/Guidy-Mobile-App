import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the app's current ThemeMode. Starts out following the device's
/// system setting (as originally requested); once the person flips the
/// Dark Mode switch in Settings, that becomes an explicit override that's
/// persisted and takes precedence over the system setting from then on.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController() : super(ThemeMode.system);

  static const String _prefsKey = 'guidy_theme_mode';

  Future<void> loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved == 'dark') {
      value = ThemeMode.dark;
    } else if (saved == 'light') {
      value = ThemeMode.light;
    } else {
      value = ThemeMode.system;
    }
  }

  Future<void> setDarkMode(bool isDark) async {
    value = isDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, isDark ? 'dark' : 'light');
  }
}

/// Single app-wide instance, mirroring how localeController is shared.
final ThemeController themeController = ThemeController();
