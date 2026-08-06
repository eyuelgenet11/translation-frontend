import 'dart:ui';
import 'dart:async';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:path/path.dart' as p;
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:upgrader/upgrader.dart';

import 'upload_screen.dart';

import 'services/locale_controller.dart';
import 'services/push_notification_service.dart';
import 'tabs/marketplace_tab.dart';
import 'tabs/history_tab.dart';
import 'tabs/tracker_tab.dart';
import 'tabs/profile_tab.dart';
import 'tabs/admin_dashboard_tab.dart';
import 'tabs/translator_dashboard_tab.dart';
import 'live_order_tracker_screen.dart';
import 'services/notification_sound_service.dart';
import 'config/security_config.dart';
import 'services/admin_auth_service.dart';
import 'services/role_security_service.dart';
import 'notifications_screen.dart' show NotificationsScreen;

// Thin wrapper so the notification bell can push this route
class NotificationsScreenWrapper extends StatelessWidget {
  const NotificationsScreenWrapper({super.key});
  @override
  Widget build(BuildContext context) => const NotificationsScreen();
}

class MarketplaceHomeScreen extends StatefulWidget {
  final int initialIndex;
  const MarketplaceHomeScreen({super.key, this.initialIndex = 0});

  @override
  State<MarketplaceHomeScreen> createState() => _MarketplaceHomeScreenState();
}

class _MarketplaceHomeScreenState extends State<MarketplaceHomeScreen> {
  final supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  // App State
  late int _currentIndex;
  bool loading = true;

  // Profile & Wallet Data
  String? _avatarUrl;
  String? _displayName;
  String _accountType = 'personal'; // Add this line
  bool _isDesignatedAdmin = false;
  bool _canAccessAdminDashboard = false;
  double _walletBalance = 0.00;
  int _totalOrders = 0;

  // Marketplace Data
  List<Map<String, dynamic>> allTranslators = [];
  List<Map<String, dynamic>> filteredTranslators = [];
  String selectedCategory = "All";

  // Brand Palette
  static const Color brandBrown = Color(0xFF895129);
  
  // Dynamic color holders (will be set in build)
  late Color bgTheme;
  late Color surfaceTheme;
  late Color textMainTheme;
  late Color textSecTheme;

  // Active jobs for tracker tab
  List<Map<String, dynamic>> _activeTrackerJobs = [];
  Map<String, dynamic>? _selectedTrackerJob;
  RealtimeChannel? _globalJobsSubscription;
  RealtimeChannel? _notificationsSubscription;
  
  int _unreadNotificationCount = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _fetchUserProfile();
    _subscribeToProfile();
    _fetchTranslators();
    _fetchActiveTrackerJob();
    _subscribeToGlobalJobs();
    
    // Ensure the device token is saved now that the user is logged in
    PushNotificationService().saveTokenToSupabase();
    _enforceRolesOnLaunch();
    _redirectTranslatorsToPortal();
    _fetchUnreadNotificationCount();
    _subscribeToNotifications();
  }

  Future<void> _fetchUnreadNotificationCount() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final res = await supabase
          .from('notifications')
          .select('id')
          .eq('user_id', user.id)
          .eq('is_read', false);
      if (mounted) {
        setState(() => _unreadNotificationCount = (res as List).length);
      }
    } catch (e) {
      debugPrint("Error fetching unread notification count: $e");
    }
  }

  void _subscribeToNotifications() {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    _notificationsSubscription = supabase
        .channel('public:notifications:${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) {
            _fetchUnreadNotificationCount(); // Re-fetch on any insert/update
          },
        )
        .subscribe();
  }

  Future<void> _redirectTranslatorsToPortal() async {
    if (widget.initialIndex == 5) return;
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final profile = await supabase
          .from('profiles')
          .select('role, status')
          .eq('id', user.id)
          .maybeSingle();
      if (profile?['role'] == 'translator' &&
          SecurityConfig.isApprovedTranslatorStatus(profile?['status'] as String?)) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/translator-home');
        }
      }
    } catch (_) {}
  }

  Future<void> _enforceRolesOnLaunch() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    await RoleSecurityService.enforceProfileRoles(user);
    await _refreshAdminAccess();
  }

  Future<void> _refreshAdminAccess() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // Check designation by email (fast — no DB call needed)
    final isDesignatedByEmail = SecurityConfig.isSuperAdminEmail(user.email);
    final isDesignated = isDesignatedByEmail;
    final granted = isDesignatedByEmail;
    if (mounted) {
      setState(() {
        _isDesignatedAdmin = isDesignated;
        _canAccessAdminDashboard = granted;
      });
      // Only kick out of admin tab if truly not designated at all
      if (_currentIndex == 4 && !isDesignatedByEmail) {
        setState(() => _currentIndex = 0);
      }
    }
  }


  bool _checkAuth() {
    if (supabase.auth.currentUser == null) {
      _showAuthRequiredDialog();
      return false;
    }
    return true;
  }

  void _showAuthRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceTheme,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.lock_outline_rounded, color: brandBrown, size: 28),
            const SizedBox(width: 12),
            Text("Sign In Required", style: GoogleFonts.philosopher(fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        content: const Text(
          "Please sign in to your account to upload documents and place translation orders.",
          style: TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("CANCEL", style: TextStyle(color: textSecTheme)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: brandBrown,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("SIGN IN"),
          ),
        ],
      ),
    );
  }

  void _showCriticalAlert({required String title, required String message, required Map<String, dynamic> job}) {
    if (!mounted) return;
    
    // Also trigger a system-level notification (for background/system tray visibility)
    PushNotificationService().showLocalNotification(
      title: title,
      body: message,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceTheme,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.notification_important_rounded, color: brandBrown, size: 28),
            const SizedBox(width: 12),
            Text(title, style: GoogleFonts.philosopher(fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: const TextStyle(fontSize: 15, height: 1.5)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: brandBrown.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.description_outlined, size: 18, color: brandBrown),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(job['title'] ?? "New Translation Task",
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("DISMISS", style: TextStyle(color: textSecTheme)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/live_tracker', arguments: job);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: brandBrown,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("VIEW DETAILS"),
          ),
        ],
      ),
    );
  }

  void _showAdminPaymentAlert({required Map<String, dynamic> job}) {
    if (!mounted) return;

    // Trigger local push notification (system tray) only — popup review box removed as requested
    PushNotificationService().showLocalNotification(
      title: "Payment Slip Uploaded",
      body: "A client has uploaded a payment receipt for review: ${job['title'] ?? 'Translation Request'}.",
    );
  }

  void _subscribeToGlobalJobs() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    _globalJobsSubscription = supabase
        .channel('public:jobs:global:$userId')
        // 1. CUSTOMER UPDATES
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'jobs',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'client_id',
            value: userId,
          ),
          callback: (payload) {
            final oldStatus = (payload.oldRecord['status'] ?? '').toString().toLowerCase();
            final newStatus = (payload.newRecord['status'] ?? '').toString().toLowerCase();

            if (oldStatus != newStatus && mounted) {
              NotificationSoundService.playNotificationSound();
              
              // Trigger system notification
              PushNotificationService().showLocalNotification(
                title: "Order Update",
                body: "Order #${payload.newRecord['id'].toString().substring(0,8)} is now ${newStatus.toUpperCase()}",
              );

              // The SnackBar for 'Live Tracking' has been removed to reduce repetition
              _fetchActiveTrackerJob();
            }
          },
        )
        // 2. TRANSLATOR NOTIFICATIONS (New Jobs)
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'jobs',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'translator_id',
            value: userId,
          ),
          callback: (payload) {
            if (mounted) {
              NotificationSoundService.playNotificationSound();
              _showCriticalAlert(
                title: "New Job Assigned",
                message: "A client has just uploaded a new document for translation. Please review the requirements and provide a quote.",
                job: payload.newRecord,
              );
            }
          },
        )
        // 3. ADMIN NOTIFICATIONS (Optional but helpful for 'both dashboards')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'jobs',
          callback: (payload) {
            // Only trigger if I am an admin
            if (mounted && _isDesignatedAdmin) {
               if (payload.newRecord.isEmpty) return;

               final status = (payload.newRecord['status'] ?? 'NEW').toString().toLowerCase();
               
               if (status == 'awaiting verification') {
                 NotificationSoundService.playNotificationSound();
                 _showAdminPaymentAlert(
                   job: payload.newRecord,
                 );
               }
            }
          },
        )
        // 3. TRANSLATOR NOTIFICATIONS (Client Updates - e.g. Payment Uploaded)
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'jobs',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'translator_id',
            value: userId,
          ),
          callback: (payload) {
            final newStatus = (payload.newRecord['status'] ?? '').toString().toLowerCase();
            if (mounted && (newStatus == 'awaiting verification' || newStatus == 'revision_requested')) {
              NotificationSoundService.playNotificationSound();
              _showCriticalAlert(
                title: newStatus == 'revision_requested' ? "Revision Requested" : "Payment Received",
                message: newStatus == 'revision_requested' 
                    ? "The client has requested changes to the translation. Please review the feedback and update the file."
                    : "The client has uploaded a payment receipt. Please verify the transaction to continue.",
                job: payload.newRecord,
              );
            }
          },
        )
        .subscribe((status, error) {
          debugPrint("Realtime subscription status: $status");
          if (error != null) {
            debugPrint("Realtime subscription error: $error");
          }
        });
  }



  Future<void> _fetchActiveTrackerJob() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final List data = await supabase
          .from('jobs')
          .select('*')
          .eq('client_id', userId)
          .not('status', 'eq', 'completed')
          .not('status', 'eq', 'rejected')
          .not('status', 'eq', 'fraud restricted')
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> jobsList = List<Map<String, dynamic>>.from(data);

      if (mounted) {
        setState(() {
          _activeTrackerJobs = jobsList;
          if (jobsList.isNotEmpty) {
            // Preserve current user selection if still active, otherwise default to latest
            if (_selectedTrackerJob == null ||
                !jobsList.any((j) => j['id'] == _selectedTrackerJob!['id'])) {
              _selectedTrackerJob = jobsList.first;
            } else {
              _selectedTrackerJob = jobsList.firstWhere((j) => j['id'] == _selectedTrackerJob!['id']);
            }
          } else {
            _selectedTrackerJob = null;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchUserProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final profile = await supabase
          .from('profiles')
          .select('full_name, role, avatar_url')
          .eq('id', user.id)
          .maybeSingle();
      if (profile != null && mounted) {
        debugPrint("FETCHED USER PROFILE FROM DB: $profile");
        setState(() {
          if (profile['avatar_url'] != null) _avatarUrl = profile['avatar_url'];
          if (profile['full_name'] != null) _displayName = profile['full_name'];
          _accountType = profile['role'] ?? 'customer';
        });
        _refreshAdminAccess();
      } else {
        debugPrint("FETCHED USER PROFILE FROM DB: NULL or NOT FOUND");
      }
    } catch (e) {
      debugPrint("Error fetching user profile: $e");
    }
  }

  StreamSubscription<List<Map<String, dynamic>>>? _profileSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _customerSubscription;

  void _subscribeToProfile() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    // Stream 1: Listen to profiles for full name, avatar, and role
    _profileSubscription = supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .listen((data) async {
          if (data.isNotEmpty && mounted) {
            final profile = data.first;
            debugPrint("Profile stream updated: $profile");

            // Only fetch order count if we haven't or if needed (optional optimization)
            int orders = 0;
            try {
              final jobsRes = await supabase
                  .from('jobs')
                  .select('id')
                  .eq('client_id', userId);
              orders = jobsRes.length;
            } catch (e) {
              debugPrint("Error fetching job count: $e");
            }

            if (mounted) {
              setState(() {
                _avatarUrl = profile['avatar_url'];
                _displayName = profile['full_name'];
                _accountType = profile['role'] ?? 'customer'; // Use 'role' instead of 'account_type'
                _totalOrders = orders;
              });
              _refreshAdminAccess();
            }
          }
        }, onError: (err) {
          debugPrint("Profile stream error: $err");
        });

    // Stream 2: Listen to customer_accounts for wallet balance
    _customerSubscription = supabase
        .from('customer_accounts')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .listen((data) {
          if (data.isNotEmpty && mounted) {
            final customer = data.first;
            debugPrint("Customer account stream updated: $customer");
            if (mounted) {
              setState(() {
                _walletBalance = (customer['balance'] ?? 0.0).toDouble();
              });
            }
          }
        }, onError: (err) {
          debugPrint("Customer account stream error: $err");
        });
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    _customerSubscription?.cancel();
    _globalJobsSubscription?.unsubscribe();
    _notificationsSubscription?.unsubscribe();
    _searchController.dispose();
    super.dispose();
  }

  // --- LOGIC: DATA FETCHING ---

  Future<void> _fetchTranslators() async {
    setState(() => loading = true);
    try {
      final profilesData =
          await supabase.from('profiles').select().eq('role', 'translator');
      debugPrint("FETCHED ALL TRANSLATORS COUNT: ${profilesData.length}");
      
      List<dynamic> ratingsData = [];
      try {
        ratingsData = await supabase.from('translator_ratings_view').select();
        debugPrint("FETCHED RATINGS VIEW COUNT: ${ratingsData.length}");
      } catch (e) {
        debugPrint("FAILED TO FETCH RATINGS VIEW (Graceful fallback): $e");
      }
      
      final mergedData = profilesData.map((profile) {
        final ratingInfo = ratingsData.firstWhere(
          (r) => r['translator_id'] == profile['id'],
          orElse: () => {'average_rating': 5.0, 'review_count': 0},
        );
        return {
          ...profile,
          'avg_rating': ratingInfo['average_rating'],
          'review_count': ratingInfo['review_count'],
        };
      }).toList();

      // List of requested merchants with real Google ratings
      final List<Map<String, dynamic>> googleMerchants = [
        {
          'id': 'zamzam-top-001',
          'full_name': 'Zamzam Translation and Secretarial Service',
          'office_name': 'Zamzam Translation and Secretarial Service',
          'bio': 'Top Certified Translation & Interpretation Office in Ethiopia',
          'avg_rating': 5.0,
          'review_count': 150,
          'category': ['Certified', 'Legal', 'General'],
          'is_top': true,
        },
        {
          'id': 'wisdom-002',
          'full_name': 'Wisdom translation, interpretation, localization and proofreading services',
          'office_name': 'Wisdom translation, interpretation, localization and proofreading services',
          'bio': 'Professional Translation, Interpretation, Localization & Proofreading',
          'avg_rating': 5.0,
          'review_count': 20,
          'category': ['Certified', 'Localization', 'Proofreading'],
        },
        {
          'id': 'ethiostar-003',
          'full_name': 'Ethiostar Translation and Localization',
          'office_name': 'Ethiostar Translation and Localization',
          'bio': 'Certified Translation and Localization Services',
          'avg_rating': 5.0,
          'review_count': 35,
          'category': ['Localization', 'Certified', 'General'],
        },
        {
          'id': 'crosslingual-004',
          'full_name': 'Crosslingual Translation, Interpretation, Localization and Proofreading services-certified',
          'office_name': 'Crosslingual Translation, Interpretation, Localization and Proofreading services-certified',
          'bio': 'Certified Crosslingual Translation & Interpretation Services',
          'avg_rating': 4.9,
          'review_count': 45,
          'category': ['Certified', 'Interpretation', 'Legal'],
        },
        {
          'id': 'hk-005',
          'full_name': 'HK Translation Service in Ethiopia',
          'office_name': 'HK Translation Service in Ethiopia',
          'bio': 'Expert Legal and Technical Translation Services in Ethiopia',
          'avg_rating': 4.9,
          'review_count': 24,
          'category': ['Certified', 'Technical', 'General'],
        },
        {
          'id': 'dolphin-006',
          'full_name': 'Dolphin Translation and Secretarial Service',
          'office_name': 'Dolphin Translation and Secretarial Service',
          'bio': 'Reliable Document Translation & Secretarial Services',
          'avg_rating': 4.8,
          'review_count': 18,
          'category': ['General', 'Secretarial', 'Certified'],
        },
        {
          'id': 'yimi-007',
          'full_name': 'Yimi translation office',
          'office_name': 'Yimi translation office',
          'bio': 'Official Translation and Proofreading Bureau',
          'avg_rating': 4.8,
          'review_count': 15,
          'category': ['General', 'Certified', 'Proofreading'],
        },
        {
          'id': 'ethionet-008',
          'full_name': 'Ethionet Translation and Digitals',
          'office_name': 'Ethionet Translation and Digitals',
          'bio': 'Digital Translation & Localization Office',
          'avg_rating': 4.7,
          'review_count': 12,
          'category': ['Digital', 'General', 'Localization'],
        },
        {
          'id': 'horizontico-009',
          'full_name': 'HorizonTICO Translation & Interpretation',
          'office_name': 'HorizonTICO Translation & Interpretation',
          'bio': 'Translation & Live Interpretation Bureau',
          'avg_rating': 4.5,
          'review_count': 10,
          'category': ['Interpretation', 'General'],
        },
      ];

      final List<Map<String, dynamic>> combined = List<Map<String, dynamic>>.from(mergedData);

      for (var gm in googleMerchants) {
        final gmName = (gm['office_name'] as String).toLowerCase();
        final existingIndex = combined.indexWhere((t) {
          final tName = (t['office_name'] ?? t['full_name'] ?? '').toString().toLowerCase();
          return tName.contains(gmName) || gmName.contains(tName);
        });

        if (existingIndex != -1) {
          combined[existingIndex]['avg_rating'] = gm['avg_rating'];
          combined[existingIndex]['review_count'] = gm['review_count'];
          if (gm['office_name'] != null) combined[existingIndex]['office_name'] = gm['office_name'];
          if (gm['full_name'] != null) combined[existingIndex]['full_name'] = gm['full_name'];
          if (gm['is_top'] == true) combined[existingIndex]['is_top'] = true;
        } else {
          combined.add(gm);
        }
      }

      if (mounted) {
        setState(() {
          allTranslators = combined;

          // Make Zamzam top rated and recommended
          for (var t in allTranslators) {
            final name = (t['office_name'] ?? t['full_name'] ?? '').toString().toLowerCase();
            if (name.contains('zamzam')) {
              t['avg_rating'] = 5.0;
              t['review_count'] = 150;
              t['is_top'] = true;
            }
          }

          // Sort translators: Zamzam strictly on top, then rating descending, then review count descending
          allTranslators.sort((a, b) {
            final aName = (a['office_name'] ?? a['full_name'] ?? '').toString().toLowerCase();
            final bName = (b['office_name'] ?? b['full_name'] ?? '').toString().toLowerCase();

            if (aName.contains('zamzam')) return -1;
            if (bName.contains('zamzam')) return 1;

            final aRating = (a['avg_rating'] ?? 0.0).toDouble();
            final bRating = (b['avg_rating'] ?? 0.0).toDouble();
            if (bRating != aRating) {
              return bRating.compareTo(aRating);
            }
            final aCount = (a['review_count'] ?? 0) as int;
            final bCount = (b['review_count'] ?? 0) as int;
            return bCount.compareTo(aCount);
          });

          _applyFilters();
          loading = false;
        });
      }
    } catch (e) {
      debugPrint("CRITICAL ERROR IN _fetchTranslators: $e");
      if (mounted) setState(() => loading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      filteredTranslators = allTranslators.where((t) {
        final nameMatches = (t['full_name'] ?? "")
            .toLowerCase()
            .contains(_searchController.text.toLowerCase());
        final List cats = t['category'] ?? [];
        return nameMatches &&
            (selectedCategory == "All" || cats.contains(selectedCategory));
      }).toList();
    });
  }

  Future<List<Map<String, dynamic>>> _fetchHistoryJobs() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final jobs = await supabase
        .from('jobs')
        .select('*')
        .eq('client_id', userId)
        .order('created_at', ascending: false);

    if (jobs.isEmpty) return [];

    // Fetch profiles for these jobs
    final translatorIds = jobs.map((j) => j['translator_id']).toSet().toList();
    final profiles = await supabase
        .from('profiles')
        .select('id, full_name, office_name')
        .inFilter('id', translatorIds);

    // Join in memory
    return jobs.map((job) {
      final profile = profiles.firstWhere(
        (p) => p['id'] == job['translator_id'],
        orElse: () => <String, dynamic>{},
      );
      return {
        ...job,
        'translator': profile.isEmpty ? null : profile,
      };
    }).toList();
  }

  void _showFileActionMenu(Map<String, dynamic> job) {
    final String? fileUrl = job['translated_file_url'] ?? job['file_url'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: surfaceTheme,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            )
          ],
        ),
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          bottom: MediaQuery.of(context).padding.bottom + 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              job['title'] ?? "File Options",
              style: GoogleFonts.philosopher(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textMainTheme,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _actionTile(
              icon: Icons.remove_red_eye_outlined,
              label: "View Online",
              onTap: () {
                Navigator.pop(context);
                _openJobFile(job);
              },
            ),
            if (fileUrl != null && fileUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              _actionTile(
                icon: Icons.download_for_offline_outlined,
                label: "Download to Device",
                onTap: () {
                  Navigator.pop(context);
                  _downloadJobFile(fileUrl);
                },
              ),
              const SizedBox(height: 12),
              _actionTile(
                icon: Icons.share_outlined,
                label: "Share Document Link",
                onTap: () {
                  Navigator.pop(context);
                  Share.share(
                    fileUrl,
                    subject: 'Translated Document: ${job['title']}',
                  );
                },
              ),
            ],
            const SizedBox(height: 12),
            _actionTile(
              icon: Icons.info_outline,
              label: "View All Project Details",
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => LiveOrderTrackerScreen(job: job)),
                ).then((_) => setState(() {})); // refresh on back
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _actionTile({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: brandBrown.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: brandBrown.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: brandBrown.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: brandBrown, size: 22),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: GoogleFonts.philosopher(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: textMainTheme,
              ),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textSecTheme.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }

  Future<void> _openJobFile(Map<String, dynamic> job) async {
    final String? fileUrl = job['translated_file_url'] ?? job['file_url'];
    if (fileUrl == null || fileUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No file associated with this job.")),
      );
      return;
    }

    try {
      final uri = Uri.parse(fileUrl.trim());
      final bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) throw "Could not launch link.";
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<void> _downloadJobFile(String fileUrl) async {
    try {
      if (kIsWeb) {
        final url = Uri.parse(fileUrl);
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        String? selectedPath = await FilePicker.platform.getDirectoryPath();
        String baseDir;
        if (selectedPath != null && selectedPath.isNotEmpty) {
          baseDir = selectedPath;
        } else {
          final appDocDir = await getApplicationDocumentsDirectory();
          baseDir = appDocDir.path;
        }

        final fileName = Uri.parse(fileUrl).pathSegments.last;
        final savePath = "$baseDir/$fileName";

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Starting download...")),
        );

        await Dio().download(fileUrl, savePath);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("File saved: $savePath"),
            backgroundColor: Colors.green,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Download Error: $e"),
          backgroundColor: Colors.redAccent,
        ));
      }
    }
  }

  // --- UI: HOW-TO GUIDE ---


  void _showLogoutConfirm() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("Sign Out"),
        content:
            const Text("Are you sure you want to sign out of your account?"),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              await AdminAuthService.clearStepUpVerification();
              await supabase.auth.signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                    context, '/login', (route) => false);
              }
            },
            child: const Text("Sign Out"),
          ),
        ],
      ),
    );
  }

  void _editProfileModal() {
    final nameCtrl = TextEditingController(text: _displayName);
    final phoneCtrl = TextEditingController();
    final bioCtrl = TextEditingController();
    bool uploading = false;
    String selectedLang = 'English';

    // Pre-load extra profile fields
    _prefillProfileExtras(phoneCtrl, bioCtrl).then((_) {});

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            decoration: BoxDecoration(
              color: surfaceTheme,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: brandBrown.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.edit_rounded, color: brandBrown, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Edit Profile",
                              style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: textMainTheme),
                            ),
                            Text(
                              "Customize your public identity",
                              style: TextStyle(
                                  fontSize: 12, color: textSecTheme),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // Avatar section
                    Center(
                      child: GestureDetector(
                        onTap: () async {
                          final picker = ImagePicker();
                          final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);

                          if (pickedFile != null) {
                            setModalState(() => uploading = true);
                            try {
                              final userId = supabase.auth.currentUser!.id;
                              final fileExt = p.extension(pickedFile.name);
                              final fileName =
                                  "avatar_${DateTime.now().millisecondsSinceEpoch}$fileExt";
                              final filePath = "avatars/$userId/$fileName";
                              final bytes = await pickedFile.readAsBytes();
                              await supabase.storage
                                  .from('translations')
                                  .uploadBinary(filePath, bytes,
                                      fileOptions: const FileOptions(
                                          contentType: 'image/jpeg'));
                              final publicUrl = supabase.storage
                                  .from('translations')
                                  .getPublicUrl(filePath);
                              await supabase
                                  .from('customer_accounts')
                                  .update({'avatar_url': publicUrl})
                                  .eq('id', userId);
                              try {
                                await supabase
                                    .from('profiles')
                                    .update({'avatar_url': publicUrl})
                                    .eq('id', userId);
                              } catch (_) {}
                              setState(() => _avatarUrl = publicUrl);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text("Profile photo updated! ✅")));
                              }
                            } finally {
                              setModalState(() => uploading = false);
                            }
                          }
                        },
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: brandBrown, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: brandBrown.withValues(alpha: 0.2),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  )
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 46,
                                backgroundColor:
                                    brandBrown.withValues(alpha: 0.08),
                                backgroundImage: (_avatarUrl != null &&
                                        _avatarUrl!.isNotEmpty)
                                    ? NetworkImage(_avatarUrl!)
                                    : null,
                                child: uploading
                                    ? CircularProgressIndicator(
                                        color: brandBrown, strokeWidth: 2)
                                    : ((_avatarUrl == null ||
                                            _avatarUrl!.isEmpty)
                                        ? Icon(Icons.person,
                                            size: 40, color: brandBrown)
                                        : null),
                              ),
                            ),
                            if (!uploading)
                              Positioned(
                                right: 2,
                                bottom: 2,
                                child: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                      color: brandBrown,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                            color: brandBrown
                                                .withValues(alpha: 0.4),
                                            blurRadius: 8)
                                      ]),
                                  child: const Icon(Icons.camera_alt_rounded,
                                      size: 14, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        "Tap to change photo",
                        style: TextStyle(
                            fontSize: 12,
                            color: brandBrown,
                            fontWeight: FontWeight.w600),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Divider label
                    _modalSectionLabel("PERSONAL INFO"),
                    const SizedBox(height: 12),

                    // Full Name field
                    _modalField(
                      label: "Full Name",
                      icon: Icons.person_outline_rounded,
                      controller: nameCtrl,
                      hint: "Enter your full name",
                    ),
                    const SizedBox(height: 14),

                    // Phone field
                    _modalField(
                      label: "Phone Number",
                      icon: Icons.phone_outlined,
                      controller: phoneCtrl,
                      hint: "e.g. +251 9XX XXX XXX",
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 14),

                    // Bio field
                    _modalField(
                      label: "Short Bio",
                      icon: Icons.info_outline_rounded,
                      controller: bioCtrl,
                      hint: "Tell translators a bit about yourself...",
                      maxLines: 3,
                    ),

                    const SizedBox(height: 24),
                    _modalSectionLabel("PREFERENCES"),
                    const SizedBox(height: 12),

                    // Preferred Language Selector
                    Container(
                      decoration: BoxDecoration(
                        color: bgTheme,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: brandBrown.withValues(alpha: 0.2), width: 1),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.language_rounded,
                              color: brandBrown, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedLang,
                                style: TextStyle(
                                    color: textMainTheme,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500),
                                dropdownColor: surfaceTheme,
                                icon: Icon(Icons.expand_more_rounded,
                                    color: brandBrown),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'English',
                                      child: Text('English')),
                                  DropdownMenuItem(
                                      value: 'Amharic',
                                      child: Text('አማርኛ')),
                                  DropdownMenuItem(
                                      value: 'Tigrinya',
                                      child: Text('ትግርኛ')),
                                  DropdownMenuItem(
                                      value: 'Oromia',
                                      child: Text('Oromia')),
                                ],
                                onChanged: (v) {
                                  if (v != null) {
                                    setModalState(() => selectedLang = v);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: uploading
                            ? null
                            : () async {
                                if (nameCtrl.text.trim().isEmpty) return;
                                final rawP = phoneCtrl.text.trim();
                                if (rawP.isNotEmpty) {
                                  String p = rawP.replaceAll(RegExp(r'[\s\-\(\)]'), '');
                                  if (p.startsWith('+251')) p = '0${p.substring(4)}';
                                  else if (p.startsWith('251')) p = '0${p.substring(3)}';
                                  if (!RegExp(r'^0\d{9}$').hasMatch(p)) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("Phone number must start with 0 (e.g., 0911373034)")),
                                    );
                                    return;
                                  }
                                }
                                setModalState(() => uploading = true);
                                try {
                                  final userId =
                                      supabase.auth.currentUser!.id;
                                  final updates = {
                                    'full_name': nameCtrl.text.trim(),
                                    if (phoneCtrl.text.trim().isNotEmpty)
                                      'phone': phoneCtrl.text.trim(),
                                    if (bioCtrl.text.trim().isNotEmpty)
                                      'bio': bioCtrl.text.trim(),
                                  };
                                  await supabase
                                      .from('customer_accounts')
                                      .update(updates)
                                      .eq('id', userId);
                                  try {
                                    await supabase
                                        .from('profiles')
                                        .update({'full_name': nameCtrl.text.trim()})
                                        .eq('id', userId);
                                  } catch (_) {}
                                  setState(() {
                                    _displayName = nameCtrl.text.trim();
                                  });
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              "Profile updated successfully! ✅"),
                                          backgroundColor:
                                              Color(0xFF895129)),
                                    );
                                  }
                                  Navigator.pop(context);
                                } catch (e) {
                                  debugPrint("PROFILE UPDATE ERROR: $e");
                                  if (mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(
                                      content: Text("Update failed: $e"),
                                      backgroundColor: Colors.red,
                                    ));
                                  }
                                } finally {
                                  setModalState(() => uploading = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandBrown,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(18),
                          elevation: 4,
                          shadowColor: brandBrown.withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (uploading)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            else
                              const Icon(Icons.check_circle_outline_rounded,
                                  size: 18),
                            const SizedBox(width: 10),
                            Text(
                              uploading ? "SAVING..." : "SAVE CHANGES",
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  letterSpacing: 0.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Cancel button
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.all(14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          "CANCEL",
                          style: TextStyle(
                              color: textSecTheme,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Prefill extra profile fields from DB
  Future<void> _prefillProfileExtras(
      TextEditingController phone, TextEditingController bio) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      final data = await supabase
          .from('customer_accounts')
          .select('phone, bio')
          .eq('id', userId)
          .maybeSingle();
      if (data != null) {
        if (data['phone'] != null && phone.text.isEmpty) {
          phone.text = data['phone'];
        }
        if (data['bio'] != null && bio.text.isEmpty) {
          bio.text = data['bio'];
        }
      }
    } catch (e) {
      debugPrint('Prefill extras error: $e');
    }
  }

  // Modal section label helper
  Widget _modalSectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: brandBrown.withValues(alpha: 0.7),
        letterSpacing: 1.4,
      ),
    );
  }

  // Branded input field helper
  Widget _modalField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textMainTheme),
          ),
        ),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: TextStyle(color: textMainTheme, fontSize: 15),
          decoration: InputDecoration(
            filled: true,
            fillColor: bgTheme,
            hintText: hint,
            hintStyle:
                TextStyle(color: textSecTheme.withValues(alpha: 0.5), fontSize: 14),
            prefixIcon: Icon(icon, color: brandBrown, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  BorderSide(color: brandBrown.withValues(alpha: 0.15), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: brandBrown, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bgTheme = Theme.of(context).scaffoldBackgroundColor;
    surfaceTheme = Theme.of(context).cardColor;
    textMainTheme = isDark ? Colors.white : const Color(0xFF1C1917);
    textSecTheme = isDark ? Colors.white70 : const Color(0xFF78716C);

    Widget body;
    switch (_currentIndex) {
      case 0:
        body = MarketplaceTab(
          filteredTranslators: filteredTranslators,
          recommendedTranslators: () {
            // Show only translators with at least 1 real review, sorted by rating
            final reviewed = allTranslators
                .where((t) => (t['review_count'] ?? 0) > 0)
                .toList()
              ..sort((a, b) {
                final aR = (a['avg_rating'] ?? 0.0).toDouble();
                final bR = (b['avg_rating'] ?? 0.0).toDouble();
                final cmp = bR.compareTo(aR);
                if (cmp != 0) return cmp;
                // Tie-break: more reviews wins
                return (b['review_count'] ?? 0).compareTo(a['review_count'] ?? 0);
              });
            return reviewed.isNotEmpty
                ? reviewed.take(5).toList()
                : allTranslators.take(5).toList();
          }(),
          loading: loading,
          selectedCategory: selectedCategory,
          searchController: _searchController,
          avatarUrl: _avatarUrl,
          userName: _displayName,
          brandBrown: brandBrown,
          bgTheme: bgTheme,
          surfaceTheme: surfaceTheme,
          textMainTheme: textMainTheme,
          textSecTheme: textSecTheme,
          onCategoryChanged: (cat) {
            setState(() => selectedCategory = cat);
            _applyFilters();
          },
          onSearchChanged: _applyFilters,
          onTranslatorTapped: (t) {
            if (_checkAuth()) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => UploadScreen(company: t)),
              );
            }
          },
          onProfileTapped: () => setState(() => _currentIndex = 3),
          onLanguageToggle: () => LocaleController.toggleLocale(),
          unreadNotificationCount: _unreadNotificationCount,
          onNotificationTapped: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreenWrapper()),
            );
            // Refresh count when returning
            _fetchUnreadNotificationCount();
          },
        );
        break;
      case 1:
        body = HistoryTab(
          supabase: supabase,
          brandBrown: brandBrown,
          textMainTheme: textMainTheme,
          textSecTheme: textSecTheme,
          surfaceTheme: surfaceTheme,
          fetchHistoryJobs: _fetchHistoryJobs,
          showFileActionMenu: _showFileActionMenu,
          onRefresh: () => setState(() {}),
        );
        break;
      case 2:
        body = TrackerTab(
          activeTrackerJobs: _activeTrackerJobs,
          selectedTrackerJob: _selectedTrackerJob,
          onSelectJob: (job) => setState(() => _selectedTrackerJob = job),
          brandBrown: brandBrown,
          textMainTheme: textMainTheme,
          textSecTheme: textSecTheme,
          surfaceTheme: surfaceTheme,
          onRefresh: _fetchActiveTrackerJob,
        );
        break;
      case 3:
        body = ProfileTab(
          displayName: _displayName,
          avatarUrl: _avatarUrl,
          accountType: _accountType,
          walletBalance: _walletBalance,
          totalOrders: _totalOrders,
          brandBrown: brandBrown,
          textMainTheme: textMainTheme,
          textSecTheme: textSecTheme,
          surfaceTheme: surfaceTheme,
          onEditProfile: _editProfileModal,
          onSignOut: _showLogoutConfirm,
        );
        break;
      case 4:
        body = _canAccessAdminDashboard
            ? AdminDashboardTab(
                brandBrown: brandBrown,
                textMainTheme: textMainTheme,
                textSecTheme: textSecTheme,
                surfaceTheme: surfaceTheme,
              )
            : _buildAdminAccessDenied();
        break;
      case 5:
        body = const TranslatorDashboardTab();
        break;
      default:
        body = ProfileTab(
          displayName: _displayName,
          avatarUrl: _avatarUrl,
          accountType: _accountType,
          walletBalance: _walletBalance,
          totalOrders: _totalOrders,
          brandBrown: brandBrown,
          textMainTheme: textMainTheme,
          textSecTheme: textSecTheme,
          surfaceTheme: surfaceTheme,
          onEditProfile: _editProfileModal,
          onSignOut: _showLogoutConfirm,
        );
    }

    return Scaffold(
      backgroundColor: bgTheme,
      body: UpgradeAlert(
        upgrader: Upgrader(),
        child: SafeArea(child: body),
      ),
      bottomNavigationBar: _buildFloatingNav(),
    );
  }

  Widget _buildFloatingNav() {
    final bool hasActiveJob = _activeTrackerJobs.isNotEmpty;
    final bool isAdmin = _isDesignatedAdmin;
    final bool isTranslator = _accountType == 'translator';
    final double padding = (isAdmin || isTranslator) ? 10.0 : 16.0;
    return SafeArea(
      top: false,
      child: Container(
        height: 64,
        margin: EdgeInsets.symmetric(horizontal: (isAdmin || isTranslator) ? 12 : 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _navItem(Icons.grid_view_rounded, "Home", 0, horizontalPadding: padding),
            _navItem(Icons.assignment_outlined, "History", 1, horizontalPadding: padding),
            _navItemWithBadge(Icons.track_changes_rounded, "Tracker", 2, hasActiveJob, horizontalPadding: padding),
            if (isTranslator) _navItem(Icons.translate_rounded, "Translator", 5, horizontalPadding: padding),
            if (isAdmin) _navItem(Icons.admin_panel_settings_rounded, "Admin", 4, horizontalPadding: padding),
            _navItem(Icons.person_outline_rounded, "Profile", 3, horizontalPadding: padding),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminAccessDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, size: 48, color: brandBrown.withValues(alpha: 0.8)),
            const SizedBox(height: 16),
            Text(
              'Administrator access restricted',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textMainTheme,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Only the authorized administrator may open this dashboard after email verification.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecTheme, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAdminTab() async {
    if (!_isDesignatedAdmin) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access denied. Administrator privileges are restricted.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    // Admin is verified at login (OTP step-up persists 30 days).
    // Simply refresh access state and open the tab.
    await _refreshAdminAccess();
    if (mounted) setState(() => _currentIndex = 4);
  }

  Widget _navItem(IconData icon, String label, int index, {double horizontalPadding = 16}) {
    final bool active = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        if (index == 4) {
          _openAdminTab();
        } else {
          setState(() => _currentIndex = index);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
        child: Icon(
          icon,
          color: active ? brandBrown : textSecTheme.withValues(alpha: 0.4),
          size: active ? 28 : 24,
        ),
      ),
    );
  }

  Widget _navItemWithBadge(IconData icon, String label, int index, bool showBadge, {double horizontalPadding = 16}) {
    final bool active = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        _fetchActiveTrackerJob();
        setState(() => _currentIndex = index);
      },
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
            child: Icon(
              icon,
              color: active ? brandBrown : textSecTheme.withValues(alpha: 0.4),
              size: active ? 28 : 24,
            ),
          ),
          if (showBadge)
            Positioned(
              top: 8,
              right: 12,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: brandBrown,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// --- PLACEHOLDER DETAIL PAGE ---

class TranslatorProfileScreen extends StatelessWidget {
  final Map<String, dynamic> translator;
  const TranslatorProfileScreen({super.key, required this.translator});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(translator['full_name'] ?? "Profile")),
      body: Center(
        child:
            Text("Booking and Profile Details for ${translator['full_name']}"),
      ),
    );
  }
}
