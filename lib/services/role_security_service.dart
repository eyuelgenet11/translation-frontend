import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/security_config.dart';

/// Enforces server-side-aligned role rules on the client after sign-in.
/// All authentication (customer, admin, translator) goes through Google OAuth.
/// Role determination happens via the `profiles` table in Supabase.
class RoleSecurityService {
  RoleSecurityService._();

  static SupabaseClient get _client => Supabase.instance.client;

  /// Ensures only the super-admin email may hold the admin role.
  /// Approved/pending translators are preserved as-is.
  /// Any other account that has self-assigned admin/translator is demoted.
  static Future<void> enforceProfileRoles(User user) async {
    final email = user.email?.trim();
    if (email == null || email.isEmpty) return;

    try {
      final profile = await _client
          .from('profiles')
          .select('role, email, status')
          .eq('id', user.id)
          .maybeSingle();

      final currentRole = profile?['role'] as String? ?? 'customer';

      // Super-admin email always gets admin role
      if (SecurityConfig.isSuperAdminEmail(email)) {
        if (profile == null) {
          await _client.from('profiles').insert({
            'id': user.id,
            'email': email,
            'full_name': user.userMetadata?['full_name'] ??
                user.userMetadata?['name'] ??
                'Administrator',
            'avatar_url': user.userMetadata?['avatar_url'] ?? user.userMetadata?['picture'],
            'role': 'admin',
            'status': 'Active',
          });
          debugPrint('RoleSecurity: created admin profile');
        } else if (currentRole != 'admin') {
          await _client.from('profiles').update({
            'role': 'admin',
            'email': email,
            'status': 'Active',
          }).eq('id', user.id);
          debugPrint('RoleSecurity: granted admin to super admin email');
        }
        return;
      }

      // Keep approved AND pending professional translators as-is.
      if (currentRole == 'translator') {
        final status = profile?['status'] as String?;
        if (SecurityConfig.isApprovedTranslatorStatus(status) ||
            SecurityConfig.isPendingTranslatorStatus(status)) {
          return;
        }
      }

      // Strip unauthorized admin or translator roles from non-staff emails.
      if (currentRole == 'admin' || currentRole == 'translator') {
        await _client.from('profiles').update({
          'role': 'customer',
          'status': 'Active',
        }).eq('id', user.id);
        debugPrint('RoleSecurity: downgraded unauthorized staff role for $email');
      }
    } catch (e) {
      debugPrint('RoleSecurity enforceProfileRoles error: $e');
    }
  }

  /// Checks whether a signed-in user is an approved translator.
  static Future<TranslatorAccessResult> verifyTranslatorAccess(String userId) async {
    final profile = await _client
        .from('profiles')
        .select('role, status')
        .eq('id', userId)
        .maybeSingle();

    if (profile == null) {
      return TranslatorAccessResult.denied('Account profile not found.');
    }

    if (profile['role'] != 'translator') {
      return TranslatorAccessResult.denied('Not a translator account.');
    }

    final status = profile['status'] as String?;
    if (!SecurityConfig.isApprovedTranslatorStatus(status)) {
      if (SecurityConfig.isPendingTranslatorStatus(status)) {
        return TranslatorAccessResult.pending(
          'Your application is under review. You will be notified once approved.',
        );
      }
      return TranslatorAccessResult.denied('Your translator account is not approved yet.');
    }

    return TranslatorAccessResult.approved();
  }
}

class TranslatorAccessResult {
  final bool isApproved;
  final bool isPending;
  final bool isDenied;
  final String message;

  TranslatorAccessResult._({
    required this.isApproved,
    required this.isPending,
    required this.isDenied,
    required this.message,
  });

  factory TranslatorAccessResult.approved() => TranslatorAccessResult._(
        isApproved: true,
        isPending: false,
        isDenied: false,
        message: '',
      );

  factory TranslatorAccessResult.pending(String message) => TranslatorAccessResult._(
        isApproved: false,
        isPending: true,
        isDenied: false,
        message: message,
      );

  factory TranslatorAccessResult.denied(String message) => TranslatorAccessResult._(
        isApproved: false,
        isPending: false,
        isDenied: true,
        message: message,
      );
}

