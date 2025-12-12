// Screen: Read-only detail view for an applied meal plan
// 
// Responsibilities:
// - Display plan information (name, target kcal, duration)
// - Show day tabs (Ngày 1, Ngày 2, ...)
// - Display macros summary (Protein, Carb, Fat) for selected day
// - Stream and display meals for the selected day
// - Show empty state when no meals exist for a day
// - Allow applying a plan (if not already active)
// - Navigate to editor for editing (no inline editing)
//
// This is a READ-ONLY view. For editing meals, navigate to MealDayEditorPage.
// For creating/editing plans, use MealCustomEditorPage.
// IMPORTANT: This page does NOT perform batch save operations directly.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calories_app/core/theme/app_colors.dart';
import 'package:calories_app/domain/meal_plans/user_meal_plan.dart';
import 'package:calories_app/domain/meal_plans/user_meal_plan_repository.dart' show MealItem;
import 'package:calories_app/features/meal_plans/domain/models/shared/meal_type.dart';
import 'package:calories_app/features/meal_plans/domain/models/shared/macros_summary.dart';
import 'package:calories_app/features/meal_plans/domain/services/macros_summary_service.dart';
import 'package:calories_app/features/meal_plans/state/applied_meal_plan_controller.dart';
import 'package:calories_app/shared/state/food_providers.dart' as food_providers;
import 'package:calories_app/shared/state/auth_providers.dart';
import 'package:calories_app/shared/state/explore_meal_plan_providers.dart' as explore_meal_plan_providers;
import 'package:calories_app/shared/state/user_meal_plan_providers.dart' as user_meal_plan_providers;
import 'package:calories_app/features/meal_plans/state/meal_plan_repository_providers.dart' show exploreTemplateMealsProvider;
import 'package:calories_app/features/meal_plans/presentation/pages/meal_day_editor_page.dart';

class MealDetailPage extends ConsumerStatefulWidget {
  const MealDetailPage({
    super.key,
    required this.planId,
    required this.isTemplate,
    this.userPlanId,
  });

  final String planId;
  final bool isTemplate; // true for template, false for user plan
  final String? userPlanId; // Required if isTemplate is false

  @override
  ConsumerState<MealDetailPage> createState() => _MealDetailPageState();
}

class _MealDetailPageState extends ConsumerState<MealDetailPage> {
  int _selectedDayIndex = 1;

  @override
  Widget build(BuildContext context) {
    if (widget.isTemplate) {
      return _buildTemplatePlanDetail();
    } else {
      return _buildUserPlanDetail();
    }
  }

  // Note: Meals are now loaded via userMealPlanMealsProvider to reduce redundant stream creation

  Widget _buildTemplatePlanDetail() {
    // Load template using cache-aware provider
    final templateAsync = ref.watch(explore_meal_plan_providers.exploreMealPlanByIdProvider(widget.planId));

    return Scaffold(
      backgroundColor: AppColors.palePink,
      body: SafeArea(
        child: Column(
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
                      'Chi tiết thực đơn',
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
            // Plan info header
            templateAsync.when(
              data: (template) {
                if (template != null) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
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
                          Text(
                            template.name,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (template.description.isNotEmpty)
                            Text(
                              template.description,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.mediumGray,
                              ),
                            ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _DetailInfoChip(
                                icon: Icons.local_fire_department_outlined,
                                label: '${template.templateKcal} kcal/ngày',
                              ),
                              _DetailInfoChip(
                                icon: Icons.calendar_month_outlined,
                                label: '${template.durationDays} ngày',
                              ),
                              _DetailInfoChip(
                                icon: Icons.restaurant_outlined,
                                label: '${template.mealsPerDay} bữa/ngày',
                              ),
                            ],
                          ),
                          if (template.tags.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: template.tags.map((tag) => Chip(
                                label: Text(tag),
                                backgroundColor: AppColors.mintGreen.withValues(alpha: 0.18),
                                labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.nearBlack,
                                ),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              )).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
            // Day selector
            templateAsync.when(
              data: (template) {
                if (template == null) {
                  return const SizedBox.shrink();
                }
                

                final totalDays = template.durationDays;
                
                // Generate all days from 1 to durationDays (template plans don't show day details)
                return SizedBox(
                  height: 70,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: totalDays,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final dayIndex = index + 1;
                      final isSelected = dayIndex == _selectedDayIndex;
                      final calories = 0.0; // Template plans don't show calories per day
                      
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedDayIndex = dayIndex);
                        },
                        child: Container(
                          width: 80,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.mintGreen : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.mintGreen
                                  : AppColors.charmingGreen,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Ngày $dayIndex',
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? AppColors.nearBlack
                                      : AppColors.mediumGray,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (calories > 0) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '${calories.toInt()} kcal',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontSize: 11,
                                    color: isSelected
                                        ? AppColors.nearBlack
                                        : AppColors.mediumGray,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
            // Show meals for selected day (preview before applying)
            Expanded(
              child: templateAsync.when(
                data: (template) {
                  if (template == null) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  // Watch meals for the selected day
                  final mealsAsync = ref.watch(
                    exploreTemplateMealsProvider(
                      (templateId: widget.planId, dayIndex: _selectedDayIndex),
                    ),
                  );
                  
                  return mealsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, stack) {
                      debugPrint('[MealDetailPage] 🔥 Error loading template meals: $error');
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
                                'Không thể tải bữa ăn mẫu.\n$error',
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
                    data: (meals) {
                      debugPrint('[MealDetailPage] 📊 Loaded ${meals.length} meals for template ${widget.planId}, day $_selectedDayIndex');
                      
                      if (meals.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.restaurant_menu_outlined,
                                  size: 64,
                                  color: AppColors.mediumGray.withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Chưa có bữa ăn cho Ngày $_selectedDayIndex',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: AppColors.mediumGray,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      
                      // Group meals by mealType
                      final mealsByType = <String, List<MealItem>>{};
                      for (final meal in meals) {
                        mealsByType.putIfAbsent(meal.mealType, () => []).add(meal);
                      }
                      
                      // Sort meal types in order: breakfast, lunch, dinner, snack
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
                          
                          // For templates, use empty planId/userId since we can't edit
                          return _MealSection(
                            mealType: mealType,
                            items: mealItems,
                            canEdit: false, // Templates are read-only
                            planId: '', // Not used when canEdit is false
                            userId: '', // Not used when canEdit is false
                            dayIndex: _selectedDayIndex,
                            goalType: template.goalType.value,
                          );
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(child: CircularProgressIndicator()),
              ),
            ),
            // Start plan button (only for templates)
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _startPlan(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mintGreen,
                    foregroundColor: AppColors.nearBlack,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Xem chi tiết & bắt đầu',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserPlanDetail() {
    if (widget.userPlanId == null) {
      return Scaffold(
        backgroundColor: AppColors.palePink,
        body: SafeArea(
          child: Center(
            child: Text(
              'Lỗi: Không tìm thấy thực đơn',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
      );
    }

    final authState = ref.watch(authStateProvider);
    final user = authState.value;
    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.palePink,
        body: SafeArea(
          child: Center(
            child: Text(
              'Vui lòng đăng nhập',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
      );
    }

    // Load user plan info from service (cache-first)
    final service = ref.read(user_meal_plan_providers.userMealPlanServiceProvider);
    final userPlanFuture = service.loadPlanByIdOnce(user.uid, widget.userPlanId!);
    
    // Watch meals stream for current selected day - automatically updates when day changes
    final mealsStream = service.getDayMeals(
      widget.userPlanId!,
      user.uid,
      _selectedDayIndex,
    );
    final mealsAsync = ref.watch(StreamProvider((ref) => mealsStream));

    return Scaffold(
      backgroundColor: AppColors.palePink,
      body: SafeArea(
        child: Column(
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
                      'Chi tiết thực đơn',
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
            // Plan info header
            FutureBuilder<UserMealPlan?>(
              future: userPlanFuture,
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  final userPlan = snapshot.data!;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
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
                          Text(
                            userPlan.name,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _DetailInfoChip(
                                icon: Icons.local_fire_department_outlined,
                                label: '${userPlan.dailyCalories} kcal/ngày',
                              ),
                              _DetailInfoChip(
                                icon: Icons.calendar_month_outlined,
                                label: '${userPlan.durationDays} ngày',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: 16),
            // Day selector
            FutureBuilder<UserMealPlan?>(
              future: userPlanFuture,
              builder: (context, planSnapshot) {
                if (!planSnapshot.hasData || planSnapshot.data == null) {
                  return const SizedBox.shrink();
                }
                
                final userPlan = planSnapshot.data!;
                final totalDays = userPlan.durationDays;
                
                // Calculate calories from meals for selected day only
                // Use AsyncValue to handle loading/error/data states properly
                return mealsAsync.when(
                  loading: () => SizedBox(
                    height: 70,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: totalDays,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final dayIndex = index + 1;
                        final isSelected = dayIndex == _selectedDayIndex;
                        return _DayTab(
                          dayIndex: dayIndex,
                          isSelected: isSelected,
                          calories: null, // Show loading for selected day
                          onTap: () => setState(() => _selectedDayIndex = dayIndex),
                        );
                      },
                    ),
                  ),
                  error: (error, stack) => SizedBox(
                    height: 70,
                    child: Center(
                      child: Text(
                        'Lỗi tải dữ liệu',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ),
                  data: (meals) {
                    // Use domain service to calculate total calories
                    final macros = meals.isEmpty 
                        ? const MacrosSummary.empty()
                        : MacrosSummaryService.sumMacros(meals);
                    final calories = macros.calories;
                    
                    // Generate all days from 1 to durationDays
                    return SizedBox(
                      height: 70,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: totalDays,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final dayIndex = index + 1;
                          final isSelected = dayIndex == _selectedDayIndex;
                          // Only show calories for selected day
                          final dayCalories = isSelected ? calories : 0.0;
                          
                          return _DayTab(
                            dayIndex: dayIndex,
                            isSelected: isSelected,
                            calories: dayCalories > 0 && isSelected ? dayCalories : null,
                            onTap: () => setState(() => _selectedDayIndex = dayIndex),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            // Day macros - calculate from meals using domain service
            // Use AsyncValue.when() to properly handle loading/error/data states
            mealsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Center(
                  child: Text(
                    'Lỗi tải macros',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
              ),
              data: (meals) {
                // Use domain service to calculate macros
                // Empty list returns empty macros (0g for all)
                final macros = MacrosSummaryService.sumMacros(meals);
                
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _MacroBox(
                          label: 'Protein',
                          value: '${macros.protein.toInt()}g',
                          color: const Color(0xFF81C784),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MacroBox(
                          label: 'Carb',
                          value: '${macros.carb.toInt()}g',
                          color: const Color(0xFF64B5F6),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MacroBox(
                          label: 'Fat',
                          value: '${macros.fat.toInt()}g',
                          color: const Color(0xFFF06292),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            // Meals list
            Expanded(
              child: FutureBuilder<UserMealPlan?>(
                future: userPlanFuture,
                builder: (context, planSnapshot) {
                  if (planSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (!planSnapshot.hasData || planSnapshot.data == null) {
                    return const Center(child: Text('Không tìm thấy thực đơn'));
                  }
                  
                  final userPlan = planSnapshot.data!;
                  // Check if this is a custom plan owned by current user
                  final isCustomPlan = userPlan.type == UserMealPlanType.custom;
                  final isOwner = userPlan.userId == user.uid;
                  final canEdit = isCustomPlan && isOwner;
                  
                  // Use AsyncValue.when() to properly handle loading/error/data states
                  // IMPORTANT: Empty list [] means "no meals for this day yet", NOT "still loading"
                  return mealsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => Center(
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
                              'Đã có lỗi xảy ra khi tải bữa ăn.\n$error',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: AppColors.mediumGray,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    data: (meals) {
                      // Empty list means no meals for this day - show empty state
                      // This is NOT a loading state - the stream has emitted an empty list
                      if (meals.isEmpty) {
                        return _EmptyMealsDayView(
                          dayIndex: _selectedDayIndex,
                          canEdit: canEdit,
                          onAddMeal: canEdit
                              ? () => _showAddMealDialog(
                                    context,
                                    ref,
                                    user.uid,
                                    userPlan.goalType.value,
                                  )
                              : null,
                        );
                      }

                      // Group meals by mealType
                      final mealsByType = <String, List<MealItem>>{};
                      for (final meal in meals) {
                        mealsByType.putIfAbsent(meal.mealType, () => []).add(meal);
                      }
                      
                      // Sort meal types in order: breakfast, lunch, dinner, snack
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
                            canEdit: canEdit,
                            planId: widget.userPlanId!,
                            userId: user.uid,
                            dayIndex: _selectedDayIndex,
                            goalType: userPlan.goalType.value,
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            // Apply button for custom user plans
            if (!widget.isTemplate && widget.userPlanId != null)
              FutureBuilder<UserMealPlan?>(
                future: userPlanFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data == null) {
                    return const SizedBox.shrink();
                  }

                  final userPlan = snapshot.data!;
                  final isActive = userPlan.isActive;
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isActive
                            ? null
                            : () => _applyCustomPlan(user.uid, userPlan.name),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.mintGreen,
                          foregroundColor: AppColors.nearBlack,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          isActive ? 'Đang áp dụng' : 'Áp dụng thực đơn',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _startPlan() async {
    debugPrint('[MealDetailPage] 🚀 _startPlan() called for template: ${widget.planId}');
    
    final authState = ref.read(authStateProvider);
    final user = authState.value;
    if (user == null) {
      debugPrint('[MealDetailPage] ⚠️ User not logged in');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đăng nhập để bắt đầu thực đơn'),
        ),
      );
      return;
    }

    debugPrint('[MealDetailPage] ✅ User logged in: ${user.uid}');

    // Get user profile for template application
    final profileAsync = ref.read(currentUserProfileProvider);
    final profile = profileAsync.value;
    if (profile == null) {
      debugPrint('[MealDetailPage] ⚠️ User profile not found');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể tải thông tin người dùng'),
        ),
      );
      return;
    }

    debugPrint('[MealDetailPage] ✅ User profile loaded');

    // Check if user already has an active plan (use provider as source of truth)
    final appliedController = ref.read(appliedMealPlanControllerProvider.notifier);
    final activePlanAsync = ref.read(user_meal_plan_providers.activeMealPlanProvider);
    final activePlan = activePlanAsync.value;

    debugPrint('[MealDetailPage] 📊 Current active plan: ${activePlan?.id ?? "none"}');

    // Show confirmation dialog if there's an active plan
    if (activePlan != null) {
      debugPrint('[MealDetailPage] ⚠️ User has active plan, showing confirmation dialog');
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
        debugPrint('[MealDetailPage] ❌ User cancelled confirmation dialog');
        return; // User cancelled
      }
      
      debugPrint('[MealDetailPage] ✅ User confirmed, proceeding with apply');
    }

    try {
      debugPrint('[MealDetailPage] 📋 Loading template: ${widget.planId}');
      
      // Get template using cache-aware service
      final service = ref.read(explore_meal_plan_providers.exploreMealPlanServiceProvider);
      final template = await service.loadPlanByIdOnce(widget.planId);
      
      if (template == null) {
        debugPrint('[MealDetailPage] 🔥 Template not found: ${widget.planId}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không tìm thấy thực đơn'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      debugPrint('[MealDetailPage] ✅ Template loaded: ${template.name} (${template.id})');
      debugPrint('[MealDetailPage] 📋 Template details: days=${template.durationDays}, kcal=${template.templateKcal}');
      debugPrint('[MealDetailPage] 🚀 Calling appliedController.applyExploreTemplate()...');

      // Apply template using controller - use the new public API
      await appliedController.applyExploreTemplate(
        templateId: template.id,
        profile: profile,
        userId: user.uid,
      );

      debugPrint('[MealDetailPage] ✅ applyExploreTemplate() completed successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã bắt đầu thực đơn thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate back and refresh
        Navigator.pop(context);
      }
    } catch (e, stackTrace) {
      debugPrint('[MealDetailPage] 🔥 Error starting plan: $e');
      debugPrint('[MealDetailPage] 🔥 Stack trace: $stackTrace');
      
      if (mounted) {
        String errorMessage = 'Không thể bắt đầu thực đơn. Vui lòng thử lại sau.';
        
        // Check for permission errors
        if (e.toString().contains('permission-denied')) {
          errorMessage = 'Bạn không có quyền thực hiện thao tác này.';
        } else if (e.toString().contains('failed-precondition')) {
          errorMessage = 'Cần tạo chỉ mục Firestore. Vui lòng liên hệ quản trị viên.';
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

  /// Apply the current custom user plan as the active meal plan.
  /// Uses AppliedMealPlanController to set the active plan.
  Future<void> _applyCustomPlan(String userId, String planName) async {
    if (widget.userPlanId == null) return;

    final appliedController = ref.read(appliedMealPlanControllerProvider.notifier);
    // Get active plan from provider (source of truth)
    final activePlanAsync = ref.read(user_meal_plan_providers.activeMealPlanProvider);
    final activePlan = activePlanAsync.value;

    try {
      // Show confirmation dialog if there's another active plan
      if (activePlan != null && activePlan.id != widget.userPlanId) {
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

      // Apply the custom plan using controller - use the new public API
      debugPrint('[MealDetailPage] 🚀 Applying custom plan: ${widget.userPlanId}');
      debugPrint('[MealDetailPage] 🚀 User ID: $userId');
      
      await appliedController.applyCustomPlan(
        planId: widget.userPlanId!,
        userId: userId,
      );
      
      // Only show success if no exception was thrown
      debugPrint('[MealDetailPage] ✅ Successfully applied custom plan: ${widget.userPlanId}');
      
      if (mounted) {
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
      debugPrint('[MealDetailPage] 🔥 ========== ERROR applying custom plan ==========');
      debugPrint('[MealDetailPage] 🔥 Plan ID: ${widget.userPlanId}');
      debugPrint('[MealDetailPage] 🔥 User ID: $userId');
      debugPrint('[MealDetailPage] 🔥 Error: $e');
      debugPrint('[MealDetailPage] 🔥 Stack trace: $stackTrace');
      debugPrint('[MealDetailPage] 🔥 ================================================');
      
      if (mounted) {
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

  /// Show dialog to add a meal to the current day
  /// For custom plans, this allows users to add meals directly from the detail page
  Future<void> _showAddMealDialog(
    BuildContext context,
    WidgetRef ref,
    String userId,
    String goalType,
  ) async {
    if (widget.userPlanId == null) return;

    debugPrint('[MealDetailPage] 🔵 Showing add meal dialog for day $_selectedDayIndex');

    // Navigate to day editor page for adding meals
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MealDayEditorPage(
          planId: widget.userPlanId!,
          userId: userId,
          dayIndex: _selectedDayIndex,
          goalType: goalType,
        ),
      ),
    );

    // Refresh meals if changes were made
    if (result == true && mounted) {
      debugPrint('[MealDetailPage] ✅ Meals added, stream will refresh automatically');
    }
  }
}

/// Empty state widget for days with no meals
/// 
/// Shows a clear message that no meals exist for this day.
/// Optionally shows an "Add Meal" button if editing is allowed.
class _EmptyMealsDayView extends StatelessWidget {
  const _EmptyMealsDayView({
    required this.dayIndex,
    this.canEdit = false,
    this.onAddMeal,
  });

  final int dayIndex;
  final bool canEdit;
  final VoidCallback? onAddMeal;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_outlined,
              size: 48,
              color: AppColors.mediumGray.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'Chưa có bữa ăn nào cho Ngày $dayIndex',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.mediumGray,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              canEdit
                  ? 'Hãy thêm bữa ở màn chỉnh sửa thực đơn.'
                  : 'Hãy thêm bữa ở màn chỉnh sửa thực đơn.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            if (canEdit && onAddMeal != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onAddMeal,
                icon: const Icon(Icons.add),
                label: const Text('Thêm bữa ăn'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mintGreen,
                  foregroundColor: AppColors.nearBlack,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Day tab widget for the day selector
class _DayTab extends StatelessWidget {
  const _DayTab({
    required this.dayIndex,
    required this.isSelected,
    this.calories,
    required this.onTap,
  });

  final int dayIndex;
  final bool isSelected;
  final double? calories; // null means loading or no data
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.mintGreen : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.mintGreen
                : AppColors.charmingGreen,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Ngày $dayIndex',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? AppColors.nearBlack
                    : AppColors.mediumGray,
              ),
              textAlign: TextAlign.center,
            ),
            if (calories != null && calories! > 0 && isSelected) ...[
              const SizedBox(height: 4),
              Text(
                '${calories!.toInt()} kcal',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: isSelected
                      ? AppColors.nearBlack
                      : AppColors.mediumGray,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailInfoChip extends StatelessWidget {
  const _DetailInfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.charmingGreen.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.nearBlack),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.nearBlack,
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroBox extends StatelessWidget {
  const _MacroBox({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.mediumGray,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.nearBlack,
            ),
          ),
        ],
      ),
    );
  }
}

class _MealSection extends ConsumerWidget {
  const _MealSection({
    required this.mealType,
    required this.items,
    this.canEdit = false,
    this.planId,
    this.userId,
    this.dayIndex,
    this.goalType,
  });

  final String mealType;
  final List<MealItem> items;
  final bool canEdit; // true if this is a custom plan owned by current user
  final String? planId;
  final String? userId;
  final int? dayIndex;
  final String? goalType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealTypeEnum = MealType.fromString(mealType);

    // Helper to get display name
    String getDisplayName(MealType type) {
      switch (type) {
        case MealType.breakfast:
          return 'Bữa sáng';
        case MealType.lunch:
          return 'Bữa trưa';
        case MealType.dinner:
          return 'Bữa tối';
        case MealType.snack:
          return 'Bữa phụ';
      }
    }

    // Helper to get icon
    IconData getIcon(MealType type) {
      switch (type) {
        case MealType.breakfast:
          return Icons.wb_sunny_outlined;
        case MealType.lunch:
          return Icons.restaurant_outlined;
        case MealType.dinner:
          return Icons.dinner_dining_outlined;
        case MealType.snack:
          return Icons.fastfood_outlined;
      }
    }

    // Helper to get color
    Color getColor(MealType type) {
      switch (type) {
        case MealType.breakfast:
          return Colors.orange;
        case MealType.lunch:
          return Colors.blue;
        case MealType.dinner:
          return Colors.purple;
        case MealType.snack:
          return Colors.green;
      }
    }

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
              Icon(getIcon(mealTypeEnum), color: getColor(mealTypeEnum)),
              const SizedBox(width: 8),
              Text(
                getDisplayName(mealTypeEnum),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (canEdit) ...[
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => _showAddMealDialogForType(
                    context,
                    ref,
                    mealTypeEnum,
                  ),
                  tooltip: 'Thêm món ăn',
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty && canEdit)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: TextButton.icon(
                  onPressed: () => _showAddMealDialogForType(
                    context,
                    ref,
                    mealTypeEnum,
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm món ăn'),
                ),
              ),
            )
          else
            ...items.map((item) => _FoodItemRow(
              item: item,
              canEdit: canEdit,
              planId: planId,
              userId: userId,
              dayIndex: dayIndex,
              goalType: goalType,
            )),
        ],
      ),
    );
  }

  Future<void> _showAddMealDialogForType(
    BuildContext context,
    WidgetRef ref,
    MealType mealTypeEnum,
  ) async {
    if (planId == null || userId == null || dayIndex == null || goalType == null) {
      return;
    }

    await _showAddMealDialog(
      context,
      ref,
      userId!,
      goalType!,
    );
  }

  Future<void> _showAddMealDialog(
    BuildContext context,
    WidgetRef ref,
    String userId,
    String goalType,
  ) async {
    if (planId == null || dayIndex == null) return;

    // Navigate to day editor page for adding meals
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MealDayEditorPage(
          planId: planId!,
          userId: userId,
          dayIndex: dayIndex!,
          goalType: goalType,
        ),
      ),
    );

    // Refresh meals if changes were made
    if (result == true && context.mounted) {
      // The stream will automatically update, no need to manually refresh
      debugPrint('[MealDetailPage] ✅ Meals updated, stream will refresh automatically');
    }
  }
}

class _FoodItemRow extends ConsumerWidget {
  const _FoodItemRow({
    required this.item,
    this.canEdit = false,
    this.planId,
    this.userId,
    this.dayIndex,
    this.goalType,
  });

  final MealItem item;
  final bool canEdit; // true if this is a custom plan owned by current user
  final String? planId;
  final String? userId;
  final int? dayIndex;
  final String? goalType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Load food name asynchronously
    final repository = ref.read(food_providers.foodRepositoryProvider);
    final foodFuture = repository.getById(item.foodId);

    return FutureBuilder(
      future: foodFuture,
      builder: (context, snapshot) {
        final foodName = snapshot.hasData && snapshot.data != null
            ? snapshot.data!.name
            : 'Món ăn (ID: ${item.foodId})';

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      foodName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${item.servingSize.toStringAsFixed(1)} phần • ${item.calories.toInt()} kcal • P: ${item.protein.toInt()}g C: ${item.carb.toInt()}g F: ${item.fat.toInt()}g',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.mediumGray,
                      ),
                    ),
                  ],
                ),
              ),
              // Read-only view: no inline edit/delete buttons
              // Users can navigate to editor to make changes
              if (canEdit)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => _editMeal(context, ref),
                  tooltip: 'Sửa (mở màn chỉnh sửa)',
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editMeal(BuildContext context, WidgetRef ref) async {
    if (planId == null || userId == null || dayIndex == null || goalType == null) {
      return;
    }

    // Navigate to day editor page for editing meals
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MealDayEditorPage(
          planId: planId!,
          userId: userId!,
          dayIndex: dayIndex!,
          goalType: goalType!,
        ),
      ),
    );

    // Refresh meals if changes were made
    if (result == true && context.mounted) {
      debugPrint('[MealDetailPage] ✅ Meal edited, stream will refresh automatically');
    }
  }

  // Note: _deleteMeal has been removed - detail page is read-only
  // Users should navigate to MealDayEditorPage to delete meals
}


