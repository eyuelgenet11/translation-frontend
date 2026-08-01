import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../live_order_tracker_screen.dart';
import '../widgets/empty_state.dart';

class TrackerTab extends StatelessWidget {
  final List<Map<String, dynamic>> activeTrackerJobs;
  final Map<String, dynamic>? selectedTrackerJob;
  final ValueChanged<Map<String, dynamic>> onSelectJob;
  final Color brandBrown;
  final Color textMainTheme;
  final Color textSecTheme;
  final Color surfaceTheme;
  final VoidCallback onRefresh;

  const TrackerTab({
    super.key,
    required this.activeTrackerJobs,
    required this.selectedTrackerJob,
    required this.onSelectJob,
    required this.brandBrown,
    required this.textMainTheme,
    required this.textSecTheme,
    required this.surfaceTheme,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (activeTrackerJobs.isEmpty) {
      return _buildEmptyState(
          "No active translation project to track.", Icons.track_changes_rounded);
    }

    final job = selectedTrackerJob ?? activeTrackerJobs.first;
    final status = (job['status'] ?? 'Unknown').toString().toLowerCase();
    final cfg = _getStatusConfig(status);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 50, 24, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [brandBrown, brandBrown.withValues(alpha: 0.75)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: brandBrown.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7, height: 7,
                            decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 5),
                          const Text("LIVE", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                        ],
                      ),
                    ),
                    if (activeTrackerJobs.length > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "${activeTrackerJobs.length} Active Projects",
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  "Live Tracker",
                  style: GoogleFonts.inter(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  activeTrackerJobs.length > 1
                      ? "Select a project below to track its progress."
                      : "Track your document in real-time.",
                  style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7)),
                ),
                if (activeTrackerJobs.length > 1) ...[
                  const SizedBox(height: 20),
                  _buildProjectSelector(),
                ],
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                // Status card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: surfaceTheme,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: (cfg['color'] as Color).withValues(alpha: 0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: (cfg['color'] as Color).withValues(alpha: 0.1),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: (cfg['color'] as Color).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(cfg['icon'] as IconData,
                                color: cfg['color'] as Color, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(cfg['label'] as String,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 17,
                                        color: cfg['color'] as Color)),
                                const SizedBox(height: 4),
                                Text(cfg['desc'] as String,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: textSecTheme,
                                        height: 1.4)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (status.contains('awaiting') || status.contains('payment')) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded,
                                  color: Colors.orange, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Tap ORDER DETAILS below to upload your Telebirr receipt.",
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange.shade800),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Job info card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: surfaceTheme,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Column(
                    children: [
                      _trackerRow("Title", job['title'] ?? "Translation Request"),
                      const Divider(height: 24),
                      _trackerRow("Languages",
                          "${job['from_lang'] ?? '?'} → ${job['to_lang'] ?? '?'}",
                          valueColor: brandBrown),
                      const Divider(height: 24),
                      _trackerRow("Total Price", "${job['price'] != null ? (double.tryParse(job['price'].toString()) ?? 0.0).toStringAsFixed(2) : '-'} ETB"),
                      const Divider(height: 24),
                      _trackerRow(
                        "Urgency / Delivery",
                        ((job['delivery_time'] ?? '').toString().isNotEmpty)
                            ? job['delivery_time'].toString()
                            : (job['urgency'] ?? '-').toString()
                      ),
                    ],
                  ),
                ),
                if (status == 'completed') ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFEF3C7)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.stars_rounded, color: Color(0xFFF59E0B), size: 22),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Loyalty points from this payment appear on your Profile.",
                            style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF92400E),
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LiveOrderTrackerScreen(
                            job: job,
                          ),
                        ),
                      ).then((_) => onRefresh());
                    },
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text("VIEW ORDER DETAILS"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandBrown,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String msg, IconData icon) {
    return PremiumEmptyState(
      title: msg,
      subtitle: "You don't have any active translation project right now. Start a new one from the marketplace.",
      icon: icon,
      brandBrown: brandBrown,
    );
  }

  Widget _buildProjectSelector() {
    final currentSelectedId = (selectedTrackerJob ?? activeTrackerJobs.first)['id'];

    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: activeTrackerJobs.length,
        itemBuilder: (context, index) {
          final item = activeTrackerJobs[index];
          final bool isSelected = item['id'] == currentSelectedId;
          final from = item['from_lang'] ?? '?';
          final to = item['to_lang'] ?? '?';
          final statusStr = (item['status'] ?? '').toString();

          return GestureDetector(
            onTap: () => onSelectJob(item),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : Icons.description_outlined,
                    size: 16,
                    color: isSelected ? brandBrown : Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$from → $to",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? brandBrown : Colors.white,
                        ),
                      ),
                      Text(
                        statusStr.toUpperCase(),
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? brandBrown.withValues(alpha: 0.75)
                              : Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _trackerRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: textSecTheme, fontSize: 13)),
        Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: valueColor)),
      ],
    );
  }

  Map<String, dynamic> _getStatusConfig(String status) {
    if (status == 'pending_review') {
      return {
        'color': Colors.green,
        'icon': Icons.rate_review_rounded,
        'label': '⚡ Review Your Document!',
        'desc': 'The translator has delivered your file. Tap to preview and accept or request a revision.'
      };
    }
    if (status == 'revision_requested') {
      return {
        'color': Colors.orange,
        'icon': Icons.published_with_changes_rounded,
        'label': 'Revision in Progress',
        'desc': 'The translator is currently making adjustments based on your feedback.'
      };
    }
    if (status == 'completed') {
      return {
        'color': Colors.green,
        'icon': Icons.task_alt_rounded,
        'label': 'Project Completed!',
        'desc': 'Success! Your document is fully translated and verified. Download the final version in details.'
      };
    }
    if (status == 'down payment verification') {
      return {
        'color': Colors.blue,
        'icon': Icons.fact_check_outlined,
        'label': 'Verifying Down Payment',
        'desc': 'Admin is confirming your down payment receipt.'
      };
    }
    if (status == 'awaiting down payment') {
      return {
        'color': Colors.orange,
        'icon': Icons.payments_outlined,
        'label': 'Down Payment Needed',
        'desc': 'Pay 50% to start the translation.'
      };
    }
    if (status == 'awaiting payment') {
      return {
        'color': Colors.orange,
        'icon': Icons.account_balance_wallet_outlined,
        'label': 'Final Payment Needed',
        'desc': 'Upload your final Telebirr receipt to receive the file.'
      };
    }
    if (status == 'awaiting verification') {
      return {
        'color': Colors.blue,
        'icon': Icons.hourglass_top_rounded,
        'label': 'Payment Under Review',
        'desc': 'Admin is verifying your payment receipt.'
      };
    }
    if (status == 'accepted' || status == 'in progress' || status == 'in_progress' || status == 'approved') {
      return {
        'color': brandBrown,
        'icon': Icons.edit_note_rounded,
        'label': 'Expert at Work',
        'desc': 'Your document is being translated with the highest attention to detail.'
      };
    }
    if (status.contains('quoted')) {
      return {
        'color': const Color(0xFF7C3AED),
        'icon': Icons.price_check_rounded,
        'label': 'Quote Received',
        'desc': 'Check History tab to accept the price.'
      };
    }
    return {
      'color': brandBrown,
      'icon': Icons.assignment_turned_in_rounded,
      'label': 'Order Received',
      'desc': 'Your translation request has been received and is ready for processing.'
    };
  }
}
