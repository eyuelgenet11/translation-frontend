import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../privacy_data_screen.dart';
import '../HelpCenterScreen.dart';
import '../widgets/how_to_guide.dart';

class ProfileTab extends StatelessWidget {
  final String? displayName;
  final String? avatarUrl;
  final String accountType;
  final double walletBalance; // Hidden as per earlier request
  final int totalOrders; // Hidden as per earlier request
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
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader("APP PREFERENCES"),
                _buildSettingsGroup([
                  _buildSettingsTile(
                    icon: Icons.language_rounded,
                    iconColor: Colors.blueAccent,
                    title: "Language",
                    subtitle: "English (US)",
                    onTap: () {
                      _showComingSoonSnack(context, "Language selection coming soon.");
                    },
                  ),
                  _buildSettingsTile(
                    icon: Icons.dark_mode_rounded,
                    iconColor: Colors.deepPurpleAccent,
                    title: "Dark Mode",
                    subtitle: "System Default",
                    hasSwitch: true,
                    onTap: () {
                      _showComingSoonSnack(context, "Theme toggling coming soon.");
                    },
                  ),
                  _buildSettingsTile(
                    icon: Icons.notifications_active_rounded,
                    iconColor: Colors.orangeAccent,
                    title: "Notifications",
                    subtitle: "All alerts ON",
                    onTap: () {
                      _showComingSoonSnack(context, "Notification preferences coming soon.");
                    },
                  ),
                ]),
                
                const SizedBox(height: 32),
                _buildSectionHeader("ACCOUNT & SECURITY"),
                _buildSettingsGroup([
                  _buildSettingsTile(
                    icon: Icons.person_outline_rounded,
                    iconColor: brandBrown,
                    title: "Personal Information",
                    subtitle: "Name, email, and avatar",
                    onTap: onEditProfile,
                  ),
                  _buildSettingsTile(
                    icon: Icons.credit_card_rounded,
                    iconColor: Colors.green.shade600,
                    title: "Payment Methods",
                    subtitle: "Manage Telebirr & Banks",
                    onTap: () {
                      _showComingSoonSnack(context, "Payment methods management coming soon.");
                    },
                  ),
                  _buildSettingsTile(
                    icon: Icons.shield_rounded,
                    iconColor: Colors.redAccent,
                    title: "Privacy & Data",
                    subtitle: "Manage your data security",
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => PrivacyDataScreen()));
                    },
                  ),
                ]),

                const SizedBox(height: 32),
                _buildSectionHeader("SUPPORT & ABOUT"),
                _buildSettingsGroup([
                  _buildSettingsTile(
                    icon: Icons.integration_instructions_rounded,
                    iconColor: Colors.teal,
                    title: "How-to Guide",
                    subtitle: "Interactive app walkthrough",
                    onTap: () {
                      showHowToGuide(context, textSecTheme);
                    },
                  ),
                  _buildSettingsTile(
                    icon: Icons.headset_mic_rounded,
                    iconColor: Colors.indigoAccent,
                    title: "Help Center",
                    subtitle: "FAQs and Live Support",
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => HelpCenterScreen()));
                    },
                  ),
                  _buildSettingsTile(
                    icon: Icons.star_rate_rounded,
                    iconColor: Colors.amber.shade700,
                    title: "Rate the App",
                    subtitle: "Love Tirgumsra?",
                    onTap: () {
                      _showComingSoonSnack(context, "Store redirection coming soon.");
                    },
                  ),
                ]),

                const SizedBox(height: 48),
                _buildSignOutButton(),
                const SizedBox(height: 100), // Padding for bottom nav
              ],
            ),
          )
        ],
      ),
    );
  }

  void _showComingSoonSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 60, bottom: 30),
      decoration: BoxDecoration(
        color: surfaceTheme,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [brandBrown, brandBrown.withValues(alpha: 0.5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: surfaceTheme,
                  backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
                      ? NetworkImage(avatarUrl!)
                      : null,
                  child: (avatarUrl == null || avatarUrl!.isEmpty)
                      ? Icon(Icons.person_rounded, size: 40, color: brandBrown)
                      : null,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4),
                    ]
                  ),
                  child: const Icon(Icons.verified_rounded, color: Colors.blueAccent, size: 24),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            displayName ?? "User Name",
            style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: textMainTheme),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: brandBrown.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "${accountType.toUpperCase()} ACCOUNT",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: brandBrown,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onEditProfile,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_rounded, size: 14, color: textSecTheme),
                  const SizedBox(width: 6),
                  Text("Edit Profile", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecTheme)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: textSecTheme.withValues(alpha: 0.5),
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceTheme,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: children.asMap().entries.map((entry) {
          int idx = entry.key;
          Widget child = entry.value;
          return Column(
            children: [
              child,
              if (idx != children.length - 1)
                Divider(height: 1, thickness: 1, color: Colors.grey.shade100, indent: 64, endIndent: 20),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    bool hasSwitch = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textMainTheme,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: textSecTheme),
                  ),
                ],
              ),
            ),
            if (hasSwitch)
              Switch(
                value: false, // Placeholder
                onChanged: (val) => onTap(),
                activeColor: brandBrown,
              )
            else
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildSignOutButton() {
    return Center(
      child: TextButton(
        onPressed: onSignOut,
        style: TextButton.styleFrom(
          foregroundColor: Colors.redAccent,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.logout_rounded, size: 20),
            const SizedBox(width: 8),
            Text(
              "Sign Out of Account",
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
