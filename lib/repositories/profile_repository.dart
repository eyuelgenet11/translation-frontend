import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_client.dart';

/// User Profile & Settings Repository
/// Routes calls to Node.js backend (`/api/profile`) with direct Supabase fallback.
class ProfileRepository {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch user profile details
  static Future<Map<String, dynamic>?> getProfile() async {
    // 1. Try Node.js Backend API
    final response = await ApiClient.get('/api/profile');
    if (response.isSuccess && response.data != null) {
      if (response.data is Map<String, dynamic>) {
        return Map<String, dynamic>.from(response.data);
      }
    }

    // 2. Direct Supabase Fallback
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    try {
      final profile = await _supabase
          .from('profiles')
          .select('*')
          .eq('id', user.id)
          .maybeSingle();

      final customer = await _supabase
          .from('customer_accounts')
          .select('*')
          .eq('id', user.id)
          .maybeSingle();

      return {
        'id': user.id,
        'email': user.email,
        'phone': user.phone ?? customer?['phone'] ?? profile?['phone'],
        'fullName': profile?['full_name'] ?? customer?['full_name'] ?? user.userMetadata?['full_name'],
        'role': profile?['role'] ?? 'customer',
        'accountType': customer?['account_type'] ?? profile?['role'] ?? 'personal',
        'loyaltyPoints': customer?['loyalty_points'] ?? 0,
        'status': profile?['status'] ?? 'Active',
      };
    } catch (e) {
      debugPrint("[ProfileRepo] Fallback error: $e");
      return null;
    }
  }

  /// Update user profile or switch account type
  static Future<bool> updateProfile({
    String? fullName,
    String? phone,
    String? accountType,
  }) async {
    // 1. Try Node.js Backend API
    final payload = <String, dynamic>{};
    if (fullName != null) payload['fullName'] = fullName;
    if (phone != null) payload['phone'] = phone;
    if (accountType != null) payload['accountType'] = accountType;

    final response = await ApiClient.patch('/api/profile', body: payload);
    if (response.isSuccess) return true;

    // 2. Direct Supabase Fallback
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    try {
      final updates = <String, dynamic>{};
      if (fullName != null) updates['full_name'] = fullName;
      if (phone != null) updates['phone'] = phone;

      if (updates.isNotEmpty) {
        await _supabase.from('profiles').update(updates).eq('id', user.id);
        await _supabase.from('customer_accounts').update(updates).eq('id', user.id);
      }

      if (accountType != null) {
        if (accountType == 'translator') {
          await _supabase.from('profiles').upsert({
            'id': user.id,
            'email': user.email,
            'full_name': fullName ?? user.userMetadata?['full_name'] ?? user.email,
            'role': 'translator',
            'status': 'Approved',
          }, onConflict: 'id');
        } else {
          await _supabase.from('customer_accounts').upsert({
            'id': user.id,
            'account_type': accountType,
          }, onConflict: 'id');
        }
      }
      return true;
    } catch (e) {
      debugPrint("[ProfileRepo] Update fallback error: $e");
      return false;
    }
  }
}
