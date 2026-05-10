import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'services/notification_sound_service.dart';
import 'services/push_notification_service.dart';
import 'screens/job_chat_screen.dart';
import 'widgets/rating_dialog.dart';

class LiveOrderTrackerScreen extends StatefulWidget {
  final Map<String, dynamic> job;

  const LiveOrderTrackerScreen({super.key, required this.job});

  @override
  State<LiveOrderTrackerScreen> createState() => _LiveOrderTrackerScreenState();
}

class _LiveOrderTrackerScreenState extends State<LiveOrderTrackerScreen> {
  final supabase = Supabase.instance.client;
  late Map<String, dynamic> _job;
  RealtimeChannel? _statusSubscription;

  // Constants consistent with app theme
  static const Color brandColor = Color(0xFF895129);
  late Color bgTheme;
  late Color cardTheme;
  late Color textThemeHeader;
  late Color textThemeSec;
  late bool isDark;

  // Status & Feedback State


  // Payment State
  final TextEditingController _refController = TextEditingController();
  PlatformFile? _receiptFile;
  Uint8List? _webReceipt;
  bool _uploadingReceipt = false;

  // Download State
  double _downloadProgress = 0;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _job = widget.job;

    _subscribeToStatusUpdates();
  }

  @override
  void dispose() {
    _statusSubscription?.unsubscribe();

    _refController.dispose();
    super.dispose();
  }

  void _subscribeToStatusUpdates() {
    _statusSubscription = supabase
        .channel('public:jobs:id=eq.${_job['id']}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'jobs',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: _job['id'],
          ),
          callback: (payload) {
            if (mounted) {
              setState(() {
                final oldStatus = _job['status'];
                _job = Map<String, dynamic>.from(payload.newRecord);
                final newStatus = _job['status'];
                
                if (oldStatus != newStatus) {
                  NotificationSoundService.playNotificationSound();
                  
                  // Trigger system-level notification (Telegram/WhatsApp style)
                  PushNotificationService().showLocalNotification(
                    title: "Status Update",
                    body: "Order #${_job['id'].toString().substring(0,8)} changed to ${newStatus.toString().toUpperCase()}",
                  );

                  _showSnack("Order status updated to: ${newStatus.toString().toUpperCase()}");
                }
              });
            }
          },
        )
        .subscribe();
  }

  // --- ACTIONS ---

  Future<void> _updateJobStatus(String status, {String? reason}) async {
    try {
      final Map<String, dynamic> updateData = {'status': status};
      if (reason != null) updateData['rejection_reason'] = reason;
      await supabase.from('jobs').update(updateData).eq('id', _job['id']);
      // Real-time listener will update the UI
    } catch (e) {
      _showSnack("Error: $e", isError: true);
    }
  }

  Future<void> _handlePaymentSubmission() async {
    final ref = _refController.text.trim();
    if (ref.isEmpty && _receiptFile == null) {
      _showSnack("Please provide a Transaction ID or a photo of your receipt.", isError: true);
      return;
    }

    setState(() => _uploadingReceipt = true);

    try {
      String? receiptUrl;
      if (_receiptFile != null) {
        final fileName = 'receipts/${_job['id']}_${DateTime.now().millisecondsSinceEpoch}.${_receiptFile!.extension}';
        if (kIsWeb) {
          await supabase.storage.from('translations').uploadBinary(fileName, _webReceipt!);
        } else {
          await supabase.storage.from('translations').upload(fileName, File(_receiptFile!.path!));
        }
        receiptUrl = supabase.storage.from('translations').getPublicUrl(fileName);
      }

      await supabase.from('jobs').update({
        'status': 'awaiting verification',
        'transaction_ref': ref,
        if (receiptUrl != null) 'receipt_url': receiptUrl,
      }).eq('id', _job['id']);

      _showSnack("Payment submitted for review! ✅");
    } catch (e) {
      _showSnack("Error submitting payment: $e", isError: true);
    } finally {
      if (mounted) setState(() => _uploadingReceipt = false);
    }
  }

  Future<void> _acceptTranslation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Accept Translation?", style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text("By accepting, you confirm the translation meets your expectations. This will complete the order."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text("YES, ACCEPT", style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _updateJobStatus('completed');
      _showSnack("✅ Translation accepted! Order is now complete.");
      
      // Delay slightly to let the status update complete, then show Rating Dialog
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) RatingDialog.show(context, _job);
      });
    }
  }

  Future<void> _submitRevisionRequest(List<String> selectedErrors, String customNote) async {
    final revisionCount = (_job['revision_count'] ?? 0) + 1;
    final allNotes = [...selectedErrors, if (customNote.isNotEmpty) customNote].join('\n• ');
    final formattedNotes = '• $allNotes';

    try {
      await supabase.from('jobs').update({
        'status': 'revision_requested',
        'revision_notes': formattedNotes,
        'revision_count': revisionCount,
      }).eq('id', _job['id']);
      _showSnack("✏️ Revision request sent to translator!");
    } catch (e) {
      _showSnack("Error sending revision: $e", isError: true);
    }
  }

  void _showRevisionSheet() {
    final List<String> commonErrors = [
      "Incorrect translation of a term",
      "Missing sentences or paragraphs",
      "Grammar or spelling errors",
      "Wrong document format",
      "Inconsistent terminology",
    ];
    final List<bool> selected = List.filled(commonErrors.length, false);
    final TextEditingController noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.92,
          minChildSize: 0.5,
          builder: (_, scrollController) => Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(
              children: [
                Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      const Icon(Icons.edit_note_rounded, color: Colors.redAccent, size: 22),
                      const SizedBox(width: 10),
                      Text("Request Revision", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: textThemeHeader)),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text("Select all errors found in the translation:", style: TextStyle(fontSize: 12, color: textThemeSec)),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      ...List.generate(commonErrors.length, (i) => CheckboxListTile(
                        value: selected[i],
                        onChanged: (v) => setSheetState(() => selected[i] = v ?? false),
                        title: Text(commonErrors[i], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        activeColor: brandColor,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      )),
                      const SizedBox(height: 16),
                      Text("Additional details (optional):", style: TextStyle(fontSize: 12, color: textThemeSec, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: noteController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: "Describe the specific errors...",
                          hintStyle: TextStyle(color: textThemeSec, fontSize: 13),
                          filled: true,
                          fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if ((_job['revision_count'] ?? 0) >= 3)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.withValues(alpha: 0.3))),
                          child: const Text("⚠️ You have used 3+ revisions. Additional revisions may incur extra charges.", style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600)),
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            final chosenErrors = [
                              for (int i = 0; i < commonErrors.length; i++)
                                if (selected[i]) commonErrors[i]
                            ];
                            if (chosenErrors.isEmpty && noteController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text("Please select at least one error or add a note.")));
                              return;
                            }
                            Navigator.pop(ctx);
                            _submitRevisionRequest(chosenErrors, noteController.text.trim());
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text("SEND REVISION REQUEST", style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }



  Future<void> _downloadTranslation(String? url) async {
    if (url == null || url.isEmpty) {
      _showSnack("No file available for download.", isError: true);
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.1;
    });

    try {
      if (kIsWeb) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          throw 'Could not launch $url';
        }
      } else {
        // Mobile: Pick a directory or fallback to Documents
        String? selectedPath = await FilePicker.platform.getDirectoryPath();
        String baseDir;
        
        if (selectedPath != null && selectedPath.isNotEmpty) {
          baseDir = selectedPath;
          debugPrint("User selected download directory: $baseDir");
        } else {
          // Fallback to internal documents
          final appDocDir = await getApplicationDocumentsDirectory();
          baseDir = appDocDir.path;
          _showSnack("No folder selected, using app default folder.");
        }

        final fileName = url.split('/').last;
        final savePath = "$baseDir/$fileName";
        
        debugPrint("Starting download to: $savePath");
        await Dio().download(url, savePath, onReceiveProgress: (rcv, tot) {
          if (tot != -1) {
            setState(() => _downloadProgress = rcv / tot);
          }
        });
        _showSnack("Saved successfully to: $savePath");
      }

      setState(() => _downloadProgress = 1.0);
    } catch (e) {
      _showSnack("Error downloading: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> getReceiptImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null) {
      setState(() {
        _receiptFile = result.files.first;
        _webReceipt = _receiptFile!.bytes;
      });
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : Theme.of(context).snackBarTheme.backgroundColor,
      ),
    );
  }

  // --- UI BUILDERS ---

  Widget _buildSectionLabel(String text) {
    return Text(text,
        style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 10,
            color: Colors.grey.shade500,
            letterSpacing: 0.5));
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
        title: Text("LIVE ORDER TRACKER",
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.philosopher(
                fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.2, color: brandColor)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusHeader(),
            const SizedBox(height: 32),
            _buildTrackerCard(),
            const SizedBox(height: 40),
            _buildJobSummary(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => JobChatScreen(job: _job),
            ),
          );
        },
        backgroundColor: brandColor,
        icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
        label: const Text("Chat", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),

    );
  }

  Widget _buildStatusHeader() {
    final status = (_job['status'] ?? '').toString().toLowerCase();
    
    // Status Display Mapping
    Map<String, dynamic> statusUi = {
      'pending': {'label': 'WAITING FOR QUOTE', 'color': Colors.orange},
      'quoted': {'label': 'PRICE QUOTED', 'color': const Color(0xFF7C3AED)},
      'price quoted': {'label': 'PRICE QUOTED', 'color': const Color(0xFF7C3AED)},
      'awaiting payment': {'label': 'AWAITING PAYMENT', 'color': Colors.orange},
      'awaiting verification': {'label': 'VERIFYING PAYMENT', 'color': Colors.blue},
      'in progress': {'label': 'WORK IN PROGRESS', 'color': brandColor},
      'in_progress': {'label': 'WORK IN PROGRESS', 'color': brandColor},
      'pending_review': {'label': 'READY FOR REVIEW', 'color': Colors.green},
      'revision_requested': {'label': 'REVISION IN PROGRESS', 'color': Colors.orange},
      'completed': {'label': 'ORDER COMPLETED', 'color': Colors.green},
      'rejected': {'label': 'ORDER REJECTED', 'color': Colors.red},
    };

    final ui = statusUi[status] ?? {'label': status.toUpperCase(), 'color': brandColor};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (ui['color'] as Color).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(ui['label'] as String,
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      color: ui['color'] as Color,
                      letterSpacing: 1.2)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(ui['label'] as String,
            style: GoogleFonts.philosopher(
                fontWeight: FontWeight.w900, fontSize: 32, color: textThemeHeader, letterSpacing: -0.5)),
      ],
    );
  }

  Widget _buildTrackerCard() {
    final status = (_job['status'] ?? '').toString().toLowerCase();

    String title = "Updating Status...";
    String message = "Please wait while we fetch the latest updates.";
    IconData icon = Icons.sensors;
    Color statusColor = brandColor;
    Widget? actions;

    if (status == 'pending') {
      title = "Analyzing Document";
      message = "An expert translator is currently evaluating your document's complexity and word count to provide an accurate quote.";
      icon = Icons.hourglass_empty_rounded;
      statusColor = Colors.orange;
      actions = _buildPendingState();
    } else if (status == 'quoted' || status == 'price quoted') {
      title = "Official Quote Ready";
      message = "We've analyzed your document. Please review the professional service fee and turnaround time below.";
      icon = Icons.request_quote_rounded;
      statusColor = const Color(0xFF7C3AED);
      actions = _buildQuotedState();
    } else if (status == 'accepted' || status == 'in progress' || status == 'in_progress') {
      title = "Translation in Progress";
      message = "Your project is in the hands of a professional. We'll notify you the moment the first draft is ready for review.";
      icon = Icons.edit_note_rounded;
      statusColor = brandColor;
      actions = _buildProgressAnimation();
    } else if (status == 'awaiting payment') {
      title = "Payment Required";
      message = "To initiate the translation, please complete the initial payment as per the quote below.";
      icon = Icons.account_balance_wallet_rounded;
      statusColor = Colors.orange;
      actions = _buildAwaitingPaymentState();
    } else if (status == 'awaiting verification') {
      title = "Verifying Transaction";
      message = "Our finance team is confirming your payment receipt. This typically takes 15-30 minutes during business hours.";
      icon = Icons.verified_user_rounded;
      statusColor = Colors.blue;
      actions = _buildVerificationPulse();
    } else if (status == 'pending_review') {
      title = "Draft Ready for Review";
      message = "The translator has uploaded the document. Please review it carefully to ensure it meets your expectations.";
      icon = Icons.mark_email_unread_rounded;
      statusColor = Colors.green;
      actions = _buildPendingReviewActions();
    } else if (status == 'revision_requested') {
      title = "Revision in Progress";
      message = "We've received your feedback. The translator is making the requested adjustments to ensure perfect quality.";
      icon = Icons.published_with_changes_rounded;
      statusColor = Colors.orange;
      actions = _buildRevisionRequestedState();
    } else if (status == 'completed') {
      title = "Project Successfully Completed";
      message = "Success! Your document is fully translated, verified, and ready for use. Download the final version below.";
      icon = Icons.task_alt_rounded;
      statusColor = Colors.green;
      actions = _buildCompletionActions();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: statusColor.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title, 
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: textThemeHeader),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(fontSize: 13, color: textThemeSec, height: 1.6)),

          if (actions != null) ...[
            const SizedBox(height: 24),
            actions,
          ],
        ],
      ),
    );
  }

  Widget _buildPendingState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text("Waiting for translator's quote...",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.orange.shade800)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotedState() {
    return Column(
      children: [
        _buildPriceBreakdown(),
        const SizedBox(height: 24),
        _buildQuoteActions(),
      ],
    );
  }

  Widget _buildAwaitingPaymentState() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blueGrey.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blueGrey, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text("Quote accepted! Please settle the fee to begin.",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildPriceBreakdown(),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildPaymentForm(),
      ],
    );
  }

  Widget _buildVerificationPulse() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text("Verification usually takes ~15 mins",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue.shade700)),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressAnimation() {
    return Column(
      children: [
        LinearProgressIndicator(
          backgroundColor: brandColor.withValues(alpha: 0.1),
          valueColor: const AlwaysStoppedAnimation<Color>(brandColor),
          borderRadius: BorderRadius.circular(10),
          minHeight: 8,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Translator at work", style: TextStyle(fontSize: 11, color: textThemeSec, fontWeight: FontWeight.w600)),
            Text("Est. Delivery: Today", style: TextStyle(fontSize: 11, color: brandColor, fontWeight: FontWeight.w800)),
          ],
        ),
      ],
    );
  }



  Widget _buildPriceBreakdown() {
    final num price = _job['price'] ?? 0;
    final num serviceCharge = price * 0.15;
    final num total = price + serviceCharge;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          _priceRow("Translation Quote", "${price.toStringAsFixed(2)} ETB"),
          _priceRow("Service Charge (15%)", "${serviceCharge.toStringAsFixed(2)} ETB"),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1),
          ),
          _priceRow("Total Amount", "${total.toStringAsFixed(2)} ETB", isBold: true),
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(label, 
              style: TextStyle(fontSize: 12, color: isBold ? textThemeHeader : textThemeSec, fontWeight: isBold ? FontWeight.w900 : FontWeight.w500),
              overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 8),
        Text(value, style: TextStyle(fontSize: 12, color: isBold ? brandColor : textThemeHeader, fontWeight: isBold ? FontWeight.w900 : FontWeight.w700)),
      ],
    );
  }

  Widget _buildQuoteActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _updateJobStatus('rejected', reason: '[CLIENT_REJECTED] Quote declined by customer'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text("REJECT", style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () => _updateJobStatus('awaiting payment'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text("ACCEPT", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentForm({bool isResubmission = false}) {
    const String merchantPhone = "+251911373034";
    const String merchantName = "Eyuel Shimelis";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel("PAYMENT DESTINATION"),
        const SizedBox(height: 12),
        // --- PAY TO CARD ---
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [brandColor.withValues(alpha: 0.9), brandColor.withValues(alpha: 0.6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded, color: Colors.white70, size: 14),
                  const SizedBox(width: 6),
                  Text("PAY VIA TELEBIRR / CBE",
                      style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                ],
              ),
              const SizedBox(height: 10),
              Text(merchantName,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(merchantPhone,
                        style: GoogleFonts.robotoMono(
                            color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(const ClipboardData(text: merchantPhone));
                      _showSnack("📋 Number copied to clipboard!");
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white30),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy_rounded, color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text("COPY", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildSectionLabel("VERIFICATION DETAILS"),
        const SizedBox(height: 12),
        TextField(
          controller: _refController,
          decoration: InputDecoration(
            hintText: "Telebirr/CBE Transaction ID (Optional)",
            hintStyle: TextStyle(color: textThemeSec),
            filled: true,
            fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(child: Divider(thickness: 1, color: Color(0xFFE2E8F0))),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  "OR attach a screenshot (Optional)",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const Expanded(child: Divider(thickness: 1, color: Color(0xFFE2E8F0))),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: getReceiptImage,
          child: Container(
            height: 80,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _receiptFile != null ? Colors.green : (isDark ? Colors.white12 : Colors.black12)),
            ),
            child: _receiptFile == null
                ? Icon(Icons.camera_alt_outlined, color: textThemeSec)
                : const Icon(Icons.check_circle, color: Colors.green),
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            "Tap the box above to upload your payment screenshot",
            style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _uploadingReceipt ? null : _handlePaymentSubmission,
            style: ElevatedButton.styleFrom(
              backgroundColor: brandColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _uploadingReceipt
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(isResubmission ? "RESUBMIT PAYMENT" : "SUBMIT PAYMENT", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingReviewActions() {
    final String? fileUrl = _job['translated_file_url'];
    final int revisionCount = _job['revision_count'] ?? 0;

    return Column(
      children: [
        // Preview Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: fileUrl != null
                ? () async {
                    final uri = Uri.parse(fileUrl);
                    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                : null,
            icon: const Icon(Icons.visibility_outlined),
            label: const Text("PREVIEW DOCUMENT", style: TextStyle(fontWeight: FontWeight.w800)),
            style: OutlinedButton.styleFrom(
              foregroundColor: brandColor,
              side: BorderSide(color: brandColor),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            // Request Revision
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _showRevisionSheet,
                icon: const Icon(Icons.edit_note_rounded, size: 18),
                label: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("REVISION", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                    if (revisionCount > 0)
                      Text("(#$revisionCount used)", style: const TextStyle(fontSize: 9, color: Colors.orange)),
                  ],
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Accept
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _acceptTranslation,
                icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                label: const Text("ACCEPT", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRevisionRequestedState() {
    final String notes = _job['revision_notes'] ?? 'No notes provided.';
    final int count = _job['revision_count'] ?? 1;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pending_actions_rounded, color: Colors.orange, size: 18),
              const SizedBox(width: 8),
              Text("Revision #$count Sent", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w900, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 10),
          Text("Your notes to the translator:", style: TextStyle(fontSize: 11, color: textThemeSec, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(notes, style: TextStyle(fontSize: 12, color: textThemeHeader, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildCompletionActions() {
    return Column(
      children: [
        if (_isDownloading) LinearProgressIndicator(value: _downloadProgress, color: Colors.green),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isDownloading ? null : () => _downloadTranslation(_job['translated_file_url']),
            icon: const Icon(Icons.download_for_offline_rounded, color: Colors.white),
            label: const Text("DOWNLOAD FINAL FILE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: brandColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildJobSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel("ASSIGNMENT DETAILS"),
        const SizedBox(height: 16),
        _summaryRow("Job ID", _job['id'].toString().substring(0, 8).toUpperCase()),
        _summaryRow("Languages", "${_job['from_lang']} → ${_job['to_lang']}"),
        _summaryRow("Price (Total)", "${_job['price'] != null ? ((_job['price'] ?? 0) * 1.15).toStringAsFixed(2) : 'Pending'} ETB"),
        _summaryRow("Urgency", _job['urgency'] ?? "Normal"),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: textThemeSec, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Flexible(
            flex: 2,
            child: Text(value, 
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: textThemeHeader),
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}
