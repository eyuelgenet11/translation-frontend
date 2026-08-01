import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '/services/api_config.dart';


class ApiService {
  // -------------------------------
  // LOGIN
  // -------------------------------
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse(ApiConfig.login),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = _handleResponse(response);

    // Store token if login is successful
    if (data['success'] == true && data.containsKey('token')) {
      ApiConfig.token = data['token'];
    }

    return data;
  }

  // -------------------------------
  // REGISTER
  // -------------------------------
  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse(ApiConfig.register),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );
    return _handleResponse(response);
  }

  // -------------------------------
  // LIST ALL JOBS (for customer)
  // -------------------------------
  static Future<List<Map<String, dynamic>>> listJobs() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.listJobs),
        headers: ApiConfig.authHeaders,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data ?? []);
      } else {
        print('Failed to fetch jobs: ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error fetching jobs: $e');
      return [];
    }
  }

  // LIST ALL THE REGISTERED COMPANIES

  static Future<List<Map<String, dynamic>>> fetchCompanies() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.fetchCompanies),
        headers: ApiConfig.authHeaders,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data ?? []);
      } else {
        print('Failed to fetch companies: ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error fetching companies: $e');
      return [];
    }
  }

  // -------------------------------
  // UPLOAD FILE (Mobile)
  // -------------------------------
  static Future<Map<String, dynamic>> uploadFile({
    required File file,
    required String sourceLang,
    required String targetLang,
    required int urgencyDays,
    int pagesEstimate = 1,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      final filename = file.path.split('/').last;
      return await uploadFileWeb(
        fileBytes: bytes,
        filename: filename,
        sourceLang: sourceLang,
        targetLang: targetLang,
        urgencyDays: urgencyDays,
        pagesEstimate: pagesEstimate,
      );
    } catch (e) {
      return {'success': false, 'message': 'Upload error: $e'};
    }
  }

  static Future<Map<String, dynamic>> uploadFileWeb({
    required Uint8List fileBytes,
    required String filename,
    required String sourceLang,
    required String targetLang,
    required int urgencyDays,
    int pagesEstimate = 1,
  }) async {
    if (ApiConfig.token == null || ApiConfig.token!.isEmpty) {
      return {
        'success': false,
        'message': 'No auth token found. Please login first.',
      };
    }

    try {
      final ext = filename.split('.').last;

      // 1️⃣ Get signed upload URL
      final res1 = await http.post(
        Uri.parse(ApiConfig.getUploadUrl),
        headers: ApiConfig.authHeaders,
        body: jsonEncode({'fileExtension': ext}),
      );

      if (res1.statusCode != 200) {
        return {
          'success': false,
          'message':
              'Failed to get signed URL: ${res1.statusCode} ${res1.body}',
        };
      }

      final data1 = jsonDecode(res1.body);
      final signedUrl = data1['signedUploadUrl'];
      final fileKey = data1['fileKey'];

      if (signedUrl == null || fileKey == null) {
        return {
          'success': false,
          'message': 'Invalid signed URL response from server',
        };
      }

      // 2️⃣ Upload file to Supabase
      final uploadRes = await http.put(
        Uri.parse(signedUrl),
        headers: {'Content-Type': 'application/octet-stream'},
        body: fileBytes,
      );

      if (uploadRes.statusCode != 200 && uploadRes.statusCode != 201) {
        return {
          'success': false,
          'message': 'Failed to upload file to storage',
        };
      }

      // 3️⃣ Create job record
      final res2 = await http.post(
        Uri.parse(ApiConfig.createJob),
        headers: ApiConfig.authHeaders,
        body: jsonEncode({
          'originalFileKey': fileKey,
          'sourceLang': sourceLang,
          'targetLang': targetLang,
          'pagesEstimate': pagesEstimate,
          'urgencyDays': urgencyDays,
        }),
      );

      if (res2.statusCode != 201) {
        return {
          'success': false,
          'message': 'Failed to create job: ${res2.body}',
        };
      }

      final jobData = jsonDecode(res2.body);
      return {
        'success': true,
        'fileId': jobData['job']['id'],
        'fileName': filename,
        'requiresPayment': false,
      };
    } catch (e) {
      return {'success': false, 'message': 'Upload error: $e'};
    }
  }

  // -------------------------------
  // SUBMIT JOB WITH TELEGRAM NOTIFY
  // Replaces direct Supabase insert from upload_screen.dart
  // Sends file + metadata to backend which:
  //  - uploads to storage
  //  - auto-calculates hidden price
  //  - notifies admin via Telegram
  // -------------------------------
  static Future<Map<String, dynamic>> submitJobWithNotify({
    required Uint8List fileBytes,
    required String filename,
    required String userId,
    required String fromLang,
    required String toLang,
    required int pageCount,
    required String urgency,
    String? translatorId,
    String merchantName = '',
    bool isHandwritten = false,
    String customerPhone = '',
  }) async {
    try {
      final uri = Uri.parse(ApiConfig.submitJobWithNotify);
      final request = http.MultipartRequest('POST', uri);

      // Text fields
      request.fields['userId']        = userId;
      request.fields['fromLang']      = fromLang;
      request.fields['toLang']        = toLang;
      request.fields['pageCount']     = pageCount.toString();
      request.fields['urgency']       = urgency;
      request.fields['isHandwritten'] = isHandwritten.toString();
      request.fields['customerPhone'] = customerPhone;
      request.fields['merchantName']  = merchantName;
      if (translatorId != null) {
        request.fields['translatorId'] = translatorId;
      }


      // File
      final ext = filename.split('.').last.toLowerCase();
      final mimeType = ext == 'pdf'
          ? 'application/pdf'
          : (ext == 'docx'
              ? 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
              : 'application/msword');

      request.files.add(http.MultipartFile.fromBytes(
        'document',
        fileBytes,
        filename: filename,
        contentType: MediaType('application', mimeType.split('/').last),
      ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      final data = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, ...data};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Submission failed.',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Upload error: $e'};
    }
  }

  // -------------------------------
  // NOTIFY TELEGRAM ADMIN (Fallback endpoint)
  // -------------------------------
  static Future<void> notifyTelegram({
    required String jobId,
    required String merchantName,
    required String fromLang,
    required String toLang,
    required int pages,
    required String urgency,
    required bool isHandwritten,
    required String customerPhone,
    required String fileUrl,
    required String fileName,
  }) async {
    try {
      final uri = Uri.parse("${ApiConfig.baseUrl}/api/jobs/notify-telegram");
      await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jobId': jobId,
          'merchantName': merchantName,
          'fromLang': fromLang,
          'toLang': toLang,
          'pages': pages,
          'urgency': urgency,
          'isHandwritten': isHandwritten,
          'customerPhone': customerPhone,
          'fileUrl': fileUrl,
          'fileName': fileName,
        }),
      );
    } catch (e) {
      print("Telegram notify fallback notice: $e");
    }
  }

  // -------------------------------
  // DOWNLOAD TRANSLATED FILE
  // -------------------------------
  static Future<Map<String, dynamic>> downloadTranslatedFile(
    String fileId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.downloadJob(fileId)),
        headers: ApiConfig.authHeaders,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        return {'success': true, ...data};
      } else {
        return {
          'success': false,
          'message': 'Download failed: ${response.body}',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // -------------------------------
  // VERIFY PAYMENT (MVP)
  // -------------------------------
  static Future<Map<String, dynamic>> verifyPayment({
    required String jobId,
    String? transactionRef,
    Uint8List? screenshotBytes,
    String? screenshotFilename,
  }) async {
    try {
      final uri = Uri.parse(ApiConfig.verifyPayment);
      final request = http.MultipartRequest('POST', uri);

      request.fields['jobId'] = jobId;
      if (transactionRef != null && transactionRef.isNotEmpty) {
        request.fields['transactionRef'] = transactionRef;
      }

      if (screenshotBytes != null) {
        final filename = screenshotFilename ?? 'receipt.png';
        final ext = filename.split('.').last.toLowerCase();
        final mimeType = (ext == 'jpg' || ext == 'jpeg') ? 'image/jpeg' : 'image/png';
        request.files.add(http.MultipartFile.fromBytes(
          'screenshot',
          screenshotBytes,
          filename: filename,
          contentType: MediaType('image', mimeType.split('/').last),
        ));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Error verifying payment: $e'};
    }
  }

  // -------------------------------
  // PROCESS PAYMENT (Legacy/Alternative)
  // -------------------------------
  static Future<Map<String, dynamic>> processPayment({
    required double amount,
    required String method,
    required String jobId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/api/payments/process"),
        headers: ApiConfig.authHeaders,
        body: jsonEncode({'amount': amount, 'method': method, 'jobId': jobId}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {
          'success': true,
          'message': data['message'] ?? 'Payment successful',
          'data': data,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Payment failed',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error processing payment: $e'};
    }
  }

  // -------------------------------
  // RESPONSE HANDLER
  // -------------------------------
  static Map<String, dynamic> _handleResponse(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, ...data};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Something went wrong',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Invalid response: $e'};
    }
  }
}
