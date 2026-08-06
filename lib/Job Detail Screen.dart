import 'dart:async';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';

class CustomerJobDetail extends StatefulWidget {
  final Map job;
  const CustomerJobDetail({super.key, required this.job});

  @override
  State<CustomerJobDetail> createState() => _CustomerJobDetailState();
}

class _CustomerJobDetailState extends State<CustomerJobDetail> {
  bool _isActionLoading = false;
  double _downloadProgress = 0;
  int _selectedRating = 0;
  String? _selectedFeedbackOption;
  final TextEditingController _feedbackController = TextEditingController();
  bool _isFeedbackSubmitting = false;
  late Map currentJobData;
  final Color brandColor = const Color(0xFF895129); // Earthy Brown
  late Color bgTheme;
  late Color cardTheme;
  late Color textThemeHeader;
  late Color textThemeSec;

  Timer? _supportTimer;
  bool _showSupportContact = false;

  @override
  void initState() {
    super.initState();
    currentJobData = widget.job;
    _listenToJobChanges();
    _startSupportTimer();
  }

  void _startSupportTimer() {
    _supportTimer?.cancel();
    final status = (currentJobData['status'] ?? '').toString().toLowerCase().trim();
    if (status == 'pending' || 
        status == 'new' ||
        status == 'awaiting verification' || 
        status == 'down payment verification') {
      setState(() {
        _showSupportContact = false;
      });
      _supportTimer = Timer(const Duration(seconds: 30), () {
        if (mounted) {
          setState(() {
            _showSupportContact = true;
          });
        }
      });
    } else {
      setState(() {
        _showSupportContact = false;
      });
    }
  }

  Future<void> _callSupport() async {
    final Uri url = Uri.parse('tel:+251911373034');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        await Clipboard.setData(const ClipboardData(text: "+251911373034"));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Could not launch phone app. Support number copied!"),
          backgroundColor: Colors.orange,
        ));
      }
    } catch (e) {
      await Clipboard.setData(const ClipboardData(text: "+251911373034"));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Support number copied: +251911373034"),
      ));
    }
  }

  Widget _buildSupportContactWidget() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedCrossFade(
      firstChild: const SizedBox.shrink(),
      secondChild: Container(
        margin: const EdgeInsets.only(top: 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF3F2D20), const Color(0xFF2B1E15)]
                : [const Color(0xFFFFF7ED), const Color(0xFFFFEDD5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFF634129) : const Color(0xFFFFD8A8),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
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
                    color: brandColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.support_agent_rounded,
                    color: brandColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Need Urgent Help?",
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: textThemeHeader,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "If the quote or payment verification is not replied to in 30 seconds, please contact us immediately.",
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.5,
                color: textThemeSec,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _callSupport,
                    icon: const Icon(Icons.phone_in_talk_rounded, size: 18, color: Colors.white),
                    label: const Text(
                      "CALL US (+251911373034)",
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      crossFadeState: _showSupportContact ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _supportTimer?.cancel();
    _feedbackController.dispose();
    super.dispose();
  }

  void _listenToJobChanges() {
    Supabase.instance.client
        .from('jobs')
        .stream(primaryKey: ['id'])
        .eq('id', widget.job['id'])
        .listen((List<Map<String, dynamic>> data) {
          if (data.isNotEmpty && mounted) {
            final String oldStatus =
                (currentJobData['status'] ?? '').toString().toLowerCase();
            final String newStatus =
                (data.first['status'] ?? '').toString().toLowerCase();

            setState(() {
              // Preserve the joined translator data if it exists in the new payload, 
              // or keep the old one if it's missing in the stream (streams don't join)
              final newJobMap = Map<String, dynamic>.from(data.first);
              if (currentJobData['translator'] != null && newJobMap['translator'] == null) {
                newJobMap['translator'] = currentJobData['translator'];
              }
              currentJobData = newJobMap;
            });

            if (newStatus != oldStatus) {
              _startSupportTimer();
            }

            if (newStatus == 'completed' && oldStatus != 'completed') {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("🎉 Translation Approved & Ready!"),
                  backgroundColor: Colors.green));
            }
          }
        });
  }

  Future<void> _downloadTranslation(String? fileUrl) async {
    if (fileUrl == null || fileUrl.isEmpty) return;
    setState(() => _isActionLoading = true);
    try {
      if (kIsWeb) {
        // Direct browser download via url_launcher
        final url = Uri.parse(fileUrl);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not launch download link.")));
        }
      } else {
        // Mobile: Choose directory or fallback
        String? selectedPath = await FilePicker.platform.getDirectoryPath();
        String baseDir;
        
        if (selectedPath != null && selectedPath.isNotEmpty) {
          baseDir = selectedPath;
        } else {
          final appDocDir = await getApplicationDocumentsDirectory();
          baseDir = appDocDir.path;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("No folder selected, using app default folder."),
            ));
          }
        }

        final fileName = Uri.parse(fileUrl).pathSegments.last;
        final savePath = "$baseDir/$fileName";

        await Dio().download(fileUrl, savePath, onReceiveProgress: (rcv, tot) {
          if (tot != -1) setState(() => _downloadProgress = rcv / tot);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("File saved successfully to: $savePath")));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Download Error: $e"), backgroundColor: Colors.redAccent));
      }
    } finally {
      setState(() {
        _isActionLoading = false;
        _downloadProgress = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bgTheme = Theme.of(context).scaffoldBackgroundColor;
    cardTheme = Theme.of(context).cardColor;
    textThemeHeader = isDark ? Colors.white : Colors.black;
    textThemeSec = isDark ? Colors.white70 : Colors.black54;

    final String status =
        (currentJobData['status'] ?? 'new').toString().toLowerCase().trim();

    return Scaffold(
      backgroundColor: bgTheme,
      appBar: AppBar(
        title: Text("TRACK YOUR ORDER",
            style: GoogleFonts.philosopher(
                fontWeight: FontWeight.w900,
                color: textThemeHeader,
                fontSize: 16,
                letterSpacing: 1.2)),
        centerTitle: true,
        backgroundColor: cardTheme,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              size: 20, color: textThemeHeader),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
          children: [
            _buildStatusHeader(status),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionLabel("PROJECT PROGRESS"),
                  const SizedBox(height: 12),
                  _buildVisualStepper(status),
                  const SizedBox(height: 32),
                  _buildSectionLabel("ACTION CENTER"),
                  const SizedBox(height: 12),
                  _buildDynamicActionUI(status),
                  _buildSupportContactWidget(),
                  if (status.contains('completed') || 
                      status.contains('finish') || 
                      status.contains('ready') ||
                      status.contains('done')) ...[
                    const SizedBox(height: 32),
                    _buildSectionLabel("YOUR FEEDBACK"),
                    const SizedBox(height: 12),
                    _buildFeedbackSection(),
                  ],
                  const SizedBox(height: 32),
                  _buildSectionLabel("PROJECT INFO"),
                  const SizedBox(height: 12),
                  _buildProjectDetails(),
                  const SizedBox(height: 100), // Extra space at the bottom for scrolling
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildSectionLabel(String text) {
    return Text(text,
        style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Colors.grey.shade500,
            letterSpacing: 1.2));
  }

  Widget _buildStatusHeader(String status) {
    return Container(
      width: double.infinity,
      color: cardTheme,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: brandColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.description_outlined, color: brandColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(currentJobData['title'] ?? "Translation Project",
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 4),
                Text(
                    "Job ID: ${currentJobData['id'].toString().toUpperCase().substring(0, 8)}",
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualStepper(String status) {
    // Determine progress index
    int step = 0;
    if (status == 'price quoted') step = 1;
    if (status == 'awaiting down payment' || status == 'down payment verification') step = 1; 
    if (status == 'approved' || status == 'in progress' || status == 'accepted') step = 2;
    if (status == 'pending review' || status == 'pending_review' || status == 'awaiting verification') step = 3;
    if (status == 'completed' || status == 'finished') step = 4;

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: cardTheme,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (index) {
              bool isDone = index <= step;
              return Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isDone ? brandColor : Colors.grey.shade200,
                        shape: BoxShape.circle,
                      ),
                      child: isDone
                          ? Icon(Icons.check,
                              size: 14, color: cardTheme)
                          : null,
                    ),
                    if (index != 4)
                      Expanded(
                          child: Container(
                              height: 3,
                              color: index < step
                                  ? brandColor
                                  : Colors.grey.shade200)),
                  ],
                ),
              );
            }),
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Sent",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textThemeSec)),
              Text("Quote",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textThemeSec)),
              Text("Working",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textThemeSec)),
              Text("Review",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textThemeSec)),
              Text("Ready",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textThemeSec)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildDynamicActionUI(String status) {
    if (status.contains('completed') || 
        status.contains('finish') || 
        status.contains('ready') ||
        status.contains('done')) {
      return _buildActionCard(
          "Download Ready",
          "Your translation is complete and approved.",
          Icons.verified_user,
           Colors.green,
          isDownload: true);
    } else if (status == 'rejected' || status == 'payment_rejected') {
      final String reason = (currentJobData['rejection_reason'] ?? "").toString();
      final bool isClientRejected = reason.contains('[CLIENT_REJECTED]');
      
      return _buildActionCard(
          isClientRejected ? "Quote Declined" : "Payment Rejected",
          isClientRejected 
              ? "You have rejected the price for this job." 
              : (reason.replaceAll('[CLIENT_REJECTED]', '').trim().isEmpty 
                  ? "Issue with payment receipt. Please resubmit." 
                  : reason.replaceAll('[CLIENT_REJECTED]', '').trim()),
          isClientRejected ? Icons.cancel_outlined : Icons.error_outline,
          isClientRejected ? Colors.grey : Colors.redAccent);
    } else if (status == 'pending review' || status == 'pending_review' || status == 'awaiting verification') {
      return _buildActionCard(
          "Checking Quality",
          "Admin is reviewing the translation now.",
          Icons.fact_check,
          brandColor);
    } else if (status == 'price quoted') {
      return _buildActionCard(
          "New Quote",
          "Check dashboard to approve the price.",
          Icons.account_balance_wallet,
          brandColor,
          showPaymentOptions: true);
    } else if (status == 'down payment verification') {
      return _buildActionCard(
          "Verifying Payment",
          "Admin is checking your down payment.",
          Icons.fact_check_outlined,
          brandColor);
    } else if (status == 'approved' || status == 'in progress' || status == 'accepted') {
      return _buildActionCard(
          "Translator at Work",
          "We are currently translating your file.",
          Icons.edit_note,
          brandColor);
    } else {
      return _buildActionCard("Finding Translator",
          "Waiting for a professional to start.", Icons.search, Colors.grey);
    }
  }

  Widget _buildActionCard(String title, String sub, IconData icon, Color color,
      {bool isDownload = false, bool showPaymentOptions = false}) {
    final double? price = currentJobData['price'] as double?;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: cardTheme,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ]),
      child: Column(
        children: [
          Icon(icon, size: 48, color: color),
          const SizedBox(height: 16),
          Text(title,
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 4),
          Text(sub,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey)),
          if (isDownload) ...[
            const SizedBox(height: 24),
            if (_downloadProgress > 0) ...[
              LinearProgressIndicator(
                  value: _downloadProgress,
                  color: Colors.green,
                  backgroundColor: Colors.green.shade50),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isActionLoading
                    ? null
                    : () => _downloadTranslation(
                        currentJobData['translated_file_url']),
                icon: const Icon(Icons.cloud_download),
                label: Text(_isActionLoading
                    ? "DOWNLOADING..."
                    : "DOWNLOAD FINAL FILE"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandColor,
                  foregroundColor: cardTheme,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ] else if (showPaymentOptions) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Handle payment via Stripe or other gateway
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandColor,
                  foregroundColor: cardTheme,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("SUBMIT RECEIPT",
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _payWithPoints(currentJobData['id'], (double.tryParse((price ?? 0).toString()) ?? 0.0) * 0.5),
                icon: Icon(Icons.stars_rounded, color: brandColor),
                label: const Text("PAY WITH POINTS"),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: brandColor, width: 2),
                  foregroundColor: brandColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 20),
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
          ]
        ],
      ),
    );
  }

  Widget _buildProjectDetails() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: cardTheme,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: [
          _buildRow("Project Title", currentJobData['title'] ?? "Not set"),
          const Divider(height: 24),
          _buildRow("Current Status",
              currentJobData['status'].toString().toUpperCase()),
          const Divider(height: 24),
          _buildRow("Languages",
              "${currentJobData['from_lang']} → ${currentJobData['to_lang']}"),
        ],
      ),
    );
  }

  Widget _buildFeedbackSection() {
    final bool hasSubmitted = currentJobData['feedback_option'] != null;

    if (hasSubmitted) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green.withValues(alpha: 0.2))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                const Text("Feedback Submitted",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 12),
            Text("Option: ${currentJobData['feedback_option']}",
                style: const TextStyle(fontWeight: FontWeight.w600)),
            if (currentJobData['feedback_text'] != null &&
                currentJobData['feedback_text'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text("Comments: ${currentJobData['feedback_text']}"),
            ]
          ],
        ),
      );
    }

    final List<String> feedbackOptions = [
      "Excellent translation quality",
      "Fast delivery time",
      "Great communication",
      "Very professional",
      "Other (please specify)"
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: cardTheme,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.1))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("RATE YOUR EXPERIENCE",
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: textThemeSec,
                  letterSpacing: 0.8)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                onPressed: () => setState(() => _selectedRating = index + 1),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  index < _selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: index < _selectedRating ? Colors.orange : Colors.grey.withValues(alpha: 0.2),
                  size: 36,
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          Text("WHAT WAS THE BEST PART?",
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: textThemeSec,
                  letterSpacing: 0.8)),
          const SizedBox(height: 8),
          // Use a Wrap or a more compact layout for feedback options to save space
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: feedbackOptions.map((opt) {
              final bool isSel = _selectedFeedbackOption == opt;
              return ChoiceChip(
                label: Text(opt, style: TextStyle(fontSize: 12, color: isSel ? Colors.white : textThemeSec)),
                selected: isSel,
                onSelected: (val) => setState(() => _selectedFeedbackOption = val ? opt : null),
                selectedColor: brandColor,
                backgroundColor: cardTheme,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isSel ? brandColor : Colors.grey.withValues(alpha: 0.2))),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _feedbackController,
            maxLines: 2,
            style: TextStyle(fontSize: 14, color: textThemeHeader),
            decoration: InputDecoration(
              hintText: "Additional comments...",
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              filled: true,
              fillColor: bgTheme,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_selectedRating == 0 || _selectedFeedbackOption == null || _isFeedbackSubmitting)
                  ? null
                  : _submitFeedback,
              style: ElevatedButton.styleFrom(
                backgroundColor: brandColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _isFeedbackSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text("SUBMIT FEEDBACK",
                      style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitFeedback() async {
    setState(() => _isFeedbackSubmitting = true);
    try {
      final String feedbackText = _feedbackController.text.trim();
      final res = await Supabase.instance.client
          .from('jobs')
          .update({
            'rating': _selectedRating,
            'feedback_option': _selectedFeedbackOption,
            'feedback_text': feedbackText,
          })
          .eq('id', currentJobData['id'])
          .select();

      if (res.isNotEmpty) {
        setState(() {
          currentJobData['feedback_option'] = _selectedFeedbackOption;
          currentJobData['feedback_text'] = feedbackText;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Thank you for your feedback!")));
        }
      }
    } finally {
      if (mounted) setState(() => _isFeedbackSubmitting = false);
    }
  }

  Future<void> _payWithPoints(dynamic jobId, double amount) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final profile = await supabase.from('customer_accounts').select('loyalty_points').eq('id', user.id).maybeSingle();
    final int currentPoints = profile?['loyalty_points'] ?? 0;

    if (currentPoints < amount) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Insufficient points! You need ${amount.toInt()} points."),
          backgroundColor: Colors.redAccent,
        ));
      }
      return;
    }

    if (!mounted) return;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Pay with Points?"),
        content: Text("Use ${amount.toInt()} loyalty points for this payment? This will be sent to admin for approval."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("USE POINTS")),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supabase.from('point_redemption_requests').insert({
        'customer_id': user.id,
        'points_amount': amount.toInt(),
        'job_id': jobId,
        'status': 'pending'
      });

      // Update job status correctly based on current state
      final currentStatus = (currentJobData['status'] ?? '').toString().toLowerCase();
      String nextStatus = 'awaiting verification'; // default for final payment
      if (currentStatus == 'awaiting down payment') {
        nextStatus = 'down payment verification';
      }

      await supabase.from('jobs').update({
        'status': nextStatus
      }).eq('id', jobId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Points request sent to admin!"),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent));
      }
    }
  }

  Widget _buildRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      ],
    );
  }
}
