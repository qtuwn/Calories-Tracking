import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/activities/activity.dart';
import '../state/activity_providers.dart';
import 'activity_form_page.dart';

/// Admin page for listing and managing activities
class ActivityListPage extends ConsumerStatefulWidget {
  const ActivityListPage({super.key});

  static const String routeName = '/admin/activities';

  @override
  ConsumerState<ActivityListPage> createState() => _ActivityListPageState();
}

class _ActivityListPageState extends ConsumerState<ActivityListPage> {
  String _searchQuery = '';
  ActivityCategory? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final activitiesAsync = _searchQuery.isEmpty
        ? ref.watch(allActivitiesProvider)
        : ref.watch(activitySearchProvider(
            (query: _searchQuery, category: _selectedCategory)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Hoạt động'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _navigateToForm(context),
            tooltip: 'Thêm hoạt động mới',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildCategoryFilter(),
          Expanded(
            child: activitiesAsync.when(
              data: (activities) => activities.isEmpty
                  ? _buildEmptyState()
                  : _buildActivityList(activities),
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
          hintText: 'Tìm kiếm hoạt động...',
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

  Widget _buildCategoryFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          _buildCategoryChip(null, 'Tất cả'),
          ...ActivityCategory.values.map(
            (category) => _buildCategoryChip(category, category.displayName),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(ActivityCategory? category, String label) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedCategory = selected ? category : null;
          });
        },
      ),
    );
  }

  Widget _buildActivityList(List<Activity> activities) {
    return ListView.builder(
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final activity = activities[index];
        return _buildActivityCard(activity);
      },
    );
  }

  Widget _buildActivityCard(Activity activity) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(activity.iconName ?? activity.name[0].toUpperCase()),
        ),
        title: Text(activity.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${activity.category.displayName} • ${activity.intensity.displayName}'),
            Text('MET: ${activity.met.toStringAsFixed(1)}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!activity.isActive)
              const Icon(Icons.visibility_off, color: Colors.grey),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _navigateToForm(context, activity),
            ),
          ],
        ),
        onTap: () => _navigateToForm(context, activity),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fitness_center, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Chưa có hoạt động nào',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _navigateToForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Thêm hoạt động đầu tiên'),
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

  void _navigateToForm(BuildContext context, [Activity? activity]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityFormPage(activity: activity),
      ),
    );
  }
}

