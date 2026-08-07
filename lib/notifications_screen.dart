import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/empty_state.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final res = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _notifications = List<Map<String, dynamic>>.from(res);
          _loading = false;
        });
      }

      // Mark all as read
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
          
    } catch (e) {
      debugPrint("Error fetching notifications: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceTheme = isDark ? const Color(0xFF292524) : Colors.white;
    final textMainTheme = isDark ? Colors.white : const Color(0xFF1C1917);
    final textSecTheme = isDark ? Colors.white70 : const Color(0xFF78716C);
    final brandBrown = const Color(0xFF8D5C3C);
    final bgColor = isDark ? Colors.black : const Color(0xFFF8F9FA);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textMainTheme, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Notifications",
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: textMainTheme,
          ),
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: brandBrown))
          : _notifications.isEmpty
              ? PremiumEmptyState(
                  title: "No Notifications",
                  subtitle: "You're all caught up! No recent alerts.",
                  icon: Icons.notifications_off_outlined,
                  brandBrown: brandBrown,
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notif = _notifications[index];
                    final isRead = notif['is_read'] == true;
                    final date = DateTime.tryParse(notif['created_at'] ?? '')?.toLocal();
                    final timeString = date != null ? "${date.hour}:${date.minute.toString().padLeft(2, '0')}" : "";

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isRead ? surfaceTheme : brandBrown.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isRead 
                            ? (isDark ? Colors.white12 : Colors.grey.shade200) 
                            : brandBrown.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isRead 
                                ? (isDark ? Colors.white10 : Colors.grey.shade100)
                                : brandBrown.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.notifications_active_rounded,
                              color: isRead ? Colors.grey.shade400 : brandBrown,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      notif['title'] ?? 'Alert',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: textMainTheme,
                                      ),
                                    ),
                                    Text(
                                      timeString,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: textSecTheme,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  notif['message'] ?? '',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: textSecTheme,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}


