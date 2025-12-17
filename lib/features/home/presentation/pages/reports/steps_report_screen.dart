import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/statistics_providers.dart';
import '../../../domain/statistics_models.dart';
import '../../../../../core/theme/theme.dart';

/// Steps Report Screen
/// 
/// Displays daily/weekly/monthly step statistics including:
/// - Total steps taken
/// - Daily step goals and achievements
/// - Step trends and patterns
/// 
/// Navigation: Accessed from Account page "Xem báo cáo thống kê" > "Số bước"
class StepsReportScreen extends ConsumerWidget {
  const StepsReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayStatsAsync = ref.watch(todayStepsStatsProvider);
    final weekStatsAsync = ref.watch(weekStepsStatsProvider);
    final monthStatsAsync = ref.watch(monthStepsStatsProvider);
    final weekDailyAsync = ref.watch(weekDailyStepsProvider);
    final monthDailyAsync = ref.watch(monthDailyStepsProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Báo cáo số bước',
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
                    'Báo cáo này sẽ hiển thị thống kê số bước theo ngày, tuần và tháng, bao gồm tổng số bước đi, mục tiêu hàng ngày, và xu hướng hoạt động.',
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
              child: todayStatsAsync.when(
                data: (stats) => _buildTodayCard(context, stats),
                loading: () => _buildLoadingCard(context),
                error: (error, stack) => _buildErrorCard(context, error.toString()),
              ),
            ),
            const SizedBox(height: 24),

            // This week section
            _buildSection(
              context,
              title: 'Tuần này',
              child: Column(
                children: [
                  weekStatsAsync.when(
                    data: (stats) => _buildPeriodSummaryCard(context, stats, 'Tổng số bước tuần này'),
                    loading: () => _buildLoadingCard(context),
                    error: (error, stack) => _buildErrorCard(context, error.toString()),
                  ),
                  const SizedBox(height: 16),
                  weekDailyAsync.when(
                    data: (dailySteps) => _buildDailyStepsList(context, dailySteps, isWeek: true),
                    loading: () => _buildLoadingCard(context),
                    error: (error, stack) => _buildErrorCard(context, error.toString()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // This month section
            _buildSection(
              context,
              title: 'Tháng này',
              child: Column(
                children: [
                  monthStatsAsync.when(
                    data: (stats) => _buildPeriodSummaryCard(context, stats, 'Tổng số bước tháng này'),
                    loading: () => _buildLoadingCard(context),
                    error: (error, stack) => _buildErrorCard(context, error.toString()),
                  ),
                  const SizedBox(height: 16),
                  monthDailyAsync.when(
                    data: (dailySteps) => _buildDailyStepsList(context, dailySteps, isWeek: false),
                    loading: () => _buildLoadingCard(context),
                    error: (error, stack) => _buildErrorCard(context, error.toString()),
                  ),
                ],
              ),
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

  Widget _buildTodayCard(BuildContext context, StepsStats stats) {
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
            'Tổng số bước',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            '${stats.totalSteps}',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.charmingGreen,
                ),
          ),
          if (stats.targetSteps != null) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: stats.progress.clamp(0.0, 1.0),
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.charmingGreen),
            ),
            const SizedBox(height: 8),
            Text(
              'Mục tiêu: ${stats.targetSteps} bước',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPeriodSummaryCard(BuildContext context, StepsStats stats, String label) {
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
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            '${stats.totalSteps}',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.charmingGreen,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyStepsList(BuildContext context, Map<DateTime, int> dailySteps, {required bool isWeek}) {
    if (dailySteps.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Chưa có dữ liệu',
          style: TextStyle(color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      );
    }

    final sortedDays = dailySteps.keys.toList()..sort();
    final dateFormat = DateFormat('dd/MM');
    final weekdayFormat = DateFormat('EEE', 'vi');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
            isWeek ? 'Số bước theo ngày trong tuần' : 'Số bước theo ngày trong tháng',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          ...sortedDays.map((day) {
            final steps = dailySteps[day] ?? 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        SizedBox(
                          width: 60,
                          child: Text(
                            isWeek ? weekdayFormat.format(day) : dateFormat.format(day),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[700],
                                ),
                          ),
                        ),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: steps > 0 ? (steps / 10000).clamp(0.0, 1.0) : 0.0,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.charmingGreen),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$steps',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLoadingCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, String error) {
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
          Icon(Icons.error_outline, color: Colors.red[400]),
          const SizedBox(height: 8),
          Text(
            'Lỗi: $error',
            style: TextStyle(color: Colors.red[700]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

