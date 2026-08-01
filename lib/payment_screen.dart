import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/api_service.dart';

class PaymentScreen extends StatefulWidget {
  final Map<String, dynamic> job;
  const PaymentScreen({super.key, required this.job});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  static const Color _brown = Color(0xFF895129);
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _refController = TextEditingController();
  bool _isVerifying = false;
  Uint8List? _screenshotBytes;
  String? _screenshotName;

  @override
  void dispose() {
    _refController.dispose();
    super.dispose();
  }

  Future<void> _pickScreenshot() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _screenshotBytes = file.bytes;
          _screenshotName = file.name;
        });
        _showSnack('Receipt screenshot attached!');
      }
    } catch (e) {
      _showSnack('Failed to select image: $e', isError: true);
    }
  }

  // ── Verify payment via backend ────────────────────────────────────────────
  Future<void> _verifyPayment() async {
    final ref = _refController.text.trim();
    if (ref.isEmpty && _screenshotBytes == null) {
      _showSnack('Please enter your transaction reference or attach a receipt screenshot.', isError: true);
      return;
    }
    setState(() => _isVerifying = true);
    try {
      final response = await ApiService.verifyPayment(
        jobId: widget.job['id'],
        transactionRef: ref.isNotEmpty ? ref : null,
        screenshotBytes: _screenshotBytes,
        screenshotFilename: _screenshotName,
      );
      if (!mounted) return;
      if (response['success'] == true) {
        _showSnack('✅ Payment submitted! Verification in progress.');
        final updatedJob = Map<String, dynamic>.from(widget.job);
        updatedJob['status'] = 'awaiting verification';
        Navigator.pushReplacementNamed(
          context,
          '/live_tracker',
          arguments: updatedJob,
        );
      } else {
        _showSnack('❌ Verification failed: ${response['message']}', isError: true);
      }
    } catch (e) {
      _showSnack('❌ Error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade700 : _brown,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnack('Copied to clipboard!');
  }

  Future<void> _openTelebirr() async {
    final uri = Uri.parse('telebirr://');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showSnack('Telebirr app not found on this device.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final headerColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white60 : Colors.black54;

    final status = (widget.job['status'] ?? 'pending') as String;
    final fromLang = widget.job['from_lang'] ?? '';
    final toLang = widget.job['to_lang'] ?? '';
    final pages = widget.job['page_count'];
    final price = widget.job['price'];
    final priceStr = (price != null && (double.tryParse(price.toString()) ?? 0) > 0)
        ? '${(double.tryParse(price.toString()) ?? 0).toStringAsFixed(2)} ETB'
        : 'Quoted Price';
    final accountNumber = '0911373034';
    final accountName = 'Eyuel Shimelis';

    final needsPayment = status.toLowerCase() == 'pending' ||
        status.toLowerCase() == 'awaiting payment';
    final isCompleted = status.toLowerCase() == 'completed';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: _brown,
        foregroundColor: Colors.white,
        title: Text(
          'Order Details',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Job summary card ──────────────────────────────────────────
            _card(
              cardColor: cardColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _brown.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          widget.job['is_handwritten'] == true
                              ? Icons.draw_outlined
                              : Icons.description_outlined,
                          color: _brown,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Translation Job',
                              style: GoogleFonts.inter(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: headerColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$fromLang → $toLang',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: subColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _statusBadge(status),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  _infoRow(Icons.file_copy_outlined, 'Pages',
                      pages != null ? '$pages page${pages == 1 ? '' : 's'}' : '—',
                      headerColor, subColor),
                  const SizedBox(height: 8),
                  _infoRow(Icons.speed_outlined, 'Urgency',
                      widget.job['urgency'] ?? 'Normal', headerColor, subColor),
                  const SizedBox(height: 8),
                  _infoRow(Icons.calendar_today_outlined, 'Submitted',
                      _formatDate(widget.job['created_at']), headerColor, subColor),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Price + payment instructions ──────────────────────────────
            if (needsPayment) ...[
              // Price highlight
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_brown, const Color(0xFFB06E3A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(
                      'Amount Due',
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      priceStr,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Pay to account card
              _card(
                cardColor: cardColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.account_balance_wallet_outlined, color: _brown, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Pay To This Account',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: headerColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 14),

                    // Telebirr / CBE
                    _accountRow(
                      label: 'Telebirr / CBE',
                      value: accountNumber,
                      name: accountName,
                      cardColor: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF5F0EB),
                      headerColor: headerColor,
                      subColor: subColor,
                      onCopy: () => _copyToClipboard(accountNumber),
                    ),

                    const SizedBox(height: 14),
                    Text(
                      '⚠️ Please transfer exactly $priceStr and enter your transaction reference below.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: subColor,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _openTelebirr,
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: Text(
                        'Open Telebirr App',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Reference entry card
              _card(
                cardColor: cardColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.receipt_long_outlined, color: _brown, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Confirm Your Payment',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: headerColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _refController,
                      style: GoogleFonts.inter(color: headerColor),
                      decoration: InputDecoration(
                        hintText: 'e.g. M12345678 or FT-XXXX',
                        hintStyle: GoogleFonts.inter(color: subColor, fontSize: 13),
                        labelText: 'Transaction Reference',
                        labelStyle: GoogleFonts.inter(color: _brown, fontSize: 13),
                        prefixIcon: Icon(Icons.tag, color: _brown, size: 20),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : const Color(0xFFF5F0EB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: _brown, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 12),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _pickScreenshot,
                      icon: Icon(
                        _screenshotBytes != null ? Icons.check_circle : Icons.add_photo_alternate_outlined,
                        color: _screenshotBytes != null ? Colors.green.shade700 : _brown,
                        size: 18,
                      ),
                      label: Text(
                        _screenshotName != null
                            ? 'Attached: $_screenshotName'
                            : 'Or Attach Receipt Screenshot Image',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _screenshotBytes != null ? Colors.green.shade700 : _brown,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44),
                        side: BorderSide(
                          color: _screenshotBytes != null ? Colors.green.shade700 : _brown.withValues(alpha: 0.5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: _isVerifying ? null : _verifyPayment,
                      icon: _isVerifying
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.verified_outlined, size: 18),
                      label: Text(
                        _isVerifying ? 'Verifying...' : 'Verify Payment',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brown,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _brown.withValues(alpha: 0.5),
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Completed state ───────────────────────────────────────────
            if (isCompleted)
              _card(
                cardColor: cardColor,
                child: Column(
                  children: [
                    Icon(Icons.task_alt, color: Colors.teal.shade600, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Translation Complete!',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: headerColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your translated document is ready to download.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: subColor, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.download_outlined),
                      label: Text(
                        'Download Translation',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade600,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Work in Progress / Other status card ─────────────────────────
            if (!needsPayment && !isCompleted)
              _card(
                cardColor: cardColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _brown.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.hourglass_bottom_rounded, color: _brown, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Translation in Progress',
                                style: GoogleFonts.inter(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: headerColor,
                                ),
                              ),
                              Text(
                                'Status: $status',
                                style: GoogleFonts.inter(fontSize: 12, color: subColor),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),

                    // Phone Call Alert Box
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.phone_in_talk_rounded, color: Colors.green, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '📞 You will receive a direct phone call as soon as your document is finished!',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Urgency & Time notice
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: _brown, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Please note: Quality translation requires careful review. Processing time varies depending on your selected urgency level (${widget.job['urgency'] ?? 'Normal'}). Our team is working on your file.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: subColor,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _card({required Color cardColor, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'pending':
      case 'awaiting payment':
        color = Colors.orange.shade700;
        break;
      case 'in progress':
        color = _brown;
        break;
      case 'completed':
        color = Colors.teal.shade600;
        break;
      case 'rejected':
        color = Colors.red.shade600;
        break;
      case 'awaiting review':
        color = Colors.indigo.shade500;
        break;
      default:
        color = Colors.grey.shade500;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value,
      Color headerColor, Color subColor) {
    return Row(
      children: [
        Icon(icon, size: 16, color: subColor),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: GoogleFonts.inter(fontSize: 13, color: subColor),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: headerColor,
          ),
        ),
      ],
    );
  }

  Widget _accountRow({
    required String label,
    required String value,
    required String name,
    required Color cardColor,
    required Color headerColor,
    required Color subColor,
    required VoidCallback onCopy,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 11, color: subColor),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: headerColor,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  name,
                  style: GoogleFonts.inter(fontSize: 12, color: subColor),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCopy,
            icon: Icon(Icons.copy_rounded, color: _brown, size: 20),
            tooltip: 'Copy',
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return '—';
    try {
      final dt = DateTime.parse(dateStr.toString()).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr.toString();
    }
  }
}
