import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:calories_app/core/theme/theme.dart';
import '../widgets/home_activity_section.dart';
import '../widgets/home_calorie_card.dart';
import '../widgets/home_header_section.dart';
import '../widgets/home_macro_section.dart';
import '../widgets/home_recent_diary_section.dart';
import '../widgets/home_water_weight_section.dart';

class DashboardPage extends ConsumerStatefulWidget {
  final VoidCallback? onNavigateToDiary;

  const DashboardPage({
    super.key,
    this.onNavigateToDiary,
  });

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  bool _showBelowFold = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _showBelowFold = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.palePink,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HomeHeaderSection(),
              const SizedBox(height: 24),
              const HomeCalorieCard(),
              const SizedBox(height: 20),
              const HomeMacroSection(),
              if (_showBelowFold) ...[
                const SizedBox(height: 24),
                HomeRecentDiarySection(
                  onNavigateToDiary: widget.onNavigateToDiary,
                ),
                const SizedBox(height: 24),
                const HomeActivitySection(),
                const SizedBox(height: 24),
                const HomeWaterWeightSection(),
                const SizedBox(height: 32),
              ] else ...[
                const SizedBox(height: 24),
                const _LoadingPlaceholder(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingPlaceholder extends StatelessWidget {
  const _LoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
