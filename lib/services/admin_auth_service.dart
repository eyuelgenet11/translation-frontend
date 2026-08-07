import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/security_config.dart';

/// Step-up OTP verification and admin session persistence helpers.
/// Admin sign-in itself is handled via Google OAuth in the login screen.
class AdminAuthService {
  AdminAuthService._();

  static const _verifiedAtKey = 'admin_otp_verified_at_ms';

  static SupabaseClient get _client => Supabase.instance.client;

  /// True when the admin has completed OTP verification within the TTL window
  /// (currently 30 days). Bypasses re-verification on app restart.
  static Future<bool> isStepUpVerified() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_verifiedAtKey);
    if (ms == null) return false;
    final verifiedAt = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateTime.now().difference(verifiedAt) < SecurityConfig.adminVerificationTtl;
  }

  /// Persists the OTP verification timestamp locally so the admin is not
  /// prompted again until the TTL expires (30 days).
  static Future<void> markStepUpVerified() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_verifiedAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Clears the persisted verification (called on sign-out).
  static Future<void> clearStepUpVerification() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_verifiedAtKey);
  }

  /// Sends a 6-digit OTP to [email] using Supabase's email OTP flow.
  static Future<void> sendEmailOtp(String email) async {
    try {
      await _client.auth.signInWithOtp(
        email: email.trim(),
        shouldCreateUser: false,
      );
    } on AuthException catch (e) {
      throw AuthException(
        e.message.isNotEmpty
            ? e.message
            : 'Could not send verification email. Enable Email OTP in Supabase.',
      );
    }
  }

  /// Verifies the OTP code from email and marks step-up as completed.
  static Future<void> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    await _client.auth.verifyOTP(
      type: OtpType.email,
      email: email.trim(),
      token: token.trim(),
    );
    await markStepUpVerified();
  }
}

