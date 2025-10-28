import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'custom_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController phoneController = TextEditingController();

  String selectedCountryCode = '+251'; // Default Ethiopia 🇪🇹

  final List<Map<String, String>> countryCodes = [
    {'emoji': '🇪🇹', 'code': '+251', 'name': 'Ethiopia'},
    {'emoji': '🇸🇩', 'code': '+249', 'name': 'Sudan'},
    {'emoji': '🇰🇪', 'code': '+254', 'name': 'Kenya'},
    {'emoji': '🇸🇦', 'code': '+966', 'name': 'Saudi Arabia'},
    {'emoji': '🇦🇪', 'code': '+971', 'name': 'UAE'},
    {'emoji': '🇶🇦', 'code': '+974', 'name': 'Qatar'},
    {'emoji': '🇺🇸', 'code': '+1', 'name': 'USA'},
    {'emoji': '🇨🇦', 'code': '+1', 'name': 'Canada'},
    {'emoji': '🇬🇧', 'code': '+44', 'name': 'United Kingdom'},
    {'emoji': '🇸🇪', 'code': '+46', 'name': 'Sweden'},
    {'emoji': '🇩🇪', 'code': '+49', 'name': 'Germany'},
    {'emoji': '🇳🇴', 'code': '+47', 'name': 'Norway'},
    {'emoji': '🇮🇱', 'code': '+972', 'name': 'Israel'},
    {'emoji': '🇰🇼', 'code': '+965', 'name': 'Kuwait'},
    {'emoji': '🇱🇧', 'code': '+961', 'name': 'Lebanon'},
    {'emoji': '🇸🇴', 'code': '+252', 'name': 'Somalia'},
    {'emoji': '🇿🇦', 'code': '+27', 'name': 'South Africa'},
    {'emoji': '🇫🇷', 'code': '+33', 'name': 'France'},
    {'emoji': '🇮🇹', 'code': '+39', 'name': 'Italy'},
    {'emoji': '🇸🇩', 'code': '+249', 'name': 'Sudan'},
  ];

  @override
  Widget build(BuildContext context) {
    const Color brandColor = Color(0xFF895129); // Mesob brand color
    const Color backgroundColor = Color(0xFFF9F5F2); // Light warm beige
    const Color accentColor = Color(0xFFD8B88A); // Gold accent

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo/Icon
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: brandColor.withOpacity(0.1),
                  ),
                  padding: const EdgeInsets.all(22),
                  child: const Icon(
                    Icons.edit_rounded, // Writing hand / pen icon
                    color: brandColor,
                    size: 60,
                  ),
                ),

                const SizedBox(height: 20),

                // Title
                Text(
                  'Geez Script Translation',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: brandColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Bridging languages, preserving heritage',
                  style: GoogleFonts.dancingScript(
                    fontSize: 20,
                    color: accentColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 40),

                // Phone Number with Country Code Dropdown
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFCCC5C1)),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedCountryCode,
                          items: countryCodes.map((country) {
                            return DropdownMenuItem<String>(
                              value: country['code'],
                              child: Text(
                                '${country['emoji']} ${country['code']}',
                                style: const TextStyle(fontSize: 15),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedCountryCode = value!;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Phone number',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Continue Button
                CustomButton(
                  text: 'Continue',
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, '/home'),
                ),

                const SizedBox(height: 18),

                // Divider
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1,
                        color: brandColor.withOpacity(0.3),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'or',
                        style: GoogleFonts.poppins(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: brandColor.withOpacity(0.3),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Register Text
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/register'),
                  child: Text(
                    "Don't have an account? Register",
                    style: GoogleFonts.poppins(
                      color: brandColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Contact Us Section
                Column(
                  children: [
                    Text(
                      "Having trouble logging in?",
                      style: GoogleFonts.poppins(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.phone_in_talk_rounded,
                            color: brandColor, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          '+251 911 22 33 44',
                          style: GoogleFonts.poppins(
                            color: brandColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Small Mesob decorative line
                Container(
                  height: 4,
                  width: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [brandColor, accentColor, brandColor],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
