import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';

/// The 9-step "How It Works" guide using real app screenshots.
/// Tap the phone screenshot OR the Next button to advance.
void showHowToGuide(BuildContext context, Color textSecTheme) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _HowItWorksSheet(textSecTheme: textSecTheme),
  );
}

class _HowItWorksSheet extends StatefulWidget {
  final Color textSecTheme;
  const _HowItWorksSheet({required this.textSecTheme});

  @override
  State<_HowItWorksSheet> createState() => _HowItWorksSheetState();
}

class _HowItWorksSheetState extends State<_HowItWorksSheet>
    with SingleTickerProviderStateMixin {
  static const _brandBrown = Color(0xFF8D5C3C);

  static const _steps = [
    _Step(
      img: 'assets/sss/Apple iPhone 16 Pro Max Screenshot 2.png',
      title: 'Browse Expert Translators',
      desc:
          'Open the app and explore our marketplace of verified, top-rated professional translators. Filter by category: Legal, Medical, Business, and more.',
      icon: Icons.search_rounded,
    ),
    _Step(
      img: 'assets/sss/Apple iPhone 16 Pro Max Screenshot 3.png',
      title: 'Upload Your Document in Seconds',
      desc:
          'Select your translator, choose source and target language, set urgency, and securely upload your document (JPG, PNG or PDF supported).',
      icon: Icons.upload_file_rounded,
    ),
    _Step(
      img: 'assets/sss/Screenshot 2026-06-11 131347.png',
      title: 'Wait for the Price Quote',
      desc:
          'Your translator analyses the document complexity and word count, then prepares an accurate price quote for you to review.',
      icon: Icons.hourglass_top_rounded,
    ),
    _Step(
      img: 'assets/sss/Screenshot 2026-06-11 131431.png',
      title: 'Review the Price - Decide Wisely',
      desc:
          'You will receive the official quote showing the translation fee and service charge. Accept to proceed or reject. Note: this decision cannot be changed.',
      icon: Icons.request_quote_outlined,
    ),
    _Step(
      img: 'assets/sss/Screenshot 2026-06-11 131334.png',
      title: 'Pay and Attach Your Screenshot',
      desc:
          'Send payment via TeleBirr or CBE to the provided account. Enter the verification code and optionally attach a payment screenshot, then submit.',
      icon: Icons.payments_outlined,
    ),
    _Step(
      img: 'assets/sss/Screenshot 2026-06-11 131402.png',
      title: 'Wait for Payment Verification',
      desc:
          'Our finance team confirms your payment receipt. Verification typically takes 15-30 minutes during business hours.',
      icon: Icons.verified_outlined,
    ),
    _Step(
      img: 'assets/sss/Screenshot 2026-06-11 131420.png',
      title: 'Work in Progress',
      desc:
          'Your project is now in the hands of a professional translator. You will be notified the moment the first draft is ready for review.',
      icon: Icons.edit_note_rounded,
    ),
    _Step(
      img: 'assets/sss/Screenshot 2026-06-11 131454.png',
      title: 'Review Your Document & Accept',
      desc:
          'The translator has uploaded the completed document. Preview it carefully and either accept it or request a revision.',
      icon: Icons.fact_check_outlined,
    ),
    _Step(
      img: 'assets/sss/Screenshot 2026-06-11 131510.png',
      title: 'Rate the Translator & Complete',
      desc:
          'Your translation is accepted and the order is complete! Rate your experience and leave an optional comment to help the community.',
      icon: Icons.star_outline_rounded,
    ),
  ];

  int _current = 0;
  bool _imgVisible = true;
  bool _textVisible = true;

  void _goTo(int index) {
    if (index < 0 || index >= _steps.length) return;
    setState(() {
      _imgVisible = false;
      _textVisible = false;
    });
    Future.delayed(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() {
        _current = index;
        _imgVisible = true;
        _textVisible = true;
      });
    });
  }

  void _next() => _goTo(_current + 1);
  void _prev() => _goTo(_current - 1);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1C1208) : Colors.white;
    final cardBg = isDark ? const Color(0xFF251809) : const Color(0xFFFAF7F4);
    final textMain = isDark ? Colors.white : const Color(0xFF1C1208);
    final step = _steps[_current];
    final isLast = _current == _steps.length - 1;

    return DraggableScrollableSheet(
      initialChildSize: 0.95,
      maxChildSize: 0.97,
      minChildSize: 0.5,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // â”€â”€ handle â”€â”€
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // â”€â”€ Header â”€â”€
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.translate('how_it_works'),
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: textMain,
                        ),
                      ),
                      Text(
                        'Tap the screen or Next to continue',
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.textSecTheme,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Step counter pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _brandBrown.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_current + 1} / ${_steps.length}',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: _brandBrown,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // â”€â”€ Main content (scrollable) â”€â”€
            Expanded(
              child: SingleChildScrollView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // â”€â”€ Screenshot (tappable) â”€â”€
                    GestureDetector(
                      onTap: _next,
                      child: AnimatedOpacity(
                        opacity: _imgVisible ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 220),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: _brandBrown.withValues(alpha: 0.18),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Stack(
                              children: [
                                Image.asset(
                                  step.img,
                                  width: double.infinity,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 320,
                                    color: _brandBrown.withValues(alpha: 0.08),
                                    child: Center(
                                      child: Icon(step.icon,
                                          size: 64, color: _brandBrown),
                                    ),
                                  ),
                                ),
                                // Tap-to-next overlay hint (only on step 1)
                                if (_current == 0)
                                  Positioned(
                                    bottom: 16,
                                    left: 0,
                                    right: 0,
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: const Text(
                                          'Tap to continue ->',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // â”€â”€ Step info card â”€â”€
                    AnimatedOpacity(
                      opacity: _textVisible ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 220),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: _brandBrown.withValues(alpha: 0.12)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: _brandBrown.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${_current + 1}',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                    color: _brandBrown,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    step.title,
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 17,
                                      color: textMain,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    step.desc,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: widget.textSecTheme,
                                      height: 1.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // â”€â”€ Dot indicators â”€â”€
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_steps.length, (i) {
                        final active = i == _current;
                        return GestureDetector(
                          onTap: () => _goTo(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: active ? 22 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: active
                                  ? _brandBrown
                                  : _brandBrown.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 24),

                    // â”€â”€ Prev / Next buttons â”€â”€
                    Row(
                      children: [
                        // Prev
                        Expanded(
                          child: AnimatedOpacity(
                            opacity: _current == 0 ? 0.3 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: OutlinedButton.icon(
                              onPressed: _current == 0 ? null : _prev,
                              icon: const Icon(Icons.arrow_back_rounded,
                                  size: 18),
                              label: const Text('Prev'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _brandBrown,
                                side: const BorderSide(color: _brandBrown),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Next / Done
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: isLast
                                ? () => Navigator.pop(context)
                                : _next,
                            icon: Icon(
                              isLast
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.arrow_forward_rounded,
                              size: 18,
                            ),
                            label: Text(isLast ? 'Done' : 'Next'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _brandBrown,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(50),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step {
  final String img;
  final String title;
  final String desc;
  final IconData icon;

  const _Step({
    required this.img,
    required this.title,
    required this.desc,
    required this.icon,
  });
}


