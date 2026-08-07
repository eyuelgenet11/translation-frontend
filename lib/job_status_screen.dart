import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/notification_sound_service.dart';

class JobStatusScreen extends StatefulWidget {
  const JobStatusScreen({super.key});

  @override
  State<JobStatusScreen> createState() => _JobStatusScreenState();
}

class _JobStatusScreenState extends State<JobStatusScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _jobs = [];
  bool _isLoading = true;
  RealtimeChannel? _channel;

  // Color palette matching the app theme
  static const Color _brown = Color(0xFF8D5C3C); // Brand brown
  late Color bgTheme;
  late Color cardTheme;
  late Color textThemeHeader;
  late Color textThemeSec;

  @override
  void initState() {
    super.initState();
    _fetchJobs();
    _subscribeToUpdates();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _fetchJobs() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await _supabase
          .from('jobs')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _jobs = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading jobs: $e')),
        );
      }
    }
  }

  void _subscribeToUpdates() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _channel = _supabase
        .channel('jobs-status-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'jobs',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            // Update the specific job in the list
            if (mounted) {
              setState(() {
                final updatedJob = Map<String, dynamic>.from(payload.newRecord);
                final index = _jobs.indexWhere((j) => j['id'] == updatedJob['id']);
                if (index != -1) {
                  final oldStatus = _jobs[index]['status'];
                  final newStatus = updatedJob['status'];
                  if (oldStatus != newStatus) {
                    NotificationSoundService.playNotificationSound();
                  }
                  _jobs[index] = updatedJob;
                } else {
                  _jobs.insert(0, updatedJob);
                }
              });
            }
          },
        )
        .subscribe();
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'Accepted':
        return Colors.green.shade700;
      case 'In Progress':
        return _brown;
      case 'Awaiting Payment':
      case 'Pending':
      case 'pending':
        return Colors.orange.shade700;
      case 'Completed':
        return Colors.teal.shade700;
      case 'Rejected':
        return Colors.red.shade700;
      case 'Awaiting Review':
        return Colors.indigo.shade500;
      default:
        return Colors.grey.shade600;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'Accepted':
        return Icons.check_circle_outline;
      case 'In Progress':
        return Icons.autorenew;
      case 'Awaiting Payment':
      case 'Pending':
      case 'pending':
        return Icons.payment;
      case 'Completed':
        return Icons.task_alt;
      case 'Rejected':
        return Icons.cancel_outlined;
      case 'Awaiting Review':
        return Icons.hourglass_top_rounded;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    bgTheme = Colors.white;
    cardTheme = Theme.of(context).cardColor;
    textThemeHeader = Colors.black87;
    textThemeSec = Colors.black54;

    return Scaffold(
      backgroundColor: bgTheme,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        surfaceTintColor: Colors.white,
        title: Text(
          'My Jobs',
          style: GoogleFonts.inter(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _fetchJobs,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _jobs.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _fetchJobs,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _jobs.length,
                    itemBuilder: (context, index) => _buildJobCard(_jobs[index]),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No Jobs Yet',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textThemeHeader,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload a document to get started.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    final status = job['status'] as String? ?? 'Unknown';
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);
    final needsPayment = status == 'Awaiting Payment' || status == 'Pending' || status == 'pending';
    final isRejected = status == 'Rejected';
    final isAwaitingReview = status == 'Awaiting Review';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.pushNamed(
            context,
            '/live_tracker',
            arguments: job,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cardTheme,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      job['is_handwritten'] == true
                          ? Icons.draw_outlined
                          : Icons.description,
                      color: _brown,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job['title'] ?? job['from_lang'] != null
                              ? '${job['from_lang'] ?? ''} â†’ ${job['to_lang'] ?? ''}'
                              : 'Translation Job',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: textThemeHeader,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Job #${(job['id'] as String?)?.substring(0, 8).toUpperCase() ?? 'N/A'}',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 5),
                        Text(
                          status,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (needsPayment)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brown,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          '/live_tracker',
                          arguments: job,
                        );
                      },
                      icon: const Icon(Icons.flash_on, size: 14, color: Colors.amber),
                      label: const Text(
                        'Pay Now',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                ],
              ),
              // Awaiting Review info row
              if (isAwaitingReview) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 13, color: Colors.indigo.shade400),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "Your handwritten document is being reviewed. We'll notify you once confirmed.",
                          style: TextStyle(fontSize: 11, color: Colors.indigo.shade400, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Rejected reason row
              if (isRejected && job['rejection_reason'] != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, size: 13, color: Colors.redAccent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          job['rejection_reason'] as String,
                          style: const TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}


