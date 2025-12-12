import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/meal_plans/explore_meal_plan.dart';
import '../../../../domain/meal_plans/meal_plan_goal_type.dart';
import '../state/explore_meal_plan_providers.dart'; // For allMealPlansProvider and mealPlanSearchProvider
import 'explore_meal_plan_form_page.dart';

/// Admin page for listing and managing explore meal plans
class ExploreMealPlanListPage extends ConsumerStatefulWidget {
  const ExploreMealPlanListPage({super.key});

  static const String routeName = '/admin/explore-meal-plans';

  @override
  ConsumerState<ExploreMealPlanListPage> createState() =>
      _ExploreMealPlanListPageState();
}

class _ExploreMealPlanListPageState
    extends ConsumerState<ExploreMealPlanListPage> {
  String _searchQuery = '';
  MealPlanGoalType? _selectedGoalType;
  bool _showUnpublished = false;

  @override
  Widget build(BuildContext context) {
    final plansAsync = _searchQuery.isEmpty && _selectedGoalType == null
        ? ref.watch(allMealPlansProvider)
        : ref.watch(mealPlanSearchProvider((
            query: _searchQuery.isEmpty ? null : _searchQuery,
            goalType: _selectedGoalType,
            minKcal: null,
            maxKcal: null,
            tags: null,
          )));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Thực đơn Khám phá'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _navigateToForm(context),
            tooltip: 'Thêm thực đơn mới',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilters(),
          Expanded(
            child: plansAsync.when(
              data: (plans) {
                final filteredPlans = _showUnpublished
                    ? plans
                    : plans.where((p) => p.isPublished).toList();
                return filteredPlans.isEmpty
                    ? _buildEmptyState()
                    : _buildPlanList(filteredPlans);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _buildErrorState(error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        decoration: const InputDecoration(
          hintText: 'Tìm kiếm thực đơn...',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          _buildGoalTypeChip(null, 'Tất cả'),
          ...MealPlanGoalType.values.map(
            (goalType) =>
                _buildGoalTypeChip(goalType, goalType.displayName),
          ),
          const SizedBox(width: 16),
          FilterChip(
            label: Text(_showUnpublished ? 'Hiện tất cả' : 'Chỉ đã xuất bản'),
            selected: _showUnpublished,
            onSelected: (selected) {
              setState(() {
                _showUnpublished = selected;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGoalTypeChip(MealPlanGoalType? goalType, String label) {
    final isSelected = _selectedGoalType == goalType;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedGoalType = selected ? goalType : null;
          });
        },
      ),
    );
  }

  Widget _buildPlanList(List<ExploreMealPlan> plans) {
    return ListView.builder(
      itemCount: plans.length,
      itemBuilder: (context, index) {
        final plan = plans[index];
        return _buildPlanCard(plan);
      },
    );
  }

  Widget _buildPlanCard(ExploreMealPlan plan) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: plan.isFeatured ? Colors.amber : Colors.blue,
          child: Text(plan.name[0].toUpperCase()),
        ),
        title: Text(plan.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${plan.goalType.displayName} • ${plan.templateKcal} kcal/ngày'),
            Text('${plan.durationDays} ngày • ${plan.mealsPerDay} bữa/ngày'),
            if (plan.tags.isNotEmpty)
              Wrap(
                spacing: 4,
                children: plan.tags
                    .take(3)
                    .map((tag) => Chip(
                          label: Text(tag, style: const TextStyle(fontSize: 10)),
                          padding: EdgeInsets.zero,
                        ))
                    .toList(),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!plan.isPublished)
              const Icon(Icons.visibility_off, color: Colors.grey, size: 20),
            if (plan.isFeatured)
              const Icon(Icons.star, color: Colors.amber, size: 20),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _navigateToForm(context, plan),
            ),
          ],
        ),
        onTap: () => _navigateToForm(context, plan),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_menu, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Chưa có thực đơn nào',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _navigateToForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Thêm thực đơn đầu tiên'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            'Lỗi khi tải danh sách',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _navigateToForm(BuildContext context, [ExploreMealPlan? plan]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExploreMealPlanFormPage(plan: plan),
      ),
    );
  }
}

