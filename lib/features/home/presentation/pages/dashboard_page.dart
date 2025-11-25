import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:calories_app/core/theme/theme.dart';
import '../widgets/home_activity_section.dart';
import '../widgets/home_calorie_card.dart';
import '../widgets/home_header_section.dart';
import '../widgets/home_macro_section.dart';
import '../widgets/home_recent_diary_section.dart';
import '../widgets/home_water_weight_section.dart';

class DashboardPage extends ConsumerWidget {
  final VoidCallback? onNavigateToDiary;

  const DashboardPage({
    super.key,
    this.onNavigateToDiary,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              const SizedBox(height: 24),
              HomeRecentDiarySection(
                onNavigateToDiary: onNavigateToDiary,
              ),
              const SizedBox(height: 24),
              const HomeActivitySection(),
              const SizedBox(height: 24),
              const HomeWaterWeightSection(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

