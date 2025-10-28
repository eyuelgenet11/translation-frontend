import 'package:flutter/material.dart';

class LanguageSelector extends StatefulWidget {
  const LanguageSelector({super.key});

  @override
  State<LanguageSelector> createState() => _LanguageSelectorState();
}

class _LanguageSelectorState extends State<LanguageSelector> {
  String selectedLanguage = 'English';
  final languages = ['English', 'አማርኛ', 'Afan Oromo'];

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'App Language',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      initialValue: selectedLanguage,
      items: languages.map((lang) {
        return DropdownMenuItem(value: lang, child: Text(lang));
      }).toList(),
      onChanged: (val) => setState(() => selectedLanguage = val!),
    );
  }
}
