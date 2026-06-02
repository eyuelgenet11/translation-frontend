import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/force_update_service.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _blurAnimation;

  @override
  void initState() {
    super.initState();
    
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack),
      ),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _blurAnimation = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
      ),
    );

    _mainController.forward();
    _navigateToNext();
  }

  void _navigateToNext() {
    Timer(const Duration(milliseconds: 3000), () async {
      if (!mounted) return;

      // ── Step 1: Check for required/soft app update via Supabase ──────────
      final update = await ForceUpdateService.checkForUpdate();

      if (!mounted) return;

      if (update.type == UpdateType.force) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => ForceUpdateDialog(requiredVersion: update.version),
        );
        return;
      }

      if (update.type == UpdateType.soft) {
        await showDialog(
          context: context,
          barrierDismissible: true,
          builder: (_) => SoftUpdateDialog(newVersion: update.version),
        );
      }

      if (!mounted) return;

      // ── Step 2: Delegate all routing to AuthService ───────────────────────
      // Handles customers, admin (with OTP check), and approved translators.
      await AuthService.tryAutoLogin(context);
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const darkBg = Color(0xFF0F0D0C);

    return Scaffold(
      backgroundColor: darkBg,
      body: Center(
        child: AnimatedBuilder(
          animation: _mainController,
          builder: (context, child) {
            return ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: _blurAnimation.value, sigmaY: _blurAnimation.value),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Container(
                      width: 200,
                      height: 200,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Image.asset(
                        'assets/icon/TERGUM_padded.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
