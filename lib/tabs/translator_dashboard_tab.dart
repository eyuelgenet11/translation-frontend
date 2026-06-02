import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/notification_sound_service.dart';
import '../services/push_notification_service.dart';
import '../utils/job_status_utils.dart';
import '../screens/translator/translator_job_detail_screen.dart';

/// Professional translator workspace tab: jobs, realtime alerts, chat & delivery.
class TranslatorDashboardTab extends StatefulWidget {
  const TranslatorDashboardTab({super.key});

  @override
  State<TranslatorDashboardTab> createState() => _TranslatorDashboardTabState();
}

class _TranslatorDashboardTabState extends State<TranslatorDashboardTab> {
  final _supabase = Supabase.instance.client;
  static const _brown = Color(0xFF895129);

  List<Map<String, dynamic>> _jobs = [];
  String? _officeName;
  String? _displayName;
  bool _loading = true;
  String _filter = 'all';
  RealtimeChannel? _jobsChannel;

  @override
  void initState() {
    super.initState();
    PushNotificationService().saveTokenToSupabase();
    _load();
    _subscribeToJobs();
  }

  @override
  void dispose() {
    _jobsChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _load() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/staff-login');
      return;
    }

    setState(() => _loading = true);
    try {
      final profile = await _supabase
          .from('profiles')
          .select('full_name, office_name, role, status')
          .eq('id', user.id)
          .maybeSingle();

      if (profile?['role'] != 'translator') {
        await _supabase.auth.signOut();
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final jobs = await _supabase
          .from('jobs')
          .select('*')
          .eq('translator_id', user.id)
          .or('settled.is.null,settled.eq.false')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _displayName = profile?['full_name'] as String?;
          _officeName = profile?['office_name'] as String?;
          _jobs = List<Map<String, dynamic>>.from(jobs);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load jobs: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _subscribeToJobs() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _jobsChannel = _supabase
        .channel('translator_dashboard_jobs')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'jobs',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'translator_id',
            value: userId,
          ),
          callback: (payload) {
            _onJobRealtime(payload);
          },
        )
        .subscribe();
  }

  void _onJobRealtime(PostgresChangePayload payload) {
    if (!mounted) return;

    final event = payload.eventType;
    if (event == PostgresChangeEvent.insert) {
      NotificationSoundService.playNotificationSound();
      PushNotificationService().showLocalNotification(
        title: 'New translation request',
        body: 'A customer assigned you a new job.',
      );
      _showJobAlert(
        'New job assigned',
        'Open the job to send your quote.',
        payload.newRecord,
      );
    } else if (event == PostgresChangeEvent.update) {
      final status = normalizeJobStatus(payload.newRecord['status']);
      if (status == 'revision requested') {
        NotificationSoundService.playNotificationSound();
        _showJobAlert(
          'Revision requested',
          'The customer asked for changes.',
          payload.newRecord,
        );
      } else if (status.contains('awaiting verification')) {
        NotificationSoundService.playNotificationSound();
        _showJobAlert(
          'Payment uploaded',
          'Admin may verify payment soon.',
          payload.newRecord,
        );
      }
    }
    _load();
  }

  void _showJobAlert(String title, String body, Map<String, dynamic> job) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('LATER')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _brown),
            onPressed: () {
              Navigator.pop(ctx);
              _openJob(job);
            },
            child: const Text('OPEN JOB', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openJob(Map<String, dynamic> job) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TranslatorJobDetailScreen(job: job),
      ),
    ).then((_) => _load());
  }

  List<Map<String, dynamic>> get _filteredJobs {
    if (_filter == 'all') return _jobs;
    return _jobs.where((j) {
      switch (_filter) {
        case 'pending':
          return jobStatusIn(j['status'], ['pending', 'quoted', 'new']);
        case 'active':
          return jobStatusIn(j['status'], [
            'in progress',
            'accepted',
            'approved',
            'awaiting payment',
            'awaiting verification',
            'revision requested',
            'pending review',
          ]);
        case 'done':
          return jobStatusIs(j['status'], 'completed');
        default:
          return true;
      }
    }).toList();
  }

  int get _pendingCount =>
      _jobs.where((j) => jobStatusIn(j['status'], ['pending', 'quoted', 'new'])).length;

  int get _activeCount => _jobs.where((j) {
        return !jobStatusIn(j['status'], ['pending', 'quoted', 'new', 'completed']) &&
            normalizeJobStatus(j['status']).isNotEmpty;
      }).length;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kelal — Translator',
                style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              Text(
                _officeName ?? _displayName ?? 'Professional workspace',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          actions: [
            IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _brown))
            : RefreshIndicator(
                color: _brown,
                onRefresh: _load,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                        child: Row(
                          children: [
                            _statCard('Queue', _pendingCount.toString(), Icons.inbox_outlined),
                            const SizedBox(width: 12),
                            _statCard('Active', _activeCount.toString(), Icons.work_outline_rounded),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 44,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            _filterChip('all', 'All'),
                            _filterChip('pending', 'Queue'),
                            _filterChip('active', 'Active'),
                            _filterChip('done', 'Done'),
                          ],
                        ),
                      ),
                    ),
                    if (_filteredJobs.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text(
                              'No jobs in this view.\nNew customer requests will appear here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey, height: 1.5),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final job = _filteredJobs[index];
                            return _jobTile(job);
                          },
                          childCount: _filteredJobs.length,
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            final pending = _jobs.where((j) => jobStatusIs(j['status'], 'pending')).toList();
            if (pending.isNotEmpty) {
              _openJob(pending.first);
            } else if (_jobs.isNotEmpty) {
              _openJob(_jobs.first);
            }
          },
          backgroundColor: _brown,
          icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white),
          label: const Text('Messages', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Icon(icon, color: _brown, size: 22),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900)),
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String id, String label) {
    final selected = _filter == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = id),
        selectedColor: _brown.withValues(alpha: 0.2),
        checkmarkColor: _brown,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          color: selected ? _brown : null,
        ),
      ),
    );
  }

  Widget _jobTile(Map<String, dynamic> job) {
    final title = '${job['from_lang'] ?? '?'} → ${job['to_lang'] ?? '?'}';
    final status = normalizeJobStatus(job['status']);
    final price = job['price'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openJob(job),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _brown.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.description_outlined, color: _brown),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _brown.withValues(alpha: 0.9),
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (price != null)
                        Text(
                          '$price ETB',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
