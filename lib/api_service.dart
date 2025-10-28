import 'dart:convert';
import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class ApiService {
  static const baseUrl = 'http://localhost:5000/api';

  // Dummy companies
  static List<Map<String, dynamic>> dummyCompanies() {
    return [
      {
        'id': '1',
        'business_name': 'Alpha Translations',
        'languages_supported': ['English', 'Amharic'],
        'rating': 4.5,
        'image_url': 'assets/images/a.png',
      },
      {
        'id': '2',
        'business_name': 'Beta Translations',
        'languages_supported': ['English', 'Oromo'],
        'rating': 4.2,
        'image_url': 'assets/images/b.png',
      },
      {
        'id': '3',
        'business_name': 'Gamma Translations',
        'languages_supported': ['English', 'Tigrinya'],
        'rating': 4.7,
        'image_url': 'assets/images/c.png',
      },
      {
        'id': '4',
        'business_name': 'Delta Translations',
        'languages_supported': ['Amharic', 'Oromo'],
        'rating': 4.1,
        'image_url': 'assets/images/d.png',
      },
      {
        'id': '5',
        'business_name': 'Epsilon Translations',
        'languages_supported': ['English', 'Amharic', 'Oromo'],
        'rating': 4.3,
        'image_url': 'assets/images/e.png',
      },
    ];
  }

  // Upload file (web-friendly)
  static Future<Map<String, dynamic>> uploadFileWeb({
    required Uint8List fileBytes,
    required String filename,
    required String companyId,
  }) async {
    final uri = Uri.parse('$baseUrl/upload');

    var request = http.MultipartRequest('POST', uri);
    request.fields['companyId'] = companyId;
    request.files.add(
      http.MultipartFile.fromBytes('file', fileBytes, filename: filename),
    );

    final response = await request.send();
    final respStr = await response.stream.bytesToString();
    return jsonDecode(respStr);
  }

  // Upload file (non-web: Android, iOS, Desktop)
  static Future<Map<String, dynamic>> uploadFile({
    File? file,
    Uint8List? fileBytes,
    String? filename,
    required String companyId,
  }) async {
    if (kIsWeb && (fileBytes == null || filename == null)) {
      throw Exception('Web upload requires fileBytes and filename');
    }
    if (!kIsWeb && file == null) {
      throw Exception('Mobile/Desktop upload requires a File object');
    }

    if (kIsWeb) {
      return await uploadFileWeb(
          fileBytes: fileBytes!, filename: filename!, companyId: companyId);
    } else {
      final uri = Uri.parse('$baseUrl/upload');
      var request = http.MultipartRequest('POST', uri);
      request.fields['companyId'] = companyId;
      request.files.add(await http.MultipartFile.fromPath('file', file!.path));

      final response = await request.send();
      final respStr = await response.stream.bytesToString();
      return jsonDecode(respStr);
    }
  }

  // Fetch uploaded files for a company
  static Future<List<Map<String, dynamic>>> getUploadedFiles(
    String companyId,
  ) async {
    final res = await http.get(Uri.parse('$baseUrl/files/$companyId'));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as List;
      return data.map((e) => e as Map<String, dynamic>).toList();
    } else {
      return [];
    }
  }

  // Fetch all companies (dummy or from API)
  static Future<List<Map<String, dynamic>>> getCompanies() async {
    // Replace with real API call if needed
    return dummyCompanies();
  }
}
