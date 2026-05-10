import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _loading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _termsAccepted = false;
  String _accountType = 'personal';

  // Step-based form (2 steps)
  int _step = 1; // 1 = Account info, 2 = Account type & confirm

  static const _brown = Color(0xFF895129);
  static const _darkBg = Color(0xFF0D0A08);

  late AnimationController _bgCtrl;
  late AnimationController _stepCtrl;
  late Animation<double> _stepFade;
  late Animation<Offset> _stepSlide;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _stepCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();

    _stepFade = CurvedAnimation(parent: _stepCtrl, curve: Curves.easeOut);
    _stepSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _stepCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _stepCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    if (name.isEmpty) { _snack('Please enter your full name.'); return; }
    if (email.isEmpty || !email.contains('@')) { _snack('Please enter a valid email.'); return; }
    if (pass.length < 6) { _snack('Password must be at least 6 characters.'); return; }

    _stepCtrl.reset();
    setState(() => _step = 2);
    _stepCtrl.forward();
  }

  Future<void> _register() async {
    if (_passCtrl.text != _confirmPassCtrl.text) {
      _snack('Passwords do not match.');
      return;
    }
    if (!_termsAccepted) {
      _snack('Please accept the Terms & Conditions to continue.');
      return;
    }

    setState(() => _loading = true);
    HapticFeedback.lightImpact();

    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
        data: {
          'full_name': _nameCtrl.text.trim(),
          'role': 'customer',
          'account_type': _accountType,
        },
      );

      if (res.user != null && mounted) {
        HapticFeedback.heavyImpact();
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on AuthException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Registration failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
              child: Column(
                children: [
                  _buildTopBar(),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: FadeTransition(
                        opacity: _stepFade,
                        child: SlideTransition(
                          position: _stepSlide,
                          child: Column(
                            children: [
                              const SizedBox(height: 16),
                              _buildStepIndicator(),
                              const SizedBox(height: 32),
                              _buildStepTitle(),
                              const SizedBox(height: 28),
                              _buildGlassCard(),
                              const SizedBox(height: 28),
                              if (_step == 1) _buildFooter(),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (_step == 2) {
                _stepCtrl.reset();
                setState(() => _step = 1);
                _stepCtrl.forward();
              } else {
                Navigator.pop(context);
              }
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white70, size: 16),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Create Account',
            style: GoogleFonts.philosopher(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _stepDot(1),
        Container(
          width: 60,
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(1),
            gradient: LinearGradient(
              colors: _step >= 2
                  ? [_brown, _brown]
                  : [_brown, Colors.white.withValues(alpha: 0.1)],
            ),
          ),
        ),
        _stepDot(2),
      ],
    );
  }

  Widget _stepDot(int step) {
    final active = _step >= step;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? _brown : Colors.white.withValues(alpha: 0.07),
        border: Border.all(
          color: active ? _brown : Colors.white.withValues(alpha: 0.15),
          width: 2,
        ),
        boxShadow: active
            ? [BoxShadow(color: _brown.withValues(alpha: 0.4), blurRadius: 12)]
            : [],
      ),
      child: Center(
        child: active && _step > step
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
            : Text(
                '$step',
                style: TextStyle(
                  color: active ? Colors.white : Colors.white30,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
      ),
    );
  }

  Widget _buildStepTitle() {
    final titles = ['Your Identity', 'Account Type'];
    final subtitles = [
      'Set up your name, email & password',
      'Tell us how you plan to use Geez Translation',
    ];
    return Column(
      children: [
        Text(
          titles[_step - 1],
          style: GoogleFonts.philosopher(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitles[_step - 1],
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 13,
            fontWeight: FontWeight.w500,
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
          child:
              _step == 1 ? _buildStep1Fields() : _buildStep2Fields(),
        ),
      ),
    );
  }

  Widget _buildStep1Fields() {
    return Column(
      children: [
        _buildField(
          controller: _nameCtrl,
          label: 'FULL NAME',
          hint: 'Your full name',
          icon: Icons.person_outline_rounded,
        ),
        const SizedBox(height: 18),
        _buildField(
          controller: _emailCtrl,
          label: 'EMAIL',
          hint: 'you@example.com',
          icon: Icons.alternate_email_rounded,
          type: TextInputType.emailAddress,
        ),
        const SizedBox(height: 18),
        _buildField(
          controller: _passCtrl,
          label: 'PASSWORD',
          hint: '6+ characters',
          icon: Icons.lock_outline_rounded,
          isPass: true,
          obscure: _obscurePass,
          onToggle: () => setState(() => _obscurePass = !_obscurePass),
        ),
        const SizedBox(height: 28),
        _buildActionBtn('NEXT STEP', _nextStep, trailingIcon: Icons.arrow_forward_rounded),
      ],
    );
  }

  Widget _buildStep2Fields() {
    return Column(
      children: [
        _buildField(
          controller: _confirmPassCtrl,
          label: 'CONFIRM PASSWORD',
          hint: 'Re-enter password',
          icon: Icons.lock_person_outlined,
          isPass: true,
          obscure: _obscureConfirm,
          onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
        ),
        const SizedBox(height: 28),
        _buildAccountTypeSelector(),
        const SizedBox(height: 24),
        _buildTermsToggle(),
        const SizedBox(height: 28),
        _buildActionBtn(
          _loading ? '' : 'CREATE ACCOUNT',
          _loading ? () {} : _register,
          loading: _loading,
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType type = TextInputType.text,
    bool isPass = false,
    bool obscure = false,
    VoidCallback? onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              color: _brown.withValues(alpha: 0.9),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPass ? obscure : false,
            keyboardType: type,
            autocorrect: false,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: _brown.withValues(alpha: 0.8), size: 20),
              suffixIcon: isPass && onToggle != null
                  ? IconButton(
                      icon: Icon(
                        obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.white.withValues(alpha: 0.3),
                        size: 18,
                      ),
                      onPressed: onToggle,
                    )
                  : null,
              border: InputBorder.none,
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.2),
                fontSize: 14,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ACCOUNT TYPE',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            color: _brown.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _typeCard('personal', 'Personal', Icons.person_outline_rounded, 'For individual use')),
            const SizedBox(width: 12),
            Expanded(child: _typeCard('business', 'Business', Icons.business_center_outlined, 'For organizations')),
          ],
        ),
      ],
    );
  }

  Widget _typeCard(String type, String title, IconData icon, String desc) {
    final isSel = _accountType == type;
    return GestureDetector(
      onTap: () => setState(() => _accountType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isSel ? _brown.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: isSel ? _brown : Colors.white.withValues(alpha: 0.1),
            width: isSel ? 2 : 1,
          ),
          boxShadow: isSel
              ? [BoxShadow(color: _brown.withValues(alpha: 0.25), blurRadius: 16)]
              : [],
        ),
        child: Column(
          children: [
            Icon(icon, color: isSel ? _brown : Colors.white30, size: 26),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: isSel ? Colors.white : Colors.white38,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSel ? Colors.white54 : Colors.white24,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsToggle() {
    return GestureDetector(
      onTap: () => setState(() => _termsAccepted = !_termsAccepted),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              color: _termsAccepted ? _brown : Colors.white.withValues(alpha: 0.07),
              border: Border.all(
                color: _termsAccepted ? _brown : Colors.white.withValues(alpha: 0.2),
              ),
            ),
            child: _termsAccepted
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'I agree to the ',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 13,
                    ),
                  ),
                  TextSpan(
                    text: 'Terms of Service',
                    style: const TextStyle(
                      color: _brown,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: ' and ',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 13,
                    ),
                  ),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: const TextStyle(
                      color: _brown,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn(String label, VoidCallback onTap,
      {IconData? trailingIcon, bool loading = false}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 58,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: loading
              ? const LinearGradient(colors: [Colors.grey, Colors.grey])
              : const LinearGradient(
                  colors: [Color(0xFFA0622F), _brown],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          boxShadow: loading
              ? []
              : [
                  BoxShadow(
                    color: _brown.withValues(alpha: 0.45),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.philosopher(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    if (trailingIcon != null) ...[
                      const SizedBox(width: 10),
                      Icon(trailingIcon, color: Colors.white, size: 18),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account? ',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 13,
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.pushReplacementNamed(context, '/login'),
          child: Text(
            'Sign In',
            style: const TextStyle(
              color: _brown,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Shared animated background (same as Login)
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
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0D0A08), Color(0xFF160C04)],
                ),
              ),
            ),
            Positioned(
              top: -80 + (t * 40),
              left: -60 + (sin(t * pi) * 20),
              child: _orb(260, const Color(0xFF895129), 0.18),
            ),
            Positioned(
              bottom: -100 + (t * 30),
              right: -80 + (cos(t * pi) * 25),
              child: _orb(300, const Color(0xFF6B3E1E), 0.14),
            ),
            Positioned(
              top: MediaQuery.of(context).size.height * 0.35,
              left: MediaQuery.of(context).size.width * 0.1,
              child: _orb(180, const Color(0xFFD4874A), 0.06),
            ),
          ],
        );
      },
    );
  }

  Widget _orb(double size, Color color, double opacity) => Container(
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
