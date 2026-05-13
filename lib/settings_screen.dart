import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/theme_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/locale_controller.dart';
import 'services/font_scale_controller.dart';
import 'HelpCenterScreen.dart';
import 'privacy_data_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Color brandColor = const Color(0xFF895129); // Brand brown
  late Color bgColor;
  late Color cardColor;

  String? _userEmail;
  String? _userName;
  String _accountType = 'personal'; 
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      if (mounted) setState(() => _userEmail = user.email);
      try {
        final data = await Supabase.instance.client
            .from('customer_accounts')
            .select('full_name, account_type')
            .eq('id', user.id)
            .maybeSingle();
        if (data != null && mounted) {
          setState(() {
            _userName = data['full_name'];
            _accountType = data['account_type'] ?? 'personal';
          });
        }
      } catch (e) {
        debugPrint("Error fetching profile for settings: $e");
      }
    }
  }

  Future<void> _loadSettings() async {
    // Other settings if any
  }

  void _handleSignOut() {
    debugPrint("Sign Out Tapped");
    showCupertinoDialog(
      context: context,
      barrierDismissible: true, // Allow tapping outside to cancel
      builder: (context) => CupertinoAlertDialog(
        title: const Text("Sign Out"),
        content: const Text("Are you sure you want to sign out of your account?"),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              setState(() => _isLoading = true);
              try {
                await Supabase.instance.client.auth.signOut();
                if (mounted) {
                  // Navigate to resolver which routes back to login screen
                  Navigator.of(context).pushNamedAndRemoveUntil('/start', (route) => false);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text("Error signing out: ${e.toString()}"),
                    backgroundColor: Colors.redAccent,
                  ));
                }
              }
            },
            child: const Text("Sign Out"),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteAccount() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Account?", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: const Text(
            "This action is irreversible. Your account and all associated data will be permanently deleted within 30 days. Are you sure you want to proceed?"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text("DELETE MY ACCOUNT"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        // Insert a deletion request
        await Supabase.instance.client.from('account_deletion_requests').insert({
          'user_id': userId,
          'email': _userEmail,
          'status': 'pending',
          'requested_at': DateTime.now().toIso8601String(),
        });
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Account deletion requested. You will now be signed out."),
        ));
        // Small delay to let user read the snackbar
        await Future.delayed(const Duration(seconds: 2));
        _handleSignOut();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Error requesting deletion: ${e.toString()}"),
          backgroundColor: Colors.redAccent,
        ));
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(child: CircularProgressIndicator(color: brandColor)),
      );
    }

    final locale = Localizations.localeOf(context).languageCode;
    final isEnglish = locale == 'en';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Settings',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: brandColor)),
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0.5,
        iconTheme: IconThemeData(color: brandColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Section
            _buildSectionHeader("Account"),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: brandColor.withValues(alpha: 0.1),
                    child: Icon(Icons.person, size: 30, color: brandColor),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_userName ?? "Loading...",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 4),
                        Text(_userEmail ?? "No email linked",
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                      ],
                    ),
                  ),
                  _buildAccountTypeBadge(),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildListTile(
              icon: Icons.account_box_outlined,
              title: "Account Type",
              subtitle: _accountType.toUpperCase(),
              onTap: _showAccountTypePicker,
            ),
            const SizedBox(height: 32),

            // Preferences
            _buildSectionHeader("Preferences"),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  _buildListTile(
                    icon: Icons.language_rounded,
                    title: "Language / ቋንቋ",
                    subtitle: isEnglish ? "English" : "Amharic",
                    trailing: Switch(
                      value: isEnglish,
                      activeColor: brandColor,
                      onChanged: (val) {
                        LocaleController.toggleLocale();
                      },
                    ),
                  ),
                  Divider(height: 1, color: Colors.grey.withValues(alpha: 0.1)),
                  _buildThemeTile(),
                  Divider(height: 1, color: Colors.grey.withValues(alpha: 0.1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.format_size_rounded, color: brandColor),
                            const SizedBox(width: 16),
                            const Text("Font Scaling",
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                            const Spacer(),
                            ValueListenableBuilder<double>(
                              valueListenable: FontScaleController.scaleNotifier,
                              builder: (context, scale, _) => Text("${(scale * 100).toInt()}%",
                                  style: TextStyle(color: brandColor, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ValueListenableBuilder<double>(
                          valueListenable: FontScaleController.scaleNotifier,
                          builder: (context, scale, _) => Slider(
                            value: scale,
                            min: 0.8,
                            max: 1.4,
                            divisions: 6,
                            activeColor: brandColor,
                            inactiveColor: brandColor.withValues(alpha: 0.1),
                            onChanged: (val) => FontScaleController.setScale(val),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Support & Legal
            _buildSectionHeader("Support & Legal"),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  _buildListTile(
                    icon: Icons.help_outline_rounded,
                    title: "Help Center",
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HelpCenterScreen())),
                  ),
                  Divider(height: 1, color: Colors.grey.withValues(alpha: 0.1)),
                  _buildListTile(
                    icon: Icons.privacy_tip_outlined,
                    title: "Privacy Policy",
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PrivacyDataScreen())),
                  ),
                  Divider(height: 1, color: Colors.grey.withValues(alpha: 0.1)),
                  _buildListTile(
                    icon: Icons.description_outlined,
                    title: "Terms of Service",
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PrivacyDataScreen())),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // About & Log out
            _buildSectionHeader("About"),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              title: const Text("App Version"),
              subtitle: const Text("1.2.0 (Premium Build)"),
              trailing: const Icon(Icons.info_outline_rounded, size: 20),
            ),
            const SizedBox(height: 24),
            
            // Log Out Button (Improved Responsiveness)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _handleSignOut,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.1)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                      SizedBox(width: 12),
                      Text(
                        "Sign Out of Account",
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Delete Account Button
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _handleDeleteAccount,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 20),
                      SizedBox(width: 12),
                      Text(
                        "Delete My Account",
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeTile() {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeNotifier,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark;
        return ListTile(
          leading: Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: brandColor),
          title: const Text("Appearance", style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(isDark ? "Dark Mode" : "Light Mode"),
          trailing: CupertinoSwitch(
            value: isDark,
            activeColor: brandColor,
            onChanged: (v) => ThemeController.toggleTheme(),
          ),
        );
      },
    );
  }

  Widget _buildAccountTypeBadge() {
    bool isBusiness = _accountType == 'business';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isBusiness ? brandColor : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _accountType.toUpperCase(),
        style: TextStyle(
          color: isBusiness ? Colors.white : Colors.grey.shade700,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  void _showAccountTypePicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text("Select Account Type"),
        message: const Text("Choose the account type that best fits your needs."),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => _updateAccountType('personal'),
            child: const Text("Personal Account"),
          ),
          CupertinoActionSheetAction(
            onPressed: () => _updateAccountType('business'),
            child: const Text("Business Account"),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
      ),
    );
  }

  Future<void> _updateAccountType(String type) async {
    Navigator.pop(context); // Close picker
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client
          .from('customer_accounts')
          .update({'account_type': type})
          .eq('id', userId);
      
      setState(() {
        _accountType = type;
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Account switched to ${type.toUpperCase()} successfully!"),
        ));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Error updating account type: $e"),
          backgroundColor: Colors.redAccent,
        ));
      }
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Colors.grey.shade500,
            letterSpacing: 1.5),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: brandColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: brandColor, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)) : null,
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 22),
    );
  }
}
