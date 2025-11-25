import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calories_app/features/home/domain/meal_item.dart';
import 'package:calories_app/features/home/domain/meal_type.dart';
import 'package:calories_app/features/home/presentation/providers/diary_provider.dart';
import 'package:calories_app/features/home/presentation/providers/food_search_providers.dart';
import 'package:calories_app/features/foods/data/food_model.dart';

/// Bottom sheet để thêm/sửa món ăn với food search
class AddMealItemBottomSheet extends ConsumerStatefulWidget {
  final MealType mealType;
  final MealItem? existingItem; // null nếu thêm mới, có giá trị nếu edit

  const AddMealItemBottomSheet({
    super.key,
    required this.mealType,
    this.existingItem,
  });

  @override
  ConsumerState<AddMealItemBottomSheet> createState() => _AddMealItemBottomSheetState();
}

class _AddMealItemBottomSheetState extends ConsumerState<AddMealItemBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _searchController;
  late TextEditingController _nameController;
  late TextEditingController _servingSizeController;
  late TextEditingController _gramsPerServingController;
  late TextEditingController _caloriesController;
  late TextEditingController _proteinController;
  late TextEditingController _carbsController;
  late TextEditingController _fatController;

  bool get isEditing => widget.existingItem != null;
  bool _showSearchResults = false;

  @override
  void initState() {
    super.initState();
    
    final item = widget.existingItem;
    _searchController = TextEditingController();
    _nameController = TextEditingController(text: item?.name ?? '');
    _servingSizeController = TextEditingController(
      text: item?.servingSize.toString() ?? '1',
    );
    _gramsPerServingController = TextEditingController(
      text: item?.gramsPerServing.toString() ?? '100',
    );
    _caloriesController = TextEditingController(
      text: item?.caloriesPer100g.toString() ?? '',
    );
    _proteinController = TextEditingController(
      text: item?.proteinPer100g.toString() ?? '',
    );
    _carbsController = TextEditingController(
      text: item?.carbsPer100g.toString() ?? '',
    );
    _fatController = TextEditingController(
      text: item?.fatPer100g.toString() ?? '',
    );

    // Listen to search query changes
    _searchController.addListener(() {
      final query = _searchController.text;
      ref.read(foodSearchQueryProvider.notifier).setQuery(query);
      setState(() {
        _showSearchResults = query.trim().isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _servingSizeController.dispose();
    _gramsPerServingController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  void _selectFood(Food food) {
    // Pre-fill form with food data
    setState(() {
      _nameController.text = food.name;
      _gramsPerServingController.text = food.defaultPortionGram.toStringAsFixed(1);
      _caloriesController.text = food.caloriesPer100g.toStringAsFixed(1);
      _proteinController.text = food.proteinPer100g.toStringAsFixed(1);
      _carbsController.text = food.carbsPer100g.toStringAsFixed(1);
      _fatController.text = food.fatPer100g.toStringAsFixed(1);
      _searchController.text = '';
      _showSearchResults = false;
    });
    
    // Set selected food in provider
    ref.read(selectedFoodProvider.notifier).setFood(food);
    
    // Clear search query
    ref.read(foodSearchQueryProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final searchResultsAsync = ref.watch(foodSearchResultsProvider);
    final selectedFood = ref.watch(selectedFoodProvider);
    final diaryNotifier = ref.read(diaryProvider.notifier);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.mealType.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    widget.mealType.icon,
                    color: widget.mealType.color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEditing ? 'Chỉnh sửa món ăn' : 'Thêm món ăn',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        widget.mealType.displayName,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Form
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Food Search (only show when adding new, not editing)
                    if (!isEditing) ...[
                      TextFormField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: 'Tìm kiếm món ăn',
                          hintText: 'Nhập tên món ăn...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    ref.read(foodSearchQueryProvider.notifier).clear();
                                    ref.read(selectedFoodProvider.notifier).clear();
                                    setState(() {
                                      _showSearchResults = false;
                                    });
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Search Results
                      if (_showSearchResults)
                        searchResultsAsync.when(
                          data: (foods) {
                            if (foods.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: const Text(
                                  'Không tìm thấy món ăn',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              );
                            }
                            
                            return Container(
                              constraints: const BoxConstraints(maxHeight: 200),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: foods.length,
                                itemBuilder: (context, index) {
                                  final food = foods[index];
                                  return ListTile(
                                    leading: const Icon(Icons.restaurant),
                                    title: Text(food.name),
                                    subtitle: Text(
                                      '${food.caloriesPer100g.toStringAsFixed(0)} kcal/100g',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    onTap: () => _selectFood(food),
                                  );
                                },
                              ),
                            );
                          },
                          loading: () => const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          error: (error, stack) => Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Lỗi tìm kiếm: $error',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ),
                      
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                    ],

                    // Selected Food Info (if food is selected)
                    if (selectedFood != null && !isEditing)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Đã chọn: ${selectedFood.name}',
                                style: TextStyle(
                                  color: Colors.green[900],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                ref.read(selectedFoodProvider.notifier).clear();
                                _nameController.clear();
                                _caloriesController.clear();
                                _proteinController.clear();
                                _carbsController.clear();
                                _fatController.clear();
                              },
                              child: const Text('Bỏ chọn'),
                            ),
                          ],
                        ),
                      ),

                    // Tên món ăn
                    _buildTextField(
                      controller: _nameController,
                      label: 'Tên món ăn',
                      hint: 'Ví dụ: Cơm gạo lứt',
                      icon: Icons.restaurant,
                      enabled: selectedFood == null || isEditing,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập tên món ăn';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Khẩu phần và gram
                    Row(
                      children: [
                        Expanded(
                          child: _buildNumberField(
                            controller: _servingSizeController,
                            label: 'Khẩu phần',
                            hint: '1',
                            suffix: 'phần',
                            icon: Icons.straighten,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildNumberField(
                            controller: _gramsPerServingController,
                            label: 'Gram/phần',
                            hint: '100',
                            suffix: 'g',
                            icon: Icons.scale,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Thông tin dinh dưỡng (trên 100g)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 6),
                              Text(
                                'Thông tin dinh dưỡng (trên 100g)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildNumberField(
                            controller: _caloriesController,
                            label: 'Calories',
                            hint: '130',
                            suffix: 'kcal',
                            icon: Icons.local_fire_department,
                            enabled: selectedFood == null || isEditing,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildNumberField(
                                  controller: _proteinController,
                                  label: 'Protein',
                                  hint: '2.7',
                                  suffix: 'g',
                                  icon: Icons.egg,
                                  enabled: selectedFood == null || isEditing,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildNumberField(
                                  controller: _carbsController,
                                  label: 'Carbs',
                                  hint: '28',
                                  suffix: 'g',
                                  icon: Icons.grain,
                                  enabled: selectedFood == null || isEditing,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildNumberField(
                                  controller: _fatController,
                                  label: 'Fat',
                                  hint: '0.7',
                                  suffix: 'g',
                                  icon: Icons.water_drop,
                                  enabled: selectedFood == null || isEditing,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Nút lưu
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => _handleSave(diaryNotifier),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.mealType.color,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          isEditing ? 'Cập nhật' : 'Thêm món',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
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
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey[100],
      ),
      validator: validator,
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String suffix,
    required IconData icon,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
        prefixIcon: Icon(icon, size: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey[100],
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Bắt buộc';
        }
        if (double.tryParse(value) == null) {
          return 'Không hợp lệ';
        }
        return null;
      },
    );
  }

  Future<void> _handleSave(DiaryNotifier diaryNotifier) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      final selectedFood = ref.read(selectedFoodProvider);
      final servingCount = double.parse(_servingSizeController.text);
      final gramsPerServing = double.parse(_gramsPerServingController.text);

      if (isEditing) {
        // Update existing entry
        final item = MealItem(
          id: widget.existingItem!.id,
          name: _nameController.text.trim(),
          servingSize: servingCount,
          gramsPerServing: gramsPerServing,
          caloriesPer100g: double.parse(_caloriesController.text),
          proteinPer100g: double.parse(_proteinController.text),
          carbsPer100g: double.parse(_carbsController.text),
          fatPer100g: double.parse(_fatController.text),
        );
        
        await diaryNotifier.updateMealItem(widget.mealType, item.id, item);
        
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cập nhật món ăn thành công'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (selectedFood != null) {
        // Add entry from Food catalog
        await diaryNotifier.addEntryFromFood(
          food: selectedFood,
          servingCount: servingCount,
          gramsPerServing: gramsPerServing,
          mealType: widget.mealType,
        );
        
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Thêm món ăn thành công'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Add custom entry (no Food catalog reference)
        final item = MealItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: _nameController.text.trim(),
          servingSize: servingCount,
          gramsPerServing: gramsPerServing,
          caloriesPer100g: double.parse(_caloriesController.text),
          proteinPer100g: double.parse(_proteinController.text),
          carbsPer100g: double.parse(_carbsController.text),
          fatPer100g: double.parse(_fatController.text),
        );
        
        await diaryNotifier.addMealItem(widget.mealType, item);
        
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Thêm món ăn thành công'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
