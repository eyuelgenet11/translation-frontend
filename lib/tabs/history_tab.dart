import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../live_order_tracker_screen.dart';
import '../Job Detail Screen.dart';
import '../widgets/empty_state.dart';

class HistoryTab extends StatelessWidget {
  final SupabaseClient supabase;
  final Color brandBrown;
  final Color textMainTheme;
  final Color textSecTheme;
  final Color surfaceTheme;
  final Future<List<Map<String, dynamic>>> Function() fetchHistoryJobs;
  final Function(Map<String, dynamic>) showFileActionMenu;
  final VoidCallback onRefresh;

  const HistoryTab({
    super.key,
    required this.supabase,
    required this.brandBrown,
    required this.textMainTheme,
    required this.textSecTheme,
    required this.surfaceTheme,
    required this.fetchHistoryJobs,
    required this.showFileActionMenu,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) {
      return _buildEmptyState("Please log in to see history", Icons.lock_outline);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 20),
          child: Text("Document History",
              style: GoogleFonts.philosopher(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: textMainTheme)),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: fetchHistoryJobs(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: Colors.brown));
              }
              if (snapshot.hasError) {
                return _buildEmptyState(
                    "Error loading history", Icons.error_outline);
              }

              final jobs = snapshot.data ?? [];
              if (jobs.isEmpty) {
                return _buildEmptyState(
                    "No documents translated yet", Icons.history);
              }

              return ListView.separated(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                itemCount: jobs.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final job = jobs[index];
                  final status =
                      (job['status'] ?? 'Unknown').toString().toLowerCase();

                  final translatorData = job['translator'];
                  final String translatorName = translatorData != null
                      ? (translatorData['office_name'] ??
                          translatorData['full_name'] ??
                          "Unknown Translator")
                      : "Unknown Translator";

                  Color statusColor = Colors.grey;
                  IconData statusIcon = Icons.access_time;

                  if (status == 'completed') {
                    statusColor = Colors.green;
                    statusIcon = Icons.check_circle;
                  } else if (status == 'in progress' ||
                      status == 'accepted' ||
                      status == 'approved') {
                    statusColor = brandBrown;
                    statusIcon = Icons.edit_note;
                  } else if (status.contains('awaiting')) {
                    statusColor = Colors.orange;
                    statusIcon = Icons.payment;
                  }

                  return InkWell(
                    onTap: () {
                      if (status == 'completed') {
                        showFileActionMenu(job);
                      } else if (status == 'pending_review' || status == 'revision_requested') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LiveOrderTrackerScreen(job: job),
                          ),
                        ).then((_) => onRefresh());
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CustomerJobDetail(job: job),
                          ),
                        ).then((_) => onRefresh());
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                          color: surfaceTheme,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4))
                          ]),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child:
                                Icon(statusIcon, color: statusColor, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  job['title'] ?? "Translation Request",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "With: $translatorName",
                                  style: TextStyle(
                                      fontSize: 12, color: textSecTheme),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  status == 'pending_review'
                                      ? '⚡ NEEDS YOUR REVIEW'
                                      : status == 'revision_requested'
                                          ? '✏️ REVISION SENT'
                                          : status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: statusColor,
                                  ),
                                ),
                                if (status == 'pending_review') ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      "Tap to Review & Accept",
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.green),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.file_open_outlined, color: Colors.brown, size: 20),
                                onPressed: () => showFileActionMenu(job),
                                tooltip: "Open File",
                              ),
                              const Icon(Icons.chevron_right, color: Colors.black26),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String msg, IconData icon) {
    return PremiumEmptyState(
      title: msg,
      subtitle: "When you start translating documents, they will appear here for easy access and tracking.",
      icon: icon,
      brandBrown: brandBrown,
    );
  }
}
