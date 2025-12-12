import 'package:calories_app/features/meal_plans/domain/models/explore/explore_meal_plan_template.dart';
import 'package:calories_app/features/meal_plans/domain/models/explore/explore_meal_day_template.dart';
import 'package:calories_app/features/meal_plans/domain/models/shared/meal_item.dart';
import 'package:calories_app/features/meal_plans/domain/models/shared/goal_type.dart';

/// Repository interface for explore meal plan templates
/// 
/// This is a domain interface - implementations are in the data layer.
/// Domain layer depends on this abstraction, not on Firestore directly.
abstract class ExploreMealPlanRepository {
  /// Get all enabled explore templates
  Stream<List<ExploreMealPlanTemplate>> getAllTemplates();

  /// Get all templates (including disabled) - for admin use
  Stream<List<ExploreMealPlanTemplate>> getAllTemplatesForAdmin();

  /// Get a specific template by ID
  Future<ExploreMealPlanTemplate?> getTemplateById(String templateId);

  /// Get templates filtered by goal type
  Stream<List<ExploreMealPlanTemplate>> getTemplatesByGoal(MealPlanGoalType goal);

  /// Get featured templates
  Stream<List<ExploreMealPlanTemplate>> getFeaturedTemplates();

  /// Get meals for a specific day in a template (stream) - read-only
  /// 
  /// This allows users to preview meals before applying a template.
  Stream<List<MealItem>> getTemplateDayMeals(
    String templateId,
    int dayIndex,
  );
}

/// Repository interface for admin CRUD operations on explore templates
/// 
/// Extends ExploreMealPlanRepository with write operations.
/// Only admins should have access to implementations of this interface.
abstract class AdminExploreMealPlanRepository extends ExploreMealPlanRepository {
  /// Create a new explore template
  /// Returns the created template ID
  Future<String> createTemplate({
    required ExploreMealPlanTemplate template,
    String? adminId,
  });

  /// Update an existing explore template
  Future<void> updateTemplate({
    required ExploreMealPlanTemplate template,
    String? adminId,
  });

  /// Delete an explore template and all its associated days/meals
  Future<void> deleteTemplate(String templateId);

  /// Get all days for a template (stream)
  Stream<List<ExploreMealDayTemplate>> getTemplateDays(String templateId);

  /// Get meals for a specific day in a template (stream)
  @override
  Stream<List<MealItem>> getTemplateDayMeals(
    String templateId,
    int dayIndex,
  );

  /// Save all meals for a day using batch write (for admin editing)
  /// 
  /// [mealsToSave] - List of meals to add or update (empty ID = new meal)
  /// [mealsToDelete] - List of meal IDs to delete
  /// 
  /// Returns true if successful (or queued offline)
  Future<bool> saveTemplateDayMealsBatch({
    required String templateId,
    required int dayIndex,
    required List<MealItem> mealsToSave,
    required List<String> mealsToDelete,
  });
}

