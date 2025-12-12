import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/activities/activity.dart';
import '../state/activity_providers.dart';

/// Form page for creating/editing activities
class ActivityFormPage extends ConsumerStatefulWidget {
  final Activity? activity;

  const ActivityFormPage({super.key, this.activity});

  @override
  ConsumerState<ActivityFormPage> createState() => _ActivityFormPageState();
}

class _ActivityFormPageState extends ConsumerState<ActivityFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _metController;
  late TextEditingController _descriptionController;
  late TextEditingController _iconNameController;

  ActivityCategory _selectedCategory = ActivityCategory.other;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final activity = widget.activity;
    _nameController = TextEditingController(text: activity?.name ?? '');
    _metController = TextEditingController(text: activity?.met.toString() ?? '');
    _descriptionController =
        TextEditingController(text: activity?.description ?? '');
    _iconNameController =
        TextEditingController(text: activity?.iconName ?? '');
    _selectedCategory = activity?.category ?? ActivityCategory.other;
    _isActive = activity?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _metController.dispose();
    _descriptionController.dispose();
    _iconNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.activity != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Chỉnh sửa Hoạt động' : 'Thêm Hoạt động'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Tên hoạt động *',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Vui lòng nhập tên hoạt động';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<ActivityCategory>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Danh mục *',
                border: OutlineInputBorder(),
              ),
              items: ActivityCategory.values.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category.displayName),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCategory = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _metController,
              decoration: const InputDecoration(
                labelText: 'MET (Metabolic Equivalent) *',
                border: OutlineInputBorder(),
                helperText: 'Giá trị từ 0.1 đến 20',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Vui lòng nhập giá trị MET';
                }
                final met = double.tryParse(value);
                if (met == null || met <= 0 || met > 20) {
                  return 'MET phải từ 0.1 đến 20';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Mô tả',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _iconNameController,
              decoration: const InputDecoration(
                labelText: 'Tên icon',
                border: OutlineInputBorder(),
                helperText: 'Tên icon Material Icons (tùy chọn)',
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Hoạt động'),
              subtitle: const Text('Hiển thị trong danh sách'),
              value: _isActive,
              onChanged: (value) {
                setState(() {
                  _isActive = value;
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

  bool _isLoading = false;

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final service = ref.read(activityServiceProvider);
      final met = double.parse(_metController.text);
      final intensity = ActivityIntensity.fromMet(met);

      final activity = Activity(
        id: widget.activity?.id ?? '',
        name: _nameController.text.trim(),
        category: _selectedCategory,
        met: met,
        intensity: intensity,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        iconName: _iconNameController.text.trim().isEmpty
            ? null
            : _iconNameController.text.trim(),
        isActive: _isActive,
        createdAt: widget.activity?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.activity == null) {
        await service.createActivity(activity);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã tạo hoạt động thành công')),
          );
          Navigator.pop(context);
        }
      } else {
        await service.updateActivity(activity);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã cập nhật hoạt động thành công')),
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
}

