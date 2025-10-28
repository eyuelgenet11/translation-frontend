import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../api_service.dart';

class UploadScreen extends StatefulWidget {
  final Map<String, dynamic> company;
  const UploadScreen({super.key, required this.company});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  File? selectedFile;
  Uint8List? selectedFileBytes;
  String? selectedFileName;
  bool uploading = false;
  List<Map<String, dynamic>> uploadedFiles = [];

  String? fromLanguage;
  String? toLanguage;

  final List<String> languages = [
    'English',
    'Amharic',
    'Afan Oromo',
    'Tigrigna',
    'Arabic',
    'French',
    'Italian',
    'German',
    'Spanish',
    'Chinese',
  ];

  @override
  void initState() {
    super.initState();
    fetchUploadedFiles();
  }

  Future<void> fetchUploadedFiles() async {
    try {
      final files = await ApiService.getUploadedFiles(widget.company['id']);
      setState(() => uploadedFiles = files);
    } catch (e) {
      debugPrint('Failed to fetch uploaded files: $e');
    }
  }

  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: kIsWeb,
    );

    if (result != null) {
      setState(() {
        selectedFileName = result.files.single.name;
        if (kIsWeb) {
          selectedFileBytes = result.files.single.bytes;
          selectedFile = null;
        } else {
          final path = result.files.single.path;
          if (path != null) selectedFile = File(path);
          selectedFileBytes = null;
        }
      });
    }
  }

  Future<void> uploadFile() async {
    if ((kIsWeb && selectedFileBytes == null) ||
        (!kIsWeb && selectedFile == null)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No file selected')));
      return;
    }

    if (fromLanguage == null || toLanguage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both languages')),
      );
      return;
    }

    setState(() => uploading = true);

    try {
      Map<String, dynamic> response;

      if (kIsWeb) {
        response = await ApiService.uploadFileWeb(
          fileBytes: selectedFileBytes!,
          filename: selectedFileName!,
          companyId: widget.company['id'],
        );
      } else {
        response = await ApiService.uploadFile(
          file: selectedFile!,
          companyId: widget.company['id'],
        );
      }

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File uploaded successfully!')),
        );
        setState(() {
          selectedFile = null;
          selectedFileBytes = null;
          selectedFileName = null;
          fromLanguage = null;
          toLanguage = null;
        });
        fetchUploadedFiles();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: ${response['message']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error uploading file: $e')));
    } finally {
      setState(() => uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final company = widget.company;

    const Color brandColor = Color(0xFF895129);
    const Color accentColor = Color(0xFFD8B88A);
    const Color backgroundColor = Color(0xFFF9F5F2);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: brandColor,
        title: Text(
          'Upload Documents',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Company Card
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEEDBC3), Color(0xFF895129)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AspectRatio(
                      aspectRatio: 3 / 2,
                      child: Image.asset(
                        company['image_url'] ?? 'assets/images/placeholder.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.business, size: 50),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            company['business_name'] ?? 'Unnamed Company',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Languages: ${company['languages_supported']?.join(', ') ?? '-'}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                size: 16,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                company['rating']?.toStringAsFixed(1) ?? '0.0',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Language Selection + Upload
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              shadowColor: brandColor.withOpacity(0.3),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'From:',
                              labelStyle: GoogleFonts.poppins(
                                color: brandColor,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            initialValue: fromLanguage,
                            items: languages
                                .map(
                                  (lang) => DropdownMenuItem(
                                    value: lang,
                                    child: Text(lang),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                fromLanguage = value;
                                if (toLanguage == fromLanguage) {
                                  toLanguage = null;
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'To:',
                              labelStyle: GoogleFonts.poppins(
                                color: brandColor,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            initialValue: toLanguage,
                            items: languages
                                .where((lang) => lang != fromLanguage)
                                .map(
                                  (lang) => DropdownMenuItem(
                                    value: lang,
                                    child: Text(lang),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) =>
                                setState(() => toLanguage = value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.attach_file, color: Colors.white),
                      label: const Text(
                        'Select a File',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandColor,
                        minimumSize: const Size(double.infinity, 45),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: pickFile,
                    ),
                    if (selectedFileName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          'Selected file: $selectedFileName',
                          style: GoogleFonts.poppins(fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 15),
                    ElevatedButton.icon(
                      icon: uploading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.cloud_upload, color: Colors.white),
                      label: Text(
                        uploading ? 'Uploading...' : 'Upload File',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: brandColor,
                        minimumSize: const Size(double.infinity, 45),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: uploading ? null : uploadFile,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Uploaded Files List
            if (uploadedFiles.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Uploaded Files:',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: brandColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...uploadedFiles.map(
                    (file) => Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: const Icon(
                          Icons.insert_drive_file,
                          color: brandColor,
                        ),
                        title: Text(
                          file['fileName'],
                          style: GoogleFonts.poppins(fontSize: 13),
                        ),
                        subtitle: Text(
                          file['uploadedAt'] ?? '',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
