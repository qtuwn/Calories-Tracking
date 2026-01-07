import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:calories_app/core/theme/theme.dart';
import '../providers/home_dashboard_providers.dart';

/// PERFORMANCE: Wrapper widget that doesn't watch any providers.
/// Only passes down the navigation callback to the actual data consumer.
class HomeRecentDiarySection extends StatelessWidget {
  final VoidCallback? onNavigateToDiary;

  const HomeRecentDiarySection({super.key, this.onNavigateToDiary});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Nhật ký gần đây',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            TextButton(
              onPressed: onNavigateToDiary,
              child: const Text('Xem tất cả'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // PERFORMANCE: Isolate provider watch to leaf widget only
        _RecentDiaryEntriesList(onNavigateToDiary: onNavigateToDiary),
      ],
    );
  }
}

/// PERFORMANCE: Leaf widget that watches the provider.
/// This isolates rebuilds to ONLY this widget when diary entries change.
class _RecentDiaryEntriesList extends ConsumerWidget {
  final VoidCallback? onNavigateToDiary;

  const _RecentDiaryEntriesList({this.onNavigateToDiary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(homeRecentDiaryEntriesProvider);

    if (entries.isEmpty) {
      return _DiaryEmptyState(onNavigateToDiary: onNavigateToDiary);
    }

    return RepaintBoundary(
      child: SizedBox(
        height: 150,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: entries.length,
          separatorBuilder: (_, __) => const SizedBox(width: 16),
          itemBuilder: (context, index) {
            final entry = entries[index];
            return _RecentDiaryCard(entry: entry);
          },
        ),
      ),
    );
  }
}

class _DiaryEmptyState extends StatelessWidget {
  final VoidCallback? onNavigateToDiary;

  const _DiaryEmptyState({this.onNavigateToDiary});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.charmingGreen.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            size: 40,
            color: AppColors.mediumGray,
          ),
          const SizedBox(height: 12),
          Text(
            'Chưa có dữ liệu',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Bắt đầu thêm bữa ăn để theo dõi dinh dưỡng mỗi ngày.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.mediumGray),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onNavigateToDiary,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mintGreen,
                foregroundColor: AppColors.nearBlack,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Thêm bữa ăn'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentDiaryCard extends StatelessWidget {
  const _RecentDiaryCard({required this.entry});

  final RecentDiaryEntry entry;

  @override
  Widget build(BuildContext context) {
    // Different colors for food vs exercise
    final iconBgColor = entry.isExercise
        ? Colors.orange.withValues(alpha: 0.2)
        : AppColors.mintGreen.withValues(alpha: 0.25);
    final iconColor = entry.isExercise ? Colors.orange : AppColors.nearBlack;
    final caloriesLabel = entry.isExercise ? 'Đốt cháy' : 'Calories';

    return Container(
      width: 200,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(entry.icon, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      entry.timeLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.mediumGray,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Text(
            entry.subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.mediumGray),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                caloriesLabel,
                style: const TextStyle(
                  color: AppColors.mediumGray,
                  fontSize: 12,
                ),
              ),
              Text(
                '${entry.calories} kcal',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: entry.isExercise ? Colors.orange : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
