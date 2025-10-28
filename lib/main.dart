import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'upload_screen.dart';
import 'job_status_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'settings_screen.dart';
import 'document_view_screen.dart';

void main() {
  runApp(const TranslationApp());
}

class TranslationApp extends StatelessWidget {
  const TranslationApp({super.key});

  static const Color brandColor = Color(0xFF895129);
  static const Color accentColor = Color(0xFFD8B88A);
  static const Color backgroundColor = Color(0xFFF9F5F2);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Translation Marketplace',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: brandColor,
        scaffoldBackgroundColor: backgroundColor,
        appBarTheme: const AppBarTheme(
          backgroundColor: brandColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.brown,
        ).copyWith(secondary: accentColor),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: brandColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/job_status': (context) => const JobStatusScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/document_view': (context) => const DocumentViewScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/upload') {
          final company = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (_) => UploadScreen(company: company),
          );
        }
        return null;
      },
    );
  }
}
