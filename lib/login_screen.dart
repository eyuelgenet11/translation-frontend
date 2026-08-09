import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:crypto/crypto.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'services/role_security_service.dart';
import 'services/admin_auth_service.dart';
import 'config/security_config.dart';
import 'services/push_notification_service.dart';
import 'package:upgrader/upgrader.dart';
import 'ds.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  bool _loading = false;

  static const _brown = DS.primary;
  static const _bg = DS.background;

  late AnimationController _bgCtrl;
  late AnimationController _entryCtrl;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  final supabase = Supabase.instance.client;
  late StreamSubscription<AuthState> _authSub;


  @override
  void initState() {
    super.initState();

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeIn = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _entryCtrl.forward();
    });

    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen(_onAuth);
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _entryCtrl.dispose();
    _authSub.cancel();
    super.dispose();
  }

  /// Called whenever Supabase fires an auth state change (e.g. Google OAuth completes).
  void _onAuth(AuthState data) async {
    if (data.event != AuthChangeEvent.signedIn || data.session == null) return;
    final user = data.session!.user;

    // Ensure profile exists and role is enforced correctly
    await _ensureProfile(user);
    await RoleSecurityService.enforceProfileRoles(user);

    // Save FCM token immediately on successful login
    try {
      await PushNotificationService().saveTokenToSupabase();
    } catch (e) {
      debugPrint("Error saving FCM token on login: $e");
    }

    // Re-fetch the final profile to get authoritative role & status
    final profile = await supabase
        .from('profiles')
        .select('role, status')
        .eq('id', user.id)
        .maybeSingle();

    final role = profile?['role'] as String?;
    final status = (profile?['status'] as String?)?.toLowerCase();

    if (!mounted) return;

    // Ã¢â€â‚¬Ã¢â€â‚¬ Admin Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
    // Admin must complete a one-time email OTP the first time.
    // After that the verification flag persists for 30 days.
    if (role == 'admin') {
      final alreadyVerified = await AdminAuthService.isStepUpVerified();
      if (!mounted) return;
      if (alreadyVerified) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pushNamed(context, '/admin-otp', arguments: user.email);
      }
      return;
    }

    // Ã¢â€â‚¬Ã¢â€â‚¬ Approved translator Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
    if (role == 'translator' && SecurityConfig.isApprovedTranslatorStatus(status)) {
      Navigator.pushReplacementNamed(context, '/translator-home');
      return;
    }

    // Ã¢â€â‚¬Ã¢â€â‚¬ Regular customer (or pending translator) Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
    Navigator.pushReplacementNamed(context, '/home');
  }

  /// Creates a profile row for brand-new users who just signed in for the first time.
  Future<void> _ensureProfile(User user) async {
    final existing = await supabase
        .from('profiles')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();

    if (existing != null) return; // Profile already exists

    final name = user.userMetadata?['full_name'] ??
        user.userMetadata?['name'] ??
        'User';
    final email = user.email ?? '';
    final avatar =
        user.userMetadata?['avatar_url'] ?? user.userMetadata?['picture'];
    final role = SecurityConfig.isSuperAdminEmail(email) ? 'admin' : 'customer';

    try {
      await supabase.from('profiles').insert({
        'id': user.id,
        'full_name': name,
        'email': email,
        'avatar_url': avatar,
        'role': role,
        'status': 'Active',
      });
      if (role == 'customer') {
        await supabase.from('customer_accounts').insert({
          'id': user.id,
          'full_name': name,
          'email': email,
          'avatar_url': avatar,
          'account_type': 'personal',
        });
      }
    } catch (e) {
      debugPrint('LoginScreen: error creating user profile: $e');
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _loading = true);
    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'io.supabase.geezapp://login-callback/',
      );
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      _snack('Google Sign-In failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _appleSignIn() async {
    setState(() => _loading = true);
    try {
      final isIOS = !kIsWeb && Theme.of(context).platform == TargetPlatform.iOS;
      final isMac = !kIsWeb && Theme.of(context).platform == TargetPlatform.macOS;
      
      if (isIOS || isMac) {
        final rawNonce = supabase.auth.generateRawNonce();
        final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

        final credential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
          nonce: hashedNonce,
        );

        final idToken = credential.identityToken;
        if (idToken == null) {
          throw const AuthException('No ID Token found.');
        }

        await supabase.auth.signInWithIdToken(
          provider: OAuthProvider.apple,
          idToken: idToken,
          nonce: rawNonce,
        );
      } else {
        await supabase.auth.signInWithOAuth(
          OAuthProvider.apple,
          redirectTo: kIsWeb ? null : 'io.supabase.geezapp://login-callback/',
        );
      }
    } catch (e) {
      debugPrint('Apple Sign-In Error: $e');
      _snack('Apple Sign-In failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _enterGuestMode() {
    HapticFeedback.lightImpact();
    if (mounted) Navigator.pushReplacementNamed(context, '/home');
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: DS.textPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: UpgradeAlert(
        upgrader: Upgrader(),
        child: Scaffold(
          backgroundColor: DS.background,
          body: SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: SlideTransition(
                position: _slideUp,
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 32),
                        _buildHeader(),
                        const SizedBox(height: 36),
                        _buildCard(),
                        const SizedBox(height: 24),
                        _buildFooter(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [_brown, Color(0xFFD4874A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _brown.withValues(alpha: 0.18),
                blurRadius: 24,
                spreadRadius: 0,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(21),
            child: SizedBox(
              width: 92,
              height: 92,
              child: Image.asset(
                'assets/icon/TERGUM_padded.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Tirgum Sra',
          style: GoogleFonts.inter(
            fontSize: 36,
            fontWeight: FontWeight.w900,
            color: DS.textPrimary,
            letterSpacing: -0.5,
            height: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'MARKETPLACE',
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 4.5,
            color: _brown.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: _brown.withValues(alpha: 0.25)),
            color: _brown.withValues(alpha: 0.07),
          ),
          child: Text(
            "Ethiopia's Premier Translation Marketplace",
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: DS.cardDecoration(),
      child: Column(
        children: [
          _buildGoogleBtn(),
          if (!kIsWeb && Theme.of(context).platform == TargetPlatform.iOS) ...[
            const SizedBox(height: 16),
            _buildAppleBtn(),
          ],
          const SizedBox(height: 20),
          _buildDivider(),
          const SizedBox(height: 20),
          _buildGuestBtn(),
        ],
      ),
    );
  }

  Widget _buildGoogleBtn() {
    return SizedBox(
      width: double.infinity,
      height: DS.buttonHeight,
      child: OutlinedButton(
        onPressed: _loading ? null : _googleSignIn,
        style: DS.secondaryButton(),
        child: _loading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: DS.primary),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/google_logo.png',
                      width: 20, height: 20),
                  const SizedBox(width: 12),
                  Text(
                    'Continue with Google',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: DS.textPrimary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildAppleBtn() {
    return SizedBox(
      height: DS.buttonHeight,
      child: SignInWithAppleButton(
        onPressed: _loading ? () {} : () => _appleSignIn(),
        borderRadius: BorderRadius.circular(DS.radiusButton),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: DS.divider, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: DS.placeholder,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Expanded(child: Divider(color: DS.divider, height: 1)),
      ],
    );
  }

  Widget _buildGuestBtn() {
    return SizedBox(
      width: double.infinity,
      height: DS.buttonHeight,
      child: OutlinedButton.icon(
        onPressed: _loading ? null : _enterGuestMode,
        icon: const Icon(Icons.person_outline_rounded, color: DS.primary, size: 20),
        label: Text(
          'Continue as Guest',
          style: GoogleFonts.inter(
            color: DS.primary,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        style: DS.secondaryButton(),
      ),
    );
  }

  Widget _buildFooter() {
    return Text(
      'By continuing, you agree to our Terms & Privacy Policy.',
      textAlign: TextAlign.center,
      style: GoogleFonts.inter(
        color: DS.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
    );
  }
}




