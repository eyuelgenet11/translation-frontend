import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/api_service.dart';

class PaymentScreen extends StatefulWidget {
  final Map<String, dynamic> job; // Passed from the list

  const PaymentScreen({super.key, required this.job});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool isUploading = false;
  final SupabaseClient supabase = Supabase.instance.client;

  final TextEditingController _refController = TextEditingController();

  // 1. Handle Verifying the Payment (MVP Flow)
  Future<void> _verifyPayment() async {
    final String ref = _refController.text.trim();
    if (ref.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the transaction reference.')),
      );
      return;
    }

    setState(() => isUploading = true);

    try {
      // Logic for MVP: Automated verification via our backend
      final response = await ApiService.verifyPayment(
        jobId: widget.job['id'],
        transactionRef: ref,
      );

      if (mounted) {
        if (response['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Payment verified! Status updated.')),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Verification failed: ${response['message']}'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() => isUploading = false);
    }
  }

  // 2. Legacy: Handle Uploading the Payment Receipt
  Future<void> _uploadReceipt() async {
    // ... preserved for fallback or physical receipts if needed
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    setState(() => isUploading = true);

    try {
      final bytes = await image.readAsBytes();
      final fileExt = image.name.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final path = 'receipts/$fileName';

      // Upload to 'payments' bucket
      await supabase.storage.from('payments').uploadBinary(path, bytes);

      // Update job status manually
      await supabase.from('jobs').update({
        'payment_screenshot_path': path,
        'status': 'Awaiting Payment',
      }).eq('id', widget.job['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Receipt uploaded! waiting for Admin.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Upload failed: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() => isUploading = false);
    }
  }

  // 3. Handle Downloading the Final Translation
  Future<void> _downloadFinalFile() async {
    // ... preserved
    try {
      final String path = widget.job['translated_file_path'];
      final String signedUrl = await supabase.storage
          .from('translations')
          .createSignedUrl(path, 600);

      final Uri url = Uri.parse(signedUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Error: File missing or access denied.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = widget.job['status'];
    final Color brandColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final Color bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Order Details', style: TextStyle(color: isDark ? Colors.black : Colors.white)),
        backgroundColor: brandColor,
        iconTheme: IconThemeData(color: isDark ? Colors.black : Colors.white),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const Divider(height: 40),
              if (status == 'Awaiting Payment' || status == 'Pending') ...[
                _buildPaymentInstructions(),
                const SizedBox(height: 20),
                TextField(
                  controller: _refController,
                  decoration: const InputDecoration(
                    labelText: 'Transaction Reference (e.g., Mxxxxxxxx)',
                    border: OutlineInputBorder(),
                    hintText: 'Enter Telebirr/CBE reference',
                  ),
                ),
                const SizedBox(height: 20),
                _buildActionButton(
                  label: isUploading ? 'Verifying...' : 'Verify Payment Automatically',
                  onPressed: isUploading ? null : _verifyPayment,
                  color: Colors.blue,
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _uploadReceipt,
                  child: const Text('Or upload a physical receipt screenshot'),
                ),
              ] else if (status == 'Completed') ...[
              _buildSuccessState(),
              const Spacer(),
              _buildActionButton(
                label: 'Download Translation',
                onPressed: _downloadFinalFile,
                color: Colors.green,
              ),
            ] else ...[
              const Center(
                  child: Text('Translator is still working on your file...')),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildHeader() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.job['title'],
          style:
              TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      Text('${widget.job['from_lang']} → ${widget.job['to_lang']}',
          style: TextStyle(color: Colors.grey)),
    ]);
  }

  Widget _buildPaymentInstructions() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: Colors.amber.shade50, borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Text('Payment Required',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
        const SizedBox(height: 10),
        const Text(
            'Please transfer the quoted amount via Telebirr or CBE and upload the screenshot below.',
            textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _buildSuccessState() {
    return Center(
      child: Column(children: [
        const Icon(Icons.check_circle, size: 80, color: Colors.green),
        const SizedBox(height: 10),
        Text('Payment Verified!',
            style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text('Your file is ready for download.', style: TextStyle()),
      ]),
    );
  }

  Widget _buildActionButton(
      {required String label,
      required VoidCallback? onPressed,
      required Color color}) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
            backgroundColor: color,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))),
        onPressed: onPressed,
        child: Text(label,
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
