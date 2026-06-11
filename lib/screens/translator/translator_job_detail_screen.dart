import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../utils/job_status_utils.dart';
import '../job_chat_screen.dart';

class TranslatorJobDetailScreen extends StatefulWidget {
  final Map<String, dynamic> job;

  const TranslatorJobDetailScreen({super.key, required this.job});

  @override
  State<TranslatorJobDetailScreen> createState() =>
      _TranslatorJobDetailScreenState();
}

class _TranslatorJobDetailScreenState extends State<TranslatorJobDetailScreen> {
  final _supabase = Supabase.instance.client;
  late Map<String, dynamic> _job;
  final _priceController = TextEditingController();
  bool _loading = false;
  PlatformFile? _selectedFile;
  RealtimeChannel? _jobChannel;

  static const _brown = Color(0xFF895129);

  @override
  void initState() {
    super.initState();
    _job = Map<String, dynamic>.from(widget.job);
    _priceController.text = _job['price']?.toString() ?? '';
    _subscribeToJob();
  }

  void _subscribeToJob() {
    final id = _job['id'];
    _jobChannel = _supabase
        .channel('translator_job_$id')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'jobs',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: id.toString(),
          ),
          callback: (payload) {
            if (mounted && payload.newRecord.isNotEmpty) {
              setState(() => _job = Map<String, dynamic>.from(payload.newRecord));
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _jobChannel?.unsubscribe();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _openUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _sendQuote() async {
    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price <= 0) {
      _snack('Enter a valid price in ETB.', isError: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final delivery = _job['delivery_requested'] == true;
      final newStatus = delivery ? 'pending' : 'quoted';
      await _supabase.from('jobs').update({
        'price': price,
        'status': newStatus,
      }).eq('id', _job['id']);
      _snack(delivery ? 'Quote saved.' : 'Quote sent to customer.');
    } catch (e) {
      _snack('Failed to send quote: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _selectedFile = result.files.first);
    }
  }

  Future<void> _deliverWork() async {
    if (_selectedFile == null) {
      _snack('Select a completed file first.', isError: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final ext = _selectedFile!.extension ?? 'pdf';
      final fileName = 'final/${_job['id']}_${DateTime.now().millisecondsSinceEpoch}.$ext';

      if (kIsWeb) {
        final bytes = _selectedFile!.bytes;
        if (bytes == null) throw Exception('Could not read file bytes.');
        await _supabase.storage.from('translations').uploadBinary(fileName, bytes);
      } else {
        final path = _selectedFile!.path;
        if (path == null) throw Exception('Invalid file path.');
        await _supabase.storage.from('translations').upload(fileName, File(path));
      }

      final publicUrl =
          _supabase.storage.from('translations').getPublicUrl(fileName);

      await _supabase.from('jobs').update({
        'status': 'pending_review',
        'translated_file_url': publicUrl,
      }).eq('id', _job['id']);

      setState(() => _selectedFile = null);
      _snack('Translation delivered — awaiting customer review.');
    } catch (e) {
      _snack('Delivery failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : _brown,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = normalizeJobStatus(_job['status']);
    final title =
        '${_job['from_lang'] ?? '?'} → ${_job['to_lang'] ?? '?'}';

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            tooltip: 'Chat with customer',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => JobChatScreen(job: _job),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _statusChip(status),
          const SizedBox(height: 16),
          _infoCard(
            'Source document',
            'Customer original file',
            action: TextButton.icon(
              onPressed: () => _openUrl(_job['file_url']?.toString()),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('View'),
            ),
          ),
          if (_job['urgency'] != null) ...[
            const SizedBox(height: 12),
            _infoCard(
              '${_job['urgency']} delivery',
              'Urgency fee: ${_job['urgency_fee'] ?? 0} ETB',
            ),
          ],
          if (_job['delivery_requested'] == true) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: const Text(
                'Physical delivery is handled by admin. Upload the digital translation only.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (jobStatusIs(_job['status'], 'pending')) _buildQuoteSection(),
          if (jobStatusIs(_job['status'], 'quoted')) _buildWait('Quote sent', 'Waiting for customer to accept.'),
          if (jobStatusIn(_job['status'], ['awaiting payment', 'awaiting verification']))
            _buildWait('Awaiting payment', 'Customer must pay before you can translate.'),
          if (jobStatusIn(_job['status'], ['in progress', 'accepted', 'approved']))
            _buildUploadSection('Deliver translation'),
          if (jobStatusIn(_job['status'], ['pending review']))
            _buildWait('Under review', 'Customer is reviewing your delivery.'),
          if (jobStatusIs(_job['status'], 'revision requested')) ...[
            if (_job['revision_notes'] != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _job['revision_notes'].toString(),
                  style: TextStyle(color: Colors.red.shade900, height: 1.4),
                ),
              ),
            _buildUploadSection('Submit revision'),
          ],
          if (jobStatusIs(_job['status'], 'completed'))
            _buildWait('Completed', 'Customer accepted this job.'),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _brown.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          status.toUpperCase(),
          style: const TextStyle(
            color: _brown,
            fontWeight: FontWeight.w800,
            fontSize: 11,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _infoCard(String title, String subtitle, {Widget? action}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ],
            ),
          ),
          if (action != null) action,
        ],
      ),
    );
  }

  Widget _buildQuoteSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Proposed price (ETB)', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(
          controller: _priceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: '0.00',
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _loading ? null : _sendQuote,
          style: ElevatedButton.styleFrom(
            backgroundColor: _brown,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(_loading ? 'Sending…' : 'Send quote'),
        ),
      ],
    );
  }

  Widget _buildUploadSection(String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Payment verified — upload your completed file.',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _pickFile,
          icon: const Icon(Icons.upload_file_rounded),
          label: Text(_selectedFile?.name ?? 'Choose file'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _loading ? null : _deliverWork,
          style: ElevatedButton.styleFrom(
            backgroundColor: _brown,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(_loading ? 'Uploading…' : label),
        ),
      ],
    );
  }

  Widget _buildWait(String title, String message) {
    return Column(
      children: [
        Icon(Icons.hourglass_top_rounded, size: 48, color: Colors.amber.shade700),
        const SizedBox(height: 12),
        Text(title, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
      ],
    );
  }
}
