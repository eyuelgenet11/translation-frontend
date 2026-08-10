import 'package:flutter/material.dart';

/// Design System tokens — derived from DESIGN.MD
class DS {
  DS._();

  // Brand
  static const Color primary        = Color(0xFF8D5C3C);
  static const Color primaryHover   = Color(0xFF7A4E33);
  static const Color primaryPressed = Color(0xFF6A422B);

  // Backgrounds
  static const Color background     = Color(0xFFFFFFFF);
  static const Color bgSecondary    = Color(0xFFFAF8F6);
  static const Color card           = Color(0xFFFFFFFF);

  // Border / Divider
  static const Color border         = Color(0xFFECE7E2);
  static const Color divider        = Color(0xFFF2F0ED);

  // Text
  static const Color textPrimary    = Color(0xFF111111);
  static const Color textSecondary  = Color(0xFF6B7280);
  static const Color placeholder    = Color(0xFF9CA3AF);

  // Semantic
  static const Color success        = Color(0xFF16A34A);
  static const Color warning        = Color(0xFFD97706);
  static const Color error          = Color(0xFFDC2626);

  // Radius
  static const double radiusCard    = 24;
  static const double radiusButton  = 18;
  static const double radiusInput   = 16;
  static const double radiusTag     = 999;

  // Sizes
  static const double buttonHeight  = 56;
  static const double inputHeight   = 56;

  // Shadow
  static List<BoxShadow> get shadow => [
    BoxShadow(
      color: const Color(0xFF111111).withValues(alpha: 0.06),
      blurRadius: 24,
      offset: const Offset(0, 6),
    ),
  ];

  // Standard white card decoration
  static BoxDecoration cardDecoration({Color? borderColor}) => BoxDecoration(
    color: card,
    borderRadius: BorderRadius.circular(radiusCard),
    border: Border.all(color: borderColor ?? border),
    boxShadow: shadow,
  );

  // Standard input decoration
  static InputDecoration inputDecoration({
    required String hint,
    String? label,
    Widget? prefix,
    Widget? suffix,
  }) =>
      InputDecoration(
        hintText: hint,
        labelText: label,
        hintStyle: const TextStyle(color: placeholder, fontSize: 14),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
        prefixIcon: prefix,
        suffixIcon: suffix,
        filled: true,
        fillColor: background,
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      );

  // Primary CTA button style
  static ButtonStyle primaryButton({double? height}) => ElevatedButton.styleFrom(
    backgroundColor: primary,
    foregroundColor: Colors.white,
    disabledBackgroundColor: primary.withValues(alpha: 0.4),
    minimumSize: Size(double.infinity, height ?? buttonHeight),
    maximumSize: Size(double.infinity, height ?? buttonHeight),
    elevation: 0,
    shadowColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusButton),
    ),
  );

  // Secondary outlined button style
  static ButtonStyle secondaryButton({double? height}) => OutlinedButton.styleFrom(
    foregroundColor: primary,
    minimumSize: Size(double.infinity, height ?? buttonHeight),
    maximumSize: Size(double.infinity, height ?? buttonHeight),
    side: const BorderSide(color: border),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusButton),
    ),
  );
}

