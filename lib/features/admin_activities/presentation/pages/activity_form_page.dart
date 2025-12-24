import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../domain/activities/activity.dart';
import '../../../../domain/images/image_storage_failure.dart';
import '../../../../shared/state/image_storage_providers.dart';
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
  
  // Image URLs (from Cloudinary or existing)
  String? _iconUrl;
  String? _coverUrl;
  
  // Upload states
  bool _isUploadingIcon = false;
  bool _isUploadingCover = false;

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
    _iconUrl = activity?.iconUrl;
    _coverUrl = activity?.coverUrl;
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
            const SizedBox(height: 24),
            
            // Icon Image Upload Section
            _buildImageUploadSection(
              title: 'Icon ảnh',
              currentUrl: _iconUrl,
              isUploading: _isUploadingIcon,
              isEnabled: isEditing, // Only enable if editing existing activity
              onUpload: _uploadIconImage,
              onRemove: () {
                setState(() {
                  _iconUrl = null;
                });
              },
            ),
            const SizedBox(height: 16),
            
            // Cover Image Upload Section
            _buildImageUploadSection(
              title: 'Ảnh bìa',
              currentUrl: _coverUrl,
              isUploading: _isUploadingCover,
              isEnabled: isEditing, // Only enable if editing existing activity
              onUpload: _uploadCoverImage,
              onRemove: () {
                setState(() {
                  _coverUrl = null;
                });
              },
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
        iconUrl: _iconUrl,
        coverUrl: _coverUrl,
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

  /// Build image upload section widget
  Widget _buildImageUploadSection({
    required String title,
    required String? currentUrl,
    required bool isUploading,
    required bool isEnabled,
    required VoidCallback onUpload,
    required VoidCallback onRemove,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (currentUrl != null && currentUrl.isNotEmpty) ...[
              // Display current image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  currentUrl,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 120,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 120,
                      color: Colors.grey[300],
                      child: const Icon(Icons.broken_image, size: 48),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: (isUploading || !isEnabled) ? null : onUpload,
                      icon: const Icon(Icons.upload),
                      label: const Text('Thay đổi'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: (isUploading || !isEnabled) ? null : onRemove,
                    icon: const Icon(Icons.delete),
                    label: const Text('Xóa'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ],
              ),
            ] else ...[
              // No image - show upload button or message
              if (!isEnabled) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Vui lòng lưu hoạt động trước khi tải ảnh',
                          style: TextStyle(
                            color: Colors.orange[900],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                OutlinedButton.icon(
                  onPressed: isUploading ? null : onUpload,
                  icon: isUploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_photo_alternate),
                  label: Text(isUploading ? 'Đang tải lên...' : 'Tải lên ảnh'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// Upload icon image
  Future<void> _uploadIconImage() async {
    // This should not be called if activity is not saved, but double-check
    if (widget.activity == null || widget.activity!.id.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng lưu hoạt động trước khi tải ảnh'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (picked == null) return;

    setState(() {
      _isUploadingIcon = true;
    });

    try {
      final bytes = await picked.readAsBytes();
      final fileName = picked.path.split('/').last;
      final mimeType = _getMimeType(fileName.split('.').last);

      final useCase = ref.read(uploadSportIconUseCaseProvider);
      final imageAsset = await useCase.execute(
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
        sportId: widget.activity!.id,
      );

      setState(() {
        _iconUrl = imageAsset.url;
        _isUploadingIcon = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã tải lên icon thành công'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on ImageStorageFailure catch (e) {
      setState(() {
        _isUploadingIcon = false;
      });

      String errorMessage = 'Lỗi tải lên icon';
      if (e is ImageUploadNetworkFailure) {
        errorMessage = 'Lỗi kết nối. Vui lòng kiểm tra internet và thử lại.';
      } else if (e is ImageUploadServerFailure) {
        errorMessage = 'Lỗi server. Vui lòng thử lại sau.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isUploadingIcon = false;
      });

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

  /// Upload cover image
  Future<void> _uploadCoverImage() async {
    // This should not be called if activity is not saved, but double-check
    if (widget.activity == null || widget.activity!.id.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng lưu hoạt động trước khi tải ảnh'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (picked == null) return;

    setState(() {
      _isUploadingCover = true;
    });

    try {
      final bytes = await picked.readAsBytes();
      final fileName = picked.path.split('/').last;
      final mimeType = _getMimeType(fileName.split('.').last);

      final useCase = ref.read(uploadSportCoverUseCaseProvider);
      final imageAsset = await useCase.execute(
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
        sportId: widget.activity!.id,
      );

      setState(() {
        _coverUrl = imageAsset.url;
        _isUploadingCover = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã tải lên ảnh bìa thành công'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on ImageStorageFailure catch (e) {
      setState(() {
        _isUploadingCover = false;
      });

      String errorMessage = 'Lỗi tải lên ảnh bìa';
      if (e is ImageUploadNetworkFailure) {
        errorMessage = 'Lỗi kết nối. Vui lòng kiểm tra internet và thử lại.';
      } else if (e is ImageUploadServerFailure) {
        errorMessage = 'Lỗi server. Vui lòng thử lại sau.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isUploadingCover = false;
      });

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

  /// Get MIME type from file extension
  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}

