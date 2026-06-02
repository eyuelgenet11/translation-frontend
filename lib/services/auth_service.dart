import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/security_config.dart';
import 'admin_auth_service.dart';
import 'push_notification_service.dart';

/// Handles automatic routing after the app launches with an existing session.
/// Called from the SplashScreen once the splash delay completes.
class AuthService {
  /// Checks the current Supabase session and routes the user accordingly.
  /// Returns true if a navigation was performed.
  static Future<bool> tryAutoLogin(BuildContext context) async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;

    if (session == null) {
      // No session — go to login screen.
      // ignore: use_build_context_synchronously
      Navigator.pushReplacementNamed(context, '/login');
      return false;
    }

    // Save FCM token immediately on successful auto-login
    try {
      await PushNotificationService().saveTokenToSupabase();
    } catch (e) {
      debugPrint("Error saving FCM token on auto-login: $e");
    }

    final profile = await client
        .from('profiles')
        .select('role, status')
        .eq('id', session.user.id)
        .maybeSingle();

    final role = profile?['role'] as String?;
    final status = (profile?['status'] as String?)?.toLowerCase();
    final adminEmail = session.user.email;

    // Admin: check whether they have completed OTP step-up within TTL
    if (role == 'admin') {
      final verified = await AdminAuthService.isStepUpVerified();
      // ignore: use_build_context_synchronously
      if (!context.mounted) return false;
      if (verified) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        // Need one-time OTP verification — replace the entire stack
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/admin-otp',
          (route) => false,
          arguments: adminEmail,
        );
      }
      return true;
    }

    // ignore: use_build_context_synchronously
    if (!context.mounted) return false;

    // Approved translator → translator dashboard
    if (role == 'translator' && SecurityConfig.isApprovedTranslatorStatus(status)) {
      Navigator.pushReplacementNamed(context, '/translator-home');
      return true;
    }

    // Any other authenticated user (customer, pending translator, etc.)
    Navigator.pushReplacementNamed(context, '/home');
    return true;
  }
}
