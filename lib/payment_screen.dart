import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ds.dart';
import 'services/api_service.dart';

class PaymentScreen extends StatefulWidget {
  final Map<String, dynamic> job;
  const PaymentScreen({super.key, required this.job});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  static const Color _brown = DS.primary;
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
      }
    } catch (e) {
      _showSnack('Failed to select image: $e', isError: true);
    }
  }

  // â”€â”€ Verify payment via backend with direct Supabase fallback â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _verifyPayment() async {
    final ref = _refController.text.trim();
    if (ref.isEmpty && _screenshotBytes == null) {
      _showSnack('Please enter your transaction reference or attach a receipt screenshot.', isError: true);
      return;
    }
    setState(() => _isVerifying = true);
    try {
      final rawJobId = widget.job['id'];
      final String jobIdStr = rawJobId.toString();
      String? receiptPublicUrl;

      Map<String, dynamic> response;
      try {
        response = await ApiService.verifyPayment(
          jobId: jobIdStr,
          transactionRef: ref.isNotEmpty ? ref : null,
          screenshotBytes: _screenshotBytes,
          screenshotFilename: _screenshotName,
        );
      } catch (err) {
        response = {'success': false, 'message': err.toString()};
      }

      // Fallback: If backend server endpoint fails or is unreachable, update Supabase directly
      if (response['success'] != true) {
        debugPrint("Backend payment verification note: ${response['message']}. Using direct Supabase update...");
        try {
          if (_screenshotBytes != null) {
            final String path = 'receipts/${jobIdStr}_${DateTime.now().millisecondsSinceEpoch}.png';
            try {
              await _supabase.storage.from('translations').uploadBinary(
                path,
                _screenshotBytes!,
                fileOptions: const FileOptions(contentType: 'image/png'),
              );
              receiptPublicUrl = _supabase.storage.from('translations').getPublicUrl(path);
            } catch (storageErr) {
              debugPrint("Receipt storage note: $storageErr");
            }
          }

          final Map<String, dynamic> updatePayload = {
            'status': 'awaiting verification',
          };
          if (ref.isNotEmpty) updatePayload['transaction_ref'] = ref;
          if (receiptPublicUrl != null) updatePayload['receipt_url'] = receiptPublicUrl;

          dynamic targetId = rawJobId;
          if (rawJobId is String && int.tryParse(rawJobId) != null) {
            targetId = int.parse(rawJobId);
          }

          await _supabase.from('jobs').update(updatePayload).eq('id', targetId);
          response = {'success': true};
        } catch (dbErr) {
          debugPrint("Direct Supabase update error: $dbErr");
        }
      }

      // Trigger direct Telegram Bot notification with inline verification buttons
      final shortJobId = jobIdStr.length > 8 ? jobIdStr.substring(0, 8).toUpperCase() : jobIdStr;
      final String refText = ref.isNotEmpty ? ref : 'Receipt Screenshot Attached';
      final String fromLang = widget.job['from_lang'] ?? '';
      final String toLang = widget.job['to_lang'] ?? '';
      final String priceText = widget.job['price'] != null ? '${widget.job['price']} ETB' : 'Quoted Price';

      final List<List<Map<String, String>>> inlineKeyboard = [
        [
          {'text': 'âœ… Approve Payment', 'callback_data': 'approve_pay_$jobIdStr'},
          {'text': 'âŒ Reject Payment', 'callback_data': 'reject_pay_$jobIdStr'},
        ]
      ];

      ApiService.sendTelegramDirect(
        text: 'ðŸ’³ <b>CUSTOMER PAYMENT SUBMITTED FOR VERIFICATION</b>\n'
              'â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”\n'
              'ðŸ†” <b>Job ID:</b> #$shortJobId\n'
              'ðŸ”¢ <b>Ref Number:</b> <code>$refText</code>\n'
              'ðŸ’° <b>Quoted Price:</b> $priceText\n'
              'ðŸ”¤ <b>Languages:</b> $fromLang â†’ $toLang\n'
              'ðŸ“± <b>Customer Phone:</b> ${widget.job['client_phone'] ?? 'N/A'}\n'
              'â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”\n'
              'âš ï¸ <i>Tap below to approve or reject this payment directly in Telegram:</i>',
        documentUrl: receiptPublicUrl,
        inlineKeyboard: inlineKeyboard,
      );

      if (!mounted) return;
      if (response['success'] == true) {
        final updatedJob = Map<String, dynamic>.from(widget.job);
        updatedJob['status'] = 'awaiting verification';
        if (ref.isNotEmpty) updatedJob['transaction_ref'] = ref;
        if (receiptPublicUrl != null) updatedJob['receipt_url'] = receiptPublicUrl;
        
        // Direct immediately to Payment Verification Underway page
        Navigator.pushReplacementNamed(
          context,
          '/live_tracker',
          arguments: updatedJob,
        );
      } else {
        _showSnack('âŒ Verification failed: ${response['message']}', isError: true);
      }
    } catch (e) {
      _showSnack('âŒ Error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? DS.error : DS.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
    final bgColor = Colors.white;
    final cardColor = Theme.of(context).cardColor;
    final headerColor = Colors.black87;
    final subColor = Colors.black54;

    final status = (widget.job['status'] ?? 'pending') as String;
    final fromLang = widget.job['from_lang'] ?? '';
    final toLang = widget.job['to_lang'] ?? '';
    final pages = widget.job['page_count'];
    final price = widget.job['price'];
    final priceStr = (price != null && (double.tryParse(price.toString()) ?? 0) > 0)
        ? '${(double.tryParse(price.toString()) ?? 0).toStringAsFixed(2)} ETB'
        : 'Quoted Price';
    const telebirrNumber = '0911373034';
    const cbeNumber = '1000416227838';
    const accountName = 'Eyuel Shimelis';

    final needsPayment = status.toLowerCase() == 'pending' ||
        status.toLowerCase() == 'awaiting payment';
    final isCompleted = status.toLowerCase() == 'completed';

    return Scaffold(
      backgroundColor: DS.background,
      appBar: AppBar(
        backgroundColor: DS.background,
        foregroundColor: DS.textPrimary,
        elevation: 0,
        surfaceTintColor: DS.background,
        title: Text(
          'Order Details',
          style: GoogleFonts.inter(
            color: DS.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // â”€â”€ Job summary card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            _dsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: DS.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          widget.job['is_handwritten'] == true
                              ? Icons.draw_outlined
                              : Icons.description_outlined,
                          color: DS.primary,
                          size: 24,
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
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: DS.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'From: $fromLang  to  $toLang',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: DS.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _statusBadge(status),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // â”€â”€ Price + payment instructions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            if (needsPayment) ...[
              // Price highlight
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
                decoration: BoxDecoration(
                  color: DS.bgSecondary,
                  borderRadius: BorderRadius.circular(DS.radiusCard),
                  border: Border.all(color: DS.border),
                ),
                child: Column(
                  children: [
                    Text(
                      'Amount Due',
                      style: GoogleFonts.inter(
                        color: DS.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      priceStr,
                      style: GoogleFonts.inter(
                        color: DS.textPrimary,
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Pay to account card
              _dsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.account_balance_wallet_outlined, color: DS.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Pay To This Account',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: DS.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(height: 1, color: DS.divider),
                    const SizedBox(height: 16),

                    // Telebirr
                    _accountRow(
                      label: 'Telebirr',
                      value: telebirrNumber,
                      name: accountName,
                      onCopy: () => _copyToClipboard(telebirrNumber),
                    ),

                    Divider(height: 24, color: DS.divider),

                    // CBE
                    _accountRow(
                      label: 'CBE (Commercial Bank of Ethiopia)',
                      value: cbeNumber,
                      name: accountName,
                      onCopy: () => _copyToClipboard(cbeNumber),
                    ),

                    const SizedBox(height: 16),
                    Text(
                      'Transfer exactly $priceStr and enter your transaction reference below.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: DS.textSecondary,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Reference entry card
              _dsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.receipt_long_outlined, color: DS.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Confirm Your Payment',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: DS.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _refController,
                      style: GoogleFonts.inter(color: DS.textPrimary),
                      decoration: DS.inputDecoration(
                        hint: 'e.g. M12345678 or FT-XXXX',
                        label: 'Transaction Reference',
                        prefix: const Icon(Icons.tag_outlined, color: DS.primary, size: 20),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _pickScreenshot,
                      icon: Icon(
                        _screenshotBytes != null ? Icons.check_circle_outline : Icons.add_photo_alternate_outlined,
                        color: _screenshotBytes != null ? DS.success : DS.primary,
                        size: 18,
                      ),
                      label: Text(
                        _screenshotName != null
                            ? 'Attached: $_screenshotName'
                            : 'Attach Receipt Screenshot',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _screenshotBytes != null ? DS.success : DS.primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        side: BorderSide(
                          color: _screenshotBytes != null ? DS.success : DS.border,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(DS.radiusButton),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: DS.buttonHeight,
                      child: ElevatedButton.icon(
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
                              fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        style: DS.primaryButton(),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // â”€â”€ Completed state â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            if (isCompleted)
              _dsCard(
                child: Column(
                  children: [
                    Icon(Icons.task_alt_rounded, color: DS.success, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Translation Complete!',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: DS.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your translated document is ready to download.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: DS.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: DS.buttonHeight,
                      child: ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.download_outlined),
                        label: Text(
                          'Download Translation',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DS.success,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(DS.radiusButton),
                          ),
                          minimumSize: const Size(double.infinity, DS.buttonHeight),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (!needsPayment && !isCompleted)
              _dsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: DS.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.hourglass_bottom_rounded, color: DS.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Translation in Progress',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: DS.textPrimary,
                                ),
                              ),
                              Text(
                                'Status: $status',
                                style: GoogleFonts.inter(fontSize: 12, color: DS.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(height: 1, color: DS.divider),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: DS.bgSecondary,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: DS.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.phone_in_talk_rounded, color: DS.success, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'You will receive a direct phone call as soon as your document is finished.',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: DS.textPrimary,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, color: DS.primary, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Processing time varies by urgency level (${widget.job['urgency'] ?? 'Normal'}). Our team is working on your file.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: DS.textSecondary,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _dsCard({required Widget child, Color? borderColor}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: DS.cardDecoration(borderColor: borderColor),
      child: child,
    );
  }

  Widget _card({required Color cardColor, required Widget child}) {
    return _dsCard(child: child);
  }

  Widget _statusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'pending':
      case 'awaiting payment':
        color = DS.warning;
        break;
      case 'in progress':
        color = DS.primary;
        break;
      case 'completed':
        color = DS.success;
        break;
      case 'rejected':
        color = DS.error;
        break;
      case 'awaiting review':
        color = const Color(0xFF4F46E5); // indigo
        break;
      default:
        color = DS.placeholder;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(DS.radiusTag),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
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
    required VoidCallback onCopy,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: DS.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: DS.textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                name,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: DS.textSecondary,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: onCopy,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: DS.bgSecondary,
              borderRadius: BorderRadius.circular(DS.radiusButton),
              border: Border.all(color: DS.border),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.copy_outlined, color: DS.primary, size: 14),
                SizedBox(width: 4),
                Text('Copy',
                    style: TextStyle(
                        color: DS.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return 'â€”';
    try {
      final dt = DateTime.parse(dateStr.toString()).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr.toString();
    }
  }
}

