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
  List<Map<String, dynamic>> _pendingTranslators = [];
  List<Map<String, dynamic>> _allRequests = [];
  List<Map<String, dynamic>> _settledHistory = [];

  // Summary statistics
  double _totalVolume = 0.0;
  double _readyToSettle = 0.0;
  double _heldEscrow = 0.0;
  double _totalSettled = 0.0;
  double _totalRevenue = 0.0;

  RealtimeChannel? _adminChannel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
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
      // Use SECURITY DEFINER RPC functions to bypass RLS, with direct query fallbacks
      List pendingRes = [];
      try {
        pendingRes = await _supabase.rpc('admin_get_pending_payments') as List;
      } catch (e) {
        debugPrint("RPC admin_get_pending_payments error: $e");
      }

      if (pendingRes.isEmpty) {
        final directData = await _supabase
            .from('jobs')
            .select('*')
            .or('status.eq.awaiting_verification,status.eq.awaiting_payment,status.eq.pending')
            .not('transaction_ref', 'is', null)
            .order('created_at', ascending: false);
        pendingRes = directData as List;
      }

      List unsettledRes = [];
      try { unsettledRes = await _supabase.rpc('admin_get_unsettled_jobs') as List; } catch (_) {}
      
      List escrowRes = [];
      try { escrowRes = await _supabase.rpc('admin_get_escrow_jobs') as List; } catch (_) {}
      
      List translatorsRes = [];
      try { translatorsRes = await _supabase.rpc('admin_get_pending_translators') as List; } catch (_) {}
      
      List requestsRes = [];
      try { requestsRes = await _supabase.rpc('admin_get_all_requests') as List; } catch (_) {
        final directReq = await _supabase.from('jobs').select('*').order('created_at', ascending: false);
        requestsRes = directReq as List;
      }
      
      List settledRes = [];
      try { settledRes = await _supabase.rpc('admin_get_settled_history') as List; } catch (_) {}

      if (mounted) {
        setState(() {
          _pendingPayments = List<Map<String, dynamic>>.from(pendingRes);
          _unsettledJobs = List<Map<String, dynamic>>.from(unsettledRes);
          _escrowJobs = List<Map<String, dynamic>>.from(escrowRes);
          _pendingTranslators = List<Map<String, dynamic>>.from(translatorsRes);
          _allRequests = List<Map<String, dynamic>>.from(requestsRes);
          _settledHistory = List<Map<String, dynamic>>.from(settledRes);

          debugPrint("Admin Dashboard Fetched Data:");
          debugPrint("- Pending Payments: ${_pendingPayments.length}");
          debugPrint("- Unsettled Jobs: ${_unsettledJobs.length}");
          debugPrint("- Escrow Jobs: ${_escrowJobs.length}");
          debugPrint("- Pending Translators: ${_pendingTranslators.length}");
          debugPrint("- All Requests: ${_allRequests.length}");
          debugPrint("- Settled History: ${_settledHistory.length}");

          // Calculate metrics
          _heldEscrow = _escrowJobs.fold(0.0, (sum, item) {
            final price = (item['price'] ?? 0.0).toDouble();
            return sum + (price * 1.20);
          });

          _readyToSettle = _unsettledJobs.fold(0.0, (sum, item) {
            return sum + (item['price'] ?? 0.0).toDouble();
          });

          _totalSettled = _settledHistory.fold(0.0, (sum, item) {
            return sum + (item['price'] ?? 0.0).toDouble();
          });

          double totalEscrowBase = _escrowJobs.fold(0.0, (sum, item) => sum + (item['price'] ?? 0.0).toDouble());
          _totalRevenue = (totalEscrowBase + _readyToSettle + _totalSettled) * 0.20;

          _totalVolume = _readyToSettle * 1.20;

          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching admin dashboard data: $e");
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Failed to load admin data: $e"),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 5),
        ));
      }
    }
  }

  Future<void> _approveTranslator(String translatorId) async {
    try {
      await _supabase.rpc('admin_approve_translator', params: {
        'p_translator_id': translatorId,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("✅ Translator approved successfully."),
        backgroundColor: Colors.green,
      ));
      _fetchData();
    } catch (e) {
      if (mounted) _showErrorDialog("Failed to approve translator: $e");
    }
  }

  Future<void> _approvePayment(String jobId) async {
    try {
      try {
        await _supabase.rpc('admin_approve_payment', params: {'p_job_id': jobId});
      } catch (_) {
        await _supabase.from('jobs').update({'status': 'In Progress'}).eq('id', jobId);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("✅ Payment approved. Status is now 'In Progress'."),
        backgroundColor: Colors.green,
      ));
      _fetchData();
    } catch (e) {
      if (mounted) _showErrorDialog("Failed to approve payment: $e");
    }
  }

  Future<void> _rejectPayment(String jobId, String reason) async {
    try {
      try {
        await _supabase.rpc('admin_reject_payment', params: {
          'p_job_id': jobId,
          'p_reason': reason,
        });
      } catch (_) {
        await _supabase.from('jobs').update({
          'status': 'awaiting_payment',
          'rejection_reason': reason,
        }).eq('id', jobId);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("❌ Payment rejected. Reason: $reason"),
        backgroundColor: Colors.redAccent,
      ));
      _fetchData();
    } catch (e) {
      if (mounted) _showErrorDialog("Failed to reject payment: $e");
    }
  }

  Future<void> _settlePayout(Map<String, dynamic> job) async {
    try {
      final double netPayout = (job['price'] ?? 0.0).toDouble();
      final double totalVolume = netPayout * 1.15;
      final double adminFee = totalVolume - netPayout;

      await _supabase.rpc('admin_settle_payout', params: {
        'p_job_id': job['id'].toString(),
        'p_net_payout': netPayout,
        'p_total_volume': totalVolume,
        'p_admin_fee': adminFee,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("✅ Settlement processed! Net payout: ${netPayout.toStringAsFixed(2)} ETB."),
        backgroundColor: Colors.green,
      ));
      _fetchData();
    } catch (e) {
      if (mounted) _showErrorDialog("Failed to settle job payout: $e");
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
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          unselectedLabelColor: widget.textSecTheme,
          indicatorColor: widget.brandBrown,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 12),
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.payments_outlined, size: 15),
                  const SizedBox(width: 5),
                  Text("Payments (${_pendingPayments.length})"),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.assignment_turned_in_outlined, size: 15),
                  const SizedBox(width: 5),
                  Text("Settle (${_unsettledJobs.length})"),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 15),
                  const SizedBox(width: 5),
                  Text("Escrow (${_escrowJobs.length})"),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.group_add_outlined, size: 15),
                  const SizedBox(width: 5),
                  Text("Translators (${_pendingTranslators.length})"),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.list_alt_rounded, size: 15),
                  const SizedBox(width: 5),
                  Text("Requests (${_allRequests.length})"),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.history_rounded, size: 15),
                  const SizedBox(width: 5),
                  Text("History (${_settledHistory.length})"),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_balance_wallet_rounded, size: 15),
                  const SizedBox(width: 5),
                  const Text("Revenue"),
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
                    _buildTranslatorsTab(),
                    _buildRequestsTab(),
                    _buildSettledHistoryTab(),
                    _buildRevenueTab(),
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
            onTap: () => _tabController.animateTo(2), // Escrow tab index
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            label: "READY TO SETTLE",
            value: "${_readyToSettle.toStringAsFixed(0)} ETB",
            icon: Icons.check_circle_outline_rounded,
            color: Colors.green.shade700,
            onTap: () => _tabController.animateTo(1), // Settle tab index
          ),
          _buildStatCard(
            label: "TOTAL SETTLED",
            value: "${_totalSettled.toStringAsFixed(0)} ETB",
            icon: Icons.history_rounded,
            color: widget.brandBrown,
            onTap: () => _tabController.animateTo(5), // Settled history tab index
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            label: "PLATFORM REVENUE",
            value: "${_totalRevenue.toStringAsFixed(0)} ETB",
            icon: Icons.account_balance_wallet_rounded,
            color: Colors.amber.shade700,
            onTap: () => _tabController.animateTo(6), // Revenue tab index
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
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
    ),
   );
  }

  Widget _buildSettledHistoryTab() {
    if (_settledHistory.isEmpty) {
      return PremiumEmptyState(
        title: "No History",
        subtitle: "There are no fully settled jobs yet.",
        icon: Icons.history_rounded,
        brandBrown: widget.brandBrown,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _settledHistory.length,
      itemBuilder: (context, index) {
        final job = _settledHistory[index];
        final translatorName = job['office_name'] ?? job['translator_name'] ?? "Unknown Translator";
        final price = (job['price'] ?? 0.0).toDouble();

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
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "SETTLED",
                      style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
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
                  Text("Total Customer Paid:", style: TextStyle(fontSize: 12, color: widget.textSecTheme)),
                  Text("${(price * 1.15).toStringAsFixed(2)} ETB", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Platform Service Charge (20%):", style: TextStyle(fontSize: 12, color: Colors.amber.shade700)),
                  Text("- ${(price * 0.20).toStringAsFixed(2)} ETB", style: TextStyle(fontSize: 12, color: Colors.amber.shade700)),
                ],
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Amount Paid to Translator", style: TextStyle(fontSize: 11, color: widget.textSecTheme)),
                      Text(
                        "${price.toStringAsFixed(2)} ETB",
                        style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, color: widget.brandBrown),
                      ),
                    ],
                  ),
                  const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
                ],
              ),
            ],
          ),
        );
      },
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
        final String reference = job['transaction_ref'] ?? '';
        final String receipt = job['receipt_url'] ?? '';
        final clientName = job['client_full_name'] ?? 'Unknown Client';

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
                crossAxisAlignment: CrossAxisAlignment.center,
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
                  const Spacer(),
                  if (reference.isNotEmpty)
                    Flexible(
                      child: ElevatedButton.icon(
                        onPressed: () => _launchTelebirrPortal(reference),
                        icon: const Icon(Icons.open_in_new_rounded, size: 14),
                        label: Text(
                          "REF: $reference",
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade50,
                          foregroundColor: Colors.blue.shade800,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
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
        final translatorName = job['office_name'] ?? job['translator_name'] ?? "Unknown Translator";
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
                  Text("Total Customer Paid:", style: TextStyle(fontSize: 12, color: widget.textSecTheme)),
                  Text("${(netPayout * 1.15).toStringAsFixed(2)} ETB", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Platform Service Charge (20%):", style: TextStyle(fontSize: 12, color: Colors.amber.shade700)),
                  Text("- ${(netPayout * 0.20).toStringAsFixed(2)} ETB", style: TextStyle(fontSize: 12, color: Colors.amber.shade700)),
                ],
              ),
              const Divider(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Net Payout Due to Translator", style: TextStyle(fontSize: 11, color: widget.textSecTheme)),
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
        final translatorName = job['office_name'] ?? job['translator_name'] ?? "Unknown Translator";
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
                  Text("Total Customer Paid:", style: TextStyle(fontSize: 12, color: widget.textSecTheme)),
                  Text("${escrowAmount.toStringAsFixed(2)} ETB", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Platform Service Charge (20%):", style: TextStyle(fontSize: 12, color: Colors.amber.shade700)),
                  Text("- ${((job['price'] ?? 0.0) * 0.20).toStringAsFixed(2)} ETB", style: TextStyle(fontSize: 12, color: Colors.amber.shade700)),
                ],
              ),
              const Divider(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Held for Translator", style: TextStyle(fontSize: 11, color: widget.textSecTheme)),
                      Text(
                        "${(job['price'] ?? 0.0).toDouble().toStringAsFixed(2)} ETB",
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

  Widget _buildTranslatorsTab() {
    if (_pendingTranslators.isEmpty) {
      return PremiumEmptyState(
        title: "No Pending Translators",
        subtitle: "There are no new translator registrations waiting for approval.",
        icon: Icons.group_off_outlined,
        brandBrown: widget.brandBrown,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _pendingTranslators.length,
      itemBuilder: (context, index) {
        final translator = _pendingTranslators[index];
        final name = translator['full_name'] ?? "Unknown";
        final office = translator['office_name'] ?? "N/A";
        final email = translator['email'] ?? "No email provided";

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
                    name,
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: widget.brandBrown),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "PENDING",
                      style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 8),
              Text("Office: $office", style: const TextStyle(fontWeight: FontWeight.w500)),
              Text("Email: $email", style: TextStyle(fontSize: 12, color: widget.textSecTheme)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _approveTranslator(translator['id']),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                  label: const Text("APPROVE TRANSLATOR"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.brandBrown,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRequestsTab() {
    if (_allRequests.isEmpty) {
      return PremiumEmptyState(
        title: "No Translation Requests",
        subtitle: "There are no translation requests in the system yet.",
        icon: Icons.list_alt_rounded,
        brandBrown: widget.brandBrown,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _allRequests.length,
      itemBuilder: (context, index) {
        final job = _allRequests[index];
        final clientName = job['client_full_name'] ?? "Unknown Client";
        final status = job['status']?.toString().toUpperCase() ?? 'UNKNOWN';
        final price = job['price'] != null ? "${job['price']} ETB" : "Not quoted yet";
        final deliveryTime = job['delivery_time'] != null ? "Time needed: ${job['delivery_time']}" : '';

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
                      color: Colors.blueGrey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status,
                      style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 8),
              Text("Client: $clientName", style: const TextStyle(fontWeight: FontWeight.w500)),
              Text("Job ID: #${job['id'].toString().substring(0, 8).toUpperCase()}", style: TextStyle(fontSize: 12, color: widget.textSecTheme)),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Quoted Price", style: TextStyle(fontSize: 11, color: widget.textSecTheme)),
                      Text(
                        price,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 14, color: widget.brandBrown),
                      ),
                    ],
                  ),
                  if (deliveryTime.isNotEmpty)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16.0),
                        child: Text(
                          deliveryTime,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                        ),
                      ),
                    )
                ],
              ),
            ],
          ),
        );
      },
    );
  }
  Widget _buildRevenueTab() {
    final allJobs = [..._escrowJobs, ..._unsettledJobs, ..._settledHistory];
    
    // Sort combined list by created_at descending
    allJobs.sort((a, b) {
      final aDate = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime.now();
      final bDate = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime.now();
      return bDate.compareTo(aDate);
    });

    if (allJobs.isEmpty) {
      return PremiumEmptyState(
        title: "No Revenue Data",
        subtitle: "There are no active or settled jobs yet.",
        icon: Icons.account_balance_wallet_rounded,
        brandBrown: widget.brandBrown,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: allJobs.length,
      itemBuilder: (context, index) {
        final job = allJobs[index];
        final double basePrice = (job['price'] ?? 0.0).toDouble();
        final double platformFee = basePrice * 0.20;
        final double totalCustomerPaid = basePrice + platformFee;
        
        final String statusStr = (job['status'] ?? '').toString().toLowerCase();
        
        Color badgeColor;
        String badgeText;
        if (job['settled'] == true) {
          badgeColor = widget.brandBrown;
          badgeText = "Settled";
        } else if (statusStr == 'completed') {
          badgeColor = Colors.green.shade700;
          badgeText = "Ready to Settle";
        } else {
          badgeColor = Colors.blue.shade700;
          badgeText = "In Escrow";
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.surfaceTheme,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Job #${job['id'].toString().substring(0, 8).toUpperCase()}",
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Translator Base Price:", style: TextStyle(fontSize: 12, color: widget.textSecTheme)),
                  Text("${basePrice.toStringAsFixed(2)} ETB", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Service Charge (15%):", style: TextStyle(fontSize: 12, color: Colors.amber.shade700, fontWeight: FontWeight.bold)),
                  Text("+ ${platformFee.toStringAsFixed(2)} ETB", style: TextStyle(fontSize: 12, color: Colors.amber.shade700, fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Customer Paid:", style: TextStyle(fontSize: 12, color: widget.textSecTheme)),
                  Text(
                    "${totalCustomerPaid.toStringAsFixed(2)} ETB",
                    style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 14, color: widget.brandBrown),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
