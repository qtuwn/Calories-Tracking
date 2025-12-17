import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/home_dashboard_providers.dart';

class HomeMacroSection extends ConsumerStatefulWidget {
  const HomeMacroSection({super.key});

  @override
  ConsumerState<HomeMacroSection> createState() => _HomeMacroSectionState();
}

class _HomeMacroSectionState extends ConsumerState<HomeMacroSection> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // OPTIMIZATION: Defer provider watch to after first frame
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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 16),
          // Show skeleton until initialized
          if (!_initialized)
            ...List.generate(
              3,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _MacroSkeleton(),
              ),
            )
          else
            ...ref.watch(homeMacroSummaryProvider).map(
              (macro) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _MacroProgressRow(macro: macro),
              ),
            ),
        ],
      ),
    );
  }
}

class _MacroSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 16,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 10,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        ),
      ],
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
          child: Icon(
            macro.icon,
            color: macro.color,
          ),
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
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
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

