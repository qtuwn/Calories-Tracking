// Custom meal plan CRUD for user plans and meals – implemented by Cursor AI
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:calories_app/core/theme/app_colors.dart';
import 'package:calories_app/domain/meal_plans/user_meal_plan_repository.dart' show MealItem;
import 'package:calories_app/domain/meal_plans/services/meal_nutrition_calculator.dart' show MealNutritionCalculator, MealNutritionException;
import 'package:calories_app/domain/foods/food.dart';
import 'package:calories_app/shared/state/food_providers.dart' as food_providers;
import 'package:calories_app/shared/state/user_meal_plan_providers.dart' as user_meal_plan_providers;
import 'package:calories_app/features/meal_plans/domain/models/shared/meal_type.dart';

/// Standalone page for editing meals in a specific day of a user's custom meal plan
/// Can be navigated to from the meal plan detail page
class MealDayEditorPage extends ConsumerStatefulWidget {
  const MealDayEditorPage({
    super.key,
    required this.planId,
    required this.userId,
    required this.dayIndex,
    required this.goalType,
  });

  final String planId;
  final String userId;
  final int dayIndex;
  final String goalType;

  @override
  ConsumerState<MealDayEditorPage> createState() => _MealDayEditorPageState();
}

class _MealDayEditorPageState extends ConsumerState<MealDayEditorPage> {
  // In-memory state for meals
  List<MealItem> _meals = [];
  List<MealItem> _initialMeals = []; // Track initial state to detect deletions
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadMeals();
  }

  Future<void> _loadMeals() async {
    debugPrint('[MealDayEditorPage] 📥 Loading meals for planId=${widget.planId}, dayIndex=${widget.dayIndex}, userId=${widget.userId}');
    
    setState(() => _isLoading = true);
    
    try {
      final service = ref.read(user_meal_plan_providers.userMealPlanServiceProvider);
      final mealsStream = service.getDayMeals(
        widget.planId,
        widget.userId,
        widget.dayIndex,
      );
      
      final meals = await mealsStream.first;
      debugPrint('[MealDayEditorPage] ✅ Loaded ${meals.length} meals for day ${widget.dayIndex}');
      
      setState(() {
        _meals = meals;
        _initialMeals = List.from(meals); // Store initial state for diff calculation
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[MealDayEditorPage] 🔥 Error loading meals: $e');
      
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể tải bữa ăn: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Save all meals for the day using a single batch write
  /// This minimizes network calls and works seamlessly offline
  Future<void> _saveMeals() async {
    debugPrint(
      '[MealDayEditorPage] 💾 Batch saving meals for day ${widget.dayIndex}: '
      'planId=${widget.planId}, userId=${widget.userId}',
    );
    
    setState(() => _isSaving = true);
    
    try {
      final service = ref.read(user_meal_plan_providers.userMealPlanServiceProvider);
      
      // Calculate which meals to save (new or updated) and which to delete
      final mealsToSave = <MealItem>[];
      final mealsToDelete = <String>[];
      
      // All current meals should be saved (new ones have empty ID, existing ones have ID)
      mealsToSave.addAll(_meals);
      
      // Find meals that were in initial state but are no longer present
      for (final initialMeal in _initialMeals) {
        if (!_meals.any((m) => m.id == initialMeal.id && m.id.isNotEmpty)) {
          mealsToDelete.add(initialMeal.id);
        }
      }
      
      debugPrint(
        '[MealDayEditorPage] 📊 Batch operation: ${mealsToSave.length} to save, '
        '${mealsToDelete.length} to delete',
      );
      
      // Use batch write - single network call (or queued offline)
      final success = await service.saveDayMealsBatch(
        planId: widget.planId,
        userId: widget.userId,
        dayIndex: widget.dayIndex,
        mealsToSave: mealsToSave,
        mealsToDelete: mealsToDelete,
      );
      
      if (success) {
        // Update initial state to current state for next save
        _initialMeals = List.from(_meals);
        
        debugPrint('[MealDayEditorPage] ✅ Batch save completed successfully');
        
        if (mounted) {
          // Check if we're likely offline (write succeeded but may be queued)
          // Firestore handles this automatically, but we can show a subtle hint
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã lưu bữa ăn thành công!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.pop(context, true); // Return true to indicate changes were saved
        }
      }
    } on FirebaseException catch (e, stackTrace) {
      final errorCode = e.code;
      final errorMessage = e.message ?? 'Unknown error';
      
      debugPrint('[MealDayEditorPage] 🔥 Firestore error: code=$errorCode, message=$errorMessage');
      debugPrint('[MealDayEditorPage] Stack trace: $stackTrace');
      
      if (mounted) {
        // Distinguish between network errors and hard failures
        if (errorCode == 'unavailable' || 
            errorCode == 'deadline-exceeded' ||
            errorMessage.contains('Unable to resolve host') ||
            errorMessage.contains('network')) {
          // Network error - write is queued offline, treat as success
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã lưu cục bộ. Sẽ đồng bộ khi có kết nối.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
          // Update initial state since write is queued
          _initialMeals = List.from(_meals);
          Navigator.pop(context, true);
        } else if (errorCode == 'permission-denied') {
          // Permission error - hard failure
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không có quyền lưu bữa ăn. Vui lòng kiểm tra quyền truy cập.'),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          // Other errors
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Không thể lưu bữa ăn: $errorMessage'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      final errorStr = e.toString();
      debugPrint('[MealDayEditorPage] 🔥 Error saving meals: $e');
      debugPrint('[MealDayEditorPage] Stack trace: $stackTrace');
      
      if (mounted) {
        // Check if it's a network-related error
        if (errorStr.contains('UNAVAILABLE') || 
            errorStr.contains('Unable to resolve host') ||
            errorStr.contains('network') ||
            errorStr.contains('DNS')) {
          // Network error - write is queued offline
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã lưu cục bộ. Sẽ đồng bộ khi có kết nối.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
          _initialMeals = List.from(_meals);
          Navigator.pop(context, true);
        } else {
          // Other errors
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Không thể lưu bữa ăn: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _onMealsChanged(List<MealItem> newMeals) {
    setState(() {
      _meals = newMeals;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get user plan from service
    final service = ref.read(user_meal_plan_providers.userMealPlanServiceProvider);
    final userPlanFuture = service.loadPlanByIdOnce(widget.userId, widget.planId);

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
          'Ngày ${widget.dayIndex}',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveMeals,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder(
              future: userPlanFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError || snapshot.data == null) {
                  return const Center(child: Text('Không tìm thấy thực đơn'));
                }

                final userPlan = snapshot.data!;
                final dailyCalories = userPlan.dailyCalories;
                final dayTotals = _calculateDayTotals(_meals);
                final exceedsLimit = dailyCalories > 0 && dayTotals['calories']! > dailyCalories;
                final percentage = dailyCalories > 0
                    ? (dayTotals['calories']! / dailyCalories * 100).clamp(0, 200)
                    : 0.0;

                return Column(
                  children: [
                    // Day nutrition summary
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
                        border: exceedsLimit
                            ? Border.all(color: Colors.red, width: 2)
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Tổng dinh dưỡng ngày ${widget.dayIndex}',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (dailyCalories > 0)
                                Text(
                                  '${percentage.toInt()}%',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: exceedsLimit ? Colors.red : AppColors.nearBlack,
                                  ),
                                ),
                            ],
                          ),
                          if (exceedsLimit) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded,
                                      color: Colors.red, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Tổng calories vượt quá giới hạn ngày ($dailyCalories kcal). '
                                      'Vui lòng xóa hoặc giảm một số món ăn.',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _NutritionChip(
                                  label: 'Calories',
                                  value: '${dayTotals['calories']!.toInt()}',
                                  unit: 'kcal',
                                  isWarning: exceedsLimit,
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
                          if (dailyCalories > 0 && !exceedsLimit) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Giới hạn: $dailyCalories kcal/ngày',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.mediumGray,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Meals list
                    Expanded(
                      child: _buildMealsList(),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Map<String, double> _calculateDayTotals(List<MealItem> meals) {
    // Use domain service for all nutrition calculations
    try {
      final totals = MealNutritionCalculator.sumMeals(
        meals,
        planId: widget.planId,
        userId: widget.userId,
        dayIndex: widget.dayIndex,
      );
      return {
        'calories': totals.calories,
        'protein': totals.protein,
        'carb': totals.carb,
        'fat': totals.fat,
      };
    } on MealNutritionException catch (e) {
      // Log error but return zeros to prevent UI crash
      debugPrint('[MealDayEditorPage] ⚠️ Nutrition calculation error: $e');
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
    for (final meal in _meals) {
      final mealType = MealType.values.firstWhere(
        (e) => e.name == meal.mealType,
        orElse: () => MealType.breakfast,
      );
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

        return _MealTypeSection(
          planId: widget.planId,
          userId: widget.userId,
          dayIndex: widget.dayIndex,
          mealType: mealType,
          items: items,
          goalType: widget.goalType,
          allMeals: _meals,
          onMealsChanged: _onMealsChanged,
        );
      },
    );
  }
}

// Reuse widgets from meal_custom_editor_page.dart
// These are copied here to avoid circular dependencies
class _MealTypeSection extends ConsumerStatefulWidget {
  const _MealTypeSection({
    required this.planId,
    required this.userId,
    required this.dayIndex,
    required this.mealType,
    required this.items,
    required this.goalType,
    required this.allMeals,
    required this.onMealsChanged,
  });

  final String planId;
  final String userId;
  final int dayIndex;
  final MealType mealType;
  final List<MealItem> items;
  final String goalType;
  final List<MealItem> allMeals;
  final ValueChanged<List<MealItem>> onMealsChanged;

  @override
  ConsumerState<_MealTypeSection> createState() => _MealTypeSectionState();
}

class _MealTypeSectionState extends ConsumerState<_MealTypeSection> {
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
            ...widget.items.map((item) => _MealItemTile(
              planId: widget.planId,
              userId: widget.userId,
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
      builder: (context) => _AddFoodDialog(
        planId: widget.planId,
        userId: widget.userId,
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

class _MealItemTile extends ConsumerWidget {
  const _MealItemTile({
    required this.planId,
    required this.userId,
    required this.dayIndex,
    required this.item,
    required this.allMeals,
    required this.onMealsChanged,
  });

  final String planId;
  final String userId;
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
                onPressed: () => _deleteItem(context, ref),
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
      builder: (context) => _EditFoodDialog(
        planId: planId,
        userId: userId,
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

  Future<void> _deleteItem(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa món ăn'),
        content: const Text('Bạn có chắc muốn xóa món này khỏi thực đơn?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final newMeals = allMeals.where((m) => m.id != item.id).toList();
    onMealsChanged(newMeals);
  }
}

class _AddFoodDialog extends ConsumerStatefulWidget {
  const _AddFoodDialog({
    required this.planId,
    required this.userId,
    required this.dayIndex,
    required this.mealType,
    required this.goalType,
    required this.allMeals,
    required this.onMealAdded,
  });

  final String planId;
  final String userId;
  final int dayIndex;
  final MealType mealType;
  final String goalType;
  final List<MealItem> allMeals;
  final ValueChanged<MealItem> onMealAdded;

  @override
  ConsumerState<_AddFoodDialog> createState() => _AddFoodDialogState();
}

class _AddFoodDialogState extends ConsumerState<_AddFoodDialog> {
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
                  debugPrint('[AddFoodDialog] Error: $error');
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
      final gramsPerServing = food.defaultPortionGram;
      final totalGrams = gramsPerServing * servingSize;
      final multiplier = totalGrams / 100.0;

      final calories = food.caloriesPer100g * multiplier;
      final protein = food.proteinPer100g * multiplier;
      final carb = food.carbsPer100g * multiplier;
      final fat = food.fatPer100g * multiplier;

      // Get user plan to check daily calorie limit
      final service = ref.read(user_meal_plan_providers.userMealPlanServiceProvider);
      final userPlan = await service.loadPlanByIdOnce(widget.userId, widget.planId);

      if (userPlan == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không tìm thấy thực đơn')),
          );
        }
        return;
      }

      final dailyCalories = userPlan.dailyCalories;

      // Create temporary meal item for validation
      final tempMealItem = MealItem(
        id: '', // Temp ID for calculation
        mealType: widget.mealType.name,
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
          tempMealItem,
          planId: widget.planId,
          userId: widget.userId,
          dayIndex: widget.dayIndex,
        );
      } on MealNutritionException catch (e) {
        debugPrint('[AddFoodDialog] ⚠️ Invalid nutrition values: $e');
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

      if (dailyCalories > 0) {
        // Calculate current day totals using domain service
        final currentDayNutrition = MealNutritionCalculator.sumMeals(
          widget.allMeals,
          planId: widget.planId,
          userId: widget.userId,
          dayIndex: widget.dayIndex,
        );
        final currentTotal = currentDayNutrition.calories;

        // Calculate new meal nutrition
        final newMealNutrition = MealNutritionCalculator.computeFromMealItem(
          tempMealItem,
          planId: widget.planId,
          userId: widget.userId,
          dayIndex: widget.dayIndex,
        );
        final newTotal = currentDayNutrition.add(newMealNutrition).calories;

        if (newTotal > dailyCalories) {
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Tổng calories sẽ vượt quá giới hạn ngày ($dailyCalories kcal). '
                  'Hiện tại: ${currentTotal.toInt()} kcal. '
                  'Sau khi thêm: ${newTotal.toInt()} kcal. '
                  'Vui lòng giảm khẩu phần hoặc xóa một số món ăn khác.',
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
          return;
        }
      }

      final mealItem = tempMealItem;

      widget.onMealAdded(mealItem);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã thêm món ăn')),
        );
      }
    } catch (e) {
      debugPrint('[AddFoodDialog] Error adding food: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể thêm món ăn')),
        );
      }
    }
  }
}

class _EditFoodDialog extends ConsumerStatefulWidget {
  const _EditFoodDialog({
    required this.planId,
    required this.userId,
    required this.dayIndex,
    required this.item,
    required this.allMeals,
    required this.onMealUpdated,
  });

  final String planId;
  final String userId;
  final int dayIndex;
  final MealItem item;
  final List<MealItem> allMeals;
  final ValueChanged<MealItem> onMealUpdated;

  @override
  ConsumerState<_EditFoodDialog> createState() => _EditFoodDialogState();
}

class _EditFoodDialogState extends ConsumerState<_EditFoodDialog> {
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
          planId: widget.planId,
          userId: widget.userId,
          dayIndex: widget.dayIndex,
        );
      } on MealNutritionException catch (e) {
        debugPrint('[EditFoodDialog] ⚠️ Invalid nutrition values: $e');
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

      final service = ref.read(user_meal_plan_providers.userMealPlanServiceProvider);
      final userPlan = await service.loadPlanByIdOnce(widget.userId, widget.planId);
      if (!context.mounted) return;

      if (userPlan == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tìm thấy thực đơn')),
        );
        return;
      }

      final dailyCalories = userPlan.dailyCalories;

      if (dailyCalories > 0) {
        // Use domain service to compute current total
        final currentDayNutrition = MealNutritionCalculator.sumMeals(
          widget.allMeals,
          planId: widget.planId,
          userId: widget.userId,
          dayIndex: widget.dayIndex,
        );

        // Calculate new total: subtract old meal, add new meal
        final oldMealNutrition = MealNutritionCalculator.computeFromMealItem(
          widget.item,
          planId: widget.planId,
          userId: widget.userId,
          dayIndex: widget.dayIndex,
        );
        final newMealNutrition = MealNutritionCalculator.computeFromMealItem(
          updatedMealItem,
          planId: widget.planId,
          userId: widget.userId,
          dayIndex: widget.dayIndex,
        );
        // Remove old meal nutrition, add new meal nutrition
        final newTotal = currentDayNutrition.calories - oldMealNutrition.calories + newMealNutrition.calories;

        if (newTotal > dailyCalories) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Tổng calories sẽ vượt quá giới hạn ngày ($dailyCalories kcal). '
                'Sau khi cập nhật: ${newTotal.toInt()} kcal. '
                'Vui lòng giảm khẩu phần.',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
          return;
        }
      }

      widget.onMealUpdated(updatedMealItem);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật món ăn')),
        );
      }
    } catch (e) {
      debugPrint('[EditFoodDialog] Error updating food: $e');
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
    this.isWarning = false,
  });

  final String label;
  final String value;
  final String unit;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isWarning
            ? Colors.red.withValues(alpha: 0.1)
            : AppColors.charmingGreen.withValues(alpha: 0.1),
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
              color: isWarning ? Colors.red : AppColors.nearBlack,
            ),
          ),
        ],
      ),
    );
  }
}

// Providers for food search (reused from meal_custom_editor_page.dart)
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

