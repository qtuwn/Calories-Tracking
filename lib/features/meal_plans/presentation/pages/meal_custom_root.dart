import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calories_app/core/theme/app_colors.dart';
import 'package:calories_app/domain/meal_plans/user_meal_plan.dart';
import 'package:calories_app/features/meal_plans/state/user_custom_meal_plan_controller.dart';
import 'package:calories_app/features/meal_plans/state/applied_meal_plan_controller.dart';
import 'package:calories_app/features/meal_plans/presentation/pages/meal_custom_editor_page.dart';
import 'package:calories_app/features/meal_plans/presentation/pages/meal_detail_page.dart';
import 'package:calories_app/features/meal_plans/presentation/widgets/meal_plan_summary_card.dart';
import 'package:calories_app/shared/state/auth_providers.dart';
import 'package:calories_app/shared/state/user_meal_plan_providers.dart' as user_meal_plan_providers;

class MealCustomRoot extends ConsumerStatefulWidget {
  const MealCustomRoot({super.key});

  @override
  ConsumerState<MealCustomRoot> createState() => _MealCustomRootState();
}

class _MealCustomRootState extends ConsumerState<MealCustomRoot> {
  @override
  void initState() {
    super.initState();
    // Load plans when widget initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = ref.read(authStateProvider);
      final user = authState.value;
      if (user != null) {
        ref.read(userCustomMealPlanControllerProvider.notifier).loadPlans(user.uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authStateAsync = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: AppColors.palePink,
      body: SafeArea(
        child: authStateAsync.when(
          data: (user) {
            if (user == null) {
              return Center(
                child: Text(
                  'Vui lòng đăng nhập',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              );
            }

            return _buildContent(context, ref, user.uid);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('Lỗi')),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, String userId) {
    // Watch controller state
    final controllerState = ref.watch(userCustomMealPlanControllerProvider);

    return Column(
      children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Text(
                  'Thực đơn tự tạo',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.nearBlack,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _buildPlansList(context, ref, userId, controllerState),
        ),
        // Create button
        Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MealCustomEditorPage(),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Tạo thực đơn mới'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mintGreen,
                foregroundColor: AppColors.nearBlack,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlansList(
    BuildContext context,
    WidgetRef ref,
    String userId,
    UserCustomMealPlanState state,
  ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
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
                  ref.read(userCustomMealPlanControllerProvider.notifier).loadPlans(userId);
                },
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.plans.isEmpty) {
      return _EmptyState(
        onCreateTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const MealCustomEditorPage(),
            ),
          );
        },
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: state.plans.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final plan = state.plans[index];
        return _CustomPlanCard(
          plan: plan,
          userId: userId,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MealDetailPage(
                  planId: plan.id,
                  isTemplate: false,
                  userPlanId: plan.id,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _CustomPlanCard extends ConsumerWidget {
  const _CustomPlanCard({
    required this.plan,
    required this.userId,
    required this.onTap,
  });

  final UserMealPlan plan;
  final String userId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        MealPlanSummaryCard(
          title: plan.name,
          subtitle: 'Mục tiêu: ${_getGoalDisplayName(plan.goalType.value)}',
          goalLabel: _getGoalDisplayName(plan.goalType.value),
          dailyCalories: plan.dailyCalories,
          durationDays: plan.durationDays,
          mealsPerDay: 4, // Default, can be calculated from days if needed
          isActive: plan.isActive,
          currentDayIndex: plan.calculateCurrentDayIndex(),
          tags: [], // User plans don't have tags
          onTap: onTap,
        ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            icon: const Icon(Icons.more_vert, color: AppColors.mediumGray),
            onPressed: () => _showMoreActions(context, ref),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ),
      ],
    );
  }

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

  Future<void> _showMoreActions(BuildContext context, WidgetRef ref) async {
    // Check if this plan is currently active (use provider as source of truth)
    final activePlanAsync = ref.read(user_meal_plan_providers.activeMealPlanProvider);
    final activePlan = activePlanAsync.value;
    final isActive = activePlan?.id == plan.id;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.mediumGray.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: const Text('Xem chi tiết'),
                onTap: () {
                  Navigator.pop(context);
                  onTap();
                },
              ),
              if (!isActive)
                ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: const Text('Áp dụng thực đơn'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _applyPlan(context, ref);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Sửa thực đơn'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MealCustomEditorPage(planId: plan.id),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Xóa thực đơn', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteDialog(context, ref);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// Apply this custom plan as the active meal plan for the current user.
  /// Uses AppliedMealPlanController to set the active plan.
  Future<void> _applyPlan(BuildContext context, WidgetRef ref) async {
    final appliedController = ref.read(appliedMealPlanControllerProvider.notifier);
    
    // Get active plan from provider (source of truth)
    final activePlanAsync = ref.read(user_meal_plan_providers.activeMealPlanProvider);
    final activePlan = activePlanAsync.value;

    try {
      // Show confirmation dialog if there's another active plan
      if (activePlan != null && activePlan.id != plan.id) {
        final shouldProceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Xác nhận thay đổi thực đơn'),
            content: Text(
              'Bạn đang có thực đơn "${activePlan.name}" đang hoạt động.\n\n'
              'Chỉ có thể có một thực đơn hoạt động tại một thời điểm. '
              'Thực đơn hiện tại sẽ bị tắt và thực đơn mới sẽ được kích hoạt.\n\n'
              'Bạn có muốn tiếp tục?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mintGreen,
                  foregroundColor: AppColors.nearBlack,
                ),
                child: const Text('Xác nhận'),
              ),
            ],
          ),
        );

        if (shouldProceed != true) {
          return; // User cancelled
        }
      }

      // Use controller to apply custom plan - use the new public API
      debugPrint('[MealCustomRoot] 🚀 Applying custom plan: ${plan.id}');
      debugPrint('[MealCustomRoot] 🚀 User ID: $userId');
      
      await appliedController.applyCustomPlan(
        planId: plan.id,
        userId: userId,
      );
      
      // Only show success if no exception was thrown
      debugPrint('[MealCustomRoot] ✅ Successfully applied custom plan: ${plan.id}');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã áp dụng thực đơn này'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e, stackTrace) {
      // Error was thrown - show error message
      debugPrint('[MealCustomRoot] 🔥 ========== ERROR applying plan ==========');
      debugPrint('[MealCustomRoot] 🔥 Plan ID: ${plan.id}');
      debugPrint('[MealCustomRoot] 🔥 User ID: $userId');
      debugPrint('[MealCustomRoot] 🔥 Error: $e');
      debugPrint('[MealCustomRoot] 🔥 Stack trace: $stackTrace');
      debugPrint('[MealCustomRoot] 🔥 =========================================');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể áp dụng thực đơn: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _showDeleteDialog(BuildContext context, WidgetRef ref) async {
    // Check if this plan is active (use provider as source of truth)
    final activePlanAsync = ref.read(user_meal_plan_providers.activeMealPlanProvider);
    final activePlan = activePlanAsync.value;
    final isActive = activePlan?.id == plan.id;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa thực đơn'),
        content: Text(
          isActive
              ? 'Thực đơn này đang được kích hoạt. Nếu xóa, bạn sẽ không còn thực đơn nào đang hoạt động.\n\n'
                  'Bạn có chắc chắn muốn xóa thực đơn này? Hành động này không thể hoàn tác.'
              : 'Bạn có chắc chắn muốn xóa thực đơn này? Hành động này không thể hoàn tác.',
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
      final controller = ref.read(userCustomMealPlanControllerProvider.notifier);
      await controller.deletePlan(plan.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa thực đơn'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('[MealCustomRoot] Error deleting plan: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể xóa thực đơn'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.onCreateTap});

  final VoidCallback? onCreateTap;

  @override
  Widget build(BuildContext context) {
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
              'Bắt đầu sáng tạo thực đơn riêng, lưu lại món yêu thích theo khẩu vị của bạn.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.mediumGray,
              ),
            ),
            if (onCreateTap != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onCreateTap,
                icon: const Icon(Icons.add),
                label: const Text('Tạo thực đơn mới'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mintGreen,
                  foregroundColor: AppColors.nearBlack,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


