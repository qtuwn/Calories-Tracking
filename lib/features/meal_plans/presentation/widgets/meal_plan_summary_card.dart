import 'package:flutter/material.dart';
import 'package:calories_app/core/theme/app_colors.dart';

/// Reusable card widget for displaying meal plan summaries
/// 
/// This widget is purely presentational - it accepts primitive values.
/// All business logic (kcal calculations, macros, etc.) should be handled
/// by controllers and domain services before passing data to this widget.
class MealPlanSummaryCard extends StatelessWidget {
  const MealPlanSummaryCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.goalLabel,
    required this.dailyCalories,
    required this.durationDays,
    required this.mealsPerDay,
    this.proteinGrams,
    this.carbGrams,
    this.fatGrams,
    this.tags = const [],
    this.isActive = false,
    this.currentDayIndex,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final String goalLabel;
  final int dailyCalories;
  final int durationDays;
  final int mealsPerDay;
  final int? proteinGrams;
  final int? carbGrams;
  final int? fatGrams;
  final List<String> tags;
  final bool isActive;
  final int? currentDayIndex;
  final VoidCallback? onTap;

  Color _getGoalColor(String goalType) {
    switch (goalType) {
      case 'lose_fat':
        return const Color(0xFFFF6B6B);
      case 'muscle_gain':
        return const Color(0xFF4ECDC4);
      case 'vegan':
        return AppColors.charmingGreen;
      case 'maintain':
        return AppColors.palePink;
      default:
        return AppColors.mintGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final goalColor = _getGoalColor(goalLabel);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: isActive
                ? AppColors.mintGreen.withValues(alpha: 0.5)
                : goalColor.withValues(alpha: 0.25),
            width: isActive ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PlanBadge(color: goalColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.nearBlack,
                              ),
                            ),
                          ),
                          if (isActive) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.mintGreen.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Đang áp dụng',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.mintGreen,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.mediumGray,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.mediumGray,
                ),
              ],
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: tags.map((tag) => Chip(
                  label: Text(tag),
                  backgroundColor: goalColor.withValues(alpha: 0.18),
                  labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.nearBlack,
                    fontWeight: FontWeight.w600,
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )).toList(),
              ),
            ],
            if (proteinGrams != null || carbGrams != null || fatGrams != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  if (proteinGrams != null)
                    Expanded(
                      child: _MacroStat(
                        label: 'Protein',
                        value: '$proteinGrams g',
                        color: const Color(0xFF81C784),
                      ),
                    ),
                  if (proteinGrams != null && carbGrams != null)
                    const SizedBox(width: 12),
                  if (carbGrams != null)
                    Expanded(
                      child: _MacroStat(
                        label: 'Carb',
                        value: '$carbGrams g',
                        color: const Color(0xFF64B5F6),
                      ),
                    ),
                  if (carbGrams != null && fatGrams != null)
                    const SizedBox(width: 12),
                  if (fatGrams != null)
                    Expanded(
                      child: _MacroStat(
                        label: 'Fat',
                        value: '$fatGrams g',
                        color: const Color(0xFFF06292),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _InfoPill(
                    icon: Icons.local_fire_department_outlined,
                    label: '$dailyCalories kcal',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoPill(
                    icon: Icons.calendar_month_outlined,
                    label: currentDayIndex != null
                        ? 'Ngày $currentDayIndex/$durationDays'
                        : durationDays >= 7
                            ? '${(durationDays / 7).round()} tuần'
                            : '$durationDays ngày',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoPill(
                    icon: Icons.restaurant_outlined,
                    label: '$mealsPerDay bữa/ngày',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, AppColors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(
        Icons.menu_book_outlined,
        color: AppColors.nearBlack,
        size: 24,
      ),
    );
  }
}

class _MacroStat extends StatelessWidget {
  const _MacroStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
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
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.nearBlack,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.charmingGreen.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.nearBlack),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.nearBlack,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

