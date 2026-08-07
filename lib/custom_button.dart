import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'ds.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const CustomButton({super.key, required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: DS.buttonHeight,
      child: ElevatedButton(
        style: DS.primaryButton(),
        onPressed: onPressed,
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}



