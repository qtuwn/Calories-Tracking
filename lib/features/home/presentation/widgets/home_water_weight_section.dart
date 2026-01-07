import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

import 'package:calories_app/features/home/domain/statistics_models.dart';

import 'package:calories_app/core/theme/theme.dart';
import 'package:calories_app/features/home/presentation/widgets/water_custom_amount_sheet.dart';
import 'package:calories_app/features/home/presentation/widgets/update_weight_sheet.dart';
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
            children: [_WaterCard(), SizedBox(height: 16), _WeightCard()],
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
    // Use selective watching to prevent unnecessary rebuilds
    final totalMl = ref.watch(
      dailyWaterIntakeProvider.select((s) => s.totalMl),
    );
    final goalMl = ref.watch(dailyWaterIntakeProvider.select((s) => s.goalMl));

    // Reconstruct minimal water state locally
    final waterState = DailyWaterIntakeState(
      totalMl: totalMl,
      goalMl: goalMl,
      isLoading: false, // Not used in this widget
      entries: [], // Not used in this widget
    );

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
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.mediumGray),
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

/// Optimized weight chart widget with proper height separation.
///
/// LAYOUT FIX: Chart canvas and labels are in separate regions (Column),
/// NOT overlaid (Stack). This ensures the CustomPainter receives ONLY
/// the chart's drawable height, not the total height including labels.
class _WeightChart extends StatelessWidget {
  final List<WeightPoint> points;
  final double height;

  const _WeightChart({required this.points, required this.height});

  // Fixed heights for proper layout separation
  static const double _labelHeight = 20.0;
  static const double _labelSpacing = 4.0;

  // Cache expensive resources to prevent recreation
  static final DateFormat _dateFormatter = DateFormat('E', 'vi');
  static const TextStyle _cachedTextStyle = TextStyle(
    color: AppColors.mediumGray,
    fontSize: 12,
  );

  @override
  Widget build(BuildContext context) {
    // Calculate the actual chart height (total height minus label region)
    final chartHeight = height - _labelHeight - _labelSpacing;

    return RepaintBoundary(
      child: SizedBox(
        height: height,
        width: double.infinity,
        // LAYOUT FIX: Use Column to separate chart and labels vertically
        // This ensures CustomPainter only receives chartHeight, not total height
        child: Column(
          children: [
            // Region 1: Chart canvas (receives ONLY chartHeight)
            SizedBox(
              height: chartHeight,
              width: double.infinity,
              child: CustomPaint(
                painter: _WeightTrendPainter(points),
                size: Size.infinite,
              ),
            ),
            // Spacing between chart and labels
            const SizedBox(height: _labelSpacing),
            // Region 2: Labels (fixed height, separate from chart)
            SizedBox(
              height: _labelHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _buildLabels(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildLabels() {
    return List.generate(points.length, (index) {
      final point = points[index];
      return Text(
        _dateFormatter.format(point.date),
        style: _cachedTextStyle,
        textAlign: TextAlign.center,
      );
    });
  }
}

class _WeightCard extends ConsumerStatefulWidget {
  const _WeightCard();

  @override
  ConsumerState<_WeightCard> createState() => _WeightCardState();
}

class _WeightCardState extends ConsumerState<_WeightCard> {
  // Cache DateFormat to prevent recreation on every build
  static final DateFormat _dateFormatter = DateFormat('dd/MM', 'vi');

  /// Convert WeightEntry to WeightPoint for chart compatibility
  WeightPoint _entryToPoint(WeightEntry entry) {
    return WeightPoint(date: entry.date, weight: entry.weightKg);
  }

  @override
  Widget build(BuildContext context) {
    // Use selective watching to prevent unnecessary rebuilds
    final latestWeightAsync = ref.watch(latestWeightProvider);
    final recentWeightsAsync = ref.watch(recentWeights30DaysProvider);

    // Pre-convert chart data outside async builders to prevent rebuilds
    final chartPoints = recentWeightsAsync.maybeWhen(
      data: (entries) {
        final validEntries = entries.where((entry) {
          final weight = entry.weightKg;
          return !weight.isNaN && !weight.isInfinite && weight > 0;
        }).toList();

        if (validEntries.isEmpty) return <WeightPoint>[];
        return validEntries.map(_entryToPoint).toList();
      },
      orElse: () => <WeightPoint>[],
    );

    // Use cached DateFormat

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
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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

              final lastDateLabel = _dateFormatter.format(latestWeight.date);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        latestWeight.weightKg.toStringAsFixed(1),
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(fontWeight: FontWeight.w700),
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
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.red),
            ),
          ),
          const SizedBox(height: 20),
          // Chart section - fixed height for performance
          if (chartPoints.isEmpty)
            const SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  'Chưa có dữ liệu biểu đồ',
                  style: TextStyle(color: Color(0xFF666666), fontSize: 14),
                ),
              ),
            )
          else
            _WeightChart(points: chartPoints, height: 120),
        ],
      ),
    );
  }
}

/// CustomPainter for the weight trend chart.
///
/// GEOMETRY FIX: This painter no longer stores canvasSize via constructor.
/// It uses ONLY the Size provided in paint(canvas, size) and calculates
/// Y positions using explicit topPadding/bottomPadding within the drawable area.
class _WeightTrendPainter extends CustomPainter {
  final List<WeightPoint> points;

  // Padding for the drawable area within the canvas
  static const double _topPadding = 8.0;
  static const double _bottomPadding = 8.0;
  static const double _leftPadding = 8.0;
  static const double _rightPadding = 8.0;

  // Paints (initialized once, reused)
  final Paint _linePaint;
  final Paint _fillPaint;
  final Paint _pointPaint;

  _WeightTrendPainter(this.points)
    : _linePaint = Paint()
        ..color = AppColors.mintGreen
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true,
      _fillPaint = Paint()
        ..color = AppColors.mintGreen.withValues(alpha: 0.2)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
      _pointPaint = Paint()
        ..color = AppColors.mintGreen
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    // Guard: Empty list or invalid size
    if (points.isEmpty || size.width <= 0 || size.height <= 0) {
      return;
    }

    // Calculate drawable area (respecting padding)
    final drawableWidth = size.width - _leftPadding - _rightPadding;
    final drawableHeight = size.height - _topPadding - _bottomPadding;

    if (drawableWidth <= 0 || drawableHeight <= 0) return;

    // Collect valid weights
    final validWeights = <double>[];
    final validPoints = <WeightPoint>[];

    for (final point in points) {
      final weight = point.weight;
      if (!weight.isNaN && !weight.isInfinite && weight > 0) {
        validWeights.add(weight);
        validPoints.add(point);
      }
    }

    if (validWeights.isEmpty) return;

    // Calculate min/max for normalization
    final minWeight = validWeights.reduce((a, b) => a < b ? a : b);
    final maxWeight = validWeights.reduce((a, b) => a > b ? a : b);
    double range = maxWeight - minWeight;
    if (range <= 0) range = 0.5; // Minimum range for identical weights

    // Calculate point offsets
    final pointOffsets = <Offset>[];
    final linePath = Path();
    final fillPath = Path();

    // Handle single point case
    if (validPoints.length == 1) {
      final weight = validPoints.first.weight;
      final normalized = (weight - minWeight) / range;
      final x = _leftPadding + drawableWidth / 2;
      // GEOMETRY FIX: y = topPadding + (1 - normalized) * drawableHeight
      // This ensures the chart is drawn within the drawable area only
      final y = _topPadding + (1 - normalized) * drawableHeight;

      if (!x.isNaN && !y.isNaN && !x.isInfinite && !y.isInfinite) {
        pointOffsets.add(Offset(x, y));
        // Draw horizontal line to indicate flat trend
        linePath.moveTo(_leftPadding + drawableWidth * 0.2, y);
        linePath.lineTo(_leftPadding + drawableWidth * 0.8, y);
      }
    } else {
      // Handle multiple points
      for (var i = 0; i < validPoints.length; i++) {
        final weight = validPoints[i].weight;
        final x = _leftPadding + drawableWidth * (i / (validPoints.length - 1));
        final normalized = (weight - minWeight) / range;
        // GEOMETRY FIX: Correct Y-axis calculation
        // y = topPadding + (1 - normalized) * drawableHeight
        // When normalized=1 (max weight): y = topPadding (top of drawable area)
        // When normalized=0 (min weight): y = topPadding + drawableHeight (bottom)
        final y = _topPadding + (1 - normalized) * drawableHeight;

        if (!x.isNaN && !y.isNaN && !x.isInfinite && !y.isInfinite) {
          pointOffsets.add(Offset(x, y));

          if (i == 0) {
            linePath.moveTo(x, y);
            fillPath.moveTo(
              x,
              _topPadding + drawableHeight,
            ); // Bottom of drawable area
            fillPath.lineTo(x, y);
          } else {
            linePath.lineTo(x, y);
            fillPath.lineTo(x, y);
          }
        }
      }

      // Close fill path at the bottom of drawable area
      if (linePath.computeMetrics().isNotEmpty && pointOffsets.isNotEmpty) {
        fillPath.lineTo(pointOffsets.last.dx, _topPadding + drawableHeight);
        fillPath.close();
      }
    }

    // Draw fill first (behind line)
    if (fillPath.computeMetrics().isNotEmpty) {
      canvas.drawPath(fillPath, _fillPaint);
    }

    // Draw line
    if (linePath.computeMetrics().isNotEmpty) {
      canvas.drawPath(linePath, _linePaint);
    }

    // Draw points
    for (final offset in pointOffsets) {
      canvas.drawCircle(offset, 4, _pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WeightTrendPainter oldDelegate) {
    // Only repaint if the actual data changed
    return !const DeepCollectionEquality().equals(oldDelegate.points, points);
  }
}
