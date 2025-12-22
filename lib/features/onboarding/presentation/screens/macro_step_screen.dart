import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calories_app/core/theme/theme.dart';

import 'package:calories_app/features/onboarding/domain/onboarding_model.dart';
import 'package:calories_app/features/onboarding/domain/macro_utils.dart';
import 'package:calories_app/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:calories_app/features/onboarding/presentation/widgets/donut_chart_widget.dart';
import 'package:calories_app/features/onboarding/presentation/widgets/progress_indicator_widget.dart';
import 'target_intake_step_screen.dart';

class MacroStepScreen extends ConsumerStatefulWidget {
  const MacroStepScreen({super.key});

  @override
  ConsumerState<MacroStepScreen> createState() => _MacroStepScreenState();
}

class _MacroStepScreenState extends ConsumerState<MacroStepScreen> {
  // Shared reactive state for real-time macro updates
  late final ValueNotifier<double> _proteinPercentNotifier;
  late final ValueNotifier<double> _carbPercentNotifier;
  late final ValueNotifier<double> _fatPercentNotifier;

  @override
  void initState() {
    super.initState();
    final state = ref.read(onboardingControllerProvider);
    _proteinPercentNotifier = ValueNotifier(state.proteinPercent ?? 20.0);
    _carbPercentNotifier = ValueNotifier(state.carbPercent ?? 50.0);
    _fatPercentNotifier = ValueNotifier(state.fatPercent ?? 30.0);
  }

  @override
  void dispose() {
    _proteinPercentNotifier.dispose();
    _carbPercentNotifier.dispose();
    _fatPercentNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final targetKcal = state.targetKcal ?? 2000.0;

    // Use ValueNotifier values for real-time updates
    return ValueListenableBuilder<double>(
      valueListenable: _proteinPercentNotifier,
      builder: (context, proteinPercent, _) {
        return ValueListenableBuilder<double>(
          valueListenable: _carbPercentNotifier,
          builder: (context, carbPercent, _) {
            return ValueListenableBuilder<double>(
              valueListenable: _fatPercentNotifier,
              builder: (context, fatPercent, _) {
                return _buildContent(
                  context,
                  targetKcal,
                  proteinPercent,
                  carbPercent,
                  fatPercent,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    double targetKcal,
    double proteinPercent,
    double carbPercent,
    double fatPercent,
  ) {
    final state = ref.watch(onboardingControllerProvider);
    
    // Calculate grams
    final proteinGrams = (proteinPercent * targetKcal / 100) / 4;
    final carbGrams = (carbPercent * targetKcal / 100) / 4;
    final fatGrams = (fatPercent * targetKcal / 100) / 9;

    return Scaffold(
      backgroundColor: AppColors.palePink,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.nearBlack),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                'Phân bổ dinh dưỡng',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.nearBlack,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tỷ lệ protein, carb và fat trong chế độ ăn của bạn',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.mediumGray),
              ),
              const SizedBox(height: 32),

              // Progress indicator - use dynamic step from state
              ProgressIndicatorWidget(
                progress: state.currentStep / OnboardingModel.totalSteps,
              ),
              const SizedBox(height: 32),

              // Donut Chart
              Center(
                child: DonutChartWidget(
                  proteinPercent: proteinPercent,
                  carbPercent: carbPercent,
                  fatPercent: fatPercent,
                  size: 240,
                ),
              ),
              const SizedBox(height: 32),

              // Legend
              _MacroLegend(
                proteinPercent: proteinPercent,
                carbPercent: carbPercent,
                fatPercent: fatPercent,
                proteinGrams: proteinGrams,
                carbGrams: carbGrams,
                fatGrams: fatGrams,
              ),
              const SizedBox(height: 32),

              // Customize Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: () => _showCustomizeBottomSheet(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.mintGreen, width: 2),
                    foregroundColor: AppColors.nearBlack,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
                    ),
                  ),
                  child: Text(
                    'Tuỳ chỉnh mục tiêu',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.nearBlack,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Continue Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate to target intake step
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TargetIntakeStepScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mintGreen,
                    foregroundColor: AppColors.nearBlack,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
                    ),
                  ),
                  child: Text(
                    'Tiếp tục',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.nearBlack,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCustomizeBottomSheet(BuildContext context) {
    final state = ref.read(onboardingControllerProvider);
    final targetKcal = state.targetKcal ?? 2000.0;

    // Use current notifier values as starting point
    double proteinPercent = _proteinPercentNotifier.value;
    double carbPercent = _carbPercentNotifier.value;
    double fatPercent = _fatPercentNotifier.value;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          // Normalize macros to ensure total = exactly 100% before calculations
          final normalized = MacroUtils.normalizeMacros(
            proteinPercent: proteinPercent,
            carbPercent: carbPercent,
            fatPercent: fatPercent,
          );
          final normalizedProtein = normalized['proteinPercent']!;
          final normalizedCarb = normalized['carbPercent']!;
          final normalizedFat = normalized['fatPercent']!;

          // Calculate grams using normalized values
          final proteinGrams = (normalizedProtein * targetKcal / 100) / 4;
          final carbGrams = (normalizedCarb * targetKcal / 100) / 4;
          final fatGrams = (normalizedFat * targetKcal / 100) / 9;
          final total = normalizedProtein + normalizedCarb + normalizedFat;
          
          // Save button is always enabled since normalization guarantees total = 100
          final isValid = true;

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: AppColors.charmingGreen,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Title
                  Text(
                    'Tuỳ chỉnh phân bổ dinh dưỡng',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.nearBlack,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tổng phải bằng 100%',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.mediumGray,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Total percentage indicator
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isValid
                          ? AppColors.mintGreen.withValues(alpha: 0.2)
                          : AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      border: Border.all(
                        color: isValid ? AppColors.mintGreen : AppColors.error,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tổng',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: AppColors.nearBlack,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        Text(
                          '${total.toStringAsFixed(1)}%',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: isValid
                                    ? AppColors.mintGreen
                                    : AppColors.error,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Protein Slider
                  _MacroSlider(
                    label: 'Protein',
                    value: normalizedProtein,
                    color: const Color(0xFF4CAF50),
                    grams: proteinGrams,
                    onChanged: (value) {
                      setModalState(() {
                        final remaining = 100 - value;
                        final otherTotal = carbPercent + fatPercent;

                        if (otherTotal > 0 && remaining > 0) {
                          // Adjust carb and fat proportionally
                          final carbRatio = carbPercent / otherTotal;
                          final fatRatio = fatPercent / otherTotal;
                          carbPercent = remaining * carbRatio;
                          fatPercent = remaining * fatRatio;
                        } else {
                          // If other macros are 0, split remaining equally
                          carbPercent = remaining / 2;
                          fatPercent = remaining / 2;
                        }
                        proteinPercent = value;

                        // Normalize to ensure total = exactly 100
                        final normalized = MacroUtils.normalizeMacros(
                          proteinPercent: proteinPercent,
                          carbPercent: carbPercent,
                          fatPercent: fatPercent,
                        );
                        proteinPercent = normalized['proteinPercent']!;
                        carbPercent = normalized['carbPercent']!;
                        fatPercent = normalized['fatPercent']!;

                        // Update shared state for real-time donut chart update
                        // Use normalized values to ensure chart reflects exact 100% total
                        _proteinPercentNotifier.value = proteinPercent;
                        _carbPercentNotifier.value = carbPercent;
                        _fatPercentNotifier.value = fatPercent;
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  // Carb Slider
                  _MacroSlider(
                    label: 'Carb',
                    value: normalizedCarb,
                    color: const Color(0xFF2196F3),
                    grams: carbGrams,
                    onChanged: (value) {
                      setModalState(() {
                        final remaining = 100 - value;
                        final otherTotal = proteinPercent + fatPercent;

                        if (otherTotal > 0 && remaining > 0) {
                          // Adjust protein and fat proportionally
                          final proteinRatio = proteinPercent / otherTotal;
                          final fatRatio = fatPercent / otherTotal;
                          proteinPercent = remaining * proteinRatio;
                          fatPercent = remaining * fatRatio;
                        } else {
                          // If other macros are 0, split remaining equally
                          proteinPercent = remaining / 2;
                          fatPercent = remaining / 2;
                        }
                        carbPercent = value;

                        // Normalize to ensure total = exactly 100
                        final normalized = MacroUtils.normalizeMacros(
                          proteinPercent: proteinPercent,
                          carbPercent: carbPercent,
                          fatPercent: fatPercent,
                        );
                        proteinPercent = normalized['proteinPercent']!;
                        carbPercent = normalized['carbPercent']!;
                        fatPercent = normalized['fatPercent']!;

                        // Update shared state for real-time donut chart update
                        // Use normalized values to ensure chart reflects exact 100% total
                        _proteinPercentNotifier.value = proteinPercent;
                        _carbPercentNotifier.value = carbPercent;
                        _fatPercentNotifier.value = fatPercent;
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  // Fat Slider
                  _MacroSlider(
                    label: 'Fat',
                    value: normalizedFat,
                    color: const Color(0xFFFF9800),
                    grams: fatGrams,
                    onChanged: (value) {
                      setModalState(() {
                        final remaining = 100 - value;
                        final otherTotal = proteinPercent + carbPercent;

                        if (otherTotal > 0 && remaining > 0) {
                          // Adjust protein and carb proportionally
                          final proteinRatio = proteinPercent / otherTotal;
                          final carbRatio = carbPercent / otherTotal;
                          proteinPercent = remaining * proteinRatio;
                          carbPercent = remaining * carbRatio;
                        } else {
                          // If other macros are 0, split remaining equally
                          proteinPercent = remaining / 2;
                          carbPercent = remaining / 2;
                        }
                        fatPercent = value;

                        // Normalize to ensure total = exactly 100
                        final normalized = MacroUtils.normalizeMacros(
                          proteinPercent: proteinPercent,
                          carbPercent: carbPercent,
                          fatPercent: fatPercent,
                        );
                        proteinPercent = normalized['proteinPercent']!;
                        carbPercent = normalized['carbPercent']!;
                        fatPercent = normalized['fatPercent']!;

                        // Update shared state for real-time donut chart update
                        // Use normalized values to ensure chart reflects exact 100% total
                        _proteinPercentNotifier.value = proteinPercent;
                        _carbPercentNotifier.value = carbPercent;
                        _fatPercentNotifier.value = fatPercent;
                      });
                    },
                  ),
                  const SizedBox(height: 32),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: isValid
                          ? () {
                              // Normalize before saving to ensure exact 100%
                              final normalized = MacroUtils.normalizeMacros(
                                proteinPercent: proteinPercent,
                                carbPercent: carbPercent,
                                fatPercent: fatPercent,
                              );
                              
                              ref
                                  .read(onboardingControllerProvider.notifier)
                                  .updateMacros(
                                    proteinPercent: normalized['proteinPercent']!,
                                    carbPercent: normalized['carbPercent']!,
                                    fatPercent: normalized['fatPercent']!,
                                  );
                              
                              // Update notifiers to match saved values
                              _proteinPercentNotifier.value = normalized['proteinPercent']!;
                              _carbPercentNotifier.value = normalized['carbPercent']!;
                              _fatPercentNotifier.value = normalized['fatPercent']!;
                              
                              Navigator.of(context).pop();
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.mintGreen,
                        foregroundColor: AppColors.nearBlack,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMedium,
                          ),
                        ),
                      ),
                      child: Text(
                        'Lưu',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.nearBlack,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MacroLegend extends StatelessWidget {
  final double proteinPercent;
  final double carbPercent;
  final double fatPercent;
  final double proteinGrams;
  final double carbGrams;
  final double fatGrams;

  const _MacroLegend({
    required this.proteinPercent,
    required this.carbPercent,
    required this.fatPercent,
    required this.proteinGrams,
    required this.carbGrams,
    required this.fatGrams,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MacroLegendItem(
          label: 'Protein',
          percent: proteinPercent,
          grams: proteinGrams,
          color: const Color(0xFF4CAF50),
        ),
        const SizedBox(height: 16),
        _MacroLegendItem(
          label: 'Carb',
          percent: carbPercent,
          grams: carbGrams,
          color: const Color(0xFF2196F3),
        ),
        const SizedBox(height: 16),
        _MacroLegendItem(
          label: 'Fat',
          percent: fatPercent,
          grams: fatGrams,
          color: const Color(0xFFFF9800),
        ),
      ],
    );
  }
}

class _MacroLegendItem extends StatelessWidget {
  final String label;
  final double percent;
  final double grams;
  final Color color;

  const _MacroLegendItem({
    required this.label,
    required this.percent,
    required this.grams,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        side: BorderSide(color: AppColors.charmingGreen.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Color indicator
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 16),

            // Label and values
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.nearBlack,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${percent.toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.mediumGray,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '•',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.mediumGray,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${grams.toStringAsFixed(0)}g',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.mediumGray,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroSlider extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final double grams;
  final ValueChanged<double> onChanged;

  const _MacroSlider({
    required this.label,
    required this.value,
    required this.color,
    required this.grams,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.nearBlack,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Text(
              '${value.toStringAsFixed(1)}% • ${grams.toStringAsFixed(0)}g',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.nearBlack,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            inactiveTrackColor: color.withValues(alpha: 0.3),
            thumbColor: color,
            overlayColor: color.withValues(alpha: 0.2),
            trackHeight: 6,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
          ),
          child: Slider(
            value: value,
            min: 0,
            max: 100,
            divisions: 1000,
            label: '${value.toStringAsFixed(1)}%',
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
