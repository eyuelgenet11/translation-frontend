import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/empty_state.dart';

class AdminDashboardTab extends StatefulWidget {
  final Color brandBrown;
  final Color textMainTheme;
  final Color textSecTheme;
  final Color surfaceTheme;

  const AdminDashboardTab({
    super.key,
    required this.brandBrown,
    required this.textMainTheme,
    required this.textSecTheme,
    required this.surfaceTheme,
  });

  @override
  State<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<AdminDashboardTab> with SingleTickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;
  late TabController _tabController;

  bool _loading = true;
  List<Map<String, dynamic>> _pendingPayments = [];
  List<Map<String, dynamic>> _unsettledJobs = [];
  List<Map<String, dynamic>> _escrowJobs = [];

  // Summary statistics
  double _totalVolume = 0.0;
  double _readyToSettle = 0.0;
  double _heldEscrow = 0.0;

  RealtimeChannel? _adminChannel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchData();
    _subscribeToJobs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _adminChannel?.unsubscribe();
    super.dispose();
  }

  // Real-time subscription to jobs table so admin updates dynamically
  void _subscribeToJobs() {
    _adminChannel = _supabase
        .channel('admin-dashboard-changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'jobs',
          callback: (payload) {
            debugPrint("Admin Dashboard: Real-time update detected.");
            _fetchData();
          },
        )
        .subscribe();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      // 1. Fetch pending payments (Awaiting Verification)
      final pendingRes = await _supabase
          .from('jobs')
          .select('*, profiles!jobs_client_id_fkey(full_name)')
          .or('status.eq.awaiting verification,status.eq.Awaiting Verification')
          .order('created_at', ascending: false);

      // 2. Fetch completed but unsettled jobs (Grouped by translator or individual)
      final unsettledRes = await _supabase
          .from('jobs')
          .select('*, profiles!fk_jobs_translator(office_name, full_name)')
          .eq('status', 'completed')
          .or('settled.is.null,settled.eq.false')
          .order('created_at', ascending: false);

      // 3. Fetch active escrow jobs (In Progress)
      final escrowRes = await _supabase
          .from('jobs')
          .select('*, profiles!fk_jobs_translator(office_name, full_name)')
          .eq('status', 'In Progress')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _pendingPayments = List<Map<String, dynamic>>.from(pendingRes);
          _unsettledJobs = List<Map<String, dynamic>>.from(unsettledRes);
          _escrowJobs = List<Map<String, dynamic>>.from(escrowRes);

          // Calculate metrics
          _heldEscrow = _escrowJobs.fold(0.0, (sum, item) {
            final price = (item['price'] ?? 0.0).toDouble();
            return sum + (price * 1.15); // Gross amount held
          });

          _readyToSettle = _unsettledJobs.fold(0.0, (sum, item) {
            return sum + (item['price'] ?? 0.0).toDouble(); // Net payouts ready
          });

          _totalVolume = _readyToSettle * 1.15; // Total gross volume ready for Z-reports

          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching admin dashboard data: $e");
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _approvePayment(String jobId) async {
    try {
      await _supabase.from('jobs').update({
        'status': 'In Progress',
        'verified_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', jobId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Payment approved. Translation status is now 'In Progress'."),
          backgroundColor: Colors.green,
        ));
      }
      _fetchData();
    } catch (e) {
      _showErrorDialog("Failed to approve payment: $e");
    }
  }

  Future<void> _rejectPayment(String jobId, String reason) async {
    try {
      await _supabase.from('jobs').update({
        'status': 'Rejected',
        'rejection_reason': reason,
      }).eq('id', jobId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Payment rejected. Reason: $reason"),
          backgroundColor: Colors.redAccent,
        ));
      }
      _fetchData();
    } catch (e) {
      _showErrorDialog("Failed to reject payment: $e");
    }
  }

  Future<void> _settlePayout(Map<String, dynamic> job) async {
    try {
      final double netPayout = (job['price'] ?? 0.0).toDouble();
      final double totalVolume = netPayout * 1.15;
      final double adminFee = totalVolume - netPayout;

      // 1. Create a partial Z-Report record
      final report = await _supabase.from('z_reports').insert({
        'report_date': DateTime.now().toUtc().toIso8601String().split('T')[0],
        'jobs_count': 1,
        'total_volume': totalVolume,
        'net_payout': netPayout,
        'admin_fee': adminFee,
      }).select().single();

      // 2. Mark the job as settled
      await _supabase.from('jobs').update({
        'settled': true,
        'z_report_id': report['id'],
      }).eq('id', job['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Settlement processed! Net payout of ${netPayout.toStringAsFixed(2)} ETB disbursed."),
          backgroundColor: Colors.green,
        ));
      }
      _fetchData();
    } catch (e) {
      _showErrorDialog("Failed to settle job payout: $e");
    }
  }

  void _showErrorDialog(String msg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Error"),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(String jobId) {
    final TextEditingController reasonController = TextEditingController();
    String selectedReason = 'Invalid Transaction ID';
    final List<String> commonReasons = [
      'Invalid Transaction ID',
      'Amount Mismatch',
      'Wrong Receiver',
      'Blurry Screenshot',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: widget.surfaceTheme,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            "Reject Payment Request",
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Select a reason or type a custom one. This will notify the customer."),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: commonReasons.map((reason) {
                  final isSelected = selectedReason == reason;
                  return InkWell(
                    onTap: () {
                      setModalState(() {
                        selectedReason = reason;
                        reasonController.text = reason;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? widget.brandBrown : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        reason,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: "Enter custom reason...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL"),
            ),
            ElevatedButton(
              onPressed: () {
                final reason = reasonController.text.trim().isNotEmpty
                    ? reasonController.text.trim()
                    : selectedReason;
                Navigator.pop(context);
                _rejectPayment(jobId, reason);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("REJECT"),
            ),
          ],
        ),
      ),
    );
  }

  void _viewReceiptImage(String receiptPath) {
    if (receiptPath.isEmpty) return;

    final String publicUrl = receiptPath.startsWith('http')
        ? receiptPath
        : _supabase.storage.from('receipts').getPublicUrl(receiptPath);

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (context) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.network(
              publicUrl,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const CircularProgressIndicator(color: Colors.white);
              },
              errorBuilder: (context, error, stackTrace) => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 12),
                  Text("Failed to load receipt image", style: GoogleFonts.inter(color: Colors.white)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _launchTelebirrPortal(String reference) async {
    final url = Uri.parse("https://transactioninfo.ethiotelecom.et/receipt/$reference");
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw "Could not launch URL";
      }
    } catch (e) {
      if (mounted) {
        Clipboard.setData(ClipboardData(text: reference));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Reference copied to clipboard. Portal could not be launched."),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // App Bar / Title
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Admin Dashboard",
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: widget.textMainTheme,
                    ),
                  ),
                  Text(
                    "Marketplace oversight & verification",
                    style: TextStyle(fontSize: 13, color: widget.textSecTheme),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                color: widget.brandBrown,
                onPressed: _fetchData,
              )
            ],
          ),
        ),

        // Statistics Overview Cards
        _buildStatsOverview(),

        // Tab bar navigation
        TabBar(
          controller: _tabController,
          labelColor: widget.brandBrown,
          unselectedLabelColor: widget.textSecTheme,
          indicatorColor: widget.brandBrown,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.payments_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text("Payments (${_pendingPayments.length})"),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.assignment_turned_in_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text("Settle (${_unsettledJobs.length})"),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 16),
                  const SizedBox(width: 6),
                  Text("Escrow (${_escrowJobs.length})"),
                ],
              ),
            ),
          ],
        ),

        // Tab body views
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: widget.brandBrown))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPaymentsTab(),
                    _buildSettleTab(),
                    _buildEscrowTab(),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildStatsOverview() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          _buildStatCard(
            label: "HELD IN ESCROW",
            value: "${_heldEscrow.toStringAsFixed(0)} ETB",
            icon: Icons.lock_outline_rounded,
            color: Colors.blue.shade700,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            label: "READY TO SETTLE",
            value: "${_readyToSettle.toStringAsFixed(0)} ETB",
            icon: Icons.check_circle_outline_rounded,
            color: Colors.green.shade700,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            label: "TOTAL VOLUME",
            value: "${_totalVolume.toStringAsFixed(0)} ETB",
            icon: Icons.trending_up_rounded,
            color: widget.brandBrown,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.surfaceTheme,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: widget.textSecTheme,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: widget.textMainTheme,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsTab() {
    if (_pendingPayments.isEmpty) {
      return PremiumEmptyState(
        title: "All Caught Up!",
        subtitle: "No pending payment receipts are waiting for review.",
        icon: Icons.done_all_rounded,
        brandBrown: widget.brandBrown,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _pendingPayments.length,
      itemBuilder: (context, index) {
        final job = _pendingPayments[index];
        final client = job['profiles'] ?? {};
        final clientName = client['full_name'] ?? "Unknown Client";
        final String reference = job['transaction_ref'] ?? '';
        final String receipt = job['receipt_url'] ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.surfaceTheme,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Lang pair and Job details
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "${job['from_lang']} → ${job['to_lang']}",
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: widget.brandBrown),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "REVIEW REQUIRED",
                      style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 8),
              Text("Client: $clientName", style: const TextStyle(fontWeight: FontWeight.w500)),
              Text("Job ID: #${job['id'].toString().substring(0, 8).toUpperCase()}", style: TextStyle(fontSize: 12, color: widget.textSecTheme)),
              const Divider(height: 24),

              // Telebirr / Payment Reference Info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Total Amount", style: TextStyle(fontSize: 11, color: widget.textSecTheme)),
                      Text(
                        "${((job['price'] ?? 0.0) * 1.15).toStringAsFixed(2)} ETB",
                        style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18, color: widget.brandBrown),
                      ),
                    ],
                  ),
                  if (reference.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: () => _launchTelebirrPortal(reference),
                      icon: const Icon(Icons.open_in_new_rounded, size: 14),
                      label: Text("REF: $reference"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade50,
                        foregroundColor: Colors.blue.shade800,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                    )
                  else if (receipt.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: () => _viewReceiptImage(receipt),
                      icon: const Icon(Icons.image_search_rounded, size: 14),
                      label: const Text("VIEW SLIP"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade50,
                        foregroundColor: Colors.green.shade800,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Action buttons: Approve / Reject
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showRejectDialog(job['id']),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text("REJECT"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("Approve Payment?"),
                            content: const Text("Ensure transaction details have been verified on the Telebirr portal before approving."),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _approvePayment(job['id']);
                                },
                                child: const Text("CONFIRM"),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text("APPROVE"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.brandBrown,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettleTab() {
    if (_unsettledJobs.isEmpty) {
      return PremiumEmptyState(
        title: "All Settled!",
        subtitle: "No completed jobs are waiting for translator payouts.",
        icon: Icons.done_outline_rounded,
        brandBrown: widget.brandBrown,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _unsettledJobs.length,
      itemBuilder: (context, index) {
        final job = _unsettledJobs[index];
        final translator = job['profiles'] ?? {};
        final translatorName = translator['office_name'] ?? translator['full_name'] ?? "Unknown Translator";
        final netPayout = (job['price'] ?? 0.0).toDouble();

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.surfaceTheme,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "${job['from_lang']} → ${job['to_lang']}",
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: widget.brandBrown),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "COMPLETED",
                      style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 8),
              Text("Translator: $translatorName", style: const TextStyle(fontWeight: FontWeight.w500)),
              Text("Job ID: #${job['id'].toString().substring(0, 8).toUpperCase()}", style: TextStyle(fontSize: 12, color: widget.textSecTheme)),
              const Divider(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Net Payout due", style: TextStyle(fontSize: 11, color: widget.textSecTheme)),
                      Text(
                        "${netPayout.toStringAsFixed(2)} ETB",
                        style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.green.shade800),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text("Disburse Settlement?"),
                          content: Text("Confirm payment of ${netPayout.toStringAsFixed(2)} ETB has been transferred to $translatorName."),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _settlePayout(job);
                              },
                              child: const Text("DISBURSE"),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.account_balance_wallet_rounded, size: 14),
                    label: const Text("DISBURSE PAYOUT"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEscrowTab() {
    if (_escrowJobs.isEmpty) {
      return PremiumEmptyState(
        title: "Escrow Empty",
        subtitle: "No translation jobs are currently in progress.",
        icon: Icons.lock_open_rounded,
        brandBrown: widget.brandBrown,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _escrowJobs.length,
      itemBuilder: (context, index) {
        final job = _escrowJobs[index];
        final translator = job['profiles'] ?? {};
        final translatorName = translator['office_name'] ?? translator['full_name'] ?? "Unknown Translator";
        final escrowAmount = ((job['price'] ?? 0.0) * 1.15).toDouble();

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.surfaceTheme,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "${job['from_lang']} → ${job['to_lang']}",
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: widget.brandBrown),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "IN PROGRESS",
                      style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 8),
              Text("Assigned to: $translatorName", style: const TextStyle(fontWeight: FontWeight.w500)),
              Text("Job ID: #${job['id'].toString().substring(0, 8).toUpperCase()}", style: TextStyle(fontSize: 12, color: widget.textSecTheme)),
              const Divider(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Funds in Escrow (Held)", style: TextStyle(fontSize: 11, color: widget.textSecTheme)),
                      Text(
                        "${escrowAmount.toStringAsFixed(2)} ETB",
                        style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.blue.shade800),
                      ),
                    ],
                  ),
                  const Icon(Icons.security_rounded, color: Colors.blueAccent, size: 28),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
