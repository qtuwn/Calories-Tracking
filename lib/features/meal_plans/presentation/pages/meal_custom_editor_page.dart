// Screen: Custom meal plan editor (CRUD)
// 
// Responsibilities:
// - Create new custom meal plans
// - Edit existing custom meal plans
// - Add/remove meals for each day
// - Save plan and meals to Firestore
// - Navigate to detail page after saving
//
// This is an EDITOR screen. For read-only viewing, use MealDetailPage.
// Custom meal plan CRUD for user plans and meals – migrated to use domain models and controllers
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calories_app/core/theme/app_colors.dart';
import 'package:calories_app/domain/meal_plans/user_meal_plan.dart';
import 'package:calories_app/domain/meal_plans/user_meal_plan_repository.dart' show MealItem;
import 'package:calories_app/domain/meal_plans/meal_plan_goal_type.dart';
import 'package:calories_app/features/meal_plans/domain/models/shared/meal_type.dart';
import 'package:calories_app/features/meal_plans/state/user_custom_meal_plan_controller.dart';
import 'package:calories_app/features/meal_plans/domain/services/kcal_calculator.dart';
import 'package:calories_app/features/meal_plans/domain/services/macros_summary_service.dart';
import 'package:calories_app/features/meal_plans/domain/services/meal_plan_validation_service.dart';
import 'package:calories_app/shared/state/food_providers.dart' as food_providers;
import 'package:calories_app/domain/foods/food.dart';
import 'package:calories_app/shared/state/auth_providers.dart';
import 'package:calories_app/shared/state/user_meal_plan_providers.dart' as user_meal_plan_providers;
import 'package:calories_app/features/meal_plans/presentation/pages/meal_detail_page.dart';

/// Callback for when meals change for a specific day
typedef OnMealsChanged = void Function(int dayIndex, List<MealItem> newMeals);

/// Duration presets for custom meal plans
const _durationPresets = [7, 14, 30, 90];

class MealCustomEditorPage extends ConsumerStatefulWidget {
  const MealCustomEditorPage({
    super.key,
    this.planId, // If provided, edit existing plan (for user custom plans)
  });

  final String? planId; // If provided, edit existing plan (for user custom plans)

  @override
  ConsumerState<MealCustomEditorPage> createState() => _MealCustomEditorPageState();
}

class _MealCustomEditorPageState extends ConsumerState<MealCustomEditorPage> {
  final _nameController = TextEditingController();
  final _caloriesController = TextEditingController();
  String _selectedGoalType = 'maintain';
  int? _selectedDurationDays;
  int _currentDayIndex = 1;
  bool _isSaving = false;
  String? _existingPlanId;
  String? _calorieError; // Validation error for daily calories
  int? _dailyCalorieLimit; // Daily calorie limit from user profile
  
  // In-memory storage for meals: dayIndex -> list of meals
  final Map<int, List<MealItem>> _mealsByDay = {};
  bool _mealsLoaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.planId != null) {
      _loadExistingPlan();
    }
  }

  /// Load existing user custom plan
  Future<void> _loadExistingPlan() async {
    final authState = ref.read(authStateProvider);
    final user = authState.value;
    if (user == null || widget.planId == null) return;

    try {
      final service = ref.read(user_meal_plan_providers.userMealPlanServiceProvider);
      final plan = await service.loadPlanByIdOnce(user.uid, widget.planId!);

      if (plan != null) {
        // Load plan into controller for editing
        final controller = ref.read(userCustomMealPlanControllerProvider.notifier);
        controller.startEditing(plan);
        
        // Update local UI state
        _nameController.text = plan.name;
        _caloriesController.text = plan.dailyCalories.toString();
        _selectedGoalType = plan.goalType.value;
        _selectedDurationDays = plan.durationDays;
        _existingPlanId = widget.planId;
        
        // Load meals from repository into local state
        await _loadMealsFromRepository(user.uid);
        
        setState(() {});
      }
    } catch (e) {
      debugPrint('[MealCustomEditorPage] Error loading plan: $e');
    }
  }


  /// Load all meals from service into local state (user custom plan)
  Future<void> _loadMealsFromRepository(String userId) async {
    if (widget.planId == null) return;
    
    try {
      final service = ref.read(user_meal_plan_providers.userMealPlanServiceProvider);
      final plan = await service.loadPlanByIdOnce(userId, widget.planId!);
      if (plan == null) return;
      
      _mealsByDay.clear();
      
      // Load meals for each day
      for (int dayIndex = 1; dayIndex <= plan.durationDays; dayIndex++) {
        final mealsStream = service.getDayMeals(widget.planId!, userId, dayIndex);
        // Take first emission to get current meals
        await for (final meals in mealsStream.take(1)) {
          if (meals.isNotEmpty) {
            _mealsByDay[dayIndex] = meals;
          }
          break;
        }
      }
      
      _mealsLoaded = true;
      debugPrint('[MealCustomEditorPage] ✅ Loaded ${_mealsByDay.length} days with meals');
    } catch (e) {
      debugPrint('[MealCustomEditorPage] Error loading meals: $e');
      _mealsLoaded = true; // Mark as loaded even on error to prevent infinite loading
    }
  }


  @override
  void dispose() {
    _nameController.dispose();
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
          widget.planId == null ? 'Tạo thực đơn mới' : 'Chỉnh sửa thực đơn',
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
                hintText: 'VD: Thực đơn giảm mỡ của tôi',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
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
                  label: MealPlanGoalType.loseFat.displayName,
                  value: 'lose_fat',
                  selected: _selectedGoalType,
                  onTap: () {
                    setState(() {
                      _selectedGoalType = 'lose_fat';
                      // Re-validate calories when goal changes
                      if (_caloriesController.text.isNotEmpty) {
                        final calories = int.tryParse(_caloriesController.text);
                        if (calories != null) {
                          // Will be validated in the Consumer widget
                          _calorieError = null;
                        }
                      }
                    });
                  },
                ),
                _GoalChip(
                  label: MealPlanGoalType.muscleGain.displayName,
                  value: 'muscle_gain',
                  selected: _selectedGoalType,
                  onTap: () {
                    setState(() {
                      _selectedGoalType = 'muscle_gain';
                      if (_caloriesController.text.isNotEmpty) {
                        final calories = int.tryParse(_caloriesController.text);
                        if (calories != null) {
                          _calorieError = null;
                        }
                      }
                    });
                  },
                ),
                _GoalChip(
                  label: MealPlanGoalType.vegan.displayName,
                  value: 'vegan',
                  selected: _selectedGoalType,
                  onTap: () {
                    setState(() {
                      _selectedGoalType = 'vegan';
                      if (_caloriesController.text.isNotEmpty) {
                        final calories = int.tryParse(_caloriesController.text);
                        if (calories != null) {
                          _calorieError = null;
                        }
                      }
                    });
                  },
                ),
                _GoalChip(
                  label: MealPlanGoalType.maintain.displayName,
                  value: 'maintain',
                  selected: _selectedGoalType,
                  onTap: () {
                    setState(() {
                      _selectedGoalType = 'maintain';
                      if (_caloriesController.text.isNotEmpty) {
                        final calories = int.tryParse(_caloriesController.text);
                        if (calories != null) {
                          _calorieError = null;
                        }
                      }
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Daily calories with validation
            Consumer(
              builder: (context, ref, child) {
                // Watch user profile for calorie limits
                final profileAsync = ref.watch(currentUserProfileProvider);
                
                return profileAsync.when(
                  data: (profile) {
                    // Use Profile directly (no conversion needed)
                    // Calculate calorie limit for selected goal
                    final goalType = MealPlanGoalType.fromString(_selectedGoalType);
                    final range = KcalCalculator.getDailyCalorieRangeForGoal(
                      profile,
                      goalType,
                    );
                    _dailyCalorieLimit = range?['max']?.toInt();
                    
                    // Update validation when goal changes
                    if (_caloriesController.text.isNotEmpty) {
                      final calories = int.tryParse(_caloriesController.text);
                      if (calories != null) {
                        _calorieError = KcalCalculator.getCalorieValidationError(
                          profile,
                          goalType,
                          calories,
                        );
                      }
                    }
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
            TextField(
                          controller: _caloriesController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: InputDecoration(
                            labelText: 'Calories mỗi ngày',
                            hintText: _dailyCalorieLimit != null
                                ? 'Khuyến nghị: ${range?['min']?.toInt() ?? 0}-$_dailyCalorieLimit kcal'
                                : 'VD: 1500',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            suffixText: 'kcal',
                            errorText: _calorieError,
                            errorMaxLines: 2,
                          ),
                            onChanged: (value) {
                            final calories = int.tryParse(value);
                            if (calories != null) {
                              setState(() {
                                final goalType = MealPlanGoalType.fromString(_selectedGoalType);
                                _calorieError = KcalCalculator.getCalorieValidationError(
                                  profile,
                                  goalType,
                                  calories,
                                );
                              });
                            } else {
                              setState(() => _calorieError = null);
                            }
                          },
                        ),
                        if (_dailyCalorieLimit != null && _calorieError == null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Giới hạn khuyến nghị: ${range?['min']?.toInt() ?? 0} - $_dailyCalorieLimit kcal/ngày',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.mediumGray,
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                  loading: () => TextField(
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
                      errorText: _calorieError,
                    ),
                    onChanged: (value) {
                      final calories = int.tryParse(value);
                      if (calories != null && (calories < 1200 || calories > 4000)) {
                        setState(() => _calorieError = 'Calories phải từ 1200-4000 kcal/ngày');
                      } else {
                        setState(() => _calorieError = null);
                      }
                    },
                  ),
                  error: (_, __) => TextField(
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
                );
              },
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
              children: _durationPresets.map((days) {
                final label = days == 7
                    ? '7 ngày (1 tuần)'
                    : days == 14
                        ? '14 ngày (2 tuần)'
                        : days == 30
                            ? '30 ngày (1 tháng)'
                            : '90 ngày (3 tháng)';
                return _DurationChip(
                  label: label,
                  days: days,
                  isSelected: _selectedDurationDays == days,
                  onTap: () => setState(() => _selectedDurationDays = days),
                );
              }).toList(),
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
        _selectedDurationDays != null &&
        _calorieError == null; // Must have no validation error
  }

  void _continueToEditor() {
    if (!_canContinue()) return;
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
              // New plan - go back to setup
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
          if (_existingPlanId != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _deletePlan,
            ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isSaving ? null : _savePlan,
          ),
        ],
      ),
      body: Column(
        children: [
          // Kcal validation summary
          Consumer(
            builder: (context, ref, child) {
              final profileAsync = ref.watch(currentUserProfileProvider);
              final planCalories = int.tryParse(_caloriesController.text.trim()) ?? 0;
              
              return profileAsync.when(
                data: (profile) {
                  final targetKcal = profile?.targetKcal;
                  if (targetKcal == null || targetKcal <= 0 || planCalories <= 0) {
                    return const SizedBox.shrink();
                  }
                  
                  final targetKcalInt = targetKcal.toInt();
                  final validation = MealPlanValidationService.validateKcalDeviation(
                    actualKcal: planCalories,
                    targetKcal: targetKcalInt,
                  );
                  
                  return _KcalValidationSummary(
                    totalKcal: planCalories,
                    targetKcal: targetKcalInt,
                    deviation: validation.deviation,
                    percentage: validation.percentage,
                    ratio: validation.ratio,
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              );
            },
          ),
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
            child: _DayMealsEditor(
              planId: _existingPlanId,
              dayIndex: _currentDayIndex,
              goalType: _selectedGoalType,
              meals: _mealsByDay[_currentDayIndex] ?? [],
              mealsLoaded: _mealsLoaded,
              onPlanCreated: (planId) {
                setState(() {
                  _existingPlanId = planId;
                });
              },
              onMealsChanged: (dayIndex, meals) {
                setState(() {
                  _mealsByDay[dayIndex] = meals;
                });
              },
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _savePlan() async {
    final name = _nameController.text.trim();
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

    final authState = ref.read(authStateProvider);
    final user = authState.value;
    if (user == null) {
      _showError('Vui lòng đăng nhập');
      return;
    }

    // Check kcal validation before saving
    final profileAsync = ref.read(currentUserProfileProvider);
    final profile = profileAsync.value;
    final targetKcal = profile?.targetKcal;
    
    if (targetKcal != null && targetKcal > 0) {
      final validation = MealPlanValidationService.validateKcalDeviation(
        actualKcal: calories,
        targetKcal: targetKcal.toInt(),
      );
      
      // If deviation > 15%, show confirmation dialog
      if (validation.isWarning) {
        final shouldProceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Thực đơn lệch so với mục tiêu'),
            content: Text(
              'Thực đơn của bạn có $calories kcal/ngày, trong khi mục tiêu của bạn là ${targetKcal.toInt()} kcal/ngày.\n\n'
              'Lệch: ${validation.deviation > 0 ? '+' : ''}${validation.deviation} kcal (${validation.percentage > 0 ? '+' : ''}${validation.percentage.toStringAsFixed(1)}%).\n\n'
              'Thực đơn lệch quá nhiều so với mục tiêu có thể ảnh hưởng đến kết quả. Bạn có muốn điều chỉnh lại các bữa ăn trước khi lưu không?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Điều chỉnh lại'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.orange,
                ),
                child: const Text('Vẫn lưu'),
              ),
            ],
          ),
        );
        
        if (shouldProceed != true) {
          return; // User chose to adjust
        }
      }
    }

    setState(() => _isSaving = true);

    // Capture all ref values BEFORE any async operations to avoid "ref after unmount" errors
    final controller = ref.read(userCustomMealPlanControllerProvider.notifier);
    final service = ref.read(user_meal_plan_providers.userMealPlanServiceProvider);
    final profileAsyncValue = ref.read(currentUserProfileProvider);
    final profileValue = profileAsyncValue.value;
    final wasNewPlan = _existingPlanId == null;
    String currentPlanId;

    try {
      UserMealPlan planToSave;
      
      if (wasNewPlan) {
        // Generate a new plan ID
        final newPlanId = '${user.uid}_${DateTime.now().millisecondsSinceEpoch}';
        
        // Create plan object
        planToSave = UserMealPlan(
          id: newPlanId,
          userId: user.uid,
          planTemplateId: null,
          name: name,
          goalType: MealPlanGoalType.fromString(_selectedGoalType),
          type: UserMealPlanType.custom,
          startDate: DateTime.now(),
          currentDayIndex: 1,
          status: UserMealPlanStatus.active,
          dailyCalories: calories,
          durationDays: _selectedDurationDays!,
          isActive: false,
          createdAt: DateTime.now(),
        );
        
        currentPlanId = newPlanId;
        _existingPlanId = currentPlanId;
      } else {
        // Load existing plan
        final existingPlan = await service.loadPlanByIdOnce(user.uid, _existingPlanId!);
        
        if (!mounted) return;
        
        if (existingPlan == null) {
          throw Exception('Plan not found: $_existingPlanId');
        }
        
        // Update plan with new values
        planToSave = existingPlan.copyWith(
          name: name,
          goalType: MealPlanGoalType.fromString(_selectedGoalType),
          dailyCalories: calories,
          durationDays: _selectedDurationDays!,
        );
        
        currentPlanId = _existingPlanId!;
      }

      // Use controller method to save plan and meals together
      // This moves all ref usage into the controller, preventing "ref after unmount" errors
      final savedPlanId = await controller.savePlanAndMeals(
        plan: planToSave,
        mealsByDay: _mealsByDay,
        profile: profileValue,
      );
      
      if (!mounted || savedPlanId == null) return;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(wasNewPlan
                ? 'Tạo thực đơn thành công!'
                : 'Cập nhật thực đơn thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        
        if (wasNewPlan) {
          // Navigate to detail page for new plans
          debugPrint('[MealCustomEditorPage] 🚀 Navigating to detail page for new plan: planId=$currentPlanId');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => MealDetailPage(
                planId: currentPlanId,
                isTemplate: false,
                userPlanId: currentPlanId,
              ),
            ),
          );
        } else {
          // For existing plans, just go back
          Navigator.pop(context);
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[MealCustomEditorPage] 🔥 Error saving plan: $e');
      debugPrint('[MealCustomEditorPage] Stack trace: $stackTrace');
      
      if (mounted) {
        String errorMessage = 'Không thể lưu thực đơn. Vui lòng thử lại sau.';
        
        if (e.toString().contains('permission-denied')) {
          errorMessage = 'Bạn không có quyền thực hiện thao tác này.';
        }
        
        _showError(errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deletePlan() async {
    if (_existingPlanId == null) return;

    final authState = ref.read(authStateProvider);
    final user = authState.value;
    if (user == null) return;

    // Check if this plan is active (use provider as source of truth)
    final activePlanAsync = ref.read(user_meal_plan_providers.activeMealPlanProvider);
    final activePlan = activePlanAsync.value;
    final isActive = activePlan?.id == _existingPlanId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa thực đơn'),
        content: Text(
          isActive
              ? 'Thực đơn này đang được kích hoạt. Nếu xóa, bạn sẽ không còn thực đơn nào đang hoạt động.\n\n'
                  'Bạn có chắc chắn muốn xóa thực đơn này?'
              : 'Bạn có chắc chắn muốn xóa thực đơn này?',
        ),
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

    try {
      final controller = ref.read(userCustomMealPlanControllerProvider.notifier);
      await controller.deletePlan(_existingPlanId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa thực đơn'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('[MealCustomEditorPage] Error deleting plan: $e');
      _showError('Không thể xóa thực đơn');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // NOTE: _saveAllMealsToRepository has been removed - saving logic moved to UserCustomMealPlanController.savePlanAndMeals()
  // This prevents "Using ref when widget is unmounted" errors by keeping all ref usage in the controller
}

class _DayMealsEditor extends ConsumerStatefulWidget {
  const _DayMealsEditor({
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
  final OnMealsChanged onMealsChanged;

  @override
  ConsumerState<_DayMealsEditor> createState() => _DayMealsEditorState();
}

class _DayMealsEditorState extends ConsumerState<_DayMealsEditor> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.value;
    if (user == null) {
      return const Center(child: Text('Vui lòng đăng nhập'));
    }

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

    // Calculate day totals from local meals
    final dayTotals = _calculateDayTotals(widget.meals);

    // Get daily calorie limit from plan
    final service = ref.read(user_meal_plan_providers.userMealPlanServiceProvider);
    final userPlanFuture = service.loadPlanByIdOnce(user.uid, widget.planId!);

    return FutureBuilder<UserMealPlan?>(
      future: userPlanFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return const Center(child: Text('Lỗi tải thực đơn'));
        }
        
        final userPlan = snapshot.data;
        final dailyCalories = userPlan?.dailyCalories ?? 0;
        final dailyCal = dailyCalories > 0 ? dailyCalories : 0;
        final exceedsLimit = dailyCal > 0 && dayTotals['calories']! > dailyCal;
        final percentage = dailyCal > 0 
            ? (dayTotals['calories']! / dailyCal * 100).clamp(0, 200)
            : 0.0;

        return Column(
          children: [
            // Day nutrition summary with validation
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
                      if (dailyCal > 0)
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
                              'Tổng calories vượt quá giới hạn ngày ($dailyCal kcal). '
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
                  if (dailyCal > 0 && !exceedsLimit) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Giới hạn: $dailyCal kcal/ngày',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.mediumGray,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Meals by type
            Expanded(
              child: _buildMealsList(user.uid),
            ),
          ],
        );
      },
    );
  }

  /// Calculate totals for the current day from meals using domain service
  Map<String, double> _calculateDayTotals(List<MealItem> meals) {
    final macros = MacrosSummaryService.sumMacros(meals);
    return {
      'calories': macros.calories,
      'protein': macros.protein,
      'carb': macros.carb,
      'fat': macros.fat,
    };
  }

  Widget _buildMealsList(String userId) {
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

        return _MealTypeSection(
          planId: widget.planId!,
          userId: userId,
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
          // Add meal to all meals list
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
          // Update the meal in the list
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

    // Delete from local state (meals will be saved to Firestore when user taps main Save)
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
  final _servingController = TextEditingController(text: '1.0');

  @override
  void dispose() {
    _searchController.dispose();
    _servingController.dispose();
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
                  debugPrint('[DayMealsEditor] Error: $error');
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
    // Show serving size input
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

      if (dailyCalories > 0) {
        // Calculate current day's total from all local meals
        double currentTotal = 0.0;
        for (final meal in widget.allMeals) {
          currentTotal += meal.calories;
        }

        // Check if adding this meal would exceed the limit
        final newTotal = currentTotal + calories;
        if (newTotal > dailyCalories) {
          if (mounted) {
            Navigator.pop(context); // Close serving size dialog
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

      // Create meal item (don't save to Firestore yet - will be saved when main Save is pressed)
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

      // Add to local state via callback
      widget.onMealAdded(mealItem);

      if (mounted) {
        Navigator.pop(context); // Close add dialog
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
      // Calculate nutrition
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
      if (!context.mounted) return;
      
      if (userPlan == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tìm thấy thực đơn')),
        );
        return;
      }
      
      final dailyCalories = userPlan.dailyCalories;

      if (dailyCalories > 0) {
        // Calculate current day's total from local meals
        double currentTotal = 0.0;
        for (final meal in widget.allMeals) {
          currentTotal += meal.calories;
        }

        // Calculate new total: subtract old item calories, add new calories
        final newTotal = currentTotal - widget.item.calories + calories;
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

      // Update meal item in local state (don't save to Firestore yet)
      final updatedMealItem = widget.item.copyWith(
        servingSize: servingSize,
        calories: calories,
        protein: protein,
        carb: carb,
        fat: fat,
      );

      // Update in local state via callback
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

/// Widget to display kcal validation summary
/// Shows total vs target kcal with deviation and percentage
class _KcalValidationSummary extends StatelessWidget {
  const _KcalValidationSummary({
    required this.totalKcal,
    required this.targetKcal,
    required this.deviation,
    required this.percentage,
    required this.ratio,
  });

  final int totalKcal;
  final int targetKcal;
  final int deviation;
  final double percentage;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final isWarning = ratio > 0.15;
    final deviationText = deviation > 0 ? '+$deviation' : '$deviation';
    final percentageText = percentage > 0 ? '+${percentage.toStringAsFixed(1)}' : percentage.toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
        border: isWarning
            ? Border.all(color: Colors.orange, width: 2)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tổng: $totalKcal kcal / Mục tiêu: $targetKcal kcal',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isWarning ? Colors.orange : AppColors.nearBlack,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Lệch: $deviationText kcal ($percentageText%)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isWarning ? Colors.orange : AppColors.mediumGray,
                    fontWeight: isWarning ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
          if (isWarning) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, 
                    color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Thực đơn lệch quá nhiều so với mục tiêu. Vui lòng điều chỉnh trước khi lưu.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Providers for food search
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
