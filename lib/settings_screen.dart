import 'package:flutter/material.dart';
import 'language_selector.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            LanguageSelector(),
            SizedBox(height: 20),
            Text('App version 1.0.0'),
          ],
        ),
      ),
    );
  }
}
