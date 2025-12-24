import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:calories_app/core/theme/theme.dart';
import '../providers/diary_provider.dart';

class HomeHeaderSection extends ConsumerStatefulWidget {
  const HomeHeaderSection({super.key});

  @override
  ConsumerState<HomeHeaderSection> createState() => _HomeHeaderSectionState();
}

class _HomeHeaderSectionState extends ConsumerState<HomeHeaderSection> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // OPTIMIZATION: Defer provider watch to after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_initialized) {
        setState(() {
          _initialized = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Use lightweight default until initialized
    if (!_initialized) {
      final now = DateTime.now();
      final dateLabel = DateFormat('EEEE, dd/MM', 'vi')
          .format(now)
          .replaceFirstMapped(RegExp(r'^\w'), (m) => m[0]!.toUpperCase());
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hôm nay',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.mediumGray,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tổng quan',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.nearBlack,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            dateLabel,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.mediumGray,
                ),
          ),
        ],
      );
    }

    // Now safe to watch providers
    final diaryState = ref.watch(diaryProvider);
    final selectedDate = diaryState.selectedDate;
    final weekDays = _generateWeekDays(selectedDate);

    final dateLabel = DateFormat('EEEE, dd/MM', 'vi')
        .format(selectedDate)
        .replaceFirstMapped(RegExp(r'^\w'), (m) => m[0]!.toUpperCase());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hôm nay',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.mediumGray,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Tổng quan',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.nearBlack,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          dateLabel,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.mediumGray,
              ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 72,
          child: ListView.separated(
            padding: const EdgeInsets.only(right: 12),
            scrollDirection: Axis.horizontal,
            itemCount: weekDays.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final date = weekDays[index];
              final isSelected = _isSameDate(date, selectedDate);
              final label = _weekdayLabel(date.weekday);
              final day = date.day;

              return GestureDetector(
                onTap: () {
                  // Sync date selection with Diary tab
                  ref.read(diaryProvider.notifier).setSelectedDate(date);
                },
                child: SizedBox(
                  height: 60,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.mintGreen.withValues(alpha: 0.9)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: isSelected
                            ? AppColors.mintGreen
                            : AppColors.charmingGreen.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                color: isSelected
                                    ? AppColors.nearBlack
                                    : AppColors.mediumGray,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$day',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                color: isSelected
                                    ? AppColors.nearBlack
                                    : AppColors.mediumGray,
                                fontWeight: FontWeight.bold,
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
      ],
    );
  }

  List<DateTime> _generateWeekDays(DateTime selected) {
    final startOfWeek = selected.subtract(Duration(days: selected.weekday - 1));
    return List.generate(
      7,
      (index) {
        final current = startOfWeek.add(Duration(days: index));
        return DateTime(current.year, current.month, current.day);
      },
    );
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _weekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'T2';
      case DateTime.tuesday:
        return 'T3';
      case DateTime.wednesday:
        return 'T4';
      case DateTime.thursday:
        return 'T5';
      case DateTime.friday:
        return 'T6';
      case DateTime.saturday:
        return 'T7';
      case DateTime.sunday:
        return 'CN';
      default:
        return '';
    }
  }
}

