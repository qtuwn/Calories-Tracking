import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:calories_app/core/theme/app_colors.dart';
import 'package:calories_app/domain/meal_plans/explore_meal_plan.dart';
import 'package:calories_app/features/meal_plans/state/admin_explore_meal_plan_controller.dart';
import 'package:calories_app/features/meal_plans/presentation/pages/explore_meal_plan_admin_editor_page.dart';
import 'package:calories_app/features/admin_explore_meal_plans/presentation/pages/explore_meal_plan_form_page.dart';
import 'package:calories_app/shared/state/auth_providers.dart';

/// Admin-only page for managing public "Discover" meal plans
class AdminDiscoverMealPlansPage extends ConsumerStatefulWidget {
  const AdminDiscoverMealPlansPage({super.key});

  @override
  ConsumerState<AdminDiscoverMealPlansPage> createState() => _AdminDiscoverMealPlansPageState();
}

class _AdminDiscoverMealPlansPageState extends ConsumerState<AdminDiscoverMealPlansPage> {
  @override
  void initState() {
    super.initState();
    // Load templates when widget initializes - use Future.microtask to avoid build-time mutations
    Future.microtask(() {
      if (mounted) {
        ref.read(adminExploreMealPlanControllerProvider.notifier).loadTemplates();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // Guard: user must be signed in
    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.palePink,
        appBar: AppBar(
          backgroundColor: AppColors.palePink,
          title: const Text('Không có quyền truy cập'),
        ),
        body: const Center(child: Text('Vui lòng đăng nhập để tiếp tục')),
      );
    }

    final profileAsync = ref.watch(currentProfileProvider(user.uid));

    return profileAsync.when(
      data: (profile) {
        // Check admin access
        final isAdmin = profile?.isAdmin ?? false;

        debugPrint(
          '[AdminDiscoverMealPlansPage] 🔍 Admin check: uid=${user.uid}, role=${profile?.role}, isAdmin=$isAdmin',
        );

        if (!isAdmin) {
          return Scaffold(
            backgroundColor: AppColors.palePink,
            appBar: AppBar(
              backgroundColor: AppColors.palePink,
              title: const Text('Không có quyền truy cập'),
            ),
            body: const Center(
              child: Text('Bạn không có quyền truy cập tính năng này'),
            ),
          );
        }

        // User is admin, show the admin page
        return _buildAdminPage(context, ref, user.uid);
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) {
        debugPrint('[AdminDiscoverMealPlansPage] 🔥 Error loading profile: $error');
        return Scaffold(
          backgroundColor: AppColors.palePink,
          appBar: AppBar(
            backgroundColor: AppColors.palePink,
            title: const Text('Lỗi'),
          ),
          body: Center(
            child: Text('Không thể tải thông tin: $error'),
          ),
        );
      },
    );
  }

  Widget _buildAdminPage(BuildContext context, WidgetRef ref, String adminId) {
    // Watch controller state
    final controllerState = ref.watch(adminExploreMealPlanControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.palePink,
      appBar: AppBar(
        backgroundColor: AppColors.palePink,
        elevation: 0,
        title: const Text(
          'Quản lý thực đơn khám phá',
          style: TextStyle(
            color: AppColors.nearBlack,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.nearBlack),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildContent(context, ref, controllerState),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Navigate to form first (create mode)
          if (!mounted) return;
          
          final createdPlanId = await Navigator.push<String>(
            context,
            MaterialPageRoute(
              builder: (_) => const ExploreMealPlanFormPage(),
            ),
          );
          
          // After form returns planId, navigate to editor
          if (mounted && createdPlanId != null && createdPlanId.isNotEmpty) {
            if (!context.mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ExploreMealPlanAdminEditorPage(
                  planId: createdPlanId,
                ),
              ),
            ).then((_) {
              // Refresh list after returning from editor
              if (mounted) {
                ref.read(adminExploreMealPlanControllerProvider.notifier).refresh();
              }
            });
          }
        },
        backgroundColor: AppColors.mintGreen,
        foregroundColor: AppColors.nearBlack,
        icon: const Icon(Icons.add),
        label: const Text('Tạo thực đơn khám phá mới'),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    AdminExploreMealPlanState state,
  ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              state.errorMessage!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.mediumGray,
                  ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(adminExploreMealPlanControllerProvider.notifier).refresh();
              },
              child: const Text('Thử lại'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      );
    }

    if (state.templates.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.mintGreen.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.menu_book_outlined,
                  size: 40,
                  color: AppColors.nearBlack,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Chưa có thực đơn nào',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.mediumGray,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: state.templates.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final template = state.templates[index];
        return _PlanCard(
          plan: template,
          onTap: () {
            // Navigate to dedicated admin editor
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ExploreMealPlanAdminEditorPage(
                  planId: template.id,
                ),
              ),
            );
          },
          onEdit: () {
            // Navigate to dedicated admin editor
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ExploreMealPlanAdminEditorPage(
                  planId: template.id,
                ),
              ),
            );
          },
          onDelete: () => _showDeleteDialog(context, ref, template),
        );
      },
    );
  }

  Future<void> _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    ExploreMealPlan plan,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa thực đơn'),
        content: Text(
          'Bạn có chắc muốn xóa thực đơn khám phá này? Người dùng sẽ không còn thấy nó trong mục Khám phá.\n\n'
          'Thực đơn: ${plan.name}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final controller = ref.read(adminExploreMealPlanControllerProvider.notifier);
      await controller.deleteTemplate(plan.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa thực đơn'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('[AdminDiscoverMealPlansPage] Error deleting plan: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể xóa thực đơn: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final ExploreMealPlan plan;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String _getGoalDisplayName(String goalType) {
    switch (goalType) {
      case 'lose_fat':
        return 'Giảm mỡ';
      case 'muscle_gain':
        return 'Tăng cơ';
      case 'vegan':
        return 'Thuần chay';
      case 'maintain':
        return 'Giữ dáng';
      default:
        return goalType;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.name,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.nearBlack,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Mục tiêu: ${_getGoalDisplayName(plan.goalType.value)}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.mediumGray,
                                ),
                          ),
                        ],
                      ),
                    ),
                    if (!plan.isEnabled)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Đã tắt',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.red,
                              ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _InfoPill(
                        icon: Icons.local_fire_department_outlined,
                        label: '${plan.templateKcal} kcal/ngày',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InfoPill(
                        icon: Icons.calendar_month_outlined,
                        label: '${plan.durationDays} ngày',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InfoPill(
                        icon: Icons.restaurant_outlined,
                        label: '${plan.mealsPerDay} bữa/ngày',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.mediumGray),
            onSelected: (value) {
              if (value == 'edit') {
                onEdit();
              } else if (value == 'delete') {
                onDelete();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Sửa thực đơn'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Xóa thực đơn', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.charmingGreen.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.nearBlack),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.nearBlack,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

