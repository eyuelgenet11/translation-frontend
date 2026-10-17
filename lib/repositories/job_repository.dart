import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_client.dart';

/// Job / Orders Repository
/// Routes calls to Node.js backend (`/api/jobs`) with direct Supabase fallback.
class JobRepository {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch user jobs / orders
  static Future<List<Map<String, dynamic>>> getJobs() async {
    // 1. Try Node.js Backend API
    final response = await ApiClient.get('/api/jobs');
    if (response.isSuccess && response.data != null) {
      if (response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
      }
    }

    // 2. Direct Supabase Fallback
    debugPrint("[JobRepo] Backend unreachable (${response.message}). Using direct Supabase fallback.");
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final res = await _supabase
          .from('jobs')
          .select('*')
          .or('client_id.eq.$userId,user_id.eq.$userId')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint("[JobRepo] Fetch jobs fallback error: $e");
      return [];
    }
  }

  /// Get single job detail by ID
  static Future<Map<String, dynamic>?> getJobDetail(dynamic jobId) async {
    // 1. Try Node.js Backend API
    final response = await ApiClient.get('/api/jobs/$jobId');
    if (response.isSuccess && response.data != null) {
      if (response.data is Map<String, dynamic>) {
        return Map<String, dynamic>.from(response.data);
      }
    }

    // 2. Direct Supabase Fallback
    debugPrint("[JobRepo] Fetch job detail fallback to Supabase for id $jobId");
    try {
      dynamic targetId = jobId;
      if (jobId is String && int.tryParse(jobId) != null) {
        targetId = int.parse(jobId);
      }

      final res = await _supabase
          .from('jobs')
          .select('*')
          .eq('id', targetId)
          .maybeSingle();

      if (res != null) {
        return Map<String, dynamic>.from(res);
      }
    } catch (e) {
      debugPrint("[JobRepo] Detail fallback error: $e");
    }
    return null;
  }

  /// Request signed upload URL from Node.js backend
  static Future<Map<String, dynamic>?> getSignedUploadUrl(String filename) async {
    final response = await ApiClient.post('/api/jobs/upload-url', body: {
      'filename': filename,
    });
    if (response.isSuccess && response.data != null && response.data is Map<String, dynamic>) {
      return Map<String, dynamic>.from(response.data);
    }
    return null;
  }

  /// Upload file bytes directly to the Supabase signed URL
  static Future<bool> uploadToSignedUrl({
    required String signedUrl,
    required List<int> bytes,
    required String contentType,
  }) async {
    try {
      final res = await http.put(
        Uri.parse(signedUrl),
        headers: {'Content-Type': contentType},
        body: bytes,
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint("[JobRepo] Signed upload error: $e");
      return false;
    }
  }

  /// Create job via Node.js backend (with Supabase fallback)
  static Future<Map<String, dynamic>?> createJob(Map<String, dynamic> jobPayload) async {
    // 1. Try Node.js Backend API
    final response = await ApiClient.post('/api/jobs/create', body: jobPayload);
    if (response.isSuccess && response.data != null && response.data is Map<String, dynamic>) {
      return Map<String, dynamic>.from(response.data);
    }

    // 2. Direct Supabase Fallback
    debugPrint("[JobRepo] Create job fallback to direct Supabase");
    try {
      final inserted = await _supabase.from('jobs').insert(jobPayload).select().single();
      return Map<String, dynamic>.from(inserted);
    } catch (e) {
      debugPrint("[JobRepo] Create job fallback error: $e");
      return null;
    }
  }

  /// Redeem loyalty points via Node.js backend (with Supabase fallback)
  static Future<bool> redeemPoints({
    required dynamic jobId,
    required double amount,
  }) async {
    // 1. Try Node.js Backend API
    final response = await ApiClient.post('/api/payments/redeem-points', body: {
      'jobId': jobId.toString(),
      'pointsAmount': amount.toInt(),
    });
    if (response.isSuccess) return true;

    // 2. Direct Supabase Fallback
    debugPrint("[JobRepo] Redeem points fallback to direct Supabase");
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    try {
      await _supabase.from('point_redemption_requests').insert({
        'customer_id': user.id,
        'points_amount': amount.toInt(),
        'job_id': jobId,
        'status': 'pending',
      });

      dynamic targetId = jobId;
      if (jobId is String && int.tryParse(jobId) != null) {
        targetId = int.parse(jobId);
      }

      await _supabase.from('jobs').update({
        'status': 'awaiting verification',
      }).eq('id', targetId);
      return true;
    } catch (e) {
      debugPrint("[JobRepo] Redeem fallback error: $e");
      return false;
    }
  }
}
