import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final TextEditingController otpController = TextEditingController();

  Future<void> verifyOtp() async {
    // TODO: Replace this with your real backend OTP validation
    if (otpController.text.trim() == '1234') {
      final prefs = await SharedPreferences.getInstance();

      // ⭐ Save verification once so OTP will never appear again
      await prefs.setBool('isVerified', true);

      if (!mounted) return;

      // ⭐ Navigate directly to home and remove all previous routes
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid OTP. Try 1234 for testing.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color brandColor = isDark ? Colors.white : const Color(0xFF1C1917);
    final Color accentColor = const Color(0xFF895129);
    final Color bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Verify OTP', style: GoogleFonts.philosopher(fontWeight: FontWeight.bold, color: brandColor)),
        centerTitle: true,
        backgroundColor: bgColor,
        foregroundColor: brandColor,
        elevation: 0.5,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Enter the 4-digit verification code sent to your device',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(height: 30),

            // ⭐ OTP Input
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '----',
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // ⭐ Verify Button
            ElevatedButton(
              onPressed: verifyOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: brandColor,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Verify',
                style: GoogleFonts.philosopher(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 10),

            // ⭐ Resend OTP
            TextButton(
              onPressed: () {
                // TODO: Add resend OTP logic
              },
              child: Text(
                'Resend Code',
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
