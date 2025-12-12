import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:calories_app/core/theme/theme.dart';
import 'package:calories_app/shared/state/auth_providers.dart';
import 'package:calories_app/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:calories_app/features/foods/ui/food_admin_page.dart';
import 'package:calories_app/features/exercise/ui/exercise_admin_list_screen.dart';
import 'package:calories_app/features/admin/ui/admin_dashboard_screen.dart';
import 'package:calories_app/features/meal_plans/presentation/pages/admin_discover_meal_plans_page.dart';
import 'package:calories_app/features/home/presentation/pages/personal_info_screen.dart';
import 'package:calories_app/features/home/presentation/pages/goals_screen.dart';
import 'package:calories_app/features/home/presentation/pages/security_screen.dart';
import 'package:calories_app/features/home/presentation/pages/about_app_screen.dart';
import 'package:calories_app/features/home/presentation/pages/help_support_screen.dart';

/// Settings page with clean WAO-style design
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    final profileAsync = user != null
        ? ref.watch(currentProfileProvider(user.uid))
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Cài đặt',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Thông tin cá nhân
          _buildSettingsItem(
            context: context,
            icon: Icons.person_outlined,
            title: 'Thông tin cá nhân',
            onTap: () => _navigateToPersonalInfo(context, ref),
          ),
          const SizedBox(height: 8),

          // Mục tiêu của tôi
          _buildSettingsItem(
            context: context,
            icon: Icons.track_changes_outlined,
            title: 'Mục tiêu của tôi',
            onTap: () => _navigateToGoals(context, ref),
          ),
          const SizedBox(height: 8),

          // Thông báo
          _buildSettingsItem(
            context: context,
            icon: Icons.notifications_outlined,
            title: 'Thông báo',
            onTap: () => _navigateToNotifications(context),
          ),
          const SizedBox(height: 8),

          // Bảo mật
          _buildSettingsItem(
            context: context,
            icon: Icons.lock_outlined,
            title: 'Bảo mật',
            onTap: () => _navigateToSecurity(context),
          ),
          const SizedBox(height: 8),

          // Trợ giúp & Hỗ trợ
          _buildSettingsItem(
            context: context,
            icon: Icons.help_outlined,
            title: 'Trợ giúp & Hỗ trợ',
            onTap: () => _navigateToHelp(context),
          ),
          const SizedBox(height: 8),

          // Về ứng dụng
          _buildSettingsItem(
            context: context,
            icon: Icons.info_outlined,
            title: 'Về ứng dụng',
            onTap: () => _navigateToAbout(context),
          ),
          const SizedBox(height: 8),

          // Admin menu item - only show if user is admin
          if (profileAsync != null)
            profileAsync.when(
              data: (profile) {
                final isAdmin = profile?.isAdmin ?? false;
                if (!isAdmin) {
                  return const SizedBox.shrink();
                }
                return Column(
                  children: [
                    _buildSettingsItem(
                      context: context,
                      icon: Icons.dashboard,
                      title: 'Admin Dashboard',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AdminDashboardScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildSettingsItem(
                      context: context,
                      icon: Icons.restaurant,
                      title: 'Food Admin',
                      onTap: () {
                        Navigator.of(
                          context,
                        ).pushNamed(FoodAdminPage.routeName);
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildSettingsItem(
                      context: context,
                      icon: Icons.fitness_center,
                      title: 'Exercise Admin',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ExerciseAdminListScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildSettingsItem(
                      context: context,
                      icon: Icons.menu_book,
                      title: 'Quản lý thực đơn khám phá',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AdminDiscoverMealPlansPage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

          // Đăng xuất (red)
          _buildSettingsItem(
            context: context,
            icon: Icons.logout,
            title: 'Đăng xuất',
            iconColor: Colors.red,
            titleColor: Colors.red,
            onTap: () => _showLogoutDialog(context, ref),
          ),
        ],
      ),
    );
  }

  /// Build a single settings item with WAO-style design
  Widget _buildSettingsItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    Color? titleColor,
  }) {
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (iconColor ?? AppColors.mintGreen).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor ?? AppColors.mintGreen, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: titleColor ?? Colors.black87,
          ),
        ),
        trailing: Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
        onTap: onTap,
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Đăng xuất'),
          content: const Text('Bạn có chắc chắn muốn đăng xuất?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _handleSignOut(context, ref);
              },
              child: const Text(
                'Đăng xuất',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Central sign-out handler that resets state and clears navigation stack
  Future<void> _handleSignOut(BuildContext context, WidgetRef ref) async {
    try {
      debugPrint('[SettingsPage] 🔵 Starting logout process...');

      // Step 1: Get user ID before signing out (needed for provider invalidation)
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid;

      // Step 2: Invalidate Riverpod providers to clear state (before sign out)
      if (uid != null) {
        debugPrint('[SettingsPage] 🔄 Invalidating providers for uid=$uid');
        ref.invalidate(currentProfileProvider(uid));
        ref.invalidate(currentUserProfileDataProvider(uid));
      }
      // Also invalidate the auth-aware profile provider
      ref.invalidate(currentUserProfileProvider);
      ref.invalidate(onboardingControllerProvider);

      final googleSignIn = GoogleSignIn();

      // Step 3: Disconnect from Google account (removes app's access)
      try {
        await googleSignIn.disconnect();
        debugPrint('[SettingsPage] ✅ Disconnected from Google');
      } catch (e) {
        // Ignore disconnect errors (e.g., if already disconnected or not signed in with Google)
        debugPrint('[SettingsPage] ℹ️ Google disconnect skipped: $e');
      }

      // Step 4: Sign out from Google Sign-In
      try {
        await googleSignIn.signOut();
        debugPrint('[SettingsPage] ✅ Signed out from Google');
      } catch (e) {
        // Ignore signOut errors (e.g., if not signed in with Google)
        debugPrint('[SettingsPage] ℹ️ Google signOut skipped: $e');
      }

      // Step 5: Sign out from Firebase
      await FirebaseAuth.instance.signOut();
      debugPrint('[SettingsPage] ✅ Signed out from Firebase');

      // Step 6: Clear navigation stack and navigate to intro
      if (!context.mounted) {
        return;
      }
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/intro',
        (route) => false, // Remove all previous routes
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đăng xuất thất bại: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToPersonalInfo(BuildContext context, WidgetRef ref) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const PersonalInfoScreen(),
      ),
    );
  }

  void _navigateToGoals(BuildContext context, WidgetRef ref) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const GoalsScreen(),
      ),
    );
  }

  void _navigateToNotifications(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Thông báo')),
          body: const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Thông báo',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tính năng này đang được phát triển.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToSecurity(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SecurityScreen(),
      ),
    );
  }

  void _navigateToHelp(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const HelpSupportScreen(),
      ),
    );
  }

  void _navigateToAbout(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AboutAppScreen(),
      ),
    );
  }
}
