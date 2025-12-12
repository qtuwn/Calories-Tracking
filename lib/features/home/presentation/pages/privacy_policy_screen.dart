import 'package:flutter/material.dart';
import 'package:calories_app/features/home/presentation/pages/privacy_policy_content.dart' show kPrivacyPolicyContentVi;

/// Privacy Policy Screen
/// 
/// Displays the privacy policy document in a scrollable view.
/// 
/// Navigation: Accessed from About App screen "Chính sách quyền riêng tư"
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Chính sách quyền riêng tư',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: SelectableText(
            kPrivacyPolicyContentVi,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.6,
                  color: Colors.black87,
                ),
          ),
        ),
      ),
    );
  }
}

