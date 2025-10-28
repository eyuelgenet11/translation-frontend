import 'package:flutter/material.dart';

class DocumentViewScreen extends StatelessWidget {
  const DocumentViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('View Document')),
      body: const Center(
        child: Text(
          'Here you can preview or download the translated document.',
        ),
      ),
    );
  }
}
