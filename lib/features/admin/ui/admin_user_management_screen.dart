import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:calories_app/core/theme/app_colors.dart';
import 'package:calories_app/shared/state/auth_providers.dart';
import 'package:calories_app/features/admin/data/admin_providers.dart';
import 'package:calories_app/shared/utils/audit_logger.dart';

/// Admin screen for managing user roles
class AdminUserManagementScreen extends ConsumerWidget {
  static const routeName = '/admin-user-management';

  const AdminUserManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.palePink,
        appBar: AppBar(
          backgroundColor: AppColors.palePink,
          title: const Text('Quản lý người dùng'),
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
              title: const Text('Quản lý người dùng'),
            ),
            body: const Center(
              child: Text('Bạn không có quyền truy cập tính năng này'),
            ),
          );
        }

        return _buildUserManagement(context, ref, user.uid);
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

  Widget _buildUserManagement(
    BuildContext context,
    WidgetRef ref,
    String currentAdminUid,
  ) {
    final usersAsync = ref.watch(allUsersProvider);

    return Scaffold(
      backgroundColor: AppColors.palePink,
      appBar: AppBar(
        backgroundColor: AppColors.palePink,
        elevation: 0,
        title: const Text(
          'Quản lý người dùng',
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
      body: usersAsync.when(
        data: (users) {
          if (users.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: AppColors.mediumGray,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Không có người dùng nào',
                    style: TextStyle(fontSize: 16, color: AppColors.mediumGray),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return _buildUserCard(context, ref, user, currentAdminUid);
            },
          );
        },
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.mintGreen),
              SizedBox(height: 16),
              Text(
                'Đang tải người dùng...',
                style: TextStyle(fontSize: 16, color: AppColors.mediumGray),
              ),
            ],
          ),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_off,
                size: 64,
                color: AppColors.mediumGray,
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Không thể tải danh sách người dùng',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.nearBlack,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Vui lòng kiểm tra kết nối mạng.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(
    BuildContext context,
    WidgetRef ref,
    UserProfile user,
    String currentAdminUid,
  ) {
    final isCurrentUser = user.uid == currentAdminUid;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.mintGreen.withValues(alpha: 0.15),
              child: Text(
                _getInitials(user.displayName ?? user.email ?? 'U'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.mintGreen,
                ),
              ),
            ),
            const SizedBox(width: 16),

            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName ?? 'Người dùng',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.nearBlack,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email ?? user.uid,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  _buildRoleBadge(user.role),
                ],
              ),
            ),

            // Action button
            if (!isCurrentUser)
              _buildRoleToggleButton(context, ref, user, currentAdminUid),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    final isAdmin = role == 'admin';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isAdmin
            ? AppColors.mintGreen.withValues(alpha: 0.15)
            : Colors.grey.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isAdmin ? 'Quản trị viên' : 'Người dùng',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isAdmin ? AppColors.mintGreen : Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildRoleToggleButton(
    BuildContext context,
    WidgetRef ref,
    UserProfile user,
    String currentAdminUid,
  ) {
    final isAdmin = user.role == 'admin';

    return ElevatedButton(
      onPressed: () =>
          _showRoleChangeDialog(context, ref, user, currentAdminUid),
      style: ElevatedButton.styleFrom(
        backgroundColor: isAdmin ? AppColors.error : AppColors.mintGreen,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child: Text(
        isAdmin ? 'Gỡ quyền Admin' : 'Gán quyền Admin',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  Future<void> _showRoleChangeDialog(
    BuildContext context,
    WidgetRef ref,
    UserProfile user,
    String currentAdminUid,
  ) async {
    final isAdmin = user.role == 'admin';
    final newRole = isAdmin ? 'user' : 'admin';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận thao tác'),
        content: Text(
          isAdmin
              ? 'Bạn có chắc muốn gỡ quyền Admin của ${user.displayName ?? user.email} không?'
              : 'Bạn có chắc muốn gán quyền Admin cho ${user.displayName ?? user.email} không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Đồng ý',
              style: TextStyle(
                color: isAdmin ? AppColors.error : AppColors.mintGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await _changeUserRole(context, ref, user, newRole, currentAdminUid);
    }
  }

  Future<void> _changeUserRole(
    BuildContext context,
    WidgetRef ref,
    UserProfile user,
    String newRole,
    String currentAdminUid,
  ) async {
    try {
      debugPrint(
        '[AdminUserManagement] 🔄 Changing role for ${user.uid} to $newRole',
      );

      // Update role in Firestore
      final repository = ref.read(adminUserRepositoryProvider);
      await repository.updateUserRole(user.uid, newRole);

      // Log the action
      await auditLogger.logAdminAction(
        currentAdminUid,
        'change_role',
        'user:${user.uid}',
        {'oldRole': user.role, 'newRole': newRole, 'targetEmail': user.email},
      );

      debugPrint(
        '[AdminUserManagement] ✅ Successfully changed role for ${user.uid}',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newRole == 'admin'
                  ? 'Đã gán quyền Admin cho ${user.displayName ?? user.email}'
                  : 'Đã gỡ quyền Admin của ${user.displayName ?? user.email}',
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[AdminUserManagement] 🔥 Error changing role: $e');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Có lỗi xảy ra: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  String _getInitials(String name) {
    final words = name.split(' ');
    if (words.isEmpty) return 'U';
    if (words.length == 1) return words[0][0].toUpperCase();
    return '${words[0][0]}${words[words.length - 1][0]}'.toUpperCase();
  }
}
