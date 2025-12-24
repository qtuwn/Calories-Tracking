import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:calories_app/core/theme/theme.dart';
import 'package:calories_app/features/exercise/data/exercise_model.dart';
import 'package:calories_app/features/exercise/data/exercise_providers.dart';
import 'package:calories_app/shared/state/image_storage_providers.dart';
import 'package:calories_app/domain/images/image_storage_failure.dart';

/// Provider for current user's role from Firestore
final _currentUserRoleProvider = StreamProvider<String?>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((doc) => doc.data()?['role'] as String? ?? 'user');
});

class ExerciseAdminEditScreen extends ConsumerStatefulWidget {
  static const routeName = '/exercise-admin-edit';
  final String? exerciseId;

  const ExerciseAdminEditScreen({super.key, this.exerciseId});

  @override
  ConsumerState<ExerciseAdminEditScreen> createState() =>
      _ExerciseAdminEditScreenState();
}

class _ExerciseAdminEditScreenState
    extends ConsumerState<ExerciseAdminEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _imageUrlController;
  late TextEditingController _descriptionController;
  late TextEditingController _metPerHourController;
  late TextEditingController _metPerKmController;

  ExerciseUnit _selectedUnit = ExerciseUnit.time;
  bool _isEnabled = true;
  List<ExerciseLevel> _levels = [];

  bool _isLoading = false;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _imageUrlController = TextEditingController();
    _descriptionController = TextEditingController();
    _metPerHourController = TextEditingController();
    _metPerKmController = TextEditingController();

    // Load existing exercise if editing
    if (widget.exerciseId != null) {
      _loadExercise();
    }
  }

  Future<void> _loadExercise() async {
    final repository = ref.read(exerciseRepositoryProvider);
    final exercise = await repository.getExerciseById(widget.exerciseId!);
    if (exercise != null && mounted) {
      setState(() {
        _nameController.text = exercise.name;
        _imageUrlController.text = exercise.imageUrl;
        _descriptionController.text = exercise.description ?? '';
        _selectedUnit = exercise.unit;
        _isEnabled = exercise.isEnabled;
        _levels = List.from(exercise.levels);
        _metPerHourController.text = exercise.metPerHour?.toString() ?? '';
        _metPerKmController.text = exercise.metPerKm?.toString() ?? '';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _imageUrlController.dispose();
    _descriptionController.dispose();
    _metPerHourController.dispose();
    _metPerKmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roleAsync = ref.watch(_currentUserRoleProvider);

    return roleAsync.when(
      data: (role) {
        // Check admin access
        if (role != 'admin') {
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
              title: Text(
                widget.exerciseId == null ? 'Thêm bài tập' : 'Sửa bài tập',
              ),
              actions: [
                if (widget.exerciseId != null)
                  IconButton(
                    icon: const Icon(Icons.delete, color: AppColors.error),
                    onPressed: _isLoading ? null : _handleDelete,
                  ),
              ],
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  _buildSectionTitle('Tên bài tập *'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Tên bài tập',
                      hintText: 'VD: Chạy bộ',
                    ),
                    validator: (v) => v?.isEmpty ?? true ? 'Bắt buộc' : null,
                  ),
                  const SizedBox(height: 24),
                  // Image URL
                  _buildSectionTitle('Ảnh (URL)'),
                  const SizedBox(height: 8),
                  // Image preview
                  if (_imageUrlController.text.trim().isNotEmpty) ...[
                    _buildImagePreview(_imageUrlController.text.trim()),
                    const SizedBox(height: 12),
                  ],
                  // URL TextField
                  TextFormField(
                    controller: _imageUrlController,
                    decoration: const InputDecoration(
                      labelText: 'URL ảnh',
                      hintText: 'https://example.com/image.jpg',
                    ),
                    onChanged: (value) {
                      setState(() {}); // Refresh preview when URL changes
                    },
                  ),
                  const SizedBox(height: 8),
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isUploadingImage || _isLoading ? null : _pickAndUploadImage,
                          icon: _isUploadingImage
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.image),
                          label: const Text('Chọn ảnh'),
                        ),
                      ),
                      if (_imageUrlController.text.trim().isNotEmpty) ...[
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _isUploadingImage || _isLoading ? null : _clearImage,
                          icon: const Icon(Icons.clear),
                          label: const Text('Xóa ảnh'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Unit type
                  _buildSectionTitle('Loại bài tập *'),
                  const SizedBox(height: 8),
                  SegmentedButton<ExerciseUnit>(
                    segments: const [
                      ButtonSegment(
                        value: ExerciseUnit.time,
                        label: Text('Thời gian'),
                        icon: Icon(Icons.timer),
                      ),
                      ButtonSegment(
                        value: ExerciseUnit.distance,
                        label: Text('Khoảng cách'),
                        icon: Icon(Icons.straighten),
                      ),
                      ButtonSegment(
                        value: ExerciseUnit.level,
                        label: Text('Mức độ'),
                        icon: Icon(Icons.stacked_bar_chart),
                      ),
                    ],
                    selected: {_selectedUnit},
                    onSelectionChanged: (Set<ExerciseUnit> selected) {
                      setState(() {
                        _selectedUnit = selected.first;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  // Unit-specific fields
                  if (_selectedUnit == ExerciseUnit.time) ...[
                    _buildSectionTitle('MET mỗi giờ *'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _metPerHourController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'),
                        ),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'MET/giờ',
                        hintText: 'VD: 8.0',
                        suffixText: 'MET/giờ',
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Bắt buộc cho bài tập thời gian';
                        }
                        if (double.tryParse(v) == null) {
                          return 'Phải là số';
                        }
                        return null;
                      },
                    ),
                  ] else if (_selectedUnit == ExerciseUnit.distance) ...[
                    _buildSectionTitle('MET mỗi km *'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _metPerKmController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'),
                        ),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'MET/km',
                        hintText: 'VD: 0.8',
                        suffixText: 'MET/km',
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Bắt buộc cho bài tập khoảng cách';
                        }
                        if (double.tryParse(v) == null) {
                          return 'Phải là số';
                        }
                        return null;
                      },
                    ),
                  ] else if (_selectedUnit == ExerciseUnit.level) ...[
                    _buildSectionTitle('Mức độ *'),
                    const SizedBox(height: 8),
                    ..._levels.asMap().entries.map((entry) {
                      final index = entry.key;
                      final level = entry.value;
                      return _buildLevelRow(index, level);
                    }),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _addLevel,
                      icon: const Icon(Icons.add),
                      label: const Text('Thêm mức độ'),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // Description
                  _buildSectionTitle('Mô tả'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả',
                      hintText: 'Mô tả về bài tập...',
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Enabled switch
                  SwitchListTile(
                    title: const Text('Kích hoạt'),
                    subtitle: const Text('Bài tập này có sẵn cho người dùng'),
                    value: _isEnabled,
                    onChanged: (value) {
                      setState(() {
                        _isEnabled = value;
                      });
                    },
                  ),
                  const SizedBox(height: 32),
                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSave,
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              widget.exerciseId == null
                                  ? 'Thêm bài tập'
                                  : 'Lưu thay đổi',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.nearBlack,
      ),
    );
  }

  Widget _buildLevelRow(int index, ExerciseLevel level) {
    final nameController = TextEditingController(text: level.name);
    final metController = TextEditingController(text: level.met.toString());

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Tên mức độ',
                  hintText: 'VD: Nhẹ, Trung bình',
                ),
                onChanged: (value) {
                  _levels[index] = ExerciseLevel(name: value, met: level.met);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: metController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                decoration: const InputDecoration(
                  labelText: 'MET',
                  suffixText: 'MET',
                ),
                onChanged: (value) {
                  final met = double.tryParse(value) ?? 0.0;
                  _levels[index] = ExerciseLevel(name: level.name, met: met);
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete, color: AppColors.error),
              onPressed: () {
                setState(() {
                  _levels.removeAt(index);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _addLevel() {
    setState(() {
      _levels.add(
        ExerciseLevel(name: 'Mức độ ${_levels.length + 1}', met: 3.0),
      );
    });
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate levels for level-based exercises
    if (_selectedUnit == ExerciseUnit.level) {
      if (_levels.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phải có ít nhất một mức độ'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final repository = ref.read(exerciseRepositoryProvider);
      final name = _nameController.text.trim();
      final exercise = Exercise(
        id: widget.exerciseId ?? '',
        name: name,
        nameLower: name.toLowerCase(),
        imageUrl: _imageUrlController.text.trim(),
        unit: _selectedUnit,
        levels: _levels,
        metPerHour: _selectedUnit == ExerciseUnit.time
            ? double.tryParse(_metPerHourController.text)
            : null,
        metPerKm: _selectedUnit == ExerciseUnit.distance
            ? double.tryParse(_metPerKmController.text)
            : null,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        isEnabled: _isEnabled,
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not signed in');
      }

      if (widget.exerciseId == null) {
        await repository.createExercise(exercise, user.uid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã thêm bài tập thành công'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.of(context).pop();
        }
      } else {
        await repository.updateExercise(exercise, user.uid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã cập nhật bài tập thành công'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.error),
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận thao tác'),
        content: const Text('Bạn có chắc muốn xóa bài tập này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Đồng ý'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not signed in');
      }

      final repository = ref.read(exerciseRepositoryProvider);
      await repository.deleteExercise(
        widget.exerciseId!,
        user.uid,
        exerciseName: _nameController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa bài tập thành công'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Lỗi: $e';

        // Handle permission-denied errors specifically
        if (e is FirebaseException) {
          if (e.code == 'permission-denied') {
            errorMessage = 'Bạn không có quyền admin để xóa bài tập.';
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.error,
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

  /// Build image preview widget
  Widget _buildImagePreview(String imageUrl) {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageUrl,
          key: ValueKey(imageUrl), // Force rebuild when URL changes
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[200],
              child: const Center(
                child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Pick image from gallery and upload to Cloudinary
  Future<void> _pickAndUploadImage() async {
    debugPrint('[ExerciseAdminEditScreen] 🔵 Starting image pick and upload');

    // Pick image from gallery
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (picked == null) {
      debugPrint('[ExerciseAdminEditScreen] ℹ️ User cancelled image picker');
      return;
    }

    debugPrint('[ExerciseAdminEditScreen] ✅ Image picked: ${picked.path}');

    setState(() {
      _isUploadingImage = true;
    });

    try {
      // Read image bytes
      debugPrint('[ExerciseAdminEditScreen] 📤 Reading image bytes...');
      final bytes = await picked.readAsBytes();
      debugPrint('[ExerciseAdminEditScreen] ✅ Read ${bytes.length} bytes from image');

      // Determine MIME type from file extension
      final fileName = picked.path.split('/').last;
      final extension = fileName.split('.').last.toLowerCase();
      final mimeType = _getMimeType(extension);
      debugPrint('[ExerciseAdminEditScreen] Detected MIME type: $mimeType');

      // Upload to Cloudinary using repository
      debugPrint('[ExerciseAdminEditScreen] 📤 Uploading to Cloudinary...');
      final repository = ref.read(imageStorageRepositoryProvider);
      final imageAsset = await repository.uploadImage(
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
        folder: 'exercises/images',
        publicId: null, // Let Cloudinary auto-generate unique ID
      );

      debugPrint('[ExerciseAdminEditScreen] ✅ Upload successful: ${imageAsset.url}');

      // Update URL field with secure URL
      setState(() {
        _imageUrlController.text = imageAsset.url;
        _isUploadingImage = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã tải lên ảnh thành công'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on ImageStorageFailure catch (e) {
      debugPrint('[ExerciseAdminEditScreen] 🔥 Image upload failed: $e');

      setState(() {
        _isUploadingImage = false;
      });

      String errorMessage = 'Lỗi tải lên ảnh';
      if (e is ImageUploadNetworkFailure) {
        errorMessage = 'Lỗi kết nối. Vui lòng kiểm tra internet và thử lại.';
      } else if (e is ImageUploadServerFailure) {
        errorMessage = 'Lỗi server. Vui lòng thử lại sau.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('[ExerciseAdminEditScreen] 🔥 Unexpected error: $e');
      debugPrint('[ExerciseAdminEditScreen] Stack trace: $stackTrace');

      setState(() {
        _isUploadingImage = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Clear image URL
  void _clearImage() {
    setState(() {
      _imageUrlController.clear();
    });
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
        return 'image/jpeg'; // Default fallback
    }
  }
}
