import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/security_config.dart';
import '../services/admin_auth_service.dart';
import '../ds.dart';

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
      canPop: false,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: DS.background,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),

                  // ── Shield icon ──────────────────────────────────────────
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: DS.primary.withValues(alpha: 0.08),
                        border: Border.all(
                          color: DS.primary.withValues(alpha: 0.20),
                          width: 1,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0F111111),
                            blurRadius: 24,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        size: 38,
                        color: DS.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Title ────────────────────────────────────────────────
                  Text(
                    'Admin Verification',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: DS.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── Subtitle ─────────────────────────────────────────────
                  Text(
                    _codeSent
                        ? 'A 6-digit code was sent to\n$_email\n\nEnter it below to access the dashboard.'
                        : 'Sending verification code to\n$_email…',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.6,
                      color: DS.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── One-time notice badge ─────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: DS.primary.withValues(alpha: 0.06),
                      border: Border.all(color: DS.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: DS.primary.withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'You only need to verify once. Access is remembered for 30 days.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: DS.textSecondary,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── OTP input ────────────────────────────────────────────
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 8,
                    textAlign: TextAlign.center,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      letterSpacing: 10,
                      fontWeight: FontWeight.w900,
                      color: DS.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: '000000',
                      hintStyle: GoogleFonts.inter(
                        color: DS.placeholder,
                        letterSpacing: 10,
                        fontSize: 28,
                        fontWeight: FontWeight.w400,
                      ),
                      counterText: '',
                      filled: true,
                      fillColor: DS.bgSecondary,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(DS.radiusInput),
                        borderSide: const BorderSide(color: DS.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(DS.radiusInput),
                        borderSide: const BorderSide(color: DS.primary, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 20),
                    ),
                  ),

                  // ── Error message ─────────────────────────────────────────
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: DS.error.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: DS.error.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: DS.error,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ── Verify button ─────────────────────────────────────────
                  SizedBox(
                    height: DS.buttonHeight,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _verify,
                      style: DS.primaryButton(),
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              'Verify & Enter Dashboard',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Resend button ─────────────────────────────────────────
                  TextButton(
                    onPressed: _sending ? null : _sendCode,
                    child: Text(
                      _codeSent ? 'Resend code' : 'Send code',
                      style: GoogleFonts.inter(
                        color: DS.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ── Sign out ─────────────────────────────────────────────
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
                      style: GoogleFonts.inter(
                        color: DS.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
