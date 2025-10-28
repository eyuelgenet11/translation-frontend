import 'package:flutter/material.dart';
import 'custom_text_field.dart';
import 'custom_button.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            CustomTextField(controller: nameController, label: 'Name'),
            const SizedBox(height: 16),
            CustomTextField(controller: emailController, label: 'Email'),
            const SizedBox(height: 16),
            CustomTextField(
              controller: passwordController,
              label: 'Password',
              obscure: true,
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: 'Register',
              onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
            ),
          ],
        ),
      ),
    );
  }
}
