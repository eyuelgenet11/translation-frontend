import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../privacy_data_screen.dart';
import '../HelpCenterScreen.dart';
import '../widgets/how_to_guide.dart';

class ProfileTab extends StatelessWidget {
  final String? displayName;
  final String? avatarUrl;
  final String accountType;
  final double walletBalance;
  final int totalOrders;
  final Color brandBrown;
  final Color textMainTheme;
  final Color textSecTheme;
  final Color surfaceTheme;
  
  final VoidCallback onEditProfile;
  final VoidCallback onSignOut;

  const ProfileTab({
    super.key,
    required this.displayName,
    required this.avatarUrl,
    required this.accountType,
    required this.walletBalance,
    required this.totalOrders,
    required this.brandBrown,
    required this.textMainTheme,
    required this.textSecTheme,
    required this.surfaceTheme,
    required this.onEditProfile,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          InkWell(
            onTap: onEditProfile,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: brandBrown.withValues(alpha: 0.3), width: 1.5),
                        ),
                        child: CircleAvatar(
                          radius: 38,
                          backgroundColor: brandBrown.withValues(alpha: 0.05),
                          backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
                              ? NetworkImage(avatarUrl!)
                              : null,
                          child: (avatarUrl == null || avatarUrl!.isEmpty)
                              ? Icon(Icons.person, size: 30, color: brandBrown)
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit, size: 14, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(displayName ?? "User Name",
                            style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: textMainTheme)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: textSecTheme.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text("${accountType.toUpperCase()} ACCOUNT",
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: textSecTheme.withValues(alpha: 0.8),
                                      letterSpacing: 0.5)),
                            ),
                            const SizedBox(width: 8),
                            // NEW: Prominent Edit Button
                            GestureDetector(
                              onTap: onEditProfile,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  border: Border.all(color: brandBrown, width: 1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text("EDIT", style: TextStyle(color: brandBrown, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
          Row(
            children: [
              _statCard("Total Orders", totalOrders.toString(),
                  Icons.assignment_turned_in_outlined),
              const SizedBox(width: 16),
              _statCard(
                  "Total Assets",
                  "${walletBalance.toStringAsFixed(0)} ETB",
                  Icons.account_balance_wallet_outlined),
            ],
          ),
          const SizedBox(height: 40),
          _sectionLabel("PREFERENCES"),
          _profileTile(context, Icons.help_outline_rounded, "How to Guide",
              "Learn how to use the marketplace", () {
                showHowToGuide(context, textSecTheme);
              }),
          _profileTile(context, Icons.settings_outlined, "App Settings",
              "Theme, language, and font scaling", () {
                Navigator.pushNamed(context, '/settings');
              }),
          const SizedBox(height: 24),
          _sectionLabel("ACCOUNT & SECURITY"),
          _profileTile(context, Icons.person_outline_rounded, "Edit Account Info",
              "Change name and profile preferences", onEditProfile),
          _profileTile(context, Icons.security_rounded, "Privacy & Data",
              "Manage your data and security", () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => PrivacyDataScreen()));
              }),
          const SizedBox(height: 24),
          _sectionLabel("SUPPORT"),
          _profileTile(context, Icons.support_agent_rounded, "Help Center",
              "FAQs and support contacts", () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => HelpCenterScreen()));
              }),
          const SizedBox(height: 40),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onSignOut,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded, color: Colors.black, size: 20),
                    SizedBox(width: 12),
                    Text(
                      "Sign Out of Account",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surfaceTheme,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: brandBrown.withValues(alpha: 0.8), size: 24),
            const SizedBox(height: 16),
            Text(value,
                style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textMainTheme)),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: textSecTheme,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 16),
      child: Text(text,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: textSecTheme.withValues(alpha: 0.4),
              letterSpacing: 1.2)),
    );
  }

  Widget _profileTile(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surfaceTheme,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: brandBrown.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: brandBrown.withValues(alpha: 0.8), size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: textMainTheme)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(fontSize: 12, color: textSecTheme)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: Colors.grey.withValues(alpha: 0.3), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
