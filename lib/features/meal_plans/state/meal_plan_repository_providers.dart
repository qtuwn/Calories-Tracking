import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calories_app/domain/meal_plans/user_meal_plan_repository.dart' show MealItem;
import 'package:calories_app/shared/state/user_meal_plan_providers.dart' as user_meal_plan_providers;
import 'package:calories_app/shared/state/explore_meal_plan_providers.dart' as explore_meal_plan_providers;

/// Provider for meals stream for a specific plan and day
/// 
/// This provider reduces redundant stream creation by centralizing the stream logic.
/// Returns an AsyncValue that handles loading, error, and data states.
/// 
/// IMPORTANT: Empty list [] means "no meals for this day yet", NOT "still loading".
/// The repository returns Stream.value([]) when the day document doesn't exist.
/// 
/// Uses the new DDD architecture service from user_meal_plan_providers.
/// The service exposes getDayMeals which wraps the repository stream.
/// 
/// Uses keepAlive to prevent stream recreation on widget rebuilds.
final userMealPlanMealsProvider = StreamProvider.autoDispose
    .family<List<MealItem>, ({String planId, String userId, int dayIndex})>(
  (ref, args) {
    // Keep provider alive during page lifetime to prevent stream recreation
    ref.keepAlive();
    
    final service = ref.watch(user_meal_plan_providers.userMealPlanServiceProvider);
    return service.getDayMeals(
      args.planId,
      args.userId,
      args.dayIndex,
    );
  },
);

/// Provider for template meals stream (read-only)
/// 
/// Used to preview meals from explore templates before applying them.
/// Returns an AsyncValue that handles loading, error, and data states.
/// 
/// Uses the new DDD architecture repository from explore_meal_plan_providers.
/// Converts MealSlot to MealItem for UI compatibility.
final exploreTemplateMealsProvider = StreamProvider.autoDispose
    .family<List<MealItem>, ({String templateId, int dayIndex})>(
  (ref, args) async* {
    final repository = ref.watch(explore_meal_plan_providers.exploreMealPlanRepositoryProvider);
    await for (final mealSlots in repository.getDayMeals(args.templateId, args.dayIndex)) {
      // Convert MealSlot to MealItem
      yield mealSlots.map((slot) {
        // Validate foodId is non-empty (MealSlot.foodId is nullable but MealItem requires non-null)
        final foodId = slot.foodId?.trim() ?? '';
        if (foodId.isEmpty) {
          throw Exception('MealSlot ${slot.id} has empty foodId - cannot convert to MealItem');
        }
        
        return MealItem(
          id: slot.id,
          mealType: slot.mealType,
          foodId: foodId,
          servingSize: slot.servingSize, // Use servingSize from MealSlot (now required)
          calories: slot.calories,
          protein: slot.protein,
          carb: slot.carb,
          fat: slot.fat,
        );
      }).toList();
    }
  },
);

// Deprecated activeMealPlanProvider removed - use user_meal_plan_providers.activeMealPlanProvider instead

