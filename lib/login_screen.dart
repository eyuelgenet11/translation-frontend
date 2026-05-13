import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'services/locale_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  bool _loading = false;

  static const _brown = Color(0xFF895129);
  static const _darkBg = Color(0xFF0D0A08);


  late AnimationController _bgCtrl;
  late AnimationController _entryCtrl;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  final supabase = Supabase.instance.client;
  late StreamSubscription<AuthState> _authSub;

  @override
  void initState() {
    super.initState();
    _loadSaved();

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

  void _onAuth(AuthState data) {
    if (data.event == AuthChangeEvent.signedIn && data.session != null) {
      final user = data.session!.user;
      
      // Check if profile exists
      supabase
          .from('profiles')
          .select('id')
          .eq('id', user.id)
          .maybeSingle()
          .then((profile) async {
        
        if (profile == null) {
          // New user! Create records in both tables
          final name = user.userMetadata?['full_name'] ??
              user.userMetadata?['name'] ??
              'User';
          final email = user.email;
          final avatar = user.userMetadata?['avatar_url'] ?? user.userMetadata?['picture'];

          try {
            // 1. Insert into profiles (Master table for auth/chat)
            await supabase.from('profiles').insert({
              'id': user.id,
              'full_name': name,
              'email': email,
              'avatar_url': avatar,
              'role': 'customer',
            });

            // 2. Insert into customer_accounts (App logic table)
            await supabase.from('customer_accounts').insert({
              'id': user.id,
              'full_name': name,
              'email': email,
              'avatar_url': avatar,
              'account_type': 'personal',
            });
          } catch (e) {
            debugPrint("Error creating user profiles: $e");
          }
        }
        
        if (mounted) Navigator.pushReplacementNamed(context, '/home');
      }).catchError((err) {
        debugPrint("Auth verification error: $err");
        if (mounted) Navigator.pushReplacementNamed(context, '/home');
      });
    }
  }

  Future<void> _loadSaved() async {
    // No saved credentials needed without email login
  }

  Future<void> _googleSignIn() async {
    setState(() => _loading = true);
    try {
      debugPrint('Starting Google OAuth sign-in...');
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'io.supabase.geezapp://login-callback/',
      );
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      _snack('Google Sign-In failed: $e');
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
      backgroundColor: const Color(0xFF2D1A0A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _darkBg,
        body: Stack(
          children: [
            _AnimatedBg(controller: _bgCtrl),
            SafeArea(
              child: FadeTransition(
                opacity: _fadeIn,
                child: SlideTransition(
                  position: _slideUp,
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        children: [
                          const SizedBox(height: 24),
                          _buildHeader(),
                          const SizedBox(height: 40),
                          _buildGlassCard(),
                          const SizedBox(height: 28),
                          _buildFooter(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _buildLangToggle(),
          ],
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
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [_brown, Color(0xFFD4874A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _brown.withValues(alpha: 0.5),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipOval(
            child: SizedBox(
              width: 92,
              height: 92,
              child: Image.asset(
                'assets/icon/fffinal logo.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Geez Translation',
          style: GoogleFonts.inter(
            fontSize: 38,
            fontWeight: FontWeight.w900,
            color: Colors.white,
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
            "Ethiopia's Premier translation marketplace",
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

  Widget _buildGlassCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            color: Colors.white.withValues(alpha: 0.04),
            border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
          ),
          child: Column(
            children: [
              _buildGoogleBtn(),
              const SizedBox(height: 20),
              _buildDivider(),
              const SizedBox(height: 20),
              _buildGuestBtn(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleBtn() {
    return GestureDetector(
      onTap: _loading ? null : _googleSignIn,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 58,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.15),
              blurRadius: 20,
              spreadRadius: -4,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: _loading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: _brown),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/images/google_logo.png',
                        width: 24, height: 24),
                    const SizedBox(width: 14),
                    Text(
                      'Continue with Google',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A1A),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.35),
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
        ),
        Expanded(
          child: Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
        ),
      ],
    );
  }

  Widget _buildGuestBtn() {
    return GestureDetector(
      onTap: _loading ? null : _enterGuestMode,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withValues(alpha: 0.06),
          border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_outline_rounded,
              color: Colors.white.withValues(alpha: 0.6),
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              'Continue as Guest',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
                fontSize: 15,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white.withValues(alpha: 0.3),
              size: 13,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Text(
      'By continuing, you agree to our Terms & Privacy Policy.',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.25),
        fontSize: 11,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
    );
  }

  Widget _buildLangToggle() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      right: 20,
      child: GestureDetector(
        onTap: LocaleController.toggleLocale,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white.withValues(alpha: 0.08),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.language, size: 14, color: Colors.white70),
                  const SizedBox(width: 6),
                  Text(
                    Localizations.localeOf(context).languageCode == 'en'
                        ? 'AM'
                        : 'EN',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
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

// ─────────────────────────────────────────────
// Animated background with floating orbs
// ─────────────────────────────────────────────
class _AnimatedBg extends StatelessWidget {
  final AnimationController controller;
  const _AnimatedBg({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = controller.value;
        return Stack(
          children: [
            // Deep dark base
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0D0A08), Color(0xFF160C04)],
                ),
              ),
            ),
            // Top orb
            Positioned(
              top: -80 + (t * 40),
              left: -60 + (sin(t * pi) * 20),
              child: _orb(260, const Color(0xFF895129), 0.18),
            ),
            // Bottom orb
            Positioned(
              bottom: -100 + (t * 30),
              right: -80 + (cos(t * pi) * 25),
              child: _orb(300, const Color(0xFF6B3E1E), 0.14),
            ),
            // Center subtle glow
            Positioned(
              top: MediaQuery.of(context).size.height * 0.35,
              left: MediaQuery.of(context).size.width * 0.1,
              child: _orb(180, const Color(0xFFD4874A), 0.06),
            ),
            // Noise/grain overlay simulation via opacity
            Positioned.fill(
              child: Opacity(
                opacity: 0.03,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      colors: [Colors.white, Colors.transparent],
                      center: Alignment.topCenter,
                      radius: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _orb(double size, Color color, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: opacity), Colors.transparent],
        ),
      ),
    );
  }
}
