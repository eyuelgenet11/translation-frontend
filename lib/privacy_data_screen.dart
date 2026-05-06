import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyDataScreen extends StatelessWidget {
  const PrivacyDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color brandColor = isDark ? Colors.white : const Color(0xFF895129);
    final Color bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Privacy & Data',
            style: GoogleFonts.philosopher(fontWeight: FontWeight.bold, color: brandColor)),
        backgroundColor: bgColor,
        elevation: 0.5,
        iconTheme: IconThemeData(color: brandColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              context,
              "Data Privacy",
              "We take your privacy seriously. Your uploaded documents are only accessible to the assigned translator and our quality assurance team.",
            ),
            _buildSection(
              context,
              "Data Usage",
              "We use your data to provide translation services, improve our marketplace, and communicate job statuses. We never sell your personal information to third parties.",
            ),
            _buildSection(
              context,
              "Account Security",
              "Your account is protected by Supabase Auth. We recommend using a strong, unique password and keeping your contact information up to date.",
            ),
            _buildSection(
              context,
              "Terms of Service",
              "By using this app, you agree to our terms. You are responsible for the documents you upload. We reserve the right to refuse translation for illegal or prohibited content. All payments are final once the translation process has begun.",
            ),
            const SizedBox(height: 40),
            Center(
              child: Text(
                "Last Updated: March 2024",
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color brandColor = isDark ? Colors.white : const Color(0xFF895129);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.philosopher(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: brandColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
