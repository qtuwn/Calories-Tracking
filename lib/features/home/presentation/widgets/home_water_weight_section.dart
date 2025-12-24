import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:calories_app/core/theme/theme.dart';
import 'package:calories_app/features/home/presentation/widgets/water_custom_amount_sheet.dart';
import 'package:calories_app/features/home/presentation/widgets/update_weight_sheet.dart';
import '../providers/home_dashboard_providers.dart';
import '../providers/water_intake_provider.dart';
import '../providers/weight_providers.dart';
import 'package:calories_app/features/home/domain/weight_entry.dart';

class HomeWaterWeightSection extends StatelessWidget {
  const HomeWaterWeightSection({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isVertical = constraints.maxWidth < 420;

        if (isVertical) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _WaterCard(),
              SizedBox(height: 16),
              _WeightCard(),
            ],
          );
        }

        return const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _WaterCard()),
            SizedBox(width: 16),
            Expanded(child: _WeightCard()),
          ],
        );
      },
    );
  }
}

class _WaterCard extends ConsumerStatefulWidget {
  const _WaterCard();

  @override
  ConsumerState<_WaterCard> createState() => _WaterCardState();
}

class _WaterCardState extends ConsumerState<_WaterCard> {
  bool _isLoading = false;

  /// Handle quick add 250ml button tap
  Future<void> _handleQuickAdd250() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(dailyWaterIntakeProvider.notifier).addQuick250();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Handle quick add 500ml button tap
  Future<void> _handleQuickAdd500() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(dailyWaterIntakeProvider.notifier).addQuick500();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Handle custom amount tap
  void _handleCustomAmount() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const WaterCustomAmountSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final waterState = ref.watch(dailyWaterIntakeProvider);

    return GestureDetector(
      onTap: _handleCustomAmount,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.mintGreen.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.water_drop,
                    color: AppColors.mintGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Uống nước',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: _handleCustomAmount,
                  icon: const Icon(Icons.add_circle_outline),
                  color: AppColors.mintGreen,
                  tooltip: 'Thêm tùy chỉnh',
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (waterState.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              Text(
                '${waterState.totalMl} ml',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(
                'Mục tiêu ${waterState.goalMl} ml',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.mediumGray,
                    ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LinearProgressIndicator(
                  value: waterState.progress,
                  minHeight: 12,
                  backgroundColor: AppColors.mintGreen.withValues(alpha: 0.12),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.mintGreen,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _handleQuickAdd250,
                      icon: const Icon(Icons.local_drink_outlined),
                      label: const Text('+250 ml'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.nearBlack,
                        side: const BorderSide(color: AppColors.charmingGreen),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _handleQuickAdd500,
                      icon: const Icon(Icons.water),
                      label: const Text('+500 ml'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.mintGreen,
                        foregroundColor: AppColors.nearBlack,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WeightCard extends ConsumerWidget {
  const _WeightCard();

  /// Convert WeightEntry to WeightPoint for chart compatibility
  WeightPoint _entryToPoint(WeightEntry entry) {
    return WeightPoint(
      date: entry.date,
      weight: entry.weightKg,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latestWeightAsync = ref.watch(latestWeightProvider);
    final recentWeightsAsync = ref.watch(recentWeights7DaysProvider);
    final formatter = DateFormat('dd/MM', 'vi');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 6),
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
                'Cân nặng gần nhất',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              TextButton(
                onPressed: () {
                  // Get initial weight from latest entry
                  final latestWeight = latestWeightAsync.value;
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => UpdateWeightSheet(
                      initialWeight: latestWeight?.weightKg,
                    ),
                  );
                },
                child: const Text('Cập nhật'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Display latest weight or empty state
          latestWeightAsync.when(
            data: (latestWeight) {
              if (latestWeight == null) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chưa có cân nặng nào',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.mediumGray,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Nhấn "Cập nhật" để thêm cân nặng đầu tiên',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.mediumGray,
                          ),
                    ),
                  ],
                );
              }

              final lastDateLabel = formatter.format(latestWeight.date);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        latestWeight.weightKg.toStringAsFixed(1),
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'kg',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.mediumGray,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cập nhật $lastDateLabel',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.mediumGray,
                        ),
                  ),
                ],
              );
            },
            loading: () => const SizedBox(
              height: 40,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stack) => Text(
              'Lỗi tải dữ liệu',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.red,
                  ),
            ),
          ),
          const SizedBox(height: 20),
          // Chart section
          SizedBox(
            height: 120,
            child: recentWeightsAsync.when(
              data: (entries) {
                // Guard: Empty list - show placeholder
                if (entries.isEmpty) {
                  return Center(
                    child: Text(
                      'Chưa có dữ liệu biểu đồ',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.mediumGray,
                          ),
                    ),
                  );
                }

                // Convert WeightEntry to WeightPoint for chart
                // Filter out any invalid entries (NaN or infinite weights)
                final validEntries = entries.where((entry) {
                  final weight = entry.weightKg;
                  return !weight.isNaN && !weight.isInfinite && weight > 0;
                }).toList();

                // Guard: After filtering, check if we still have valid data
                if (validEntries.isEmpty) {
                  return Center(
                    child: Text(
                      'Dữ liệu không hợp lệ',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.mediumGray,
                          ),
                    ),
                  );
                }

                final points = validEntries.map(_entryToPoint).toList();

                // Guard: Ensure we have at least one valid point before rendering
                if (points.isEmpty) {
                  return Center(
                    child: Text(
                      'Chưa có dữ liệu biểu đồ',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.mediumGray,
                          ),
                    ),
                  );
                }

                return CustomPaint(
                  painter: _WeightTrendPainter(points),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(points.length, (index) {
                        final point = points[index];
                        return Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const SizedBox(height: 90),
                              Text(
                                DateFormat('E', 'vi').format(point.date),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppColors.mediumGray,
                                    ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text(
                  'Lỗi tải biểu đồ',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.red,
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeightTrendPainter extends CustomPainter {
  _WeightTrendPainter(this.points);

  final List<WeightPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    // Guard: Empty list - do not draw anything
    if (points.isEmpty) {
      return;
    }

    // Guard: Validate size to prevent NaN
    if (size.width <= 0 || size.height <= 0 || size.width.isNaN || size.height.isNaN) {
      return;
    }

    final paint = Paint()
      ..color = AppColors.mintGreen
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = AppColors.mintGreen.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    // Calculate min/max weights with safety checks
    // First, collect all valid weights
    final validWeights = <double>[];
    
    for (final point in points) {
      final weight = point.weight;
      // Guard: Skip invalid weights
      if (weight.isNaN || weight.isInfinite || weight <= 0) {
        continue;
      }
      validWeights.add(weight);
    }

    // Guard: Ensure we found at least one valid weight
    if (validWeights.isEmpty) {
      return;
    }

    // Calculate min/max from valid weights
    final minWeight = validWeights.reduce((a, b) => a < b ? a : b);
    final maxWeight = validWeights.reduce((a, b) => a > b ? a : b);

    // Calculate range with protection against division by zero
    // If all weights are identical, use a minimum range to avoid division by zero
    double range = maxWeight - minWeight;
    if (range <= 0) {
      // All weights are identical - draw a flat line at center
      range = 0.5; // Use minimum range for normalization
    }

    // Guard: Ensure range is valid and not zero
    if (range.isNaN || range.isInfinite || range <= 0) {
      range = 0.5;
    }

    final path = Path();
    final fillPath = Path();

    // Handle single point case
    if (points.length == 1) {
      final point = points.first;
      final weight = point.weight;
      
      // Guard: Skip invalid weight
      if (weight.isNaN || weight.isInfinite) {
        return;
      }

      // Draw single centered point
      final x = size.width / 2;
      final normalized = (weight - minWeight) / range;
      final y = size.height - (normalized * size.height * 0.8) - size.height * 0.1;

      // Guard: Ensure coordinates are valid before drawing
      if (x.isNaN || y.isNaN || x.isInfinite || y.isInfinite) {
        return;
      }

      final offset = Offset(x, y);
      canvas.drawCircle(offset, 4, Paint()..color = AppColors.mintGreen);
      
      // Draw a small horizontal line to indicate flat trend
      path.moveTo(size.width * 0.2, y);
      path.lineTo(size.width * 0.8, y);
      canvas.drawPath(path, paint);
      
      return;
    }

    // Multiple points - draw line chart
    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final weight = point.weight;
      
      // Guard: Skip invalid weights
      if (weight.isNaN || weight.isInfinite) {
        continue;
      }

      // Calculate x position - protect against division by zero
      final x = size.width * (i / (points.length - 1));
      
      // Calculate normalized weight position
      final normalized = (weight - minWeight) / range;
      final y = size.height - (normalized * size.height * 0.8) - size.height * 0.1;

      // Guard: Ensure coordinates are valid before using them
      if (x.isNaN || y.isNaN || x.isInfinite || y.isInfinite) {
        continue;
      }

      final offset = Offset(x, y);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }

      // Draw point circle
      canvas.drawCircle(offset, 4, Paint()..color = AppColors.mintGreen);
    }

    // Only draw paths if we have valid points
    if (path.computeMetrics().isNotEmpty) {
      fillPath.lineTo(size.width, size.height);
      fillPath.close();
      canvas.drawPath(fillPath, fillPaint);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

