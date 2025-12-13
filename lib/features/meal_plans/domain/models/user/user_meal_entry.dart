import 'package:calories_app/domain/meal_plans/user_meal_plan_repository.dart' show MealItem;

/// Alias for MealItem in user meal plan context
/// 
/// This is the same as MealItem but provides semantic clarity
/// that this entry belongs to a user's meal plan.
typedef UserMealEntry = MealItem;

