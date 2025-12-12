import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calories_app/core/theme/app_colors.dart';
import 'package:calories_app/domain/meal_plans/explore_meal_plan.dart';
import 'package:calories_app/domain/meal_plans/meal_plan_goal_type.dart';
import 'package:calories_app/shared/state/explore_meal_plan_providers.dart' as explore_meal_plan_providers;
import 'package:calories_app/features/meal_plans/presentation/pages/meal_detail_page.dart';
import 'package:calories_app/features/meal_plans/presentation/widgets/meal_plan_summary_card.dart';

class MealExplorePage extends ConsumerStatefulWidget {
  const MealExplorePage({super.key});

  @override
  ConsumerState<MealExplorePage> createState() => _MealExplorePageState();
}

class _MealExplorePageState extends ConsumerState<MealExplorePage> {
  MealPlanGoalType? _selectedGoalFilter;

  @override
  Widget build(BuildContext context) {
    // Watch published meal plans with cache-first architecture
    final allPlansAsync = ref.watch(explore_meal_plan_providers.publishedMealPlansProvider);
    
    // Filter by goal type if selected
    final AsyncValue<List<ExploreMealPlan>> plansAsync = allPlansAsync.when(
      data: (plans) {
        if (_selectedGoalFilter == null) {
          return AsyncValue.data(plans);
        }
        final filtered = plans.where((p) => p.goalType == _selectedGoalFilter).toList();
        return AsyncValue.data(filtered);
      },
      loading: () => const AsyncValue<List<ExploreMealPlan>>.loading(),
      error: (error, stack) => AsyncValue<List<ExploreMealPlan>>.error(error, stack),
    );

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
                      'Khám phá thực đơn',
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
            // Goal filter chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chọn mục tiêu dinh dưỡng',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: 5,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _GoalChip(
                            label: 'Tất cả',
                            isSelected: _selectedGoalFilter == null,
                            onTap: () {
                              setState(() {
                                _selectedGoalFilter = null;
                              });
                            },
                            goalValue: null,
                          );
                        }
                        final goalTypes = [
                          MealPlanGoalType.loseFat,
                          MealPlanGoalType.muscleGain,
                          MealPlanGoalType.vegan,
                          MealPlanGoalType.maintain,
                        ];
                        final goalType = goalTypes[index - 1];
                        return _GoalChip(
                          label: goalType.displayName,
                          isSelected: _selectedGoalFilter == goalType,
                          onTap: () {
                            setState(() {
                              _selectedGoalFilter = goalType;
                            });
                          },
                          goalValue: goalType,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _buildContent(context, plansAsync),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AsyncValue<List<ExploreMealPlan>> plansAsync) {
    return plansAsync.when(
      data: (plans) {
        if (plans.isEmpty) {
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
                    'Chưa có thực đơn nào phù hợp',
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
          itemCount: plans.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final plan = plans[index];
            return MealPlanSummaryCard(
              title: plan.name,
              subtitle: plan.description,
              goalLabel: plan.goalType.displayName,
              dailyCalories: plan.templateKcal,
              durationDays: plan.durationDays,
              mealsPerDay: plan.mealsPerDay,
              tags: plan.tags,
              isActive: false,
              onTap: () {
                // Navigate to detail page
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MealDetailPage(
                      planId: plan.id,
                      isTemplate: true,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Lỗi khi tải danh sách thực đơn',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.mediumGray,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(explore_meal_plan_providers.publishedMealPlansProvider);
                },
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Get color for a goal type chip
Color _getGoalChipColorForGoalType(MealPlanGoalType? goalType, bool isSelected) {
  if (!isSelected) {
    return Colors.white;
  }

  if (goalType == null) {
    return AppColors.mintGreen;
  }

  switch (goalType) {
    case MealPlanGoalType.loseFat:
      return const Color(0xFFFF6B6B); // Red/orange for fat loss
    case MealPlanGoalType.loseWeight:
      return const Color(0xFFFF6B6B); // Red/orange for weight loss
    case MealPlanGoalType.muscleGain:
      return const Color(0xFF4ECDC4); // Teal/blue for muscle gain
    case MealPlanGoalType.vegan:
      return AppColors.charmingGreen; // Green for vegan
    case MealPlanGoalType.maintain:
      return AppColors.palePink; // Soft pastel for maintain
    case MealPlanGoalType.maintainWeight:
      return AppColors.palePink; // Soft pastel for maintain weight
    case MealPlanGoalType.gainWeight:
      return const Color(0xFF4ECDC4); // Teal/blue for weight gain
    case MealPlanGoalType.other:
      return AppColors.mediumGray; // Gray for other
  }
}

/// Get border color for a goal type chip
Color _getGoalChipBorderColorForGoalType(MealPlanGoalType? goalType, bool isSelected) {
  if (!isSelected) {
    return AppColors.charmingGreen.withValues(alpha: 0.4);
  }

  if (goalType == null) {
    return AppColors.mintGreen;
  }

  switch (goalType) {
    case MealPlanGoalType.loseFat:
      return const Color(0xFFFF6B6B);
    case MealPlanGoalType.loseWeight:
      return const Color(0xFFFF6B6B);
    case MealPlanGoalType.muscleGain:
      return const Color(0xFF4ECDC4);
    case MealPlanGoalType.vegan:
      return AppColors.charmingGreen;
    case MealPlanGoalType.maintain:
      return AppColors.palePink;
    case MealPlanGoalType.maintainWeight:
      return AppColors.palePink;
    case MealPlanGoalType.gainWeight:
      return const Color(0xFF4ECDC4);
    case MealPlanGoalType.other:
      return AppColors.mediumGray;
  }
}

class _GoalChip extends StatelessWidget {
  const _GoalChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.goalValue,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final MealPlanGoalType? goalValue; // Goal type enum or null (all)

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _getGoalChipColorForGoalType(goalValue, isSelected);
    final borderColor = _getGoalChipBorderColorForGoalType(goalValue, isSelected);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? backgroundColor.withValues(alpha: 0.9)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: isSelected ? AppColors.nearBlack : AppColors.mediumGray,
            ),
          ),
        ),
      ),
    );
  }
}

