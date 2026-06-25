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
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 50, 24, 28),
          decoration: BoxDecoration(
            color: surfaceTheme,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: brandBrown.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "TIRGUMSRA",
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: brandBrown,
                    letterSpacing: 2.0,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Document History",
                style: GoogleFonts.inter(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: textMainTheme,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "All your past and ongoing translation requests.",
                style: TextStyle(fontSize: 13, color: textSecTheme),
              ),
            ],
          ),
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

                  return GestureDetector(
                    onTap: () {
                      if (status == 'completed') {
                        showFileActionMenu(job);
                      } else if (status == 'pending_review' || status == 'revision_requested') {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => LiveOrderTrackerScreen(job: job))).then((_) => onRefresh());
                      } else {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => CustomerJobDetail(job: job))).then((_) => onRefresh());
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                          color: surfaceTheme,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))]),
                      child: IntrinsicHeight(
                        child: Row(
                          children: [
                            Container(
                              width: 5,
                              decoration: BoxDecoration(
                                color: statusColor,
                                borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                                          child: Icon(statusIcon, color: statusColor, size: 18),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            job['title'] ?? "Translation Request",
                                            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, color: textMainTheme),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Icon(Icons.chevron_right_rounded, color: textSecTheme.withValues(alpha: 0.4), size: 20),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(color: brandBrown.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                                          child: Text("${job['from_lang'] ?? '?'} → ${job['to_lang'] ?? '?'}",
                                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: brandBrown)),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                          child: Text(
                                            status == 'pending_review' ? '⚡ REVIEW NOW' : status == 'revision_requested' ? '✏️ REVISION' : status.toUpperCase(),
                                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: statusColor),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text("Translator: $translatorName", style: TextStyle(fontSize: 11, color: textSecTheme)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
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
