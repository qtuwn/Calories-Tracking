import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:calories_app/core/theme/app_colors.dart';
import 'package:calories_app/shared/state/auth_providers.dart';
import 'package:calories_app/features/admin/data/admin_providers.dart';
import 'package:calories_app/features/admin/ui/admin_user_management_screen.dart';
import 'package:calories_app/features/admin/ui/admin_audit_log_screen.dart';
import 'package:calories_app/features/foods/ui/food_admin_page.dart';
import 'package:calories_app/features/exercise/ui/exercise_admin_list_screen.dart';

/// Admin dashboard screen showing statistics and navigation to admin features
class AdminDashboardScreen extends ConsumerWidget {
  static const routeName = '/admin-dashboard';

  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;

    // Guard: user must be signed in
    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.palePink,
        appBar: AppBar(
          backgroundColor: AppColors.palePink,
          title: const Text('Admin Dashboard'),
        ),
        body: const Center(child: Text('Vui lòng đăng nhập để tiếp tục')),
      );
    }

    final profileAsync = ref.watch(currentProfileProvider(user.uid));

    return profileAsync.when(
      data: (profile) {
        final isAdmin = profile?.isAdmin ?? false;

        if (!isAdmin) {
          return Scaffold(
            backgroundColor: AppColors.palePink,
            appBar: AppBar(
              backgroundColor: AppColors.palePink,
              title: const Text('Admin Dashboard'),
            ),
            body: const Center(
              child: Text('Bạn không có quyền truy cập tính năng này'),
            ),
          );
        }

        return _buildDashboard(context, ref);
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.palePink,
          title: const Text('Error'),
        ),
        body: Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.palePink,
      appBar: AppBar(
        backgroundColor: AppColors.palePink,
        elevation: 0,
        title: const Text(
          'Bảng điều khiển quản trị',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: AppColors.nearBlack,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.nearBlack),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Statistics section
            const Text(
              'Thống kê hệ thống',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.nearBlack,
              ),
            ),
            const SizedBox(height: 16),
            statsAsync.when(
              data: (stats) => _buildStatsGrid(stats),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.cloud_off,
                        size: 48,
                        color: AppColors.mediumGray,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Không thể tải thống kê',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.nearBlack,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Vui lòng kiểm tra kết nối mạng.',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Management section
            const Text(
              'Quản lý',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.nearBlack,
              ),
            ),
            const SizedBox(height: 16),
            _buildManagementGrid(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(AdminStats stats) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 0.9,
      children: [
        _buildStatCard(
          title: 'Người dùng',
          value: stats.totalUsers.toString(),
          icon: Icons.people,
          color: AppColors.mintGreen,
        ),
        _buildStatCard(
          title: 'Thực phẩm',
          value: stats.totalFoods.toString(),
          icon: Icons.restaurant,
          color: Colors.orange,
        ),
        _buildStatCard(
          title: 'Bài tập',
          value: stats.totalExercises.toString(),
          icon: Icons.fitness_center,
          color: Colors.purple,
        ),
        _buildStatCard(
          title: 'Nhật ký hôm nay',
          value: stats.totalDiaryEntriesToday.toString(),
          icon: Icons.book,
          color: Colors.blue,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
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
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.nearBlack,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildManagementGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.2,
      children: [
        _buildManagementCard(
          context: context,
          title: 'Người dùng',
          icon: Icons.manage_accounts,
          color: AppColors.mintGreen,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AdminUserManagementScreen(),
              ),
            );
          },
        ),
        _buildManagementCard(
          context: context,
          title: 'Thực phẩm',
          icon: Icons.restaurant_menu,
          color: Colors.orange,
          onTap: () {
            Navigator.of(context).pushNamed(FoodAdminPage.routeName);
          },
        ),
        _buildManagementCard(
          context: context,
          title: 'Bài tập',
          icon: Icons.fitness_center,
          color: Colors.purple,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ExerciseAdminListScreen(),
              ),
            );
          },
        ),
        _buildManagementCard(
          context: context,
          title: 'Nhật ký hoạt động',
          icon: Icons.history,
          color: Colors.blue,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminAuditLogScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildManagementCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.nearBlack,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
