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
      'app_title': 'ግዕዝ ትርጉም',
      'home': 'መነሻ',
      'tracker': 'ተከታታይ',
      'profile': 'ፕሮፋይል',
      'settings': 'ቅንብሮች',
      'how_it_works': 'እንዴት እንደሚሰራ',
      'search_placeholder': 'ተርጓሚዎችን ይፈልጉ...',
      'recommended': 'የተመከሩ ባለሙያዎች',
      'verified': 'የተረጋገጡ ተርጓሚዎች',
      'login': 'ግባ',
      'register': 'ተመዝገብ',
      'email': 'ኢሜይል',
      'password': 'የይለፍ ቃል',
      'upload': 'ሰነድ ይጫኑ',
      'source_lang': 'የመነሻ ቋንቋ',
      'target_lang': 'የመድረሻ ቋንቋ',
      'urgency': 'አስቸኳይነት',
      'place_order': 'ትዕዛዝ በማስገባት ላይ',
      'active_job': 'ንቁ ስራ',
      'no_active_job': 'በአሁኑ ጊዜ ምንም ንቁ ስራዎች የሉም',
      'payment_verified': 'ክፍያ ተረጋግጧል',
      'in_progress': 'በሂደት ላይ',
      'completed': 'ተጠናቋል',
      'enter_valid_email': 'እባክዎን ትክክለኛ የኢሜይል አድራሻ ያስገቡ',
      'recovery_link_sent': 'የማግኛ ሊንክ ተልኳል ወደ',
      'identity_required': 'ኢሜይል እና የይለፍ ቃል ያስፈልጋል',
      'invalid_credentials': 'የተሳሳተ ኢሜይል ወይም የይለፍ ቃል',
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
