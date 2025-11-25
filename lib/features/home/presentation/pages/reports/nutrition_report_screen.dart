import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calories_app/features/home/presentation/providers/statistics_providers.dart';
import 'package:calories_app/features/home/domain/statistics_models.dart';

/// Nutrition Report Screen
/// 
/// Displays daily/weekly/monthly nutrition statistics including:
/// - Total calories consumed
/// - Macro breakdown (protein, carbs, fat)
/// - Meal patterns and trends
/// 
/// Navigation: Accessed from Account page "Xem báo cáo thống kê" > "Dinh dưỡng"
class NutritionReportScreen extends ConsumerWidget {
  const NutritionReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Báo cáo dinh dưỡng',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Description card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
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
                  Text(
                    'Tổng quan',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Báo cáo này sẽ hiển thị thống kê dinh dưỡng theo ngày, tuần và tháng, bao gồm tổng lượng calo, phân tích đa lượng (protein, carb, fat), và xu hướng bữa ăn.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Today section
            _buildSection(
              context,
              title: 'Hôm nay',
              child: _buildTodaySection(context, ref),
            ),
            const SizedBox(height: 24),

            // This week section
            _buildSection(
              context,
              title: 'Tuần này',
              child: _buildWeekSection(context, ref),
            ),
            const SizedBox(height: 24),

            // This month section
            _buildSection(
              context,
              title: 'Tháng này',
              child: _buildMonthSection(context, ref),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, {required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }

  Widget _buildTodaySection(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(todayNutritionStatsProvider);

    return statsAsync.when(
      data: (stats) {
        if (stats.entryCount == 0) {
          return _buildEmptyState(context, 'Chưa có dữ liệu dinh dưỡng hôm nay');
        }

        return Column(
          children: [
            _buildNutritionSummaryCard(context, stats),
            const SizedBox(height: 16),
            _buildMacroBreakdownCard(context, stats),
          ],
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => _buildErrorState(context, error.toString(), () {
        ref.invalidate(todayNutritionStatsProvider);
      }),
    );
  }

  Widget _buildWeekSection(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(weekNutritionStatsProvider);

    return statsAsync.when(
      data: (stats) {
        if (stats.entryCount == 0) {
          return _buildEmptyState(context, 'Chưa có dữ liệu dinh dưỡng tuần này');
        }

        return Column(
          children: [
            _buildNutritionSummaryCard(context, stats),
            const SizedBox(height: 16),
            _buildMacroBreakdownCard(context, stats),
            // TODO: Add weekly trends chart here
          ],
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => _buildErrorState(context, error.toString(), () {
        ref.invalidate(weekNutritionStatsProvider);
      }),
    );
  }

  Widget _buildMonthSection(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(monthNutritionStatsProvider);

    return statsAsync.when(
      data: (stats) {
        if (stats.entryCount == 0) {
          return _buildEmptyState(context, 'Chưa có dữ liệu dinh dưỡng tháng này');
        }

        return Column(
          children: [
            _buildNutritionSummaryCard(context, stats),
            const SizedBox(height: 16),
            _buildMacroBreakdownCard(context, stats),
            // TODO: Add monthly trends chart here
          ],
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => _buildErrorState(context, error.toString(), () {
        ref.invalidate(monthNutritionStatsProvider);
      }),
    );
  }

  Widget _buildNutritionSummaryCard(BuildContext context, NutritionStats stats) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
              Text(
                'Tổng calo',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (stats.targetCalories != null)
                Text(
                  'Mục tiêu: ${stats.targetCalories!.toStringAsFixed(0)} kcal',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            stats.totalCalories.toStringAsFixed(0),
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
          ),
          Text(
            'kcal',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          if (stats.targetCalories != null) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: stats.progress.clamp(0, 1),
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                stats.isTargetMet ? Colors.green : Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              stats.isTargetMet
                  ? 'Đã đạt mục tiêu! (Dư ${stats.exceeded.toStringAsFixed(0)} kcal)'
                  : 'Còn ${stats.remaining.toStringAsFixed(0)} kcal để đạt mục tiêu',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: stats.isTargetMet ? Colors.green : Colors.grey[600],
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMacroBreakdownCard(BuildContext context, NutritionStats stats) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Text(
            'Phân tích đa lượng',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          _buildMacroRow(context, 'Chất đạm', stats.totalProtein, const Color(0xFF81C784)),
          const SizedBox(height: 12),
          _buildMacroRow(context, 'Đường bột', stats.totalCarbs, const Color(0xFF64B5F6)),
          const SizedBox(height: 12),
          _buildMacroRow(context, 'Chất béo', stats.totalFat, const Color(0xFFF48FB1)),
        ],
      ),
    );
  }

  Widget _buildMacroRow(BuildContext context, String label, double grams, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        Text(
          '${grams.toStringAsFixed(1)} g',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.restaurant_menu,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error, VoidCallback onRetry) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: Colors.red[400], size: 32),
          const SizedBox(height: 8),
          Text(
            'Lỗi tải dữ liệu',
            style: TextStyle(
              color: Colors.red[700],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            error,
            style: TextStyle(
              color: Colors.red[600],
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }
}

