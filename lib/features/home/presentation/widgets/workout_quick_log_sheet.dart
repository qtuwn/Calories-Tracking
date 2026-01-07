import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calories_app/core/theme/theme.dart';
import 'package:calories_app/features/home/domain/workout_type.dart';
import 'package:calories_app/features/home/presentation/providers/quick_workout_log_provider.dart';

/// A modal bottom sheet for quickly logging a manual workout session.
///
/// Allows the user to:
/// - View the selected workout activity name and icon
/// - Input duration in minutes (required)
/// - Input calories burned (optional, auto-calculated if not provided)
/// - Add an optional note
/// - Save or cancel the workout log
class WorkoutQuickLogSheet extends ConsumerStatefulWidget {
  const WorkoutQuickLogSheet({super.key, required this.workoutType});

  final WorkoutType workoutType;

  @override
  ConsumerState<WorkoutQuickLogSheet> createState() =>
      _WorkoutQuickLogSheetState();
}

class _WorkoutQuickLogSheetState extends ConsumerState<WorkoutQuickLogSheet> {
  final _formKey = GlobalKey<FormState>();
  final _durationController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _noteController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _durationController.dispose();
    _caloriesController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final durationMinutes = double.parse(_durationController.text.trim());
      final caloriesInput = _caloriesController.text.trim();
      final note = _noteController.text.trim();

      // Use custom calories if provided, otherwise let provider calculate
      final caloriesBurned = caloriesInput.isNotEmpty
          ? double.parse(caloriesInput)
          : null;

      await ref
          .read(quickWorkoutLogProvider.notifier)
          .logQuickWorkout(
            workoutType: widget.workoutType,
            durationMinutes: durationMinutes,
            caloriesBurned: caloriesBurned,
            note: note.isNotEmpty ? note : null,
          );

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi khi lưu bài tập: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with icon and title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.mintGreen.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        widget.workoutType.icon,
                        size: 28,
                        color: AppColors.charmingGreen,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ghi nhanh bài tập',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.mediumGray),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.workoutType.displayName,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      color: AppColors.mediumGray,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Duration input (required)
                Text(
                  'Thời lượng (phút) *',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.nearBlack,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _durationController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+\.?\d{0,1}'),
                    ),
                  ],
                  decoration: InputDecoration(
                    hintText: 'Ví dụ: 30',
                    suffixText: 'phút',
                    filled: true,
                    fillColor: AppColors.nearBlack.withValues(alpha: 0.04),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập thời lượng';
                    }
                    final duration = double.tryParse(value.trim());
                    if (duration == null || duration <= 0) {
                      return 'Thời lượng phải lớn hơn 0';
                    }
                    if (duration > 1440) {
                      // 24 hours max
                      return 'Thời lượng không được quá 1440 phút';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Calories input (optional)
                Text(
                  'Calo đốt cháy (tùy chọn)',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.nearBlack,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Để trống để tự động tính toán dựa trên cân nặng của bạn',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.mediumGray),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _caloriesController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+\.?\d{0,1}'),
                    ),
                  ],
                  decoration: InputDecoration(
                    hintText: 'Ví dụ: 250',
                    suffixText: 'kcal',
                    filled: true,
                    fillColor: AppColors.nearBlack.withValues(alpha: 0.04),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      final calories = double.tryParse(value.trim());
                      if (calories == null || calories <= 0) {
                        return 'Calo phải lớn hơn 0';
                      }
                      if (calories > 5000) {
                        return 'Calo không được quá 5000';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Note input (optional)
                Text(
                  'Ghi chú (tùy chọn)',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.nearBlack,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _noteController,
                  maxLines: 3,
                  maxLength: 200,
                  decoration: InputDecoration(
                    hintText: 'Ví dụ: Chạy ở công viên',
                    filled: true,
                    fillColor: AppColors.nearBlack.withValues(alpha: 0.04),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 4),

                // Error message
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _errorMessage!,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.red),
                    ),
                  ),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: BorderSide(
                            color: AppColors.mediumGray.withValues(alpha: 0.5),
                          ),
                        ),
                        child: const Text('Hủy'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.mintGreen,
                          foregroundColor: AppColors.nearBlack,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Lưu'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
