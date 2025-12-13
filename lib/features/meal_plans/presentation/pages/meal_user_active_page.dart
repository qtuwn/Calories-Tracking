// Screen: Active meal plan overview
// 
// Responsibilities:
// - Display currently active meal plan summary
// - Show today's macros and meals
// - Navigate to detail page for full plan view
//
// This is a summary/overview screen. For full detail view, see MealDetailPage.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calories_app/core/theme/app_colors.dart';
import 'package:calories_app/domain/meal_plans/user_meal_plan.dart';
import 'package:calories_app/domain/meal_plans/user_meal_plan_repository.dart' show MealItem;
import 'package:calories_app/shared/state/user_meal_plan_providers.dart' as user_meal_plan_providers;
import 'package:calories_app/features/meal_plans/state/meal_plan_repository_providers.dart' show userMealPlanMealsProvider;
import 'package:calories_app/features/meal_plans/presentation/pages/meal_detail_page.dart';
import 'package:calories_app/features/meal_plans/presentation/widgets/meal_plan_summary_card.dart';
import 'package:calories_app/features/meal_plans/domain/models/shared/meal_type.dart';
import 'package:calories_app/features/home/presentation/providers/diary_provider.dart';
import 'package:calories_app/shared/state/food_providers.dart' as food_providers;
import 'package:calories_app/shared/state/auth_providers.dart';

class MealUserActivePage extends ConsumerStatefulWidget {
  const MealUserActivePage({super.key});

  @override
  ConsumerState<MealUserActivePage> createState() => _MealUserActivePageState();
}

class _MealUserActivePageState extends ConsumerState<MealUserActivePage> {
  @override
  Widget build(BuildContext context) {
    // Use activeMealPlanProvider as SINGLE SOURCE OF TRUTH
    // This ensures the UI always reflects the currently active plan from Firestore
    // The provider automatically updates when Firestore changes (e.g., after applying a template)
    // Uses cache-first architecture for instant loading
    final activePlanAsync = ref.watch(user_meal_plan_providers.activeMealPlanProvider);
    final authState = ref.watch(authStateProvider);
    final user = authState.value;

    return Scaffold(
      backgroundColor: AppColors.palePink,
      body: SafeArea(
        child: activePlanAsync.when(
          data: (activePlan) {
            debugPrint('[MealUserActivePage] [ActivePlan] UI received active plan: ${activePlan?.id ?? "none"}, name=${activePlan?.name ?? "N/A"}');
            
            if (activePlan == null || user == null) {
              return _EmptyState(
                message: 'Bạn chưa có thực đơn nào. Hãy khám phá và lưu lại kế hoạch phù hợp!',
                onExploreTap: () {
                  try {
                    final tabController = DefaultTabController.of(context);
                    tabController.animateTo(1);
                  } catch (_) {
                    Navigator.pushNamed(context, '/meals/explore');
                  }
                },
                onCustomTap: () {
                  try {
                    final tabController = DefaultTabController.of(context);
                    tabController.animateTo(2);
                  } catch (_) {
                    Navigator.pushNamed(context, '/meals/custom');
                  }
                },
              );
            }

            // FAIL-FAST: Check if plan has 0 days (invalid state)
            // This should never happen if apply template worked correctly,
            // but we guard against it in the UI to prevent crashes
            if (activePlan.durationDays == 0) {
              debugPrint('[ActivePlan] Active plan has no days → invalid state (planId=${activePlan.id}, name="${activePlan.name}")');
              
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
                        'Meal plan is empty. Please re-apply.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Thực đơn trống. Vui lòng áp dụng lại.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.mediumGray,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Watch meals for the active plan's current day
            // Use ref.watch() to ensure it rebuilds when active plan changes
            final todayIndex = activePlan.calculateCurrentDayIndex();
            final mealsAsync = ref.watch(
              userMealPlanMealsProvider((
                planId: activePlan.id,
                userId: user.uid,
                dayIndex: todayIndex,
              )),
            );

            debugPrint('[MealUserActivePage] [Meals] Streaming meals for active planId=${activePlan.id}, day=$todayIndex');

            return _buildContent(context, ref, activePlan, mealsAsync, user.uid);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) {
            debugPrint('[MealUserActivePage] 🔥 Error loading active plan: $error');
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
                      'Không thể tải thực đơn. Vui lòng thử lại sau.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.mediumGray,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // Invalidate provider to retry
                        ref.invalidate(user_meal_plan_providers.activeMealPlanProvider);
                      },
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    UserMealPlan userPlan,
    AsyncValue<List<MealItem>> mealsAsync,
    String userId,
  ) {
    // userPlan is guaranteed to be non-null (handled in when() callback above)
    final currentDayIndex = userPlan.calculateCurrentDayIndex();

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
                  'Thực đơn của bạn',
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
        // Plan info card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: MealPlanSummaryCard(
            title: userPlan.name,
            subtitle: 'Mục tiêu: ${_getGoalDisplayName(userPlan.goalType.value)}',
            goalLabel: _getGoalDisplayName(userPlan.goalType.value),
            dailyCalories: userPlan.dailyCalories,
            durationDays: userPlan.durationDays,
            mealsPerDay: 4, // Default
            isActive: userPlan.isActive,
            currentDayIndex: currentDayIndex,
            tags: [],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MealDetailPage(
                    planId: userPlan.planTemplateId ?? userPlan.id,
                    isTemplate: userPlan.planTemplateId != null,
                    userPlanId: userPlan.id,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        // Today's meals - use AsyncValue.when() for proper state handling
        Expanded(
          child: mealsAsync.when(
            data: (meals) {
              debugPrint('[MealUserActivePage] [Meals] Loaded ${meals.length} meals for active plan');
              
              if (meals.isEmpty) {
                return Center(
                  child: Text(
                    'Chưa có bữa ăn nào cho hôm nay',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.mediumGray,
                    ),
                  ),
                );
              }

              // Group meals by mealType
              final mealsByType = <String, List<MealItem>>{};
              for (final meal in meals) {
                mealsByType.putIfAbsent(meal.mealType, () => []).add(meal);
              }
              
              // Sort meal types
              final sortedMealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];
              final sortedEntries = mealsByType.entries.toList()
                ..sort((a, b) {
                  final indexA = sortedMealTypes.indexOf(a.key);
                  final indexB = sortedMealTypes.indexOf(b.key);
                  if (indexA == -1 && indexB == -1) return a.key.compareTo(b.key);
                  if (indexA == -1) return 1;
                  if (indexB == -1) return -1;
                  return indexA.compareTo(indexB);
                });

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                itemCount: sortedEntries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final entry = sortedEntries[index];
                  final mealType = entry.key;
                  final mealItems = entry.value;

                  return _MealSection(
                    mealType: mealType,
                    items: mealItems,
                    onToggleDiary: (item, isLogged) {
                      if (isLogged) {
                        _addToDiary(context, ref, item);
                      } else {
                        _addToDiary(context, ref, item);
                      }
                    },
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) {
              debugPrint('[MealUserActivePage] [Meals] 🔥 Error loading meals: $error');
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
                        'Không thể tải bữa ăn. Vui lòng thử lại sau.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.mediumGray,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
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

  Future<void> _addToDiary(
    BuildContext context,
    WidgetRef ref,
    MealItem mealItem,
  ) async {
    try {
      // Get food from repository
      final foodRepository = ref.read(food_providers.foodRepositoryProvider);
      final food = await foodRepository.getById(mealItem.foodId);

      if (food == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không tìm thấy thông tin món ăn'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Get meal type
      final mealType = MealType.values.firstWhere(
        (e) => e.name == mealItem.mealType,
        orElse: () => MealType.breakfast,
      );

      // Add to diary
      final diaryNotifier = ref.read(diaryProvider.notifier);
      await diaryNotifier.addEntryFromFood(
        food: food,
        servingCount: mealItem.servingSize,
        gramsPerServing: 100.0, // Default, can be improved
        mealType: mealType,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã thêm vào nhật ký'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('[MealUserActivePage] 🔥 Error adding to diary: $e');
      debugPrint('[MealUserActivePage] Stack trace: $stackTrace');
      
      if (context.mounted) {
        String errorMessage = 'Không thể thêm vào nhật ký. Vui lòng thử lại sau.';
        if (e.toString().contains('permission-denied')) {
          errorMessage = 'Bạn không có quyền thêm vào nhật ký.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.message,
    this.onExploreTap,
    this.onCustomTap,
  });

  final String message;
  final VoidCallback? onExploreTap;
  final VoidCallback? onCustomTap;

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
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.mediumGray,
              ),
            ),
            if (onExploreTap != null || onCustomTap != null) ...[
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  if (onExploreTap != null)
                    ElevatedButton.icon(
                      onPressed: onExploreTap,
                      icon: const Icon(Icons.explore),
                      label: const Text('Khám phá thực đơn'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.mintGreen,
                        foregroundColor: AppColors.nearBlack,
                      ),
                    ),
                  if (onCustomTap != null)
                    ElevatedButton.icon(
                      onPressed: onCustomTap,
                      icon: const Icon(Icons.add),
                      label: const Text('Tạo thực đơn'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.charmingGreen,
                        foregroundColor: AppColors.nearBlack,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}


class _MealSection extends StatelessWidget {
  const _MealSection({
    required this.mealType,
    required this.items,
    required this.onToggleDiary,
  });

  final String mealType;
  final List<MealItem> items;
  final void Function(MealItem item, bool isLogged) onToggleDiary;

  @override
  Widget build(BuildContext context) {
    final mealTypeEnum = MealType.values.firstWhere(
      (e) => e.name == mealType,
      orElse: () => MealType.breakfast,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(mealTypeEnum.icon, color: mealTypeEnum.color),
              const SizedBox(width: 8),
              Text(
                mealTypeEnum.displayName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) => _FoodItemRow(
                item: item,
                mealType: mealType,
                onToggle: (isLogged) => onToggleDiary(item, isLogged),
              )),
        ],
      ),
    );
  }
}

class _FoodItemRow extends ConsumerStatefulWidget {
  const _FoodItemRow({
    required this.item,
    required this.mealType,
    required this.onToggle,
  });

  final MealItem item;
  final String mealType;
  final ValueChanged<bool> onToggle;

  @override
  ConsumerState<_FoodItemRow> createState() => _FoodItemRowState();
}

class _FoodItemRowState extends ConsumerState<_FoodItemRow> {
  bool _isLogged = false; // Track logged state locally

  @override
  Widget build(BuildContext context) {
    // Load food name using memoized provider (prevents repeated lookups)
    final foodAsync = ref.watch(food_providers.foodByIdProvider(widget.item.foodId));
    
    // Check if item is already in diary for today
    final diaryState = ref.watch(diaryProvider);
    final todayEntries = diaryState.entriesForSelectedDate;
    
    // Check if this food is already logged (simple check by foodId and mealType)
    final isInDiary = todayEntries.any((entry) =>
        entry.foodId == widget.item.foodId &&
        entry.mealType == widget.mealType);
    
    // Update local state if diary state changes
    if (_isLogged != isInDiary) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _isLogged = isInDiary);
        }
      });
    }
    
    return foodAsync.when(
      data: (food) {
        final foodName = food?.name ?? 'Món ăn (ID: ${widget.item.foodId})';
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Checkbox(
                value: _isLogged,
                onChanged: (value) {
                  setState(() => _isLogged = value ?? false);
                  widget.onToggle(_isLogged);
                },
                activeColor: AppColors.mintGreen,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      foodName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration: _isLogged ? TextDecoration.lineThrough : null,
                        color: _isLogged ? AppColors.mediumGray : AppColors.nearBlack,
                      ),
                    ),
                    Text(
                      '${widget.item.servingSize.toStringAsFixed(1)} phần • ${widget.item.calories.toInt()} kcal • P: ${widget.item.protein.toInt()}g C: ${widget.item.carb.toInt()}g F: ${widget.item.fat.toInt()}g',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.mediumGray,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Checkbox(
              value: _isLogged,
              onChanged: (value) {
                setState(() => _isLogged = value ?? false);
                widget.onToggle(_isLogged);
              },
              activeColor: AppColors.mintGreen,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Đang tải...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${widget.item.servingSize.toStringAsFixed(1)} phần • ${widget.item.calories.toInt()} kcal',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.mediumGray,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      error: (error, stack) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Checkbox(
              value: _isLogged,
              onChanged: (value) {
                setState(() => _isLogged = value ?? false);
                widget.onToggle(_isLogged);
              },
              activeColor: AppColors.mintGreen,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Món ăn (ID: ${widget.item.foodId})',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${widget.item.servingSize.toStringAsFixed(1)} phần • ${widget.item.calories.toInt()} kcal',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.mediumGray,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

