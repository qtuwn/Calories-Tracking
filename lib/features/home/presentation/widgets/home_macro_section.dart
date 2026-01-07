import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/home_dashboard_providers.dart';

/// PERFORMANCE: Container widget that doesn't watch any providers.
/// Provider watch is isolated to leaf widget only.
class HomeMacroSection extends StatelessWidget {
  const HomeMacroSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dinh dưỡng hôm nay',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          // PERFORMANCE: Isolate provider watch to leaf widget
          const _MacroProgressList(),
        ],
      ),
    );
  }
}

/// PERFORMANCE: Leaf widget that watches the provider.
/// Rebuilds ONLY when macro data changes, not on every diary update.
class _MacroProgressList extends ConsumerWidget {
  const _MacroProgressList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final macros = ref.watch(homeMacroSummaryProvider);

    return RepaintBoundary(
      child: Column(
        children: macros
            .map(
              (macro) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _MacroProgressRow(macro: macro),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _MacroProgressRow extends StatelessWidget {
  const _MacroProgressRow({required this.macro});

  final MacroProgress macro;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: macro.color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(macro.icon, color: macro.color),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    macro.label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${macro.consumed.toStringAsFixed(0)} / ${macro.target.toStringAsFixed(0)} ${macro.unit}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: macro.progress,
                  minHeight: 10,
                  backgroundColor: macro.color.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(macro.color),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
