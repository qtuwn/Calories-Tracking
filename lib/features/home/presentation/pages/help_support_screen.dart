import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// TODO: Add url_launcher package to pubspec.yaml to enable mailto: and tel: links
// import 'package:url_launcher/url_launcher.dart';

/// Help & Support Screen
/// 
/// Provides contact information and support resources for users.
/// 
/// Navigation: Accessed from Settings page "Trợ giúp & Hỗ trợ"
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Trợ giúp & Hỗ trợ',
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Contact Support Section
          _buildContactSection(context),
          const SizedBox(height: 8),

          // Guide & Notes Section
          _buildGuideSection(context),
        ],
      ),
    );
  }

  Widget _buildContactSection(BuildContext context) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Text(
              'Liên hệ hỗ trợ',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
            ),
          ),
          _buildContactItem(
            context,
            icon: Icons.email_outlined,
            label: 'Email',
            value: 'tuquoctuan201@gmail.com',
            onTap: () => _handleEmailTap(context),
          ),
          Divider(height: 1, color: Colors.grey[200], indent: 20, endIndent: 20),
          _buildContactItem(
            context,
            icon: Icons.phone_outlined,
            label: 'Điện thoại',
            value: '0969 305 319',
            onTap: () => _handlePhoneTap(context),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildContactItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFAAF0D1).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFFAAF0D1), size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideSection(BuildContext context) {
    return Container(
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hướng dẫn & lưu ý',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Nếu bạn gặp vấn đề về đăng nhập, đồng bộ calo hoặc Google Fit, hãy liên hệ qua email hoặc số điện thoại bên trên để được hỗ trợ.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[700],
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleEmailTap(BuildContext context) async {
    const email = 'tuquoctuan201@gmail.com';
    
    // TODO: Implement mailto: link when url_launcher is added
    // try {
    //   final uri = Uri(scheme: 'mailto', path: email);
    //   if (await canLaunchUrl(uri)) {
    //     await launchUrl(uri);
    //     return;
    //   }
    // } catch (e) {
    //   // Fall through to clipboard fallback
    // }
    
    // Fallback: Copy to clipboard
    await Clipboard.setData(const ClipboardData(text: email));
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã sao chép địa chỉ email vào clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handlePhoneTap(BuildContext context) async {
    const phone = '0969305319';
    
    // TODO: Implement tel: link when url_launcher is added
    // try {
    //   final uri = Uri(scheme: 'tel', path: phone);
    //   if (await canLaunchUrl(uri)) {
    //     await launchUrl(uri);
    //     return;
    //   }
    // } catch (e) {
    //   // Fall through to clipboard fallback
    // }
    
    // Fallback: Copy to clipboard
    await Clipboard.setData(const ClipboardData(text: phone));
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã sao chép số điện thoại vào clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

