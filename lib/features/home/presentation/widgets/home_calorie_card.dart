import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:calories_app/core/theme/theme.dart';
import '../providers/home_dashboard_providers.dart';
import '../providers/water_intake_provider.dart';

class HomeCalorieCard extends ConsumerStatefulWidget {
  const HomeCalorieCard({super.key});

  @override
  ConsumerState<HomeCalorieCard> createState() => _HomeCalorieCardState();
}

class _HomeCalorieCardState extends ConsumerState<HomeCalorieCard> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // OPTIMIZATION: Defer heavy provider watches to after first frame
    // This prevents blocking initial render with Firestore streams
    Future.microtask(() {
      if (mounted && !_initialized) {
        setState(() {
          _initialized = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show skeleton/placeholder until providers are ready
    if (!_initialized) {
      return Container(
        height: 200,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1E2432),
              const Color(0xFF2A3040),
              AppColors.nearBlack.withValues(alpha: 0.85),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFAAF0D1)),
          ),
        ),
      );
    }

    // Now safe to watch heavy providers
    final summary = ref.watch(homeDailySummaryProvider);
    final waterState = ref.watch(dailyWaterIntakeProvider);
    final todayWaterMl = waterState.totalMl;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 360;
        final ringSize = isCompact ? 110.0 : 140.0;

        Widget content = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _CalorieTextBlock(
                summary: summary,
                todayWaterMl: todayWaterMl,
              ),
            ),
            SizedBox(width: isCompact ? 12 : 16),
            _CalorieProgressRing(summary: summary, diameter: ringSize),
          ],
        );

        if (isCompact) {
          content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CalorieTextBlock(summary: summary, todayWaterMl: todayWaterMl),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.center,
                child: _CalorieProgressRing(
                  summary: summary,
                  diameter: ringSize,
                ),
              ),
            ],
          );
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1E2432),
                const Color(0xFF2A3040),
                AppColors.nearBlack.withValues(alpha: 0.85),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: content,
        );
      },
    );
  }
}

class _CalorieTextBlock extends StatelessWidget {
  const _CalorieTextBlock({required this.summary, this.todayWaterMl = 0});

  final DailySummary summary;
  final int todayWaterMl;

  @override
  Widget build(BuildContext context) {
    // Use computed properties from DailySummary model (business logic moved out of widget)
    final exceeded = summary.exceeded;
    final remaining = summary.remaining;
    final isOverGoal = summary.isOverGoal;

    // Pink color for Fat macro (same as used in nutrition bars)
    const pinkFat = Color(0xFFF48FB1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mục tiêu calo',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 8),
        Text(
          isOverGoal ? 'Vượt mục tiêu' : 'Còn lại',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(
            text: isOverGoal
                ? exceeded.toStringAsFixed(0)
                : remaining.toStringAsFixed(0),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: isOverGoal ? pinkFat : Colors.white,
              fontWeight: FontWeight.w700,
            ),
            children: [
              TextSpan(
                text: ' kcal',
                style: TextStyle(
                  color: isOverGoal
                      ? pinkFat.withValues(alpha: 0.8)
                      : Colors.white70,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        // Show exceeded message when over goal
        if (isOverGoal) ...[
          const SizedBox(height: 8),
          Text(
            'Dư ${exceeded.toStringAsFixed(0)} kcal so với mục tiêu',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: pinkFat.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
        ],
        const SizedBox(height: 20),
        // 2x2 grid layout: Row 1 = Mục tiêu | Đã nạp, Row 2 = Tập luyện | Nước
        Column(
          children: [
            // Row 1: Mục tiêu | Đã nạp
            Row(
              children: [
                Expanded(
                  child: _CalorieStat(
                    label: 'Mục tiêu',
                    value: summary.goal,
                    color: Colors.white70,
                  ),
                ),
                Expanded(
                  child: _CalorieStat(
                    label: 'Đã nạp',
                    value: summary.consumed,
                    color: const Color(
                      0xFFF48FB1,
                    ), // Pink color matching Fat macro
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Row 2: Tập luyện | Nước
            Row(
              children: [
                Expanded(
                  child: _CalorieStat(
                    label: 'Tập luyện',
                    value: summary.burned,
                    color: const Color(0xFF81D4FA), // Blue color for exercise
                  ),
                ),
                Expanded(
                  child: _CalorieStat(
                    label: 'Nước',
                    value: null, // Water doesn't have a kcal value
                    waterMl: todayWaterMl,
                    color: AppColors.mintGreen, // Mint green for water
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _CalorieStat extends StatelessWidget {
  const _CalorieStat({
    required this.label,
    required this.color,
    this.value,
    this.waterMl,
  });

  final String label;
  final double? value; // Nullable for water stat
  final Color color;
  final int? waterMl;

  @override
  Widget build(BuildContext context) {
    // All labels use the same style
    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: Colors.white70,
    );

    // All values use the same base style
    final valueStyle = Theme.of(
      context,
    ).textTheme.bodyLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w600);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(height: 4),
        // Show water value if waterMl is provided, otherwise show kcal value
        if (waterMl != null)
          Text('$waterMl ml', style: valueStyle?.copyWith(color: color))
        else if (value != null)
          Text(
            '${value!.toStringAsFixed(0)} kcal',
            style: valueStyle?.copyWith(color: color),
          ),
      ],
    );
  }
}

class _CalorieProgressRing extends StatelessWidget {
  const _CalorieProgressRing({required this.summary, this.diameter = 140});

  final DailySummary summary;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: diameter,
      width: diameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            height: diameter,
            width: diameter,
            child: CircularProgressIndicator(
              value: summary.progress,
              strokeWidth: 14,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.mintGreen),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                summary.netIntake.toStringAsFixed(0),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'nạp ròng',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
