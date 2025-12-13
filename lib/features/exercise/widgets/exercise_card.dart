import 'package:flutter/material.dart';
import 'package:calories_app/core/theme/theme.dart';
import 'package:calories_app/features/exercise/data/exercise_model.dart';

class ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final VoidCallback? onTap;

  const ExerciseCard({
    super.key,
    required this.exercise,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Exercise image
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  exercise.imageUrl.isNotEmpty
                      ? exercise.imageUrl
                      : 'https://via.placeholder.com/80',
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.charmingGreen.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.fitness_center,
                        color: AppColors.mediumGray,
                        size: 40,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              // Exercise info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.nearBlack,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Unit badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.mintGreen.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getUnitLabel(exercise.unit),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.nearBlack,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Arrow icon
              const Icon(
                Icons.chevron_right,
                color: AppColors.mediumGray,
              ),
            ],
          ),
        ),
      ),
    );
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
}

