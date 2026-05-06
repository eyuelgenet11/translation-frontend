import 'package:flutter/material.dart';

const Color brandColor = Color(0xFF895129);
const Color backgroundColor = Color(0xFFF9F5F2);

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: brandColor,
        title: Text('Services', style: TextStyle()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Our Services',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: brandColor,
              ),
            ),
            const SizedBox(height: 20),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.translate),
                      title: Text("Document Translation"),
                    ),
                    ListTile(
                      leading: Icon(Icons.chat),
                      title: Text("Live Translation"),
                    ),
                    ListTile(
                      leading: Icon(Icons.language),
                      title: Text("Multilingual Support"),
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
