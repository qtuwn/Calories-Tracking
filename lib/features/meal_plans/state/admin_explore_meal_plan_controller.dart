import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calories_app/domain/meal_plans/explore_meal_plan.dart' show ExploreMealPlan, MealSlot;
import 'package:calories_app/domain/meal_plans/user_meal_plan_repository.dart' show MealItem;
import 'package:calories_app/shared/state/explore_meal_plan_providers.dart' as explore_shared;

/// State for admin explore meal plan controller
class AdminExploreMealPlanState {
  final List<ExploreMealPlan> templates;
  final ExploreMealPlan? editingTemplate; // Currently editing template
  final Map<int, List<MealItem>> editingDayMeals; // dayIndex -> meals for editing template
  final bool isLoading;
  final String? errorMessage;

  const AdminExploreMealPlanState({
    this.templates = const [],
    this.editingTemplate,
    this.editingDayMeals = const {},
    this.isLoading = false,
    this.errorMessage,
  });

  AdminExploreMealPlanState copyWith({
    List<ExploreMealPlan>? templates,
    ExploreMealPlan? editingTemplate,
    Map<int, List<MealItem>>? editingDayMeals,
    bool? isLoading,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool clearEditingTemplate = false,
    bool clearEditingDayMeals = false,
  }) {
    return AdminExploreMealPlanState(
      templates: templates ?? this.templates,
      editingTemplate: clearEditingTemplate ? null : (editingTemplate ?? this.editingTemplate),
      editingDayMeals: clearEditingDayMeals ? const {} : (editingDayMeals ?? this.editingDayMeals),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Controller for managing explore meal plan templates (admin operations)
///
/// Responsibilities:
/// - Load all explore templates (including disabled ones) for admin
/// - Create, update, and delete templates
/// - Manage loading and error states
///
/// Dependencies:
/// - ExploreMealPlanService (via shared providers)
class AdminExploreMealPlanController extends Notifier<AdminExploreMealPlanState> {
  StreamSubscription<List<ExploreMealPlan>>? _templatesSubscription;

  @override
  AdminExploreMealPlanState build() {
    // Use shared repository provider for admin operations
    ref.onDispose(() {
      _templatesSubscription?.cancel();
    });

    // Return initial state only - no side effects in build()
    return const AdminExploreMealPlanState();
  }

  /// Load all explore templates (including disabled ones)
  Future<void> loadTemplates() async {
    if (!ref.mounted) return;
    
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      final repository = ref.read(explore_shared.exploreMealPlanRepositoryProvider);

      // Cancel previous subscription if any
      await _templatesSubscription?.cancel();
      
      if (!ref.mounted) return;

      // Subscribe to templates stream (admin version includes disabled)
      _templatesSubscription = repository.watchAllPlans().listen(
        (templates) {
          if (!ref.mounted) return;
          debugPrint('[AdminExploreMealPlanController] 📊 Loaded ${templates.length} templates');
          state = state.copyWith(
            templates: templates,
            isLoading: false,
            clearErrorMessage: true,
          );
        },
        onError: (error, stackTrace) {
          if (!ref.mounted) return;
          debugPrint('[AdminExploreMealPlanController] 🔥 Error loading templates: $error');
          state = state.copyWith(
            isLoading: false,
            errorMessage: 'Failed to load templates: ${error.toString()}',
          );
        },
      );
    } catch (e) {
      if (!ref.mounted) return;
      debugPrint('[AdminExploreMealPlanController] 🔥 Error in loadTemplates: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load templates: ${e.toString()}',
      );
    }
  }

  /// Refresh templates (reload from repository)
  Future<void> refresh() async {
    await loadTemplates();
  }

  /// Load a template by ID for editing
  Future<ExploreMealPlan?> loadTemplateForEditing(String templateId) async {
    if (!ref.mounted) return null;
    
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);
      final service = ref.read(explore_shared.exploreMealPlanServiceProvider);
      final template = await service.loadPlanByIdOnce(templateId);
      
      if (!ref.mounted) return template;
      
      if (template != null) {
        // Initialize editingDayMeals as empty map if not already set
        // This ensures empty templates show empty state, not loading
        final currentEditingMeals = state.editingDayMeals;
        state = state.copyWith(
          editingTemplate: template,
          editingDayMeals: currentEditingMeals.isEmpty ? const {} : currentEditingMeals,
          isLoading: false,
          clearErrorMessage: true,
        );
        debugPrint('[AdminExploreMealPlanController] ✅ Loaded template for editing: $templateId');
      } else {
        state = state.copyWith(
          isLoading: false,
          editingDayMeals: const {}, // Ensure empty map, not null
          errorMessage: 'Template not found',
        );
      }
      
      return template;
    } catch (e) {
      if (!ref.mounted) return null;
      debugPrint('[AdminExploreMealPlanController] 🔥 Error loading template: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load template: ${e.toString()}',
      );
      rethrow;
    }
  }

  /// Load meals for a specific day of the editing template
  Future<void> loadEditingDayMeals(String templateId, int dayIndex) async {
    if (!ref.mounted) return;
    
    try {
      final repository = ref.read(explore_shared.exploreMealPlanRepositoryProvider);
      final mealsStream = repository.getDayMeals(templateId, dayIndex);
      
      // Take first emission to get current meals
      await for (final mealSlots in mealsStream.take(1)) {
        if (!ref.mounted) return;
        
        // Convert MealSlot to MealItem
        final meals = mealSlots.map((slot) {
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
        
        final updatedMeals = Map<int, List<MealItem>>.from(state.editingDayMeals);
        // Always set the day entry, even if empty list (for empty templates)
        updatedMeals[dayIndex] = meals;
        
        state = state.copyWith(
          editingDayMeals: updatedMeals,
          isLoading: false, // Ensure loading is false after loading meals
        );
        debugPrint('[AdminExploreMealPlanController] ✅ Loaded ${meals.length} meals for day $dayIndex');
        break;
      }
    } catch (e) {
      if (!ref.mounted) return;
      debugPrint('[AdminExploreMealPlanController] 🔥 Error loading day meals: $e');
      // Ensure loading is false even on error
      final updatedMeals = Map<int, List<MealItem>>.from(state.editingDayMeals);
      updatedMeals[dayIndex] = []; // Set empty list for failed day
      state = state.copyWith(
        editingDayMeals: updatedMeals,
        isLoading: false,
      );
    }
  }

  /// Create a new template
  Future<String> createTemplate({
    required ExploreMealPlan template,
    String? adminId,
  }) async {
    if (!ref.mounted) throw Exception('Controller disposed');
    
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);
      final service = ref.read(explore_shared.exploreMealPlanServiceProvider);
      final created = await service.createPlan(template);
      
      if (!ref.mounted) return created.id;
      
      debugPrint('[AdminExploreMealPlanController] ✅ Created template: ${created.id}');
      
      // Update editing template with the created plan
      state = state.copyWith(
        editingTemplate: created,
        isLoading: false,
        clearErrorMessage: true,
      );
      
      // Reload templates list
      await loadTemplates();
      
      return created.id;
    } catch (e) {
      if (!ref.mounted) rethrow;
      debugPrint('[AdminExploreMealPlanController] 🔥 Error creating template: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to create template: ${e.toString()}',
      );
      rethrow;
    }
  }

  /// Update an existing template
  Future<void> updateTemplate({
    required ExploreMealPlan template,
    String? adminId,
  }) async {
    if (!ref.mounted) return;
    
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);
      final service = ref.read(explore_shared.exploreMealPlanServiceProvider);
      await service.updatePlan(template);
      
      if (!ref.mounted) return;
      
      debugPrint('[AdminExploreMealPlanController] ✅ Updated template: ${template.id}');
      
      // Update editing template
      state = state.copyWith(
        editingTemplate: template,
        isLoading: false,
        clearErrorMessage: true,
      );
      
      // Reload templates list
      await loadTemplates();
    } catch (e) {
      if (!ref.mounted) return;
      debugPrint('[AdminExploreMealPlanController] 🔥 Error updating template: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to update template: ${e.toString()}',
      );
      rethrow;
    }
  }

  /// Save meals for a specific day of the editing template
  Future<void> saveEditingDayMeals({
    required String templateId,
    required int dayIndex,
    required List<MealItem> mealsToSave,
    required List<String> mealsToDelete,
  }) async {
    if (!ref.mounted) return;
    
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);
      final repository = ref.read(explore_shared.exploreMealPlanRepositoryProvider);
      
      // Convert MealItem to MealSlot
      final mealsToSaveAsSlots = mealsToSave.map((item) => MealSlot(
        id: item.id,
        name: '', // MealItem doesn't have name, use empty or derive from food
        mealType: item.mealType,
        calories: item.calories,
        protein: item.protein,
        carb: item.carb,
        fat: item.fat,
        foodId: item.foodId,
        description: null,
        servingSize: item.servingSize, // Required: copy from MealItem
      )).toList();
      
      await repository.saveDayMeals(
        planId: templateId,
        dayIndex: dayIndex,
        mealsToSave: mealsToSaveAsSlots,
        mealsToDelete: mealsToDelete,
      );
      
      if (!ref.mounted) return;
      
      // Reload meals for this day to get updated state
      await loadEditingDayMeals(templateId, dayIndex);
      
      if (!ref.mounted) return;
      
      state = state.copyWith(
        isLoading: false,
        clearErrorMessage: true,
      );
      debugPrint('[AdminExploreMealPlanController] ✅ Saved meals for day $dayIndex');
    } catch (e) {
      if (!ref.mounted) return;
      debugPrint('[AdminExploreMealPlanController] 🔥 Error saving day meals: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to save meals: ${e.toString()}',
      );
      rethrow;
    }
  }

  /// Clear editing state
  void clearEditing() {
    state = state.copyWith(
      clearEditingTemplate: true,
      clearEditingDayMeals: true,
    );
  }

  /// Delete a template
  Future<void> deleteTemplate(String templateId) async {
    if (!ref.mounted) return;
    
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);
      final service = ref.read(explore_shared.exploreMealPlanServiceProvider);
      await service.deletePlan(templateId);
      
      if (!ref.mounted) return;
      
      debugPrint('[AdminExploreMealPlanController] ✅ Deleted template: $templateId');
      // Templates will auto-update via stream
      state = state.copyWith(isLoading: false, clearErrorMessage: true);
    } catch (e) {
      if (!ref.mounted) return;
      debugPrint('[AdminExploreMealPlanController] 🔥 Error deleting template: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to delete template: ${e.toString()}',
      );
      rethrow; // Re-throw so UI can show error
    }
  }
}

/// Provider for admin explore meal plan controller
final adminExploreMealPlanControllerProvider =
    NotifierProvider.autoDispose<AdminExploreMealPlanController, AdminExploreMealPlanState>(
  AdminExploreMealPlanController.new,
);

