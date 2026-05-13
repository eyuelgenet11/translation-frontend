import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color brandColor = isDark ? Colors.white : const Color(0xFF895129);
    final Color bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Notifications',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: brandColor)),
        backgroundColor: bgColor,
        elevation: 0.5,
        iconTheme: IconThemeData(color: brandColor),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none_rounded, size: 80, color: brandColor.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text(
              'No new notifications',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We\'ll notify you when your translation is ready.',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
