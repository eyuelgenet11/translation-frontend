/// Central security constants for role and admin access control.
class SecurityConfig {
  SecurityConfig._();

  static const String superAdminEmail = 'eyuelshimelis65@gmail.com';

  /// How long admin step-up verification remains valid after OTP.
  static const Duration adminVerificationTtl = Duration(days: 30);

  static bool isSuperAdminEmail(String? email) {
    if (email == null || email.trim().isEmpty) return false;
    return email.trim().toLowerCase() == superAdminEmail.toLowerCase();
  }

  static bool isApprovedTranslatorStatus(String? status) {
    if (status == null) return false;
    final s = status.toLowerCase();
    return s == 'approved' || s == 'active';
  }

  static bool isPendingTranslatorStatus(String? status) {
    if (status == null) return false;
    final s = status.toLowerCase();
    return s == 'pending' || s == 'new';
  }
}

