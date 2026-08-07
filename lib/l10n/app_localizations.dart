import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const _localizedValues = {
    'en': {
      'app_title': 'Ge\'ez Script Translation',
      'home': 'Home',
      'tracker': 'Tracker',
      'profile': 'Profile',
      'settings': 'Settings',
      'how_it_works': 'How It Works',
      'search_placeholder': 'Search translators...',
      'recommended': 'Recommended Experts',
      'verified': 'Verified Translators',
      'login': 'Login',
      'register': 'Register',
      'email': 'Email',
      'password': 'Password',
      'upload': 'Upload Document',
      'source_lang': 'Source Language',
      'target_lang': 'Target Language',
      'urgency': 'Urgency',
      'place_order': 'Place Order',
      'active_job': 'Active Job',
      'no_active_job': 'No active tasks currently',
      'payment_verified': 'Payment Verified',
      'in_progress': 'In Progress',
      'completed': 'Completed',
      'enter_valid_email': 'Please enter a valid email address',
      'recovery_link_sent': 'Recovery link sent to',
      'identity_required': 'Email and password are required',
      'invalid_credentials': 'Incorrect email or password',
    },
    'am': {
      'app_title': 'áŒá‹•á‹ á‰µáˆ­áŒ‰áˆ',
      'home': 'áˆ˜áŠáˆ»',
      'tracker': 'á‰°áŠ¨á‰³á‰³á‹­',
      'profile': 'á•áˆ®á‹á‹­áˆ',
      'settings': 'á‰…áŠ•á‰¥áˆ®á‰½',
      'how_it_works': 'áŠ¥áŠ•á‹´á‰µ áŠ¥áŠ•á‹°áˆšáˆ°áˆ«',
      'search_placeholder': 'á‰°áˆ­áŒ“áˆšá‹Žá‰½áŠ• á‹­áˆáˆáŒ‰...',
      'recommended': 'á‹¨á‰°áˆ˜áŠ¨áˆ© á‰£áˆˆáˆ™á‹«á‹Žá‰½',
      'verified': 'á‹¨á‰°áˆ¨áŒ‹áŒˆáŒ¡ á‰°áˆ­áŒ“áˆšá‹Žá‰½',
      'login': 'áŒá‰£',
      'register': 'á‰°áˆ˜á‹áŒˆá‰¥',
      'email': 'áŠ¢áˆœá‹­áˆ',
      'password': 'á‹¨á‹­áˆˆá á‰ƒáˆ',
      'upload': 'áˆ°áŠá‹µ á‹­áŒ«áŠ‘',
      'source_lang': 'á‹¨áˆ˜áŠáˆ» á‰‹áŠ•á‰‹',
      'target_lang': 'á‹¨áˆ˜á‹µáˆ¨áˆ» á‰‹áŠ•á‰‹',
      'urgency': 'áŠ áˆµá‰¸áŠ³á‹­áŠá‰µ',
      'place_order': 'á‰µá‹•á‹›á‹ á‰ áˆ›áˆµáŒˆá‰£á‰µ áˆ‹á‹­',
      'active_job': 'áŠ•á‰ áˆµáˆ«',
      'no_active_job': 'á‰ áŠ áˆáŠ‘ áŒŠá‹œ áˆáŠ•áˆ áŠ•á‰ áˆµáˆ«á‹Žá‰½ á‹¨áˆ‰áˆ',
      'payment_verified': 'áŠ­áá‹« á‰°áˆ¨áŒ‹áŒáŒ§áˆ',
      'in_progress': 'á‰ áˆ‚á‹°á‰µ áˆ‹á‹­',
      'completed': 'á‰°áŒ áŠ“á‰‹áˆ',
      'enter_valid_email': 'áŠ¥á‰£áŠ­á‹ŽáŠ• á‰µáŠ­áŠ­áˆˆáŠ› á‹¨áŠ¢áˆœá‹­áˆ áŠ á‹µáˆ«áˆ» á‹«áˆµáŒˆá‰¡',
      'recovery_link_sent': 'á‹¨áˆ›áŒáŠ› áˆŠáŠ•áŠ­ á‰°áˆáŠ³áˆ á‹ˆá‹°',
      'identity_required': 'áŠ¢áˆœá‹­áˆ áŠ¥áŠ“ á‹¨á‹­áˆˆá á‰ƒáˆ á‹«áˆµáˆáˆáŒ‹áˆ',
      'invalid_credentials': 'á‹¨á‰°áˆ³áˆ³á‰° áŠ¢áˆœá‹­áˆ á‹ˆá‹­áˆ á‹¨á‹­áˆˆá á‰ƒáˆ',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'am'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}

