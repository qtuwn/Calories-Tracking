import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:calories_app/core/theme/theme.dart';
import 'package:calories_app/features/activity/data/activity_providers.dart';
import 'package:calories_app/features/exercise/ui/exercise_list_screen.dart';
import 'package:calories_app/features/home/domain/workout_type.dart';
import 'package:calories_app/features/home/presentation/widgets/workout_activity_chip.dart';
import 'package:calories_app/features/home/presentation/widgets/workout_quick_log_sheet.dart';
import '../providers/home_dashboard_providers.dart';
import '../providers/diary_provider.dart';

/// PERFORMANCE: Memoized categories list (static data, never changes)
const _activityCategories = [
  ActivityCategory(workoutType: WorkoutType.running),
  ActivityCategory(workoutType: WorkoutType.cycling),
  ActivityCategory(workoutType: WorkoutType.badminton),
  ActivityCategory(workoutType: WorkoutType.yoga),
  ActivityCategory(workoutType: WorkoutType.other),
];

/// PERFORMANCE: Container widget that doesn't watch any stream providers.
/// Static data is used directly, stream providers are isolated to leaf widgets.
class HomeActivitySection extends StatelessWidget {
  const HomeActivitySection({super.key});

  /// Handle tap on an activity chip.
  void _handleActivityChipTap(BuildContext context, WorkoutType workoutType) {
    if (workoutType == WorkoutType.other) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ExerciseListScreen()));
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => WorkoutQuickLogSheet(workoutType: workoutType),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // PERFORMANCE: Use const categories directly, no provider needed
    final categories = _activityCategories;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.nearBlack.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.charmingGreen.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Hoạt động tập luyện',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ExerciseListScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.more_horiz),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: categories
                .map(
                  (category) => WorkoutActivityChip(
                    workoutType: category.workoutType,
                    onTap: () =>
                        _handleActivityChipTap(context, category.workoutType),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isVertical = constraints.maxWidth < 420;
              if (isVertical) {
                return const Column(
                  children: [
                    _StepsCard(),
                    SizedBox(height: 16),
                    _WorkoutCard(),
                  ],
                );
              }

              return const Row(
                children: [
                  Expanded(child: _StepsCard()),
                  SizedBox(width: 16),
                  Expanded(child: _WorkoutCard()),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StepsCard extends ConsumerStatefulWidget {
  const _StepsCard();

  @override
  ConsumerState<_StepsCard> createState() => _StepsCardState();
}

class _StepsCardState extends ConsumerState<_StepsCard> {
  bool _isLoading = false;

  Future<void> _handleConnect() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(activityControllerProvider.notifier).connectAndSync();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleRefresh() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(activityControllerProvider.notifier).refreshToday();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activityState = ref.watch(activityControllerProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(10),
                child: const Icon(
                  Icons.directions_walk,
                  color: Color(0xFF43A047),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Bước chân',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (activityState.connected)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đã kết nối Health Connect',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.mediumGray),
                ),
                const SizedBox(height: 8),
                Text(
                  '${activityState.steps}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.nearBlack,
                  ),
                ),
                Text(
                  'bước hôm nay',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.mediumGray),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _isLoading ? null : _handleRefresh,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 18),
                  label: const Text('Làm mới'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.mintGreen,
                  ),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kết nối Health Connect để tự động cập nhật',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.mediumGray),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _handleConnect,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.link),
                  label: const Text('Kết nối ngay'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.nearBlack,
                    side: const BorderSide(color: AppColors.charmingGreen),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _WorkoutCard extends ConsumerWidget {
  const _WorkoutCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use selective watching to prevent unnecessary rebuilds
    final calories = ref.watch(
      diaryProvider.select((s) => s.totalCaloriesBurned),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF212531), Color(0xFF1B1F29)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tập luyện',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                onPressed: () {
                  // Navigate to manual exercise list screen to add/log workout
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ExerciseListScreen(),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: AppColors.mintGreen,
                ),
              ),
            ],
          ),
          Text(
            '${calories.toStringAsFixed(0)} kcal',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'Đã đốt hôm nay',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
