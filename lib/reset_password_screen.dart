import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;

  late Color brandColor;
  final Color accentColor = const Color(0xFF8D5C3C);
  late Color bgColor;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    final password = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();

    if (password.isEmpty || confirm.isEmpty) {
      _snack("Please fill both fields.");
      return;
    }

    if (password != confirm) {
      _snack("Passwords do not match.");
      return;
    }

    if (password.length < 6) {
      _snack("Password must be at least 6 characters.");
      return;
    }

    setState(() => _loading = true);

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: password),
      );
      
      _snack("Password updated successfully!");
      if (mounted) {
        // Clear backstack and go to login
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } on AuthException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack("Error: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Theme.of(context).snackBarTheme.backgroundColor,
    ));
  }

  Widget _buildModernInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: brandColor.withValues(alpha: 0.6),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200]!, 
                width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: TextField(
            controller: controller,
            obscureText: _obscurePassword,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: brandColor),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: accentColor, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey[400],
                    size: 18),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              border: InputBorder.none,
              hintText: hint,
              hintStyle: TextStyle(
                  color: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.grey[300], 
                  fontSize: 14),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    brandColor = isDark ? Colors.white : const Color(0xFF1C1917);
    bgColor = Theme.of(context).scaffoldBackgroundColor;
    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // ðŸ“¸ Premium Background
          Positioned.fill(
            child: Opacity(
              opacity: Theme.of(context).brightness == Brightness.dark ? 0.15 : 0.4,
              child: Image.asset(
                'assets/images/login_bg_parchment.png',
                fit: BoxFit.cover,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.black : null,
                colorBlendMode: Theme.of(context).brightness == Brightness.dark ? BlendMode.darken : null,
              ),
            ),
          ),
          // Custom Back Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            child: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: accentColor),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      "Reset Password",
                      style: GoogleFonts.philosopher(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: accentColor,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Please enter your new password below. Make sure it's at least 6 characters long.",
                      style: TextStyle(
                        fontSize: 14,
                        color: brandColor.withValues(alpha: 0.6),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 48),
                    _buildModernInput(
                      controller: _passwordController,
                      label: "New Password",
                      hint: "â€¢â€¢â€¢â€¢â€¢â€¢â€¢â€¢",
                      icon: Icons.lock_outline_rounded,
                    ),
                    const SizedBox(height: 20),
                    _buildModernInput(
                      controller: _confirmController,
                      label: "Confirm Password",
                      hint: "â€¢â€¢â€¢â€¢â€¢â€¢â€¢â€¢",
                      icon: Icons.lock_outline_rounded,
                    ),
                    const SizedBox(height: 48),
                    _buildUpdateButton(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          colors: _loading
              ? [Colors.grey[400]!, Colors.grey[500]!]
              : [accentColor, accentColor.withValues(alpha: 0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: _loading ? [] : [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _loading ? null : _updatePassword,
          borderRadius: BorderRadius.circular(30),
          child: Center(
            child: _loading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : Text(
                    "UPDATE PASSWORD",
                    style: GoogleFonts.philosopher(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}


