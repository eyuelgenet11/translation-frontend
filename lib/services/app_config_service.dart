import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

/// Structured Supabase client configuration
class SupabaseConfig {
  final String url;
  final String anonKey;

  const SupabaseConfig({required this.url, required this.anonKey});
}

/// Dynamically manages client configuration from the cloud backend.
/// Automatically falls back to local cache if offline, ensuring 100% reliability.
class AppConfigService {
  static const String _prefUrlKey = 'cached_supabase_url';
  static const String _prefAnonKey = 'cached_supabase_anon_key';

  // Environment-based or secure fallback values
  static const String _defaultUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://pbzptliuiwbifbrizkoi.supabase.co',
  );
  static const String _defaultAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBienB0bGl1aXdiaWZicml6a29pIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk2MTk4NTcsImV4cCI6MjA4NTE5NTg1N30.vK_FRa4P-kbdc7WtZ78RzLe7KFbZGlRs2bUyC9vy-ik',
  );

  /// Fetches Supabase client config dynamically from Render backend.
  /// Automatically caches locally and falls back gracefully when offline.
  static Future<SupabaseConfig> getSupabaseConfig() async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {}

    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/config/public');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final String? url = data['supabaseUrl'];
        final String? key = data['supabaseAnonKey'];

        if (url != null && url.isNotEmpty && key != null && key.isNotEmpty) {
          if (prefs != null) {
            await prefs.setString(_prefUrlKey, url);
            await prefs.setString(_prefAnonKey, key);
          }
          debugPrint('[AppConfigService] Loaded Supabase config dynamically from Render backend.');
          return SupabaseConfig(url: url, anonKey: key);
        }
      }
    } catch (e) {
      debugPrint('[AppConfigService] Dynamic config fetch notice (using cache/fallback): $e');
    }

    // Fallback to cache if offline
    if (prefs != null) {
      final cachedUrl = prefs.getString(_prefUrlKey);
      final cachedKey = prefs.getString(_prefAnonKey);
      if (cachedUrl != null && cachedKey != null) {
        debugPrint('[AppConfigService] Loaded Supabase config from local cache.');
        return SupabaseConfig(url: cachedUrl, anonKey: cachedKey);
      }
    }

    return const SupabaseConfig(url: _defaultUrl, anonKey: _defaultAnonKey);
  }
}
