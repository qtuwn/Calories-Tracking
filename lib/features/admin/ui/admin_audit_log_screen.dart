import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:calories_app/core/theme/app_colors.dart';
import 'package:calories_app/shared/state/auth_providers.dart';
import 'package:calories_app/features/admin/data/admin_providers.dart';

/// Admin screen for viewing audit logs
class AdminAuditLogScreen extends ConsumerWidget {
  static const routeName = '/admin-audit-logs';

  const AdminAuditLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.palePink,
        appBar: AppBar(
          backgroundColor: AppColors.palePink,
          title: const Text('Nhật ký hoạt động'),
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
              title: const Text('Nhật ký hoạt động'),
            ),
            body: const Center(
              child: Text('Bạn không có quyền truy cập tính năng này'),
            ),
          );
        }

        return _buildAuditLogViewer(context, ref);
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

  Widget _buildAuditLogViewer(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(auditLogsProvider);

    return Scaffold(
      backgroundColor: AppColors.palePink,
      appBar: AppBar(
        backgroundColor: AppColors.palePink,
        elevation: 0,
        title: const Text(
          'Nhật ký hoạt động',
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
      body: logsAsync.when(
        data: (logs) {
          debugPrint(
            '[AuditLogScreen] 📋 Loaded ${logs.length} audit log entries',
          );

          if (logs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: AppColors.mediumGray),
                  SizedBox(height: 16),
                  Text(
                    'Chưa có hoạt động nào',
                    style: TextStyle(fontSize: 16, color: AppColors.mediumGray),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              return _buildLogCard(log);
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
                'Đang tải nhật ký hoạt động...',
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
                  'Không thể tải nhật ký hoạt động',
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

  Widget _buildLogCard(log) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm:ss');

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Action and timestamp
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getActionColor(log.action).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getActionIcon(log.action),
                    size: 20,
                    color: _getActionColor(log.action),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatAction(log.action),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.nearBlack,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateFormat.format(log.timestamp),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Actor
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  'Admin: ${log.actorId.substring(0, 8)}...',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Target
            Row(
              children: [
                Icon(Icons.adjust, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Target: ${log.target}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),

            // Payload (if exists)
            if (log.payload != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _formatPayload(log.payload!),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getActionColor(String action) {
    if (action.contains('create')) return Colors.green;
    if (action.contains('update') || action.contains('change')) {
      return Colors.orange;
    }
    if (action.contains('delete')) return Colors.red;
    return AppColors.mintGreen;
  }

  IconData _getActionIcon(String action) {
    if (action.contains('create')) return Icons.add_circle;
    if (action.contains('update') || action.contains('change')) {
      return Icons.edit;
    }
    if (action.contains('delete')) return Icons.delete;
    return Icons.bolt;
  }

  String _formatAction(String action) {
    switch (action) {
      case 'create_food':
        return 'Tạo thực phẩm';
      case 'update_food':
        return 'Cập nhật thực phẩm';
      case 'delete_food':
        return 'Xóa thực phẩm';
      case 'create_exercise':
        return 'Tạo bài tập';
      case 'update_exercise':
        return 'Cập nhật bài tập';
      case 'delete_exercise':
        return 'Xóa bài tập';
      case 'change_role':
        return 'Thay đổi quyền';
      default:
        return action;
    }
  }

  String _formatPayload(Map<String, dynamic> payload) {
    final parts = <String>[];
    payload.forEach((key, value) {
      parts.add('$key: $value');
    });
    return parts.join('\n');
  }
}
