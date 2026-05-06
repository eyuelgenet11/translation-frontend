import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get localBaseUrl {
    if (kIsWeb) return "http://localhost:5000";
    return "http://192.168.8.181:5000"; // Machine IP for real device/emulator testing
  }

  static String get baseUrl => localBaseUrl; // Final base URL

  static String get fetchCompanies => "$baseUrl/api/companies";
  static String get login => "$baseUrl/api/login";
  static String get register => "$baseUrl/api/register";
  static String get getUploadUrl => "$baseUrl/api/jobs/upload-url";
  static String get createJob => "$baseUrl/api/jobs/upload";
  static String get verifyPayment => "$baseUrl/api/payments/verify-and-update";
  static String get listJobs => "$baseUrl/api/jobs";

  static String? token; // ✅ Make sure this is defined as nullable

  // Helper function to get headers
  static Map<String, String> get authHeaders {
    // ✅ Check for null token safely
    if (token != null && token!.isNotEmpty) {
      return {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
    } else {
      return {'Content-Type': 'application/json'};
    }
  }

  static String getJobDetails(dynamic id) => "$baseUrl/api/jobs/$id";
  static String downloadJob(dynamic id) => "$baseUrl/api/jobs/$id/download";
}
