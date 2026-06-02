import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/security_config.dart';
import '../services/admin_auth_service.dart';

/// One-time email OTP verification for the admin before accessing the dashboard.
/// After successful verification the flag is persisted locally for 30 days,
/// so the admin is never asked again until the TTL expires or they sign out.
class AdminOtpScreen extends StatefulWidget {
  final String? email;

  const AdminOtpScreen({super.key, this.email});

  @override
  State<AdminOtpScreen> createState() => _AdminOtpScreenState();
}

class _AdminOtpScreenState extends State<AdminOtpScreen> {
  final _codeController = TextEditingController();
  bool _loading = false;
  bool _sending = false;
  bool _codeSent = false;
  String? _error;
  late String _email;

  static const _brown = Color(0xFF895129);
  static const _darkBg = Color(0xFF0D0A08);

  @override
  void initState() {
    super.initState();
    _email = widget.email ??
        Supabase.instance.client.auth.currentUser?.email ??
        SecurityConfig.superAdminEmail;
    _sendCode();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!SecurityConfig.isSuperAdminEmail(_email)) {
      setState(() => _error = 'This email is not authorized for admin access.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await AdminAuthService.sendEmailOtp(_email);
      if (mounted) {
        setState(() {
          _codeSent = true;
          _sending = false;
        });
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message.isNotEmpty
              ? e.message
              : 'Could not send verification code. Enable Email OTP in Supabase Auth.';
          _sending = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not send verification code: $e';
          _sending = false;
        });
      }
    }
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length < 6) {
      setState(() => _error = 'Enter the 6-digit code from your email.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AdminAuthService.verifyEmailOtp(email: _email, token: code);
      if (!mounted) return;
      // Replace the entire stack with /home — admin is now verified
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Invalid or expired code. Please try again.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Prevent back navigation — admin must verify to access the app
      canPop: false,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: _darkBg,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),

                  // Shield icon
                  Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _brown.withValues(alpha: 0.12),
                        border: Border.all(
                          color: _brown.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        size: 42,
                        color: Color(0xFFD4874A),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  Text(
                    'Admin Verification',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    _codeSent
                        ? 'A 6-digit verification code was sent to\n$_email\n\nEnter it below to access the admin dashboard.'
                        : 'Sending verification code to\n$_email…',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // One-time notice
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: _brown.withValues(alpha: 0.1),
                      border: Border.all(color: _brown.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 15, color: _brown.withValues(alpha: 0.9)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'You only need to verify once. The app remembers your access for 30 days.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.6),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // OTP input
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 8,
                    textAlign: TextAlign.center,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(
                      fontSize: 28,
                      letterSpacing: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    decoration: InputDecoration(
                      hintText: '000000',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.2),
                        letterSpacing: 10,
                        fontSize: 28,
                      ),
                      counterText: '',
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Verify button
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _verify,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brown,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Verify & Enter Dashboard',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Resend code
                  TextButton(
                    onPressed: _sending ? null : _sendCode,
                    child: Text(
                      _codeSent ? 'Resend code' : 'Send code',
                      style: TextStyle(
                        color: _brown,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Sign out option
                  TextButton(
                    onPressed: () async {
                      await Supabase.instance.client.auth.signOut();
                      if (mounted) {
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          '/login',
                          (route) => false,
                        );
                      }
                    },
                    child: Text(
                      'Sign out',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
