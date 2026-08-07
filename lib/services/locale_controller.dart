import 'package:flutter/material.dart';

class LocaleController {
  static final ValueNotifier<Locale> localeNotifier = ValueNotifier(const Locale('en'));

  static void toggleLocale() {
    if (localeNotifier.value.languageCode == 'en') {
      localeNotifier.value = const Locale('am');
    } else {
      localeNotifier.value = const Locale('en');
    }
  }

  static void setLocale(String langCode) {
    localeNotifier.value = Locale(langCode);
  }
}

