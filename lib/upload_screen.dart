import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdfx/pdfx.dart';
import 'package:archive/archive.dart';
import 'services/api_service.dart';
import 'services/notification_sound_service.dart';
import 'payment_screen.dart';
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
  String urgency = 'Normal';
  bool isHandwritten = false; // admin gets Accept/Reject prompt when true
  bool isMedical = false; // Medical document flag for price calculation

  // Auto page count (calculated by system from uploaded document)
  int _autoPageCount = 1;
  // Customer phone — collected here, sent to admin via Telegram
  final TextEditingController _phoneController = TextEditingController();

  List<PlatformFile> _pickedFiles = [];
  List<XFile> _pickedImages = []; // Images picked from gallery/camera

  // --- DYNAMIC LANGUAGES ---
  List<String> allLanguages = [
    'English', 'Amharic', 'Tigrinya', 'Oromiffa', 'French', 'Arabic', 
    'Sidama', 'Wolayta', 'Somali', 'Afar', 'Spanish', 'Chinese', 'German', 'Italian'
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

  Future<int> _countPagesFromBytes(Uint8List bytes, String filename) async {
    final nameLower = filename.toLowerCase();

    // --- A. PDF FILES (Using pdfx native PDFium rendering engine) ---
    if (nameLower.endsWith('.pdf')) {
      try {
        final pdfDoc = await PdfDocument.openData(bytes);
        final int count = pdfDoc.pagesCount;
        await pdfDoc.close();
        debugPrint("pdfx engine count for $filename: $count");
        if (count > 0) return count;
      } catch (e) {
        debugPrint("pdfx engine notice for $filename: $e (using fallback)");
      }
      return _fallbackPdfCount(bytes);
    }

    // --- B. WORD DOCX FILES (Extracting docProps/app.xml from ZIP) ---
    if (nameLower.endsWith('.docx')) {
      try {
        final archive = ZipDecoder().decodeBytes(bytes);
        for (final file in archive) {
          if (file.name == 'docProps/app.xml') {
            final String xml = utf8.decode(file.content as List<int>, allowMalformed: true);
            final match = RegExp(r'<Pages>(\d+)</Pages>').firstMatch(xml);
            if (match != null && match.group(1) != null) {
              final int count = int.tryParse(match.group(1)!) ?? 1;
              debugPrint("DOCX XML page count for $filename: $count");
              return count > 0 ? count : 1;
            }
          }
        }
      } catch (e) {
        debugPrint("DOCX parse error for $filename: $e");
      }
      return 1;
    }

    return 1;
  }

  int _fallbackPdfCount(Uint8List bytes) {
    try {
      final String fullContent = latin1.decode(bytes, allowInvalid: true);
      int maxFoundPages = 0;

      final RegExp countRegex = RegExp(r'/Count\s*(\d+)');
      final RegExp kidsRegex = RegExp(r'/Kids\s*\[\s*([^\]]+)\]');
      final RegExp pageRegex = RegExp(r'/Type\s*/Page(?![a-zA-Z])');

      for (final m in countRegex.allMatches(fullContent)) {
        final int p = int.tryParse(m.group(1) ?? '') ?? 0;
        if (p > maxFoundPages) maxFoundPages = p;
      }
      for (final m in kidsRegex.allMatches(fullContent)) {
        final String kidsStr = m.group(1) ?? '';
        final int rCount = RegExp(r'\b\d+\s+\d+\s+R\b').allMatches(kidsStr).length;
        if (rCount > maxFoundPages) maxFoundPages = rCount;
      }
      final int directPageCount = pageRegex.allMatches(fullContent).length;
      if (directPageCount > maxFoundPages) maxFoundPages = directPageCount;

      if (maxFoundPages > 0) return maxFoundPages;
    } catch (_) {}
    return 1;
  }

  Future<void> _updateAutoPageCount(List<PlatformFile> files) async {
    int total = 0;
    for (var file in files) {
      try {
        Uint8List? bytes = file.bytes;
        if ((bytes == null || bytes.isEmpty) && file.path != null && file.path!.isNotEmpty) {
          final io.File f = io.File(file.path!);
          if (await f.exists()) {
            bytes = await f.readAsBytes();
          }
        }
        if (bytes != null && bytes.isNotEmpty) {
          final int count = await _countPagesFromBytes(bytes, file.name);
          debugPrint("Total Page Count for ${file.name}: $count");
          total += count;
        } else {
          total += 1;
        }
      } catch (e) {
        debugPrint("Error in _updateAutoPageCount for ${file.name}: $e");
        total += 1;
      }
    }
    if (mounted) {
      setState(() {
        _autoPageCount = total > 0 ? total : 1;
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
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
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: brandBrown.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                "TIRGUMSRA",
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 1.5, color: brandBrown),
              ),
            ),
            const SizedBox(width: 8),
            const Text("New Request",
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.black87)),
          ],
        ),
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
            const SizedBox(height: 24),
            // Customer contact
            _buildSectionLabelWithIcon(Icons.contact_phone_outlined, "YOUR CONTACT"),
            const SizedBox(height: 12),
            _phoneField(),
            const SizedBox(height: 16),
            // Medical document checkbox prompt
            _medicalPrompt(),
            const SizedBox(height: 24),
            // Urgency selector
            _buildSectionLabelWithIcon(Icons.timer_outlined, "SERVICE URGENCY"),
            const SizedBox(height: 12),
            _urgencySelector(),
            const SizedBox(height: 32),
            _buildSectionLabelWithIcon(Icons.attach_file_rounded, "DOCUMENT ATTACHMENT"),
            const SizedBox(height: 16),
            _documentPickerArea(),
            const SizedBox(height: 20),
            // Handwritten document toggle
            _handwrittenToggle(),
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
    final String rawPhone = _phoneController.text.trim();
    String phone = rawPhone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (phone.startsWith('+251')) {
      phone = '0${phone.substring(4)}';
    } else if (phone.startsWith('251')) {
      phone = '0${phone.substring(3)}';
    }

    if (fromLang == null || toLang == null || (_pickedFiles.isEmpty && _pickedImages.isEmpty)) {
      _showSnack("Please select languages and upload a document or image");
      return;
    }
    if (rawPhone.isEmpty) {
      _showSnack("Please enter your phone number");
      return;
    }
    if (!RegExp(r'^0\d{9}$').hasMatch(phone)) {
      _showSnack("Phone number must start with 0 (e.g., 0911373034)");
      return;
    }

    setState(() => processing = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() => processing = false);
        _showLoginRequiredDialog();
        return;
      }

      // Determine file name and bytes - support both documents and images
      String filename;
      List<int> allBytes = [];

      if (_pickedFiles.isNotEmpty) {
        // Document path
        final PlatformFile firstFile = _pickedFiles.first;
        filename = firstFile.name;
        for (var f in _pickedFiles) {
          if (f.bytes != null) {
            allBytes.addAll(f.bytes!);
          } else if (f.path != null) {
            final raw = await io.File(f.path!).readAsBytes();
            allBytes.addAll(raw);
          }
        }
      } else {
        // Image path — use first image name & bytes
        final XFile firstImage = _pickedImages.first;
        filename = firstImage.name.isNotEmpty ? firstImage.name : 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
        for (var img in _pickedImages) {
          final raw = await img.readAsBytes();
          allBytes.addAll(raw);
        }
      }

      if (allBytes.isEmpty) {
        setState(() => processing = false);
        _showSnack("Unable to read file content. Please re-select the document or image.");
        return;
      }

      final String merchantNameStr = widget.company['office_name'] ?? widget.company['full_name'] ?? 'General Marketplace';

      Map<String, dynamic> result;
      try {
        result = await ApiService.submitJobWithNotify(
          fileBytes:     Uint8List.fromList(allBytes),
          filename:      filename,
          userId:        user.id,
          fromLang:      fromLang!,
          toLang:        toLang!,
          pageCount:     _autoPageCount,
          urgency:       urgency,
          translatorId:  widget.company['id']?.toString(),
          merchantName:  merchantNameStr,
          isHandwritten: isHandwritten,
          isMedical:     isMedical,
          customerPhone: phone,
        );
      } catch (e) {
        result = {'success': false, 'message': e.toString()};
      }

      // Fallback: If backend server is unreachable, upload directly via Supabase client
      if (result['success'] != true) {
        debugPrint("Backend unreachable: ${result['message']}. Using direct Supabase fallback...");
        
        // Use same path format as backend: jobs/{userId}/{timestamp}_{filename}
        final String storagePath = 'jobs/${user.id}/${DateTime.now().millisecondsSinceEpoch}_$filename';
        
        try {
          await supabase.storage.from('translations').uploadBinary(
            storagePath,
            Uint8List.fromList(allBytes),
            fileOptions: FileOptions(
              contentType: filename.toLowerCase().endsWith('.pdf') ? 'application/pdf' : 'image/jpeg',
            ),
          );
        } catch (storageErr) {
          debugPrint("Storage upload note: $storageErr");
        }

        final String fileUrl = supabase.storage.from('translations').getPublicUrl(storagePath);

        bool isAfarOrSomali(String? lang) {
          if (lang == null) return false;
          final l = lang.trim().toLowerCase();
          return l.contains('afar') || l.contains('somali') || l.contains('ሶማሊ') || l.contains('ዓፋር');
        }

        bool isLocalLang(String? lang) {
          if (lang == null) return false;
          final l = lang.trim().toLowerCase();
          return l.contains('amharic') || l.contains('አማርኛ') ||
                 l.contains('english') ||
                 l.contains('orom') || l.contains('oromiffa') || l.contains('afaan') ||
                 l.contains('tigr') || l.contains('tigray') ||
                 l.contains('arabic') || l.contains('ዓረብኛ') ||
                 l.contains('sidama') || l.contains('wolayta') || l.contains('wolaytta') ||
                 isAfarOrSomali(l);
        }

        final bool hasAfarOrSomali = isAfarOrSomali(fromLang) || isAfarOrSomali(toLang);
        final bool isLocalPair     = isLocalLang(fromLang) && isLocalLang(toLang);

        final int pricePerPage = isMedical
            ? (isLocalPair ? 400 : 550)
            : (hasAfarOrSomali
                ? (isLocalPair ? 400 : 500)
                : (isLocalPair ? 250 : 500));

        final double basePrice = (_autoPageCount * pricePerPage).toDouble();
        // Apply 20% service fee on base price
        final double serviceFee = basePrice * 0.20;
        const double urgencyFee = 0.0; // Urgency fee removed from price calculation
        final double totalPrice = basePrice + serviceFee;

        // Only use translator_id if it's a valid UUID (not a display-only string like 'wisdom-002')
        final rawTranslatorId = widget.company['id']?.toString();
        final uuidRegex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);
        final String? validTranslatorId = (rawTranslatorId != null && uuidRegex.hasMatch(rawTranslatorId)) ? rawTranslatorId : null;

        final Map<String, dynamic> jobPayload = {
          'client_id': user.id,
          'from_lang': fromLang,
          'to_lang': toLang,
          'page_count': _autoPageCount,
          'urgency': urgency,
          'urgency_fee': urgencyFee,
          'file_url': fileUrl,
          'status': isHandwritten ? 'Awaiting Review' : 'pending',
          'is_handwritten': isHandwritten,
          'is_medical': isMedical,
          'client_phone': phone,
          'price': totalPrice,
        };
        if (validTranslatorId != null) jobPayload['translator_id'] = validTranslatorId;

        final insertedJob = await supabase.from('jobs').insert(jobPayload).select().single();

        // Send Telegram Notification to Admin containing Merchant Name & File URL
        ApiService.notifyTelegram(
          jobId: insertedJob['id']?.toString() ?? '',
          merchantName: merchantNameStr,
          fromLang: fromLang!,
          toLang: toLang!,
          pages: _autoPageCount,
          urgency: urgency,
          isHandwritten: isHandwritten,
          customerPhone: phone,
          fileUrl: fileUrl,
          fileName: filename,
        );

        // Direct Telegram Bot HTTP call backup
        ApiService.sendTelegramDirect(
          text: '📝 <b>NEW TRANSLATION JOB UPLOADED</b>\n'
                '━━━━━━━━━━━━━━━━━━━━\n'
                '🆔 <b>Job ID:</b> #${insertedJob['id']}\n'
                '🏪 <b>Merchant:</b> $merchantNameStr\n'
                '📄 <b>Pages:</b> $_autoPageCount\n'
                '🔤 <b>Language:</b> $fromLang → $toLang\n'
                '📱 <b>Customer Phone:</b> $phone\n'
                '⚡ <b>Urgency:</b> $urgency\n'
                '💰 <b>Price:</b> ${totalPrice.toStringAsFixed(2)} ETB',
          documentUrl: fileUrl,
        );

        result = {'success': true, 'data': insertedJob};
      }

      if (!mounted) return;

      if (result['success'] == true) {
        NotificationSoundService.playSuccessSound();
        final jobData = result['data'] as Map<String, dynamic>? ?? {};

        if (isHandwritten) {
          _showSnack('✅ Submitted! Admin will review your handwritten document.');
          Navigator.pushReplacementNamed(context, '/live_tracker', arguments: jobData);
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => PaymentScreen(job: jobData),
            ),
          );
        }
      } else {
        _showSnack("Submission failed: ${result['message']}");
      }
    } catch (e) {
      _showSnack("Upload failed: ${e.toString()}");
    } finally {
      if (mounted) setState(() => processing = false);
    }
  }

  // --- UI COMPONENTS ---

  // Phone number field — collected at upload time, sent to admin via Telegram
  Widget _phoneField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(Icons.phone_outlined, size: 18, color: brandBrown.withValues(alpha: 0.7)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))],
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: textThemeHeader,
              ),
              decoration: InputDecoration(
                hintText: '09XXXXXXXX  (e.g., 0911373034)',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white24 : Colors.black26,
                  fontSize: 13,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- MEDICAL DOCUMENT CHECKBOX WIDGET ---
  Widget _medicalPrompt() {
    return GestureDetector(
      onTap: () => setState(() => isMedical = !isMedical),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isMedical
              ? brandBrown.withValues(alpha: 0.10)
              : (isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isMedical ? brandBrown : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              height: 24,
              width: 24,
              child: Checkbox(
                value: isMedical,
                onChanged: (val) => setState(() => isMedical = val ?? false),
                activeColor: brandBrown,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Medical Document',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: isMedical ? brandBrown : textThemeHeader,
                ),
              ),
            ),
            Icon(
              Icons.medical_services_outlined,
              color: isMedical ? brandBrown : textThemeSec,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // --- HANDWRITTEN DOCUMENT TOGGLE WIDGET ---
  Widget _handwrittenToggle() {
    return GestureDetector(
      onTap: () => setState(() => isHandwritten = !isHandwritten),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isHandwritten
              ? const Color(0xFF895129).withValues(alpha: 0.10)
              : (isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isHandwritten ? brandBrown : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 26,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                color: isHandwritten ? brandBrown : (isDark ? Colors.white24 : Colors.black26),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                alignment: isHandwritten ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Handwritten Document',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: isHandwritten ? brandBrown : textThemeHeader,
                    ),
                  ),
                  Text(
                    'Admin will review and confirm before processing',
                    style: TextStyle(fontSize: 11, color: textThemeSec),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.draw_outlined,
              color: isHandwritten ? brandBrown : textThemeSec,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }



  // Urgency selector — labels only, no prices shown to user
  Widget _urgencySelector() {
    final options = [
      const _UrgencyOption('Normal',      'Standard delivery',         Icons.access_time_rounded),
      const _UrgencyOption('Urgent',      'Prioritized processing',    Icons.bolt_rounded),
      const _UrgencyOption('Super Urgent','Immediate attention needed', Icons.local_fire_department_rounded),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: options.map((opt) {
          final bool isSel = urgency == opt.label;
          return GestureDetector(
            onTap: () => setState(() => urgency = opt.label),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSel
                    ? brandBrown.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSel ? brandBrown : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(opt.icon,
                      size: 20,
                      color: isSel ? brandBrown : textThemeSec),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(opt.label,
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: isSel ? brandBrown : textThemeHeader)),
                        Text(opt.subtitle,
                            style: TextStyle(
                                fontSize: 11,
                                color: textThemeSec)),
                      ],
                    ),
                  ),
                  if (isSel)
                    Icon(Icons.check_circle_rounded, color: brandBrown, size: 18),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

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

  Future<void> _pickDocumentFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
      withData: true,
    );
    if (result != null) {
      setState(() {
        _pickedFiles = result.files;
        _pickedImages = [];
      });
      await _updateAutoPageCount(result.files);
    }
  }

  Future<void> _pickImageFrom(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = source == ImageSource.gallery
        ? await picker.pickMultiImage(imageQuality: 90)
        : [await picker.pickImage(source: ImageSource.camera, imageQuality: 90)].whereType<XFile>().toList();

    if (images.isEmpty) return;

    setState(() {
      _pickedImages = images;
      _pickedFiles = [];
      // Each image counts as 1 page
      _autoPageCount = images.length;
    });
  }

  Widget _documentPickerArea() {
    final bool hasFiles = _pickedFiles.isNotEmpty;
    final bool hasImages = _pickedImages.isNotEmpty;
    final bool hasAny = hasFiles || hasImages;

    return Column(
      children: [
        // --- Main drop zone ---
        Container(
          height: 160,
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : brandBrown,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
              width: 1.5,
            ),
          ),
          child: !hasAny
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_upload_rounded, size: 40, color: textThemeHeader),
                    const SizedBox(height: 10),
                    Text(
                      AppLocalizations.of(context)?.translate('upload') ?? 'Upload Document or Image',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textThemeHeader),
                    ),
                    Text(
                      'PDF, Word Docs, or Images',
                      style: TextStyle(fontSize: 11, color: textThemeHeader.withValues(alpha: 0.65)),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      hasImages ? Icons.image_rounded : Icons.library_books_rounded,
                      size: 36,
                      color: textThemeHeader,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hasImages
                          ? '${_pickedImages.length} image${_pickedImages.length > 1 ? 's' : ''} selected'
                          : '${_pickedFiles.length} file${_pickedFiles.length > 1 ? 's' : ''} selected',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textThemeHeader),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? brandBrown : Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.description_rounded, size: 13, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            '$_autoPageCount page${_autoPageCount > 1 ? 's' : ''}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        // --- 3 Action Buttons: Document | Gallery | Camera ---
        Row(
          children: [
            Expanded(
              child: _attachButton(
                icon: Icons.insert_drive_file_rounded,
                label: 'Document',
                onTap: _pickDocumentFiles,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _attachButton(
                icon: Icons.photo_library_rounded,
                label: 'Gallery',
                onTap: () => _pickImageFrom(ImageSource.gallery),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _attachButton(
                icon: Icons.camera_alt_rounded,
                label: 'Camera',
                onTap: () => _pickImageFrom(ImageSource.camera),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _attachButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : brandBrown.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: brandBrown.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: brandBrown),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : brandBrown,
              ),
            ),
          ],
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

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardTheme,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: brandBrown, size: 28),
            SizedBox(width: 12),
            Text("Sign In Required", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          "Please sign in to your account to upload documents and place translation orders.",
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: brandBrown,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("SIGN IN"),
          ),
        ],
      ),
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

// Helper data class for urgency options
class _UrgencyOption {
  final String label;
  final String subtitle;
  final IconData icon;
  const _UrgencyOption(this.label, this.subtitle, this.icon);
}
