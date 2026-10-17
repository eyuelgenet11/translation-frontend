import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_client.dart';

/// Notification Repository
/// Communicates through Node.js backend (`/api/notifications`),
/// with automatic direct Supabase fallback if the backend server is unreachable.
class NotificationRepository {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch user notifications
  static Future<List<Map<String, dynamic>>> fetchNotifications() async {
    // 1. Try Node.js Backend API
    final response = await ApiClient.get('/api/notifications');
    if (response.isSuccess && response.data != null) {
      if (response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
      }
    }

    // 2. Fallback to direct Supabase client if server is offline
    debugPrint("[NotificationRepo] Backend unreachable (${response.message}). Using Supabase fallback.");
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final res = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint("[NotificationRepo] Fallback error: $e");
      return [];
    }
  }

  /// Mark all notifications as read
  static Future<void> markAllAsRead() async {
    // 1. Try Node.js Backend API
    final response = await ApiClient.post('/api/notifications/mark-all-read');
    if (response.isSuccess) return;

    // 2. Fallback to direct Supabase update
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (e) {
      debugPrint("[NotificationRepo] Mark read fallback error: $e");
    }
  }

  /// Mark single notification as read
  static Future<void> markAsRead(String notificationId) async {
    // 1. Try Node.js Backend API
    final response = await ApiClient.patch('/api/notifications/$notificationId/read');
    if (response.isSuccess) return;

    // 2. Fallback
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      debugPrint("[NotificationRepo] Single mark read fallback error: $e");
    }
  }

  /// Register Device FCM Token
  static Future<void> registerDeviceToken({
    required String fcmToken,
    required String platform,
  }) async {
    // 1. Try Node.js Backend API
    final response = await ApiClient.post('/api/notifications/register-device', body: {
      'fcmToken': fcmToken,
      'platform': platform,
    });
    if (response.isSuccess) {
      debugPrint("[NotificationRepo] Device token registered via Node.js backend.");
      return;
    }

    // 2. Fallback via RPC in Supabase
    debugPrint("[NotificationRepo] Token registration fallback via Supabase RPC.");
    try {
      await _supabase.rpc('register_device_token', params: {
        'fcm_token_param': fcmToken,
        'platform_param': platform,
      });
    } catch (e) {
      debugPrint("[NotificationRepo] Token fallback error: $e");
    }
  }
}
