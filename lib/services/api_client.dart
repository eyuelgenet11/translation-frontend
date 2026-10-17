import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_config.dart';

/// Centralized HTTP Client for Flutter -> Node.js Backend communication.
/// Automatically handles:
/// - Attaching Supabase session JWT tokens to `Authorization: Bearer <token>`
/// - Base URL routing
/// - Unified JSON parsing and error handling
class ApiClient {
  static final http.Client _httpClient = http.Client();

  /// Gets current Supabase JWT token, or null if unauthenticated
  static String? get _authToken {
    try {
      return Supabase.instance.client.auth.currentSession?.accessToken;
    } catch (_) {
      return null;
    }
  }

  /// Builds standard request headers with Authorization Bearer token
  static Map<String, String> _buildHeaders({Map<String, String>? extraHeaders}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final token = _authToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }
    return headers;
  }

  /// Resolves relative endpoint path with ApiConfig.baseUrl
  static Uri _buildUri(String path, [Map<String, dynamic>? queryParams]) {
    final base = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final urlString = '$base$cleanPath';

    if (queryParams != null && queryParams.isNotEmpty) {
      final stringParams = queryParams.map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      );
      return Uri.parse(urlString).replace(queryParameters: stringParams);
    }
    return Uri.parse(urlString);
  }

  /// GET request
  static Future<ApiResponse> get(
    String path, {
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final uri = _buildUri(path, queryParams);
      final response = await _httpClient
          .get(uri, headers: _buildHeaders(extraHeaders: headers))
          .timeout(timeout);
      return _parseResponse(response);
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// POST request
  static Future<ApiResponse> post(
    String path, {
    dynamic body,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final uri = _buildUri(path);
      final payload = body != null ? jsonEncode(body) : null;
      final response = await _httpClient
          .post(uri, headers: _buildHeaders(extraHeaders: headers), body: payload)
          .timeout(timeout);
      return _parseResponse(response);
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// PATCH request
  static Future<ApiResponse> patch(
    String path, {
    dynamic body,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final uri = _buildUri(path);
      final payload = body != null ? jsonEncode(body) : null;
      final response = await _httpClient
          .patch(uri, headers: _buildHeaders(extraHeaders: headers), body: payload)
          .timeout(timeout);
      return _parseResponse(response);
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// DELETE request
  static Future<ApiResponse> delete(
    String path, {
    dynamic body,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final uri = _buildUri(path);
      final payload = body != null ? jsonEncode(body) : null;
      final response = await _httpClient
          .delete(uri, headers: _buildHeaders(extraHeaders: headers), body: payload)
          .timeout(timeout);
      return _parseResponse(response);
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// Parses raw HTTP response into structured [ApiResponse]
  static ApiResponse _parseResponse(http.Response res) {
    dynamic decoded;
    try {
      if (res.body.isNotEmpty) {
        decoded = jsonDecode(res.body);
      }
    } catch (_) {
      decoded = res.body;
    }

    final isOk = res.statusCode >= 200 && res.statusCode < 300;
    if (isOk) {
      return ApiResponse.success(
        statusCode: res.statusCode,
        data: decoded is Map<String, dynamic> && decoded.containsKey('data')
            ? decoded['data']
            : decoded,
        rawJson: decoded is Map<String, dynamic> ? decoded : null,
      );
    } else {
      String message = 'Server error (${res.statusCode})';
      if (decoded is Map<String, dynamic>) {
        message = decoded['message'] ?? decoded['error'] ?? message;
      }
      return ApiResponse.failure(
        statusCode: res.statusCode,
        message: message,
        data: decoded,
      );
    }
  }
}

/// Standardized API Response Wrapper
class ApiResponse {
  final bool isSuccess;
  final int statusCode;
  final String? message;
  final dynamic data;
  final Map<String, dynamic>? rawJson;

  ApiResponse({
    required this.isSuccess,
    this.statusCode = 200,
    this.message,
    this.data,
    this.rawJson,
  });

  factory ApiResponse.success({
    int statusCode = 200,
    dynamic data,
    Map<String, dynamic>? rawJson,
  }) {
    return ApiResponse(
      isSuccess: true,
      statusCode: statusCode,
      data: data,
      rawJson: rawJson,
    );
  }

  factory ApiResponse.failure({
    required int statusCode,
    required String message,
    dynamic data,
  }) {
    return ApiResponse(
      isSuccess: false,
      statusCode: statusCode,
      message: message,
      data: data,
    );
  }

  factory ApiResponse.error(String errorMessage) {
    return ApiResponse(
      isSuccess: false,
      statusCode: 0,
      message: errorMessage,
    );
  }
}
