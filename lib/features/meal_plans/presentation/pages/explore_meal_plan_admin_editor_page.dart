// Admin-only editor for Explore meal plan templates
// This is separate from user custom plan editor to follow SOLID principles
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:calories_app/core/theme/app_colors.dart';
import 'package:calories_app/domain/meal_plans/explore_meal_plan.dart';
import 'package:calories_app/domain/meal_plans/user_meal_plan_repository.dart' show MealItem;
import 'package:calories_app/domain/meal_plans/meal_plan_goal_type.dart';
import 'package:calories_app/features/meal_plans/domain/models/shared/meal_type.dart';
import 'package:calories_app/features/meal_plans/state/admin_explore_meal_plan_controller.dart';
import 'package:calories_app/shared/state/explore_meal_plan_providers.dart' as explore_shared;
import 'package:calories_app/shared/state/food_providers.dart' as food_providers;
import 'package:calories_app/domain/meal_plans/services/meal_nutrition_calculator.dart' show MealNutritionCalculator, MealNutritionException;
import 'package:calories_app/domain/foods/food.dart';

/// Admin editor for Explore meal plan templates
/// Uses meal_plans collection (not user_meal_plans)
/// No user-specific kcal validation - templates are generic
class ExploreMealPlanAdminEditorPage extends ConsumerStatefulWidget {
  const ExploreMealPlanAdminEditorPage({
    super.key,
    this.planId, // If provided, edit existing template
  });

  final String? planId;

  @override
  ConsumerState<ExploreMealPlanAdminEditorPage> createState() =>
      _ExploreMealPlanAdminEditorPageState();
}

class _ExploreMealPlanAdminEditorPageState
    extends ConsumerState<ExploreMealPlanAdminEditorPage> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _caloriesController = TextEditingController();
  String _selectedGoalType = 'maintain';
  int? _selectedDurationDays;
  int _currentDayIndex = 1;
  bool _isSaving = false;
  String? _existingPlanId;
  bool? _existingIsPublished;
  bool? _existingIsEnabled;
  DateTime? _existingCreatedAt;
  List<String> _existingTags = [];
  String? _existingDifficulty;
  String? _existingCreatedBy;
  
  // In-memory storage for meals: dayIndex -> list of meals
  final Map<int, List<MealItem>> _mealsByDay = {};
  bool _mealsLoaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.planId != null) {
      // Load template using Future.microtask to avoid build-time mutations
      Future.microtask(() {
        if (mounted) {
          _loadExistingTemplate();
        }
      });
    }
  }

  /// Load existing template
  Future<void> _loadExistingTemplate() async {
    if (widget.planId == null) return;

    try {
      final controller = ref.read(adminExploreMealPlanControllerProvider.notifier);
      final template = await controller.loadTemplateForEditing(widget.planId!);

      if (template != null) {
        _nameController.text = template.name;
        _descriptionController.text = template.description;
        _caloriesController.text = template.templateKcal.toString();
        _selectedGoalType = template.goalType.value;
        _selectedDurationDays = template.durationDays;
        _existingPlanId = widget.planId;
        // Preserve all metadata when updating (don't overwrite form's settings)
        _existingIsPublished = template.isPublished;
        _existingIsEnabled = template.isEnabled;
        _existingCreatedAt = template.createdAt;
        _existingTags = List<String>.from(template.tags); // Preserve tags
        _existingDifficulty = template.difficulty; // Preserve difficulty
        _existingCreatedBy = template.createdBy; // Preserve createdBy
        
        // Load meals from repository
        await _loadMealsFromRepository();
        
        // Ensure mealsLoaded is true even if no meals were found
        if (!_mealsLoaded) {
          _mealsLoaded = true;
          debugPrint('[ExploreMealPlanAdminEditor] 🟢 Template loaded with no meals, showing empty state');
        }
        
        setState(() {});
      } else {
        // Template not found - set loaded to true to show empty state
        _mealsLoaded = true;
        setState(() {});
      }
    } catch (e) {
      debugPrint('[ExploreMealPlanAdminEditor] Error loading template: $e');
    }
  }

  /// Load all meals from repository into local state
  Future<void> _loadMealsFromRepository() async {
    if (widget.planId == null) {
      // For new templates, set loaded state to true immediately (no meals to load)
      _mealsLoaded = true;
      debugPrint('[ExploreMealPlanAdminEditor] 🟢 No meals found, initializing empty editor state');
      return;
    }
    
    try {
      final service = ref.read(explore_shared.exploreMealPlanServiceProvider);
      final template = await service.loadPlanByIdOnce(widget.planId!);
      if (template == null) {
        _mealsLoaded = true;
        return;
      }
      
      _mealsByDay.clear();
      
      // Load meals for each day
      final repository = ref.read(explore_shared.exploreMealPlanRepositoryProvider);
      for (int dayIndex = 1; dayIndex <= template.durationDays; dayIndex++) {
        final mealsStream = repository.getDayMeals(widget.planId!, dayIndex);
        // Take first emission to get current meals
        await for (final mealSlots in mealsStream.take(1)) {
          if (mealSlots.isNotEmpty) {
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
            _mealsByDay[dayIndex] = meals;
          }
          break;
        }
      }
      
      _mealsLoaded = true;
      debugPrint('[ExploreMealPlanAdminEditor] ✅ Loaded ${_mealsByDay.length} days with meals');
    } catch (e) {
      debugPrint('[ExploreMealPlanAdminEditor] Error loading meals: $e');
      _mealsLoaded = true; // Always set loaded to true, even on error, to show empty state
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedDurationDays == null && widget.planId == null) {
      return _buildSetupView();
    }

    return _buildEditorView();
  }

  Widget _buildSetupView() {
    return Scaffold(
      backgroundColor: AppColors.palePink,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.planId == null
              ? 'Tạo thực đơn khám phá mới'
              : 'Chỉnh sửa thực đơn khám phá',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name field
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Tên thực đơn',
                hintText: 'VD: Thực đơn giảm mỡ 7 ngày',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Description field (for templates)
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Mô tả ngắn',
                hintText: 'Mô tả về thực đơn này...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            // Goal type selector
            Text(
              'Mục tiêu',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _GoalChip(
                  label: 'Giảm mỡ',
                  value: 'lose_fat',
                  selected: _selectedGoalType,
                  onTap: () => setState(() => _selectedGoalType = 'lose_fat'),
                ),
                _GoalChip(
                  label: 'Tăng cơ',
                  value: 'muscle_gain',
                  selected: _selectedGoalType,
                  onTap: () => setState(() => _selectedGoalType = 'muscle_gain'),
                ),
                _GoalChip(
                  label: 'Thuần chay',
                  value: 'vegan',
                  selected: _selectedGoalType,
                  onTap: () => setState(() => _selectedGoalType = 'vegan'),
                ),
                _GoalChip(
                  label: 'Giữ dáng',
                  value: 'maintain',
                  selected: _selectedGoalType,
                  onTap: () => setState(() => _selectedGoalType = 'maintain'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Daily calories (no user-specific validation)
            TextField(
              controller: _caloriesController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Calories mỗi ngày',
                hintText: 'VD: 1500',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixText: 'kcal',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Lưu ý: Đây là calories mẫu của template, không phải mục tiêu cá nhân của người dùng',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.mediumGray,
                  ),
            ),
            const SizedBox(height: 20),
            // Duration presets
            Text(
              'Thời gian',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _DurationChip(
                  label: '7 ngày (1 tuần)',
                  days: 7,
                  isSelected: _selectedDurationDays == 7,
                  onTap: () => setState(() => _selectedDurationDays = 7),
                ),
                _DurationChip(
                  label: '14 ngày (2 tuần)',
                  days: 14,
                  isSelected: _selectedDurationDays == 14,
                  onTap: () => setState(() => _selectedDurationDays = 14),
                ),
                _DurationChip(
                  label: '30 ngày (1 tháng)',
                  days: 30,
                  isSelected: _selectedDurationDays == 30,
                  onTap: () => setState(() => _selectedDurationDays = 30),
                ),
                _DurationChip(
                  label: '90 ngày (3 tháng)',
                  days: 90,
                  isSelected: _selectedDurationDays == 90,
                  onTap: () => setState(() => _selectedDurationDays = 90),
                ),
              ],
            ),
            const SizedBox(height: 40),
            // Continue button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canContinue() ? _continueToEditor : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mintGreen,
                  foregroundColor: AppColors.nearBlack,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Tiếp tục',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canContinue() {
    return _nameController.text.trim().isNotEmpty &&
        _caloriesController.text.trim().isNotEmpty &&
        _selectedDurationDays != null;
  }

  void _continueToEditor() {
    if (!_canContinue()) return;
    
    // For new templates, set mealsLoaded to true since there are no meals to load yet
    // This prevents infinite loading spinner
    if (widget.planId == null) {
      _mealsLoaded = true;
      debugPrint('[ExploreMealPlanAdminEditor] 🟢 No meals found, initializing empty editor state');
    }
    
    setState(() {});
  }

  Widget _buildEditorView() {
    final durationDays = _selectedDurationDays ?? 7;
    final days = List.generate(durationDays, (index) => index + 1);

    return Scaffold(
      backgroundColor: AppColors.palePink,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_existingPlanId == null) {
              setState(() => _selectedDurationDays = null);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          _nameController.text.trim().isEmpty
              ? (widget.planId == null ? 'Tạo thực đơn' : 'Sửa thực đơn')
              : _nameController.text.trim(),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveTemplate,
          ),
        ],
      ),
      body: Column(
        children: [
          // Day selector
          Container(
            height: 70,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: days.length,
              itemBuilder: (context, index) {
                final day = days[index];
                final isSelected = day == _currentDayIndex;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () => setState(() => _currentDayIndex = day),
                    child: Container(
                      width: 70,
                      padding: const EdgeInsets.all(12),
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
                        children: [
                          Text(
                            'Ngày $day',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? AppColors.nearBlack
                                      : AppColors.mediumGray,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Meals for current day
          Expanded(
            child: _AdminDayMealsEditor(
              planId: _existingPlanId,
              dayIndex: _currentDayIndex,
              goalType: _selectedGoalType,
              meals: _mealsByDay[_currentDayIndex] ?? [],
              mealsLoaded: _mealsLoaded,
              onPlanCreated: (planId) {
                setState(() {
                  _existingPlanId = planId;
                  // Ensure mealsLoaded is true after plan is created
                  // so the UI can show empty state and allow adding meals
                  _mealsLoaded = true;
                  // Initialize empty meals list for current day if not exists
                  _mealsByDay.putIfAbsent(_currentDayIndex, () => []);
                });
              },
              onMealsChanged: (dayIndex, meals) {
                setState(() {
                  // Always update _mealsByDay when meals change
                  // This ensures we track which days have been edited
                  _mealsByDay[dayIndex] = meals;
                  debugPrint('[ExploreMealPlanAdminEditor] 📝 Updated day $dayIndex: ${meals.length} meals');
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveTemplate() async {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final caloriesStr = _caloriesController.text.trim();

    if (name.isEmpty) {
      _showError('Vui lòng nhập tên thực đơn');
      return;
    }

    if (caloriesStr.isEmpty) {
      _showError('Vui lòng nhập calories mỗi ngày');
      return;
    }

    final calories = int.tryParse(caloriesStr);
    if (calories == null || calories <= 0) {
      _showError('Calories phải là số dương');
      return;
    }

    if (_selectedDurationDays == null) {
      _showError('Vui lòng chọn thời gian');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('Vui lòng đăng nhập');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final controller = ref.read(adminExploreMealPlanControllerProvider.notifier);
      final wasNewTemplate = _existingPlanId == null;
      String currentPlanId;

      // Create domain model
      // When updating existing template, preserve all metadata from loaded template
      // When creating new template, use defaults (form sets these to true)
      final template = ExploreMealPlan(
        id: _existingPlanId ?? '',
        name: name,
        description: description,
        goalType: MealPlanGoalType.fromString(_selectedGoalType),
        templateKcal: calories,
        durationDays: _selectedDurationDays!,
        mealsPerDay: 4, // Default
        tags: _existingTags, // Preserve existing tags (loaded from template)
        isFeatured: false,
        isPublished: _existingIsPublished ?? false, // Preserve existing or default to false for new
        isEnabled: _existingIsEnabled ?? true, // Preserve existing or default to true
        createdAt: _existingCreatedAt ?? DateTime.now(), // Preserve original createdAt when updating
        updatedAt: DateTime.now(), // Always update timestamp
        createdBy: _existingCreatedBy, // Preserve createdBy from existing template
        difficulty: _existingDifficulty, // Preserve difficulty from existing template
      );

        if (wasNewTemplate) {
        // Create new template
        currentPlanId = await controller.createTemplate(
          template: template,
          adminId: user.uid,
        );
        _existingPlanId = currentPlanId;
        // Ensure mealsLoaded is true and initialize empty meals for current day
        _mealsLoaded = true;
        _mealsByDay.putIfAbsent(_currentDayIndex, () => []);
        setState(() {}); // Update UI to enable "Add meal" button
        
        // For new templates, show success message and allow user to add meals
        // Don't validate meals yet - user needs to add them first
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Thực đơn đã được tạo. Vui lòng thêm ít nhất một bữa ăn và lưu lại.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        setState(() => _isSaving = false);
        return; // Exit early - user can now add meals and save again
      } else {
        // Update existing template
        await controller.updateTemplate(
          template: template,
          adminId: user.uid,
        );
        currentPlanId = _existingPlanId!;
      }

      // Validate that at least some meals exist before saving (only for existing templates)
      // Calculate total meals across all days
      final totalMeals = _mealsByDay.values
          .expand((meals) => meals)
          .length;
      
      if (totalMeals == 0) {
        if (mounted) {
          _showError('Vui lòng thêm ít nhất một bữa ăn cho một ngày trước khi lưu');
        }
        setState(() => _isSaving = false);
        return;
      }
      
      // Filter to only days that have meals (non-empty lists)
      final daysWithMeals = _mealsByDay.entries
          .where((entry) => entry.value.isNotEmpty)
          .toList();

      // Save all meals using batch writes via controller
      await _saveAllMealsViaController(currentPlanId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã lưu thực đơn khám phá (${daysWithMeals.length} ngày có bữa ăn)'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e, stackTrace) {
      debugPrint('[ExploreMealPlanAdminEditor] 🔥 Error saving template: $e');
      debugPrint('[ExploreMealPlanAdminEditor] Stack trace: $stackTrace');
      if (mounted) {
        _showError('Không thể lưu thực đơn: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// Save all meals from local state via controller (admin mode)
  Future<void> _saveAllMealsViaController(String planId) async {
    try {
      // Filter to only days that have meals (non-empty lists)
      final daysWithMeals = _mealsByDay.entries
          .where((entry) => entry.value.isNotEmpty)
          .toList();
      
      debugPrint(
        '[ExploreMealPlanAdminEditor] 💾 Batch saving meals for ${daysWithMeals.length} days (${_mealsByDay.length} total days in state)',
      );

      if (daysWithMeals.isEmpty) {
        debugPrint('[ExploreMealPlanAdminEditor] ⚠️ No days with meals to save - returning early without calling repository');
        // Return early - don't call repository if there are no meals
        // Validation should have caught this, but this is a safety check
        return;
      }

      final controller = ref.read(adminExploreMealPlanControllerProvider.notifier);
      final repository = ref.read(explore_shared.exploreMealPlanRepositoryProvider);

      // Save meals for each day that has meals using batch writes
      for (final entry in daysWithMeals) {
        final dayIndex = entry.key;
        final meals = entry.value;

        debugPrint('[ExploreMealPlanAdminEditor] 💾 Saving ${meals.length} meals for day $dayIndex');

        // Get existing meals for this day to determine deletions
        final existingMealSlots = await repository
            .getDayMeals(planId, dayIndex)
            .first;
        final existingMealIds = existingMealSlots.map((m) => m.id).toSet();
        final currentMealIds = meals.where((m) => m.id.isNotEmpty).map((m) => m.id).toSet();
        final mealsToDelete = existingMealIds.difference(currentMealIds).toList();

        await controller.saveEditingDayMeals(
          templateId: planId,
          dayIndex: dayIndex,
          mealsToSave: meals,
          mealsToDelete: mealsToDelete,
        );
      }

      debugPrint('[ExploreMealPlanAdminEditor] ✅ Saved all meals for ${daysWithMeals.length} days');
    } catch (e, stackTrace) {
      debugPrint('[ExploreMealPlanAdminEditor] 🔥 Error saving meals: $e');
      debugPrint('[ExploreMealPlanAdminEditor] Stack trace: $stackTrace');
      rethrow;
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// Helper widgets
class _GoalChip extends StatelessWidget {
  const _GoalChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final String selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.mintGreen : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.mintGreen : AppColors.charmingGreen,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.nearBlack : AppColors.mediumGray,
              ),
        ),
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  const _DurationChip({
    required this.label,
    required this.days,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final int days;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.mintGreen : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.mintGreen : AppColors.charmingGreen,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.nearBlack : AppColors.mediumGray,
              ),
        ),
      ),
    );
  }
}

// Day meals editor for admin (uses correct Firestore paths)
class _AdminDayMealsEditor extends ConsumerStatefulWidget {
  const _AdminDayMealsEditor({
    required this.planId,
    required this.dayIndex,
    required this.goalType,
    required this.meals,
    required this.mealsLoaded,
    required this.onPlanCreated,
    required this.onMealsChanged,
  });

  final String? planId;
  final int dayIndex;
  final String goalType;
  final List<MealItem> meals;
  final bool mealsLoaded;
  final ValueChanged<String> onPlanCreated;
  final void Function(int, List<MealItem>) onMealsChanged;

  @override
  ConsumerState<_AdminDayMealsEditor> createState() =>
      _AdminDayMealsEditorState();
}

class _AdminDayMealsEditorState extends ConsumerState<_AdminDayMealsEditor> {
  @override
  Widget build(BuildContext context) {
    if (widget.planId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, size: 48, color: AppColors.mediumGray),
            const SizedBox(height: 16),
            Text(
              'Vui lòng lưu thực đơn trước khi thêm bữa ăn',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.mediumGray,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (!widget.mealsLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    // Show empty state when no meals exist for this day
    if (widget.meals.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.restaurant_outlined,
                size: 64,
                color: AppColors.mediumGray.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Chưa có bữa ăn nào cho Ngày ${widget.dayIndex}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.nearBlack,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Hãy thêm bữa ăn để tạo thực đơn cho ngày này',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.mediumGray,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => _showAddMealForEmptyDay(context),
                icon: const Icon(Icons.add),
                label: Text('Thêm bữa ăn cho Ngày ${widget.dayIndex}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mintGreen,
                  foregroundColor: AppColors.nearBlack,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Calculate day totals
    final dayTotals = _calculateDayTotals(widget.meals);

    return Column(
      children: [
        // Day nutrition summary (no user-specific validation)
        Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tổng dinh dưỡng ngày ${widget.dayIndex}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _NutritionChip(
                      label: 'Calories',
                      value: '${dayTotals['calories']!.toInt()}',
                      unit: 'kcal',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _NutritionChip(
                      label: 'Protein',
                      value: '${dayTotals['protein']!.toInt()}',
                      unit: 'g',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _NutritionChip(
                      label: 'Carb',
                      value: '${dayTotals['carb']!.toInt()}',
                      unit: 'g',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _NutritionChip(
                      label: 'Fat',
                      value: '${dayTotals['fat']!.toInt()}',
                      unit: 'g',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Meals by type
        Expanded(
          child: _buildMealsList(),
        ),
      ],
    );
  }

  /// Show add meal dialog when clicking the button in empty state
  /// This opens the first meal type (breakfast) dialog
  Future<void> _showAddMealForEmptyDay(BuildContext context) async {
    // planId should be set after template creation
    // If null, show message to save template first
    if (widget.planId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng lưu thông tin thực đơn (tên, mục tiêu, số ngày) trước khi thêm bữa ăn'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    
    // Show the add food dialog for breakfast (first meal type)
    await showDialog(
      context: context,
      builder: (context) => _AdminAddFoodDialog(
        planId: widget.planId!,
        dayIndex: widget.dayIndex,
        mealType: MealType.breakfast,
        goalType: widget.goalType,
        allMeals: widget.meals,
        onMealAdded: (meal) {
          // Add meal to the list
          final newMeals = List<MealItem>.from(widget.meals)..add(meal);
          widget.onMealsChanged(widget.dayIndex, newMeals);
        },
      ),
    );
  }

  Map<String, double> _calculateDayTotals(List<MealItem> meals) {
      // Use domain service for calculations
      try {
        final nutrition = MealNutritionCalculator.sumMeals(
          meals,
          planId: widget.planId, // For admin templates, use planId
          dayIndex: widget.dayIndex,
        );
      return {
        'calories': nutrition.calories,
        'protein': nutrition.protein,
        'carb': nutrition.carb,
        'fat': nutrition.fat,
      };
    } on MealNutritionException catch (e) {
      // Log error but return zeros to prevent UI crash
      debugPrint('[ExploreMealPlanAdminEditorPage] ⚠️ Nutrition calculation error: $e');
      return {
        'calories': 0.0,
        'protein': 0.0,
        'carb': 0.0,
        'fat': 0.0,
      };
    }
  }

  Widget _buildMealsList() {
    final mealsByType = <MealType, List<MealItem>>{};
    for (final meal in widget.meals) {
      final mealType = MealType.fromString(meal.mealType);
      mealsByType.putIfAbsent(mealType, () => []).add(meal);
    }

    final sortedMealTypes = [
      MealType.breakfast,
      MealType.lunch,
      MealType.dinner,
      MealType.snack,
    ];

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: sortedMealTypes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final mealType = sortedMealTypes[index];
        final items = mealsByType[mealType] ?? [];

        return _AdminMealTypeSection(
          planId: widget.planId!,
          dayIndex: widget.dayIndex,
          mealType: mealType,
          items: items,
          goalType: widget.goalType,
          allMeals: widget.meals,
          onMealsChanged: (newMeals) {
            widget.onMealsChanged(widget.dayIndex, newMeals);
          },
        );
      },
    );
  }
}

class _AdminMealTypeSection extends ConsumerStatefulWidget {
  const _AdminMealTypeSection({
    required this.planId,
    required this.dayIndex,
    required this.mealType,
    required this.items,
    required this.goalType,
    required this.allMeals,
    required this.onMealsChanged,
  });

  final String planId;
  final int dayIndex;
  final MealType mealType;
  final List<MealItem> items;
  final String goalType;
  final List<MealItem> allMeals;
  final ValueChanged<List<MealItem>> onMealsChanged;

  @override
  ConsumerState<_AdminMealTypeSection> createState() =>
      _AdminMealTypeSectionState();
}

class _AdminMealTypeSectionState
    extends ConsumerState<_AdminMealTypeSection> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(widget.mealType.icon, color: widget.mealType.color),
              const SizedBox(width: 8),
              Text(
                widget.mealType.displayName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => _showAddFoodDialog(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Chưa có món ăn nào',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.mediumGray,
                    ),
              ),
            )
          else
            ...widget.items.map((item) => _AdminMealItemTile(
                  planId: widget.planId,
                  dayIndex: widget.dayIndex,
                  item: item,
                  allMeals: widget.allMeals,
                  onMealsChanged: widget.onMealsChanged,
                )),
        ],
      ),
    );
  }

  Future<void> _showAddFoodDialog() async {
    await showDialog(
      context: context,
      builder: (context) => _AdminAddFoodDialog(
        planId: widget.planId,
        dayIndex: widget.dayIndex,
        mealType: widget.mealType,
        goalType: widget.goalType,
        allMeals: widget.allMeals,
        onMealAdded: (meal) {
          final newMeals = List<MealItem>.from(widget.allMeals)..add(meal);
          widget.onMealsChanged(newMeals);
        },
      ),
    );
  }
}

class _AdminMealItemTile extends ConsumerWidget {
  const _AdminMealItemTile({
    required this.planId,
    required this.dayIndex,
    required this.item,
    required this.allMeals,
    required this.onMealsChanged,
  });

  final String planId;
  final int dayIndex;
  final MealItem item;
  final List<MealItem> allMeals;
  final ValueChanged<List<MealItem>> onMealsChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(food_providers.foodRepositoryProvider);
    final foodFuture = repository.getById(item.foodId);

    return FutureBuilder<Food?>(
      future: foodFuture,
      builder: (context, snapshot) {
        final foodName = snapshot.hasData && snapshot.data != null
            ? snapshot.data!.name
            : 'Món ăn (ID: ${item.foodId})';

        return ListTile(
          title: Text(
            foodName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${item.servingSize.toStringAsFixed(1)} phần • '
            '${item.calories.toInt()} kcal • '
            'P: ${item.protein.toInt()}g C: ${item.carb.toInt()}g F: ${item.fat.toInt()}g',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () => _editItem(context, ref),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                onPressed: () => _deleteItem(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editItem(BuildContext context, WidgetRef ref) async {
    await showDialog(
      context: context,
      builder: (context) => _AdminEditFoodDialog(
        planId: planId,
        dayIndex: dayIndex,
        item: item,
        allMeals: allMeals,
        onMealUpdated: (updatedMeal) {
          final newMeals = allMeals.map((m) => m.id == item.id ? updatedMeal : m).toList();
          onMealsChanged(newMeals);
        },
      ),
    );
  }

  void _deleteItem(BuildContext context) {
    final newMeals = allMeals.where((m) => m.id != item.id).toList();
    onMealsChanged(newMeals);
  }
}

// Add food dialog for admin (uses correct Firestore paths)
class _AdminAddFoodDialog extends ConsumerStatefulWidget {
  const _AdminAddFoodDialog({
    required this.planId,
    required this.dayIndex,
    required this.mealType,
    required this.goalType,
    required this.allMeals,
    required this.onMealAdded,
  });

  final String planId;
  final int dayIndex;
  final MealType mealType;
  final String goalType;
  final List<MealItem> allMeals;
  final ValueChanged<MealItem> onMealAdded;

  @override
  ConsumerState<_AdminAddFoodDialog> createState() =>
      _AdminAddFoodDialogState();
}

class _AdminAddFoodDialogState extends ConsumerState<_AdminAddFoodDialog> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = _searchController.text;
    final foodsAsync = searchQuery.isEmpty
        ? ref.watch(foodSearchProvider(''))
        : ref.watch(foodSearchByGoalProvider((query: searchQuery, goalType: widget.goalType)));

    return Dialog(
      child: Container(
        width: double.maxFinite,
        height: 600,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Thêm món ăn - ${widget.mealType.displayName}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Tìm món ăn',
                hintText: 'Nhập tên món ăn...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: foodsAsync.when(
                data: (foods) {
                  if (foods.isEmpty) {
                    return Center(
                      child: Text(
                        searchQuery.isEmpty
                            ? 'Nhập tên món ăn để tìm kiếm'
                            : 'Không tìm thấy món ăn',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.mediumGray,
                            ),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: foods.length,
                    itemBuilder: (context, index) {
                      final food = foods[index];
                      return ListTile(
                        title: Text(food.name),
                        subtitle: Text(
                          '${food.caloriesPer100g.toStringAsFixed(0)} kcal/100g • '
                          'P: ${food.proteinPer100g.toStringAsFixed(1)}g '
                          'C: ${food.carbsPer100g.toStringAsFixed(1)}g '
                          'F: ${food.fatPer100g.toStringAsFixed(1)}g',
                        ),
                        onTap: () => _selectFood(food),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) {
                  debugPrint('[AdminAddFoodDialog] Error: $error');
                  return Center(child: Text('Lỗi: $error'));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectFood(Food food) async {
    final servingSize = await showDialog<double>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: '1.0');
        return AlertDialog(
          title: Text('Khẩu phần - ${food.name}'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Số phần',
              hintText: 'VD: 1.5',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () {
                final value = double.tryParse(controller.text);
                Navigator.pop(context, value ?? 1.0);
              },
              child: const Text('Thêm'),
            ),
          ],
        );
      },
    );

    if (servingSize == null) return;

    try {
      // Calculate nutrition
      final gramsPerServing = food.defaultPortionGram;
      final totalGrams = gramsPerServing * servingSize;
      final multiplier = totalGrams / 100.0;

      final calories = food.caloriesPer100g * multiplier;
      final protein = food.proteinPer100g * multiplier;
      final carb = food.carbsPer100g * multiplier;
      final fat = food.fatPer100g * multiplier;

      // Create meal item for validation
      final mealItem = MealItem(
        id: '', // Will be auto-generated when saving to Firestore
        mealType: widget.mealType.value,
        foodId: food.id,
        servingSize: servingSize,
        calories: calories,
        protein: protein,
        carb: carb,
        fat: fat,
      );

      // Validate nutrition using domain service
      try {
        MealNutritionCalculator.computeFromMealItem(
          mealItem,
          planId: widget.planId, // For admin templates, use planId
          dayIndex: widget.dayIndex,
        );
      } on MealNutritionException catch (e) {
        debugPrint('[AdminAddFoodDialog] ⚠️ Invalid nutrition values: $e');
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Giá trị dinh dưỡng không hợp lệ: ${e.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Add to local state via callback
      widget.onMealAdded(mealItem);

      if (mounted) {
        Navigator.pop(context); // Close add dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã thêm món ăn')),
        );
      }
    } catch (e) {
      debugPrint('[AdminAddFoodDialog] Error adding food: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể thêm món ăn')),
        );
      }
    }
  }
}

// Edit food dialog for admin
class _AdminEditFoodDialog extends ConsumerStatefulWidget {
  const _AdminEditFoodDialog({
    required this.planId,
    required this.dayIndex,
    required this.item,
    required this.allMeals,
    required this.onMealUpdated,
  });

  final String planId;
  final int dayIndex;
  final MealItem item;
  final List<MealItem> allMeals;
  final ValueChanged<MealItem> onMealUpdated;

  @override
  ConsumerState<_AdminEditFoodDialog> createState() =>
      _AdminEditFoodDialogState();
}

class _AdminEditFoodDialogState extends ConsumerState<_AdminEditFoodDialog> {
  late final TextEditingController _servingController;

  @override
  void initState() {
    super.initState();
    _servingController = TextEditingController(
      text: widget.item.servingSize.toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _servingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.read(food_providers.foodRepositoryProvider);
    final foodFuture = repository.getById(widget.item.foodId);

    return FutureBuilder<Food?>(
      future: foodFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const AlertDialog(
            content: Text('Không tìm thấy thông tin món ăn'),
          );
        }

        final food = snapshot.data!;

        return AlertDialog(
          title: Text('Chỉnh sửa - ${food.name}'),
          content: TextField(
            controller: _servingController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Số phần',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => _saveChanges(food),
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveChanges(Food food) async {
    final servingSize = double.tryParse(_servingController.text);
    if (servingSize == null || servingSize <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Số phần không hợp lệ')),
      );
      return;
    }

    try {
      // Calculate nutrition
      final gramsPerServing = food.defaultPortionGram;
      final totalGrams = gramsPerServing * servingSize;
      final multiplier = totalGrams / 100.0;

      final calories = food.caloriesPer100g * multiplier;
      final protein = food.proteinPer100g * multiplier;
      final carb = food.carbsPer100g * multiplier;
      final fat = food.fatPer100g * multiplier;

      // Create updated meal item for validation
      final updatedMealItem = widget.item.copyWith(
        servingSize: servingSize,
        calories: calories,
        protein: protein,
        carb: carb,
        fat: fat,
      );

      // Validate nutrition using domain service
      try {
        MealNutritionCalculator.computeFromMealItem(
          updatedMealItem,
          planId: widget.planId, // For admin templates, use planId
          dayIndex: widget.dayIndex,
        );
      } on MealNutritionException catch (e) {
        debugPrint('[AdminEditFoodDialog] ⚠️ Invalid nutrition values: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Giá trị dinh dưỡng không hợp lệ: ${e.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Update in local state via callback
      widget.onMealUpdated(updatedMealItem);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật món ăn')),
        );
      }
    } catch (e) {
      debugPrint('[AdminEditFoodDialog] Error updating food: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể cập nhật món ăn')),
        );
      }
    }
  }
}

class _NutritionChip extends StatelessWidget {
  const _NutritionChip({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.charmingGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
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
            '$value $unit',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.nearBlack,
                ),
          ),
        ],
      ),
    );
  }
}

// Providers for food search (reused from user editor)
final foodSearchProvider = StreamProvider.family<List<Food>, String>((ref, query) {
  final repository = ref.watch(food_providers.foodRepositoryProvider);
  if (query.isEmpty) {
    return Stream.value([]);
  }
  return repository.search(query);
});

final foodSearchByGoalProvider = StreamProvider.family<List<Food>, ({String query, String goalType})>((ref, params) {
  final repository = ref.watch(food_providers.foodRepositoryProvider);
  if (params.query.isEmpty) {
    return Stream.value([]);
  }
  return repository.searchByGoal(params.query, params.goalType);
});

