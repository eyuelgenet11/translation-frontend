import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;
import 'services/notification_sound_service.dart';
import 'l10n/app_localizations.dart';

class UploadScreen extends StatefulWidget {
  final Map<String, dynamic> company;
  const UploadScreen({super.key, required this.company});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final supabase = Supabase.instance.client;
  static const Color brandBrown = Color(0xFF895129);
  late Color bgTheme;
  late Color cardTheme;
  late Color textThemeHeader;
  late Color textThemeSec;
  late bool isDark;

  // --- PRESERVED STATE ---
  String? fromLang;
  String? toLang;
  bool processing = false;


  XFile? _pickedFile;
  Uint8List? _webImage;
  final picker = ImagePicker();

  // --- DYNAMIC LANGUAGES ---
  List<String> allLanguages = [
    'English', 'Amharic', 'Tigrinya', 'Oromiffa', 'French', 'Arabic', 
    'Sidama', 'Wolayta', 'Somali'
  ];
  bool loadingLanguages = false;

  @override
  void initState() {
    super.initState();
    _fetchLanguages();
  }

  Future<void> _fetchLanguages() async {
    if (!mounted) return;
    setState(() => loadingLanguages = true);
    
    try {
      final data = await supabase
          .from('languages')
          .select('name')
          .order('name', ascending: true);
      
      if (data.isNotEmpty) {
        final List<String> fetchedLangs = (data as List)
            .map((item) => item['name'] as String)
            .toList();
        
        if (mounted) {
          setState(() {
            allLanguages = fetchedLangs;
          });
        }
      }
    } catch (e) {
      debugPrint("Language fetch failed: $e (Using fallbacks)");
    } finally {
      if (mounted) setState(() => loadingLanguages = false);
    }
  }

  @override
  void dispose() {

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    isDark = Theme.of(context).brightness == Brightness.dark;
    bgTheme = Theme.of(context).scaffoldBackgroundColor;
    cardTheme = Theme.of(context).cardColor;
    textThemeHeader = isDark ? Colors.white : Colors.black;
    textThemeSec = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: bgTheme,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bgTheme,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textThemeHeader, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("TRANSLATION REQUEST",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.2, color: brandBrown)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionLabelWithIcon(Icons.person_outline_rounded, "TRANSLATOR"),
            const SizedBox(height: 12),
            _translatorProfileHeader(),
            const SizedBox(height: 32),
            _buildSectionLabelWithIcon(Icons.assignment_outlined, "ASSIGNMENT SPECIFICATIONS"),
            const SizedBox(height: 16),
            _infoTakingBox(
                label: "Source Language",
                child: _customDropdown(fromLang, (v) => setState(() => fromLang = v), allLanguages)),
            const SizedBox(height: 12),
            _infoTakingBox(
                label: "Target Language",
                child: _customDropdown(toLang, (v) => setState(() => toLang = v), 
                    allLanguages.where((l) => l != fromLang).toList())),
            const SizedBox(height: 32),
            _buildSectionLabelWithIcon(Icons.attach_file_rounded, "DOCUMENT ATTACHMENT"),
            const SizedBox(height: 16),
            _documentPickerArea(),
            const SizedBox(height: 32),

            const SizedBox(height: 48),
            _actionButton(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- ACTIONS ---

  Future<void> _submitJob() async {
    if (fromLang == null || toLang == null || _pickedFile == null) {
      _showSnack("Please select languages and upload a document");
      return;
    }

    setState(() => processing = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("User not authenticated");

      final fileExt = p.extension(_pickedFile!.name);
      final fileName = "${DateTime.now().millisecondsSinceEpoch}$fileExt";
      final filePath = "jobs/${user.id}/$fileName";

      final bytes = await _pickedFile!.readAsBytes();
      await supabase.storage.from('translations').uploadBinary(filePath, bytes);

      final String publicUrl = supabase.storage.from('translations').getPublicUrl(filePath);

      final data = await supabase.from('jobs').insert({
        'client_id': user.id,
        'translator_id': widget.company['id'],
        'from_lang': fromLang,
        'to_lang': toLang,
        'file_url': publicUrl,
        'status': 'pending',

        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

      if (mounted) {
        NotificationSoundService.playSuccessSound();
        _showSnack("✅ Job submitted! Translator notified.");
        Navigator.pushReplacementNamed(context, '/live_tracker', arguments: data);
      }
    } catch (e) {
      _showSnack("Upload failed: ${e.toString()}");
    } finally {
      if (mounted) setState(() => processing = false);
    }
  }

  // --- UI COMPONENTS ---

  Widget _translatorProfileHeader() {
    final avatar = widget.company['avatar_url'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: cardTheme,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200)),
      child: Row(
        children: [
          Hero(
            tag: 'translator_avatar_${widget.company['id']}',
            child: CircleAvatar(
              radius: 24,
              backgroundColor: brandBrown.withValues(alpha: 0.05),
              backgroundImage: (avatar != null && avatar.isNotEmpty) ? NetworkImage(avatar) : null,
              child: (avatar == null || avatar.isEmpty) ? const Icon(Icons.person, color: brandBrown) : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.company['full_name'] ?? "Expert Translator",
                    style: TextStyle(color: textThemeHeader, fontWeight: FontWeight.w800, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const Text("Translator Profile",
                    style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const Icon(Icons.verified_user_rounded, color: Colors.green, size: 20),
        ],
      ),
    );
  }

  Widget _infoTakingBox({required String label, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: brandBrown, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }

  Widget _customDropdown(String? value, Function(String?) onChanged, List<String> items) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        icon: Icon(Icons.expand_more_rounded, color: isDark ? Colors.white38 : Colors.black38),
        hint: Text("Select...", style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 14)),
        items: items.map((e) => DropdownMenuItem(
            value: e,
            child: Text(e, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _documentPickerArea() {
    return GestureDetector(
      onTap: () async {
        final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
        if (pickedFile != null) {
          final bytes = await pickedFile.readAsBytes();
          setState(() {
            _webImage = bytes;
            _pickedFile = pickedFile;
          });
        }
      },
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : brandBrown,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05), width: 1.5),
        ),
        child: _pickedFile == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.cloud_upload_rounded, size: 40, color: textThemeHeader),
                   const SizedBox(height: 12),
                   Text(AppLocalizations.of(context)!.translate('upload'),
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textThemeHeader)),
                   Text("JPG, PNG or PDF supported", style: TextStyle(fontSize: 11, color: textThemeSec)),
                ],
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.memory(_webImage!, fit: BoxFit.cover),
              ),
      ),
    );
  }



  Widget _actionButton() {
    return SizedBox(
      width: double.infinity,
      height: 68,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandBrown,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          elevation: 0,
        ),
        onPressed: processing ? null : _submitJob,
        child: processing
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text("PLACE ORDER",
                style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(text,
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.grey.shade500, letterSpacing: 0.5));
  }

  Widget _buildSectionLabelWithIcon(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade400),
        const SizedBox(width: 8),
        _buildSectionLabel(text),
      ],
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Theme.of(context).snackBarTheme.backgroundColor,
      ),
    );
  }
}
