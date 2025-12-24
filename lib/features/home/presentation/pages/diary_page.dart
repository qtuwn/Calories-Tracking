import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calories_app/domain/diary/diary_entry.dart';
import 'package:calories_app/features/home/domain/diary_meal_item.dart';
import 'package:calories_app/features/meal_plans/domain/models/shared/meal_type.dart';
import 'package:calories_app/features/home/presentation/providers/diary_provider.dart';
import 'package:calories_app/features/home/presentation/widgets/add_meal_item_bottom_sheet.dart';
import 'package:calories_app/features/home/presentation/widgets/daily_summary_card.dart';
import 'package:calories_app/features/home/presentation/widgets/meal_card.dart';

class DiaryPage extends ConsumerStatefulWidget {
  const DiaryPage({super.key});

  @override
  ConsumerState<DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends ConsumerState<DiaryPage> {
  // Cache MealType.values list to avoid recreating on every build
  static final _mealTypes = MealType.values;

  @override
  Widget build(BuildContext context) {
    final diaryState = ref.watch(diaryProvider);
    final diaryNotifier = ref.read(diaryProvider.notifier);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Nhật Ký',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.black87),
            onPressed: () => _selectDate(context, diaryNotifier),
          ),
        ],
      ),
      body: diaryState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : diaryState.errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(
                        diaryState.errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          diaryNotifier.reload();
                        },
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date Selector
                      _buildDateSelector(diaryNotifier, diaryState),
                      const SizedBox(height: 20),

                      // Daily Summary
                      _buildDailySummary(diaryNotifier, diaryState),
                      const SizedBox(height: 20),

                      // Meal Type Buttons
                      _buildMealTypeButtons(diaryNotifier),
                      const SizedBox(height: 20),

                      // Empty State or Meals Log
                      if (diaryState.entriesForSelectedDate.isEmpty)
                        _buildEmptyState()
                      else ...[
                        _buildMealsLog(diaryNotifier),
                        const SizedBox(height: 20),
                        _buildExerciseLog(diaryNotifier, diaryState.entriesForSelectedDate.where((e) => e.isExercise).toList()),
                      ],
                    ],
                  ),
                ),
    );
  }

  Future<void> _selectDate(BuildContext context, DiaryNotifier notifier) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: notifier.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != notifier.selectedDate) {
      notifier.setSelectedDate(picked);
    }
  }

  Widget _buildDateSelector(DiaryNotifier notifier, DiaryState state) {
    final selectedDate = state.selectedDate;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              notifier.setSelectedDate(
                selectedDate.subtract(const Duration(days: 1)),
              );
            },
          ),
          Text(
            '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              if (selectedDate.isBefore(DateTime.now())) {
                notifier.setSelectedDate(
                  selectedDate.add(const Duration(days: 1)),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDailySummary(DiaryNotifier notifier, DiaryState diaryState) {
    return Column(
      children: [
        DailySummaryCard(
          totalCalories: notifier.totalCalories,
          totalProtein: notifier.totalProtein,
          totalCarbs: notifier.totalCarbs,
          totalFat: notifier.totalFat,
        ),
        // Show calorie breakdown if there are exercises
        if (diaryState.totalCaloriesBurned > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Năng lượng nạp vào',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '+${diaryState.totalCaloriesConsumed.toStringAsFixed(0)} kcal',
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Năng lượng đốt cháy',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '-${diaryState.totalCaloriesBurned.toStringAsFixed(0)} kcal',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tổng cộng',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${diaryState.totalCalories.toStringAsFixed(0)} kcal',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMealTypeButtons(DiaryNotifier notifier) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thêm bữa ăn',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.5,
            children: _mealTypes.map((mealType) {
              return _buildMealTypeButton(mealType, notifier);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMealTypeButton(MealType mealType, DiaryNotifier notifier) {
    return InkWell(
      onTap: () => _showAddMealItemSheet(context, notifier, mealType),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: mealType.color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: mealType.color.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              mealType.icon,
              color: mealType.color,
              size: 20,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                mealType.displayName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: mealType.color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant_menu,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Chưa có bữa ăn nào',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Thêm món ăn đầu tiên của bạn!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealsLog(DiaryNotifier notifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bữa ăn',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        ..._mealTypes.map((mealType) {
          final meal = notifier.getMealByType(mealType);
          return MealCard(
            meal: meal,
            onAddItem: () => _showAddMealItemSheet(context, notifier, mealType),
            onEditItem: (item) => _showEditMealItemSheet(
              context,
              notifier,
              mealType,
              item,
            ),
            onDeleteItem: (itemId) => notifier.deleteMealItem(mealType, itemId),
          );
        }),
      ],
    );
  }

  void _showAddMealItemSheet(
    BuildContext context,
    DiaryNotifier notifier,
    MealType mealType,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AddMealItemBottomSheet(mealType: mealType),
      ),
    );
    // Note: AddMealItemBottomSheet now handles saving directly via DiaryNotifier
  }

  void _showEditMealItemSheet(
    BuildContext context,
    DiaryNotifier notifier,
    MealType mealType,
    DiaryMealItem item,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AddMealItemBottomSheet(
          mealType: mealType,
          existingItem: item,
        ),
      ),
    );
    // Note: AddMealItemBottomSheet now handles saving directly via DiaryNotifier
  }

  Widget _buildExerciseLog(DiaryNotifier notifier, List<DiaryEntry> exerciseEntries) {
    if (exerciseEntries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Hoạt động thể chất',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${exerciseEntries.length} bài tập',
                  style: TextStyle(
                    color: Colors.orange[700],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...exerciseEntries.map((entry) => _buildExerciseItem(entry, notifier)),
        ],
      ),
    );
  }

  Widget _buildExerciseItem(DiaryEntry entry, DiaryNotifier notifier) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.fitness_center,
              color: Colors.orange,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.exerciseName ?? 'Bài tập',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${entry.durationMinutes?.toStringAsFixed(0) ?? 0} phút • ${entry.calories.toStringAsFixed(0)} kcal',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () {
              _confirmDeleteExercise(context, entry, notifier);
            },
          ),
        ],
      ),
    );
  }

  void _confirmDeleteExercise(
    BuildContext context,
    DiaryEntry entry,
    DiaryNotifier notifier,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa bài tập'),
        content: Text('Bạn có chắc muốn xóa "${entry.exerciseName ?? 'bài tập này'}" khỏi nhật ký?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await notifier.deleteExerciseEntry(entry.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã xóa bài tập'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Lỗi: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

