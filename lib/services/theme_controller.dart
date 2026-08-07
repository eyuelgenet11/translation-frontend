import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController {
  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('is_dark_mode') ?? false;
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  static Future<void> toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    if (themeNotifier.value == ThemeMode.light) {
      themeNotifier.value = ThemeMode.dark;
      await prefs.setBool('is_dark_mode', true);
    } else {
      themeNotifier.value = ThemeMode.light;
      await prefs.setBool('is_dark_mode', false);
    }
  }

  static bool get isDark => themeNotifier.value == ThemeMode.dark;
}

