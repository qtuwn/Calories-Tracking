import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calories_app/features/home/presentation/providers/statistics_providers.dart';
import 'package:calories_app/features/home/domain/statistics_models.dart';

/// Weight Report Screen
/// 
/// Displays daily/weekly/monthly weight statistics including:
/// - Weight trends and progress
/// - Weight change over time
/// - Goal progress visualization
/// 
/// Navigation: Accessed from Account page "Xem báo cáo thống kê" > "Cân nặng"
class WeightReportScreen extends ConsumerWidget {
  const WeightReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Báo cáo cân nặng',
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
                    'Báo cáo này sẽ hiển thị thống kê cân nặng theo ngày, tuần và tháng, bao gồm xu hướng cân nặng, tiến độ mục tiêu, và biểu đồ thay đổi theo thời gian.',
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
    final statsAsync = ref.watch(todayWeightStatsProvider);

    return statsAsync.when(
      data: (stats) {
        if (stats.latestWeight == null) {
          return _buildEmptyState(context, 'Chưa có dữ liệu cân nặng hôm nay');
        }
        return _buildWeightSummaryCard(context, stats, isToday: true);
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => _buildErrorState(context, error.toString(), () {
        ref.invalidate(todayWeightStatsProvider);
      }),
    );
  }

  Widget _buildWeekSection(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(weekWeightStatsProvider);

    return statsAsync.when(
      data: (stats) {
        if (stats.entryCount == 0) {
          return _buildEmptyState(context, 'Chưa có dữ liệu cân nặng tuần này');
        }
        return _buildWeightSummaryCard(context, stats, isToday: false);
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => _buildErrorState(context, error.toString(), () {
        ref.invalidate(weekWeightStatsProvider);
      }),
    );
  }

  Widget _buildMonthSection(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(monthWeightStatsProvider);

    return statsAsync.when(
      data: (stats) {
        if (stats.entryCount == 0) {
          return _buildEmptyState(context, 'Chưa có dữ liệu cân nặng tháng này');
        }
        return _buildWeightSummaryCard(context, stats, isToday: false);
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => _buildErrorState(context, error.toString(), () {
        ref.invalidate(monthWeightStatsProvider);
      }),
    );
  }

  Widget _buildWeightSummaryCard(BuildContext context, WeightStats stats, {required bool isToday}) {
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
          // Current weight
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cân nặng hiện tại',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (stats.targetWeight != null)
                Text(
                  'Mục tiêu: ${stats.targetWeight!.toStringAsFixed(1)} kg',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            stats.latestWeight!.toStringAsFixed(1),
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
          ),
          Text(
            'kg',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          
          // Change indicator
          if (isToday && stats.changeVsPrevious != null) ...[
            const SizedBox(height: 16),
            _buildChangeRow(
              context,
              stats.changeVsPrevious! > 0
                  ? '+${stats.changeVsPrevious!.toStringAsFixed(1)} kg so với hôm qua'
                  : '${stats.changeVsPrevious!.toStringAsFixed(1)} kg so với hôm qua',
              stats.changeVsPrevious! > 0 ? Colors.red : Colors.green,
            ),
          ] else if (!isToday && stats.weightChange != null) ...[
            const SizedBox(height: 16),
            _buildChangeRow(
              context,
              stats.weightChange! > 0
                  ? '+${stats.weightChange!.toStringAsFixed(1)} kg'
                  : '${stats.weightChange!.toStringAsFixed(1)} kg',
              stats.isWeightGain ? Colors.red : Colors.green,
            ),
            const SizedBox(height: 8),
            Text(
              stats.trendLabel,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
          
          // Progress to goal
          if (stats.targetWeight != null && stats.progressToGoal != null) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: stats.progressToGoal!.clamp(0, 1),
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            const SizedBox(height: 8),
            Text(
              'Tiến độ: ${(stats.progressToGoal! * 100).toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
          
          // Start and end weights for week/month
          if (!isToday && stats.earliestWeight != null) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cân nặng đầu kỳ',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    Text(
                      '${stats.earliestWeight!.toStringAsFixed(1)} kg',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Cân nặng cuối kỳ',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    Text(
                      '${stats.latestWeight!.toStringAsFixed(1)} kg',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ],
          
          // TODO: Add simple weight trend chart here using weightHistory
        ],
      ),
    );
  }

  Widget _buildChangeRow(BuildContext context, String text, Color color) {
    return Row(
      children: [
        Icon(
          color == Colors.green ? Icons.trending_down : Icons.trending_up,
          color: color,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
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
            Icons.monitor_weight,
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

