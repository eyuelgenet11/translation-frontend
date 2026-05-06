import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FontScaleController {
  static final ValueNotifier<double> scaleNotifier = ValueNotifier(1.0);

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    scaleNotifier.value = prefs.getDouble('geez_scale') ?? 1.0;
  }

  static Future<void> setScale(double scale) async {
    final prefs = await SharedPreferences.getInstance();
    scaleNotifier.value = scale;
    await prefs.setDouble('geez_scale', scale);
  }

  static double get scale => scaleNotifier.value;
}
