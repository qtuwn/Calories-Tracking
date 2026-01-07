import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Migrated from lib/features/meals to lib/features/meal_plans
import 'package:calories_app/features/meal_plans/presentation/pages/meals_root_page.dart';

class MenuPage extends ConsumerWidget {
  const MenuPage({super.key, this.onNavigateToHome});

  /// Callback to navigate to home screen (index 0)
  final VoidCallback? onNavigateToHome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // MealsRootPage is a wrapper that uses the new meal_plans pages
    // It will be moved to meal_plans module in a future cleanup
    return MealsRootPage(onNavigateToHome: onNavigateToHome);
  }
}
