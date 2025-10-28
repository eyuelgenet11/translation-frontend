import 'package:flutter/material.dart';

class JobStatusScreen extends StatelessWidget {
  const JobStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final jobs = [
      {'id': '123', 'status': 'Completed'},
      {'id': '124', 'status': 'In Progress'},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Job Status')),
      body: ListView.builder(
        itemCount: jobs.length,
        itemBuilder: (context, index) {
          final job = jobs[index];
          return ListTile(
            title: Text('Job ID: ${job['id']}'),
            subtitle: Text('Status: ${job['status']}'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.pushNamed(context, '/document_view'),
          );
        },
      ),
    );
  }
}
