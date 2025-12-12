import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calories_app/core/theme/app_colors.dart';
import 'package:calories_app/features/meal_plans/presentation/pages/meal_explore_page.dart';
import 'package:calories_app/features/meal_plans/presentation/pages/meal_user_active_page.dart';
import 'package:calories_app/features/meal_plans/presentation/pages/meal_custom_root.dart';

/// Root page for meal plans feature
/// 
/// This page displays three tabs:
/// - "Thực đơn của bạn" (Your Meal Plans) - shows active plan
/// - "Khám phá thực đơn" (Explore Meal Plans) - shows explore templates
/// - "Thực đơn tự tạo" (Custom Meal Plans) - shows user-created plans
class MealsRootPage extends ConsumerStatefulWidget {
  const MealsRootPage({super.key});

  @override
  ConsumerState<MealsRootPage> createState() => _MealsRootPageState();
}

class _MealsRootPageState extends ConsumerState<MealsRootPage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.palePink,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _MealsHeader(
                  onSearchTap: () {
                    // Meal plan search page navigation not yet implemented
                  },
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const TabBar(
                    indicator: BoxDecoration(
                      color: AppColors.mintGreen,
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: AppColors.nearBlack,
                    unselectedLabelColor: AppColors.mediumGray,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                    tabs: [
                      Tab(text: 'Thực đơn của bạn'),
                      Tab(text: 'Khám phá thực đơn'),
                      Tab(text: 'Thực đơn tự tạo'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  physics: const BouncingScrollPhysics(),
                  children: const [
                    MealUserActivePage(),
                    MealExplorePage(),
                    MealCustomRoot(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MealsHeader extends StatelessWidget {
  const _MealsHeader({required this.onSearchTap});

  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    final greeting = _greetingText();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: AppColors.mediumGray),
        ),
        const SizedBox(height: 4),
        Text(
          'Thực đơn hôm nay',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.nearBlack,
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: onSearchTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.mintGreen.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.search, color: AppColors.nearBlack),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Tìm thực đơn theo mục tiêu hoặc món ăn bạn thích...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.mediumGray,
                    ),
                  ),
                ),
                const Icon(Icons.tune, color: AppColors.nearBlack),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _greetingText() {
    final hour = DateTime.now().hour;
    if (hour < 11) {
      return 'Chào buổi sáng';
    }
    if (hour < 17) {
      return 'Buổi chiều năng động';
    }
    return 'Buổi tối thư giãn';
  }
}

