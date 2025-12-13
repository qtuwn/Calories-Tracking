import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calories_app/core/theme/theme.dart';
import 'package:calories_app/features/exercise/data/exercise_model.dart';
import 'package:calories_app/features/exercise/data/exercise_providers.dart';
import 'package:calories_app/features/home/presentation/providers/diary_provider.dart';
import 'package:calories_app/shared/state/auth_providers.dart';

class ExerciseDetailScreen extends ConsumerStatefulWidget {
  static const routeName = '/exercise-detail';

  final String exerciseId;

  const ExerciseDetailScreen({
    super.key,
    required this.exerciseId,
  });

  @override
  ConsumerState<ExerciseDetailScreen> createState() =>
      _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState
    extends ConsumerState<ExerciseDetailScreen> {
  double _inputValue = 0.0;
  int _selectedLevelIndex = 0;
  double _calculatedCalories = 0.0;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final exerciseAsync = ref.watch(_exerciseProvider(widget.exerciseId));
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.palePink,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: AppBar(
          backgroundColor: AppColors.palePink,
          elevation: 0,
          leadingWidth: 72,
          leading: Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Center(
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 2,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.of(context).pop(),
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(
                      Icons.arrow_back,
                      size: 22,
                      color: AppColors.nearBlack,
                    ),
                  ),
                ),
              ),
            ),
          ),
          centerTitle: true,
        ),
      ),
      body: exerciseAsync.when(
        data: (exercise) {
          if (exercise == null) {
            return const Center(
              child: Text('Không tìm thấy bài tập'),
            );
          }

          final userWeight = profileAsync.value?.weightKg ?? 70.0; // Default weight

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Exercise image and name
                _buildExerciseHeader(exercise),
                const SizedBox(height: 24),
                // Input section based on unit type
                _buildInputSection(exercise, userWeight),
                const SizedBox(height: 24),
                // Calories result card
                if (_calculatedCalories > 0) ...[
                  _buildCaloriesCard(),
                  const SizedBox(height: 16),
                  _buildSaveToDiaryButton(exercise),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Có lỗi xảy ra: $error',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExerciseHeader(Exercise exercise) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
            child: Image.network(
              exercise.imageUrl.isNotEmpty
                  ? exercise.imageUrl
                  : 'https://via.placeholder.com/400x200',
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppColors.charmingGreen.withValues(alpha: 0.2),
                  ),
                  child: const Icon(
                    Icons.fitness_center,
                    size: 64,
                    color: AppColors.mediumGray,
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.nearBlack,
                      ),
                ),
                if (exercise.description != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    exercise.description!,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.mediumGray,
                        ),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.mintGreen.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getUnitLabel(exercise.unit),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.nearBlack,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection(Exercise exercise, double userWeight) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getInputTitle(exercise.unit),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.nearBlack,
                  ),
            ),
            const SizedBox(height: 16),
            if (exercise.unit == ExerciseUnit.level) ...[
              // Level selector
              Text(
                'Mức độ',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.mediumGray,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: exercise.levels.asMap().entries.map((entry) {
                  final index = entry.key;
                  final level = entry.value;
                  final isSelected = _selectedLevelIndex == index;
                  return FilterChip(
                    label: Text(level.name),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedLevelIndex = index;
                        _calculateCalories(exercise, userWeight);
                      });
                    },
                    selectedColor: AppColors.mintGreen.withValues(alpha: 0.5),
                    backgroundColor: Colors.white,
                    checkmarkColor: AppColors.nearBlack,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? AppColors.nearBlack
                          : AppColors.mediumGray,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.mintGreen
                          : AppColors.charmingGreen.withValues(alpha: 0.3),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],
            // Input field
            TextField(
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                labelText: _getInputLabel(exercise.unit),
                hintText: _getInputHint(exercise.unit),
                suffixText: _getInputSuffix(exercise.unit),
              ),
              onChanged: (value) {
                setState(() {
                  _inputValue = double.tryParse(value) ?? 0.0;
                  _calculateCalories(exercise, userWeight);
                });
              },
            ),
            const SizedBox(height: 20),
            // Calculate button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _inputValue > 0 ? () {
                  _calculateCalories(exercise, userWeight);
                } : null,
                child: const Text('Tính toán'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaloriesCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      color: AppColors.mintGreen.withValues(alpha: 0.2),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              'Lượng calo đốt cháy',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.mediumGray,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _calculatedCalories.toStringAsFixed(0),
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.nearBlack,
                  ),
            ),
            Text(
              'kcal',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.mediumGray,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  void _calculateCalories(Exercise exercise, double userWeight) {
    setState(() {
      switch (exercise.unit) {
        case ExerciseUnit.time:
          _calculatedCalories =
              exercise.calculateCaloriesTime(userWeight, _inputValue);
          break;
        case ExerciseUnit.distance:
          _calculatedCalories =
              exercise.calculateCaloriesDistance(userWeight, _inputValue);
          break;
        case ExerciseUnit.level:
          if (exercise.levels.isNotEmpty &&
              _selectedLevelIndex < exercise.levels.length) {
            _calculatedCalories = exercise.calculateCaloriesLevel(
              userWeight,
              _inputValue,
              _selectedLevelIndex,
            );
          } else {
            _calculatedCalories = 0.0;
          }
          break;
      }
    });
  }

  String _getUnitLabel(ExerciseUnit unit) {
    switch (unit) {
      case ExerciseUnit.time:
        return 'Thời gian';
      case ExerciseUnit.distance:
        return 'Khoảng cách';
      case ExerciseUnit.level:
        return 'Mức độ';
    }
  }

  String _getInputTitle(ExerciseUnit unit) {
    switch (unit) {
      case ExerciseUnit.time:
        return 'Nhập thời gian tập luyện';
      case ExerciseUnit.distance:
        return 'Nhập khoảng cách';
      case ExerciseUnit.level:
        return 'Chọn mức độ và thời gian';
    }
  }

  String _getInputLabel(ExerciseUnit unit) {
    switch (unit) {
      case ExerciseUnit.time:
        return 'Thời gian (phút)';
      case ExerciseUnit.distance:
        return 'Khoảng cách (km)';
      case ExerciseUnit.level:
        return 'Thời gian (phút)';
    }
  }

  String _getInputHint(ExerciseUnit unit) {
    switch (unit) {
      case ExerciseUnit.time:
        return 'VD: 30';
      case ExerciseUnit.distance:
        return 'VD: 5';
      case ExerciseUnit.level:
        return 'VD: 30';
    }
  }

  String _getInputSuffix(ExerciseUnit unit) {
    switch (unit) {
      case ExerciseUnit.time:
        return 'phút';
      case ExerciseUnit.distance:
        return 'km';
      case ExerciseUnit.level:
        return 'phút';
    }
  }

  Widget _buildSaveToDiaryButton(Exercise exercise) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSaving
            ? null
            : () async {
                await _saveToDiary(exercise);
              },
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.add_circle_outline),
        label: Text(_isSaving ? 'Đang lưu...' : 'Lưu vào nhật ký'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.charmingGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Future<void> _saveToDiary(Exercise exercise) async {
    if (_calculatedCalories <= 0 || _inputValue <= 0) {
      _showErrorSnackBar('Vui lòng tính toán calo trước khi lưu');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final diaryNotifier = ref.read(diaryProvider.notifier);

      // Determine duration and other fields based on unit type
      double durationMinutes = _inputValue;
      double? exerciseValue = _inputValue;
      String? levelName;

      if (exercise.unit == ExerciseUnit.level && 
          _selectedLevelIndex < exercise.levels.length) {
        levelName = exercise.levels[_selectedLevelIndex].name;
      }

      // Add exercise to diary
      await diaryNotifier.addExerciseEntry(
        exercise: exercise,
        durationMinutes: durationMinutes,
        caloriesBurned: _calculatedCalories,
        exerciseValue: exerciseValue,
        exerciseLevelName: levelName,
      );

      if (mounted) {
        _showSuccessSnackBar('Đã thêm bài tập vào nhật ký!');
        // Optionally go back after saving
        // Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Có lỗi xảy ra: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.charmingGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

/// Provider for single exercise by ID
final _exerciseProvider = FutureProvider.family<Exercise?, String>((ref, id) {
  final repository = ref.watch(exerciseRepositoryProvider);
  return repository.getExerciseById(id);
});

