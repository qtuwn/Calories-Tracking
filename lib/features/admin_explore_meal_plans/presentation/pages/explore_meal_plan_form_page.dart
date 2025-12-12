import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/meal_plans/explore_meal_plan.dart';
import '../../../../domain/meal_plans/meal_plan_goal_type.dart';
import '../../../../shared/state/explore_meal_plan_providers.dart' as explore_meal_plan_providers;

/// Form page for creating/editing explore meal plans
class ExploreMealPlanFormPage extends ConsumerStatefulWidget {
  final ExploreMealPlan? plan;

  const ExploreMealPlanFormPage({super.key, this.plan});

  @override
  ConsumerState<ExploreMealPlanFormPage> createState() =>
      _ExploreMealPlanFormPageState();
}

class _ExploreMealPlanFormPageState
    extends ConsumerState<ExploreMealPlanFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _caloriesController;
  late TextEditingController _durationController;
  late TextEditingController _mealsPerDayController;
  late TextEditingController _tagsController;

  MealPlanGoalType _selectedGoalType = MealPlanGoalType.other;
  bool _isFeatured = false;
  bool _isPublished = false;
  bool _isEnabled = true;
  String? _difficulty;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final plan = widget.plan;
    _nameController = TextEditingController(text: plan?.name ?? '');
    _descriptionController =
        TextEditingController(text: plan?.description ?? '');
    _caloriesController =
        TextEditingController(text: plan?.templateKcal.toString() ?? '');
    _durationController =
        TextEditingController(text: plan?.durationDays.toString() ?? '7');
    _mealsPerDayController =
        TextEditingController(text: plan?.mealsPerDay.toString() ?? '3');
    _tagsController =
        TextEditingController(text: plan?.tags.join(', ') ?? '');
    _selectedGoalType = plan?.goalType ?? MealPlanGoalType.other;
    _isFeatured = plan?.isFeatured ?? false;
    _isPublished = plan?.isPublished ?? false;
    _isEnabled = plan?.isEnabled ?? true;
    _difficulty = plan?.difficulty;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _caloriesController.dispose();
    _durationController.dispose();
    _mealsPerDayController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.plan != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Chỉnh sửa Thực đơn' : 'Thêm Thực đơn'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _handleDelete,
              tooltip: 'Xóa thực đơn',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Tên thực đơn *',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Vui lòng nhập tên thực đơn';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<MealPlanGoalType>(
              value: _selectedGoalType,
              decoration: const InputDecoration(
                labelText: 'Mục tiêu *',
                border: OutlineInputBorder(),
              ),
              items: MealPlanGoalType.values.map((goalType) {
                return DropdownMenuItem(
                  value: goalType,
                  child: Text(goalType.displayName),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedGoalType = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Mô tả *',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Vui lòng nhập mô tả';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _caloriesController,
              decoration: const InputDecoration(
                labelText: 'Calories/ngày *',
                border: OutlineInputBorder(),
                helperText: 'Ví dụ: 1500, 2000',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Vui lòng nhập calories';
                }
                final kcal = int.tryParse(value);
                if (kcal == null || kcal <= 0 || kcal > 10000) {
                  return 'Calories phải từ 1 đến 10000';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _durationController,
              decoration: const InputDecoration(
                labelText: 'Số ngày *',
                border: OutlineInputBorder(),
                helperText: 'Ví dụ: 7, 14, 30',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Vui lòng nhập số ngày';
                }
                final days = int.tryParse(value);
                if (days == null || days <= 0 || days > 365) {
                  return 'Số ngày phải từ 1 đến 365';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _mealsPerDayController,
              decoration: const InputDecoration(
                labelText: 'Số bữa/ngày *',
                border: OutlineInputBorder(),
                helperText: 'Ví dụ: 3, 4, 5',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Vui lòng nhập số bữa';
                }
                final meals = int.tryParse(value);
                if (meals == null || meals <= 0 || meals > 10) {
                  return 'Số bữa phải từ 1 đến 10';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Tags (phân cách bằng dấu phẩy)',
                border: OutlineInputBorder(),
                helperText: 'Ví dụ: Beginner, Nhẹ bụng, Nhanh',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _difficulty,
              decoration: const InputDecoration(
                labelText: 'Độ khó',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'easy', child: Text('Dễ')),
                DropdownMenuItem(value: 'medium', child: Text('Trung bình')),
                DropdownMenuItem(value: 'hard', child: Text('Khó')),
              ],
              onChanged: (value) {
                setState(() {
                  _difficulty = value;
                });
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Nổi bật'),
              subtitle: const Text('Hiển thị trong danh sách nổi bật'),
              value: _isFeatured,
              onChanged: (value) {
                setState(() {
                  _isFeatured = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Đã xuất bản'),
              subtitle: const Text('Hiển thị cho người dùng'),
              value: _isPublished,
              onChanged: (value) {
                setState(() {
                  _isPublished = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Kích hoạt'),
              subtitle: const Text('Thực đơn có sẵn'),
              value: _isEnabled,
              onChanged: (value) {
                setState(() {
                  _isEnabled = value;
                });
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleSave,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isEditing ? 'Cập nhật' : 'Tạo mới'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final service = ref.read(explore_meal_plan_providers.exploreMealPlanServiceProvider);

      final tags = _tagsController.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final plan = ExploreMealPlan(
        id: widget.plan?.id ?? '',
        name: _nameController.text.trim(),
        goalType: _selectedGoalType,
        description: _descriptionController.text.trim(),
        templateKcal: int.parse(_caloriesController.text),
        durationDays: int.parse(_durationController.text),
        mealsPerDay: int.parse(_mealsPerDayController.text),
        tags: tags,
        isFeatured: _isFeatured,
        isPublished: _isPublished,
        isEnabled: _isEnabled,
        createdAt: widget.plan?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        difficulty: _difficulty,
      );

      if (widget.plan == null) {
        await service.createPlan(plan);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã tạo thực đơn thành công')),
          );
          Navigator.pop(context);
        }
      } else {
        await service.updatePlan(plan);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã cập nhật thực đơn thành công')),
          );
          Navigator.pop(context);
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
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc muốn xóa thực đơn này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true || widget.plan == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final service = ref.read(explore_meal_plan_providers.exploreMealPlanServiceProvider);
      await service.deletePlan(widget.plan!.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa thực đơn thành công')),
        );
        Navigator.pop(context);
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
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

