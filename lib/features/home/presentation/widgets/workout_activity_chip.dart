import 'package:flutter/material.dart';
import 'package:calories_app/core/theme/theme.dart';
import 'package:calories_app/features/home/domain/workout_type.dart';

/// A reusable chip widget for workout activity selection on the Home screen.
/// 
/// Displays an activity icon and label, with tap interaction and visual feedback.
/// Used in the "Hoạt động tập luyện" section for quick workout logging.
class WorkoutActivityChip extends StatelessWidget {
  const WorkoutActivityChip({
    super.key,
    required this.workoutType,
    required this.onTap,
  });

  final WorkoutType workoutType;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.mediumGray.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                workoutType.icon,
                size: 18,
                color: AppColors.nearBlack,
              ),
              const SizedBox(width: 8),
              Text(
                workoutType.displayName,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.nearBlack,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

