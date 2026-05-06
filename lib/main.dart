import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/push_notification_service.dart';


import 'login_screen.dart';
import 'register_screen.dart';
import 'otp_screen.dart';
import 'home_screen.dart';
import 'upload_screen.dart';
import 'job_status_screen.dart';
import 'settings_screen.dart';
import 'document_view_screen.dart';
import 'live_order_tracker_screen.dart';
import 'reset_password_screen.dart';
import 'l10n/app_localizations.dart';
import 'services/locale_controller.dart';
import 'services/theme_controller.dart';
import 'services/font_scale_controller.dart';
import 'screens/splash_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 1. Initialize Firebase
    await Firebase.initializeApp();

    // 2. Initialize Supabase
    await Supabase.initialize(
      url: 'https://pbzptliuiwbifbrizkoi.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBienB0bGl1aXdiaWZicml6a29pIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk2MTk4NTcsImV4cCI6MjA4NTE5NTg1N30.vK_FRa4P-kbdc7WtZ78RzLe7KFbZGlRs2bUyC9vy-ik',
    );

    // 3. Initialize Push Notification Service
    final pushService = PushNotificationService();
    await pushService.initialize();

    // 4. Initialize Theme Controller
    await ThemeController.initialize();

    // 5. Initialize Font Scale Controller
    await FontScaleController.initialize();
  } catch (e) {
    debugPrint("Initialization Error: $e");
  }

  runApp(const TranslationApp());
}

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class TranslationApp extends StatefulWidget {
  const TranslationApp({super.key});
  static bool isRecoveringPassword = false;

  @override
  State<TranslationApp> createState() => _TranslationAppState();
}

class _TranslationAppState extends State<TranslationApp> {
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      debugPrint("Auth State Change: $event");

      if (event == AuthChangeEvent.passwordRecovery) {
        debugPrint("!!! PASSWORD RECOVERY EVENT DETECTED !!!");
        TranslationApp.isRecoveringPassword = true;
        
        // Use a longer delay or a more robust navigation strategy
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (rootNavigatorKey.currentState != null) {
               debugPrint("Navigating to /reset-password...");
               rootNavigatorKey.currentState?.pushNamedAndRemoveUntil(
                '/reset-password',
                (route) => false,
              );
            } else {
              debugPrint("Navigator state is null, cannot push /reset-password");
            }
          });
        });
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: LocaleController.localeNotifier,
      builder: (context, locale, child) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: ThemeController.themeNotifier,
          builder: (context, themeMode, child) {
            return ValueListenableBuilder<double>(
              valueListenable: FontScaleController.scaleNotifier,
              builder: (context, fontScale, child) {
                return MaterialApp(
                  navigatorKey: rootNavigatorKey,
                  title: "Geez Translation Marketplace",
                  debugShowCheckedModeBanner: false,
                  locale: locale,
                  themeMode: themeMode,
                  builder: (context, child) {
                    final data = MediaQuery.of(context);
                    return MediaQuery(
                      data: data.copyWith(
                        textScaler: TextScaler.linear(fontScale),
                      ),
                      child: child!,
                    );
                  },
                  theme: ThemeData(
                    useMaterial3: true,
                    brightness: Brightness.light,
                    colorScheme: ColorScheme.fromSeed(
                      seedColor: const Color(0xFF895129),
                      brightness: Brightness.light,
                      primary: const Color(0xFF895129),
                      onPrimary: Colors.white,
                    ),
                    scaffoldBackgroundColor: const Color(0xFFFFFFFF),
                    textTheme: GoogleFonts.philosopherTextTheme(),
                    snackBarTheme: SnackBarThemeData(
                      backgroundColor: const Color(0xFF1E293B),
                      contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  darkTheme: ThemeData(
                    useMaterial3: true,
                    brightness: Brightness.dark,
                    colorScheme: ColorScheme.fromSeed(
                      seedColor: const Color(0xFF895129),
                      brightness: Brightness.dark,
                      primary: const Color(0xFF895129),
                      onPrimary: Colors.white,
                    ),
                    scaffoldBackgroundColor: const Color(0xFF000000), // Pure black
                    textTheme: GoogleFonts.philosopherTextTheme(ThemeData.dark().textTheme),
                    snackBarTheme: SnackBarThemeData(
                      backgroundColor: const Color(0xFF222222), // Dark grey
                      contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  supportedLocales: const [
                    Locale('en', ''),
                    Locale('am', ''),
                  ],
                  localizationsDelegates: const [
                    AppLocalizationsDelegate(),
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  localeResolutionCallback: (locale, supportedLocales) {
                    for (var supportedLocale in supportedLocales) {
                      if (supportedLocale.languageCode == locale?.languageCode) {
                        return supportedLocale;
                      }
                    }
                    return supportedLocales.first;
                  },
                  initialRoute: '/splash',
                  routes: {
                    '/': (context) => const SplashScreen(),
                    '/splash': (context) => const SplashScreen(),
                    '/login': (context) => const LoginScreen(),
                    '/register': (context) => const RegisterScreen(),
                    '/otp': (context) => const OtpScreen(),
                    '/home': (context) => const MarketplaceHomeScreen(),
                    '/upload': (context) => const UploadScreen(company: {}),
                    '/job_status': (context) => const JobStatusScreen(),
                    '/settings': (context) => const SettingsScreen(),
                    '/document_view': (context) => const DocumentViewScreen(),
                    '/live_tracker': (context) {
                      final job = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
                      return LiveOrderTrackerScreen(job: job);
                    },
                    '/reset-password': (context) => const ResetPasswordScreen(),
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

