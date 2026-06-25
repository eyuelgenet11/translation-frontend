import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/force_update_service.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  // Logo animations
  late AnimationController _logoController;
  late Animation<double> _logoFade;
  late Animation<double> _logoScale;
  late Animation<double> _logoBlur;

  // Text animations (delayed after logo)
  late AnimationController _textController;
  late Animation<double> _nameFade;
  late Animation<Offset> _nameSlide;
  late Animation<double> _taglineFade;

  // Progress bar
  late AnimationController _progressController;

  static const Color _brandBrown = Color(0xFF895129);
  static const Color _darkBg = Color(0xFF0A0806);

  @override
  void initState() {
    super.initState();

    // Logo: blur-in + scale + fade over 2s
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: const Interval(0.0, 0.6, curve: Curves.easeIn)),
    );
    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack)),
    );
    _logoBlur = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(parent: _logoController, curve: const Interval(0.0, 0.5, curve: Curves.easeInOut)),
    );

    // Text: slides up + fades, starts after logo is mostly done
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _nameFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );
    _nameSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _textController, curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic)),
    );
    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: const Interval(0.4, 1.0, curve: Curves.easeOut)),
    );

    // Progress bar across the full 3s duration
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    // Sequence: start logo, delay 800ms then start text, start progress immediately
    _logoController.forward();
    _progressController.forward();
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _textController.forward();
    });

    _navigateToNext();
  }

  void _navigateToNext() {
    Timer(const Duration(milliseconds: 3200), () async {
      if (!mounted) return;

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
      await AuthService.tryAutoLogin(context);
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      body: Stack(
        children: [
          // ── Background: deep radial gradient ──
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.4,
                colors: [
                  Color(0xFF1A1008), // warm dark center
                  Color(0xFF080503), // very dark edge
                ],
              ),
            ),
          ),

          // ── Subtle warm glow behind logo ──
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _brandBrown.withValues(alpha: 0.18),
                    _brandBrown.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // ── Logo + Text center stack ──
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated Logo Box
                AnimatedBuilder(
                  animation: _logoController,
                  builder: (context, _) {
                    return ImageFiltered(
                      imageFilter: ImageFilter.blur(
                        sigmaX: _logoBlur.value,
                        sigmaY: _logoBlur.value,
                      ),
                      child: FadeTransition(
                        opacity: _logoFade,
                        child: ScaleTransition(
                          scale: _logoScale,
                          child: Container(
                            width: 140,
                            height: 140,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: [
                                BoxShadow(
                                  color: _brandBrown.withValues(alpha: 0.5),
                                  blurRadius: 60,
                                  spreadRadius: 8,
                                  offset: const Offset(0, 8),
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 30,
                                  offset: const Offset(0, 16),
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/icon/TERGUM_padded.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 32),

                // Animated "Tirgumsra" brand name
                AnimatedBuilder(
                  animation: _textController,
                  builder: (context, _) {
                    return Column(
                      children: [
                        SlideTransition(
                          position: _nameSlide,
                          child: FadeTransition(
                            opacity: _nameFade,
                            child: Text(
                              "Tirgumsra",
                              style: GoogleFonts.inter(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        FadeTransition(
                          opacity: _taglineFade,
                          child: Text(
                            "Translate with confidence.",
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withValues(alpha: 0.45),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // ── Bottom loading progress bar ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedBuilder(
              animation: _progressController,
              builder: (context, _) {
                return LinearProgressIndicator(
                  value: _progressController.value,
                  minHeight: 3,
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _brandBrown.withValues(alpha: 0.8),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

