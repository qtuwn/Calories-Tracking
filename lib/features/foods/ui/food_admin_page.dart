import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:calories_app/domain/foods/food.dart';
import 'package:calories_app/shared/state/food_providers.dart' as food_providers;
import 'package:calories_app/features/foods/data/food_providers.dart'; // For foodCategoryFilterProvider
import 'package:calories_app/features/foods/data/food_categories.dart';
import 'package:calories_app/core/theme/app_colors.dart';
import 'package:calories_app/shared/state/auth_providers.dart';

/// Admin-only page for managing the food catalog
class FoodAdminPage extends ConsumerWidget {
  static const routeName = '/food-admin';

  const FoodAdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;

    // Guard: user must be signed in
    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.palePink,
        appBar: AppBar(
          backgroundColor: AppColors.palePink,
          title: const Text('Không có quyền truy cập'),
        ),
        body: const Center(child: Text('Vui lòng đăng nhập để tiếp tục')),
      );
    }

    final profileAsync = ref.watch(currentProfileProvider(user.uid));

    return profileAsync.when(
      data: (profile) {
        // Check admin access using centralized provider
        final isAdmin = profile?.isAdmin ?? false;

        debugPrint(
          '[FoodAdminPage] 🔍 Admin check: uid=${user.uid}, role=${profile?.role}, isAdmin=$isAdmin',
        );

        if (!isAdmin) {
          return Scaffold(
            backgroundColor: AppColors.palePink,
            appBar: AppBar(
              backgroundColor: AppColors.palePink,
              title: const Text('Không có quyền truy cập'),
            ),
            body: const Center(
              child: Text('Bạn không có quyền truy cập tính năng này'),
            ),
          );
        }

        // User is admin, show the admin page
        return _buildAdminPage(context, ref);
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.palePink,
          title: const Text('Error'),
        ),
        body: Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildAdminPage(BuildContext context, WidgetRef ref) {
    final foodsAsync = ref.watch(food_providers.allFoodsProvider);
    final selectedCategory = ref.watch(foodCategoryFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.palePink,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: AppBar(
          backgroundColor: AppColors.palePink,
          elevation: 0,
          leadingWidth: 72,
          leading: Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Center(
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 2,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.of(context).pop(),
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(
                      Icons.arrow_back,
                      size: 22,
                      color: AppColors.nearBlack,
                    ),
                  ),
                ),
              ),
            ),
          ),
          centerTitle: true,
          title: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.mintGreen.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Food Catalog',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppColors.nearBlack,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Admin',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.nearBlack,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Category filter bar
          _buildCategoryFilterBar(context, ref, selectedCategory),
          // Food list
          Expanded(
            child: foodsAsync.when(
              data: (foods) {

                // Apply category filter
                final filteredFoods =
                    (selectedCategory == null || selectedCategory == 'All')
                    ? foods
                    : foods.where((food) {
                        final cat = (food.category ?? '').toLowerCase();
                        final selected = selectedCategory.toLowerCase();
                        return cat == selected;
                      }).toList();

                if (filteredFoods.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.restaurant_menu,
                          size: 64,
                          color: AppColors.charmingGreen.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          selectedCategory == 'All' || selectedCategory == null
                              ? 'No foods in catalog'
                              : 'No foods in "$selectedCategory" category',
                          style: const TextStyle(
                            color: AppColors.mediumGray,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          selectedCategory == 'All' || selectedCategory == null
                              ? 'Tap "Add food" to add a food'
                              : 'Try selecting a different category',
                          style: TextStyle(
                            color: AppColors.mediumGray.withValues(alpha: 0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.1),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: ListView.builder(
                    key: ValueKey('${filteredFoods.length}_$selectedCategory'),
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredFoods.length,
                    itemBuilder: (context, index) {
                      final food = filteredFoods[index];
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: Duration(milliseconds: 300 + (index * 50)),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: _buildFoodCard(context, ref, food),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: AppColors.mintGreen,
                ),
              ),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error: $error',
                      style: const TextStyle(
                        color: AppColors.mediumGray,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFoodForm(context, ref, null),
        backgroundColor: AppColors.mintGreen,
        foregroundColor: AppColors.nearBlack,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: const Icon(Icons.add, size: 20),
        label: const Text(
          'Add food',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildCategoryFilterBar(
    BuildContext context,
    WidgetRef ref,
    String? selectedCategory,
  ) {
    return Container(
      color: AppColors.palePink,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: foodCategories.map((cat) {
            final isSelected =
                (selectedCategory == null || selectedCategory == 'All')
                ? cat == 'All'
                : selectedCategory == cat;

            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                label: Text(cat),
                selected: isSelected,
                labelStyle: TextStyle(
                  color: isSelected
                      ? AppColors.nearBlack
                      : AppColors.mediumGray,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 14,
                ),
                selectedColor: categoryColor(
                  cat == 'All' ? null : cat,
                ).withValues(alpha: 0.3),
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: isSelected
                      ? categoryColor(
                          cat == 'All' ? null : cat,
                        ).withValues(alpha: 0.6)
                      : AppColors.charmingGreen.withValues(alpha: 0.3),
                  width: isSelected ? 1.5 : 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                onSelected: (_) {
                  ref
                      .read(foodCategoryFilterProvider.notifier)
                      .setCategory(cat == 'All' ? 'All' : cat);
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFoodCard(BuildContext context, WidgetRef ref, Food food) {
    final catColor = categoryColor(food.category).withValues(alpha: 0.4);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: catColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _showFoodForm(context, ref, food),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Food name with category dot
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: categoryColor(
                                food.category,
                              ).withValues(alpha: 0.9),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              food.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: AppColors.nearBlack,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Category
                      if (food.category != null) ...[
                        Text(
                          food.category!,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.mediumGray,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      // Nutrition summary
                      Text(
                        '${food.caloriesPer100g.toStringAsFixed(0)} kcal / 100g | '
                        'P: ${food.proteinPer100g.toStringAsFixed(1)}g | '
                        'C: ${food.carbsPer100g.toStringAsFixed(1)}g | '
                        'F: ${food.fatPer100g.toStringAsFixed(1)}g',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.mediumGray,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Default portion
                      Text(
                        'Default: ${food.defaultPortionGram.toStringAsFixed(0)}g (${food.defaultPortionName})',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.mediumGray.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Action buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      color: AppColors.mediumGray,
                      onPressed: () => _showFoodForm(context, ref, food),
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20),
                      color: AppColors.error.withValues(alpha: 0.8),
                      onPressed: () => _showDeleteDialog(context, ref, food),
                      tooltip: 'Delete',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFoodForm(BuildContext context, WidgetRef ref, Food? existingFood) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _FoodFormDialog(
          existingFood: existingFood,
          onSave: (food) async {
            final user = FirebaseAuth.instance.currentUser;
            if (user == null) return;

            final repository = ref.read(food_providers.foodRepositoryProvider);
            await repository.createOrUpdate(food, user.uid);
            // Invalidate cache to refresh UI
            ref.invalidate(food_providers.allFoodsProvider);
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    existingFood == null
                        ? 'Đã thêm thực phẩm thành công'
                        : 'Đã cập nhật thực phẩm thành công',
                  ),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, Food food) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Xác nhận xóa',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.nearBlack,
          ),
        ),
        content: Text(
          'Bạn có chắc muốn xóa "${food.name}" không?',
          style: const TextStyle(color: AppColors.mediumGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Hủy',
              style: TextStyle(color: AppColors.mediumGray),
            ),
          ),
          TextButton(
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) return;

              final service = ref.read(food_providers.foodServiceProvider);
              final repository = ref.read(food_providers.foodRepositoryProvider);
              await repository.delete(food.id, user.uid, foodName: food.name);
              // Clear cache to refresh UI
              await service.clearCache();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Đã xóa thực phẩm thành công'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }
            },
            child: const Text(
              'Đồng ý',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodFormDialog extends StatefulWidget {
  final Food? existingFood;
  final Function(Food) onSave;

  const _FoodFormDialog({required this.existingFood, required this.onSave});

  @override
  State<_FoodFormDialog> createState() => _FoodFormDialogState();
}

class _FoodFormDialogState extends State<_FoodFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _categoryController;
  late TextEditingController _caloriesController;
  late TextEditingController _proteinController;
  late TextEditingController _carbsController;
  late TextEditingController _fatController;
  late TextEditingController _portionGramController;
  late TextEditingController _portionNameController;

  @override
  void initState() {
    super.initState();
    final food = widget.existingFood;
    _nameController = TextEditingController(text: food?.name ?? '');
    _categoryController = TextEditingController(text: food?.category ?? '');
    _caloriesController = TextEditingController(
      text: food?.caloriesPer100g.toString() ?? '',
    );
    _proteinController = TextEditingController(
      text: food?.proteinPer100g.toString() ?? '',
    );
    _carbsController = TextEditingController(
      text: food?.carbsPer100g.toString() ?? '',
    );
    _fatController = TextEditingController(
      text: food?.fatPer100g.toString() ?? '',
    );
    _portionGramController = TextEditingController(
      text: food?.defaultPortionGram.toString() ?? '100',
    );
    _portionNameController = TextEditingController(
      text: food?.defaultPortionName ?? 'chén',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _portionGramController.dispose();
    _portionNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.existingFood == null ? 'Add Food' : 'Edit Food',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.nearBlack,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  color: AppColors.mediumGray,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name section
                    const Text(
                      'Name *',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.nearBlack,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _nameController,
                      label: 'Food name',
                      hint: 'e.g., Cơm trắng',
                      icon: Icons.restaurant,
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),
                    // Category section
                    const Text(
                      'Category',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.nearBlack,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _categoryController,
                      label: 'Category',
                      hint: 'e.g., Rice, Meat',
                      icon: Icons.category,
                    ),
                    const SizedBox(height: 20),
                    // Nutrition section
                    const Text(
                      'Nutrition per 100g *',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.nearBlack,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildNumberField(
                      controller: _caloriesController,
                      label: 'Calories',
                      suffix: 'kcal',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildNumberField(
                            controller: _proteinController,
                            label: 'Protein',
                            suffix: 'g',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildNumberField(
                            controller: _carbsController,
                            label: 'Carbs',
                            suffix: 'g',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildNumberField(
                            controller: _fatController,
                            label: 'Fat',
                            suffix: 'g',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Default Portion section
                    const Text(
                      'Default Portion',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.nearBlack,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildNumberField(
                            controller: _portionGramController,
                            label: 'Grams',
                            suffix: 'g',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _portionNameController,
                            label: 'Portion Name',
                            hint: 'e.g., chén',
                            icon: Icons.straighten,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Save button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: Material(
                        color: AppColors.mintGreen,
                        borderRadius: BorderRadius.circular(24),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: _handleSave,
                          child: Container(
                            alignment: Alignment.center,
                            child: Text(
                              widget.existingFood == null
                                  ? 'Add Food'
                                  : 'Save Changes',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.nearBlack,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: AppColors.mediumGray),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppColors.charmingGreen.withValues(alpha: 0.3),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppColors.charmingGreen.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.mintGreen, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required String suffix,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppColors.charmingGreen.withValues(alpha: 0.3),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppColors.charmingGreen.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.mintGreen, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) {
          return 'Required';
        }
        if (double.tryParse(v) == null) {
          return 'Invalid';
        }
        return null;
      },
    );
  }

  void _handleSave() {
    if (_formKey.currentState!.validate()) {
      final food = Food(
        id: widget.existingFood?.id ?? '',
        name: _nameController.text.trim(),
        nameLower: _nameController.text.trim().toLowerCase(),
        category: _categoryController.text.trim().isEmpty
            ? null
            : _categoryController.text.trim(),
        caloriesPer100g: double.parse(_caloriesController.text),
        proteinPer100g: double.parse(_proteinController.text),
        carbsPer100g: double.parse(_carbsController.text),
        fatPer100g: double.parse(_fatController.text),
        defaultPortionGram: double.parse(_portionGramController.text),
        defaultPortionName: _portionNameController.text.trim().isEmpty
            ? 'chén'
            : _portionNameController.text.trim(),
      );

      widget.onSave(food);
    }
  }
}
