import 'package:flutter/material.dart';

const Color brandColor = Color(0xFF895129);
const Color backgroundColor = Color(0xFFF9F5F2);

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: brandColor,
        title: Text('Contact', style: TextStyle()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Contact Us',
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
                      leading: Icon(Icons.phone),
                      title: Text("Phone: +251 900 000 000"),
                    ),
                    ListTile(
                      leading: Icon(Icons.email),
                      title: Text("Email: info@example.com"),
                    ),
                    ListTile(
                      leading: Icon(Icons.location_on),
                      title: Text("Address: Addis Ababa, Ethiopia"),
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
