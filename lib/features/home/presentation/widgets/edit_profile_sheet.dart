import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calories_app/core/utils/bmi_calculator.dart';
import 'package:calories_app/features/onboarding/domain/profile_model.dart';
import 'package:calories_app/data/firebase/profile_repository.dart';
import 'package:calories_app/shared/state/auth_providers.dart';

/// Gender option with canonical value for storage and Vietnamese label for display.
/// 
/// Ensures consistent gender values across the app:
/// - Value: 'male', 'female', 'other' (stored in Firestore)
/// - Label: 'Nam', 'Nữ', 'Khác' (displayed in UI)
class GenderOption {
  final String value; // Canonical value for storage ('male', 'female', 'other')
  final String label; // Vietnamese label for display ('Nam', 'Nữ', 'Khác')

  const GenderOption(this.value, this.label);
}

/// Modal bottom sheet for editing physical profile attributes.
/// 
/// Allows user to update:
/// - Gender
/// - Age/Date of Birth
/// - Height (cm)
/// - Current Weight (kg)
/// - Target Weight (kg)
/// - Activity Level
/// 
/// Changes are persisted to Firestore and trigger automatic UI updates
/// via the currentUserProfileProvider stream.
class EditProfileSheet extends ConsumerStatefulWidget {
  const EditProfileSheet({
    super.key,
    required this.profile,
  });

  final ProfileModel profile;

  @override
  ConsumerState<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _heightController;
  late TextEditingController _currentWeightController;
  late TextEditingController _targetWeightController;
  
  // Dropdown values
  String? _selectedGender;
  String? _selectedActivityLevel;
  String? _selectedGoalType;
  
  bool _isLoading = false;
  String? _errorMessage;

  /// Gender options with canonical values for storage and Vietnamese labels for display.
  /// 
  /// Values stored in Firestore: 'male', 'female', 'other'
  /// Labels displayed in UI: 'Nam', 'Nữ', 'Khác'
  static const List<GenderOption> _genderOptions = [
    GenderOption('male', 'Nam'),
    GenderOption('female', 'Nữ'),
    GenderOption('other', 'Khác'),
  ];

  // Activity level options with multipliers
  final Map<String, double> _activityLevels = {
    'Ít vận động': 1.2,
    'Nhẹ (1-3 ngày/tuần)': 1.375,
    'Vừa phải (3-5 ngày/tuần)': 1.55,
    'Nhiều (6-7 ngày/tuần)': 1.725,
    'Rất nhiều (2 lần/ngày)': 1.9,
  };

  // Goal types
  final Map<String, String> _goalTypes = {
    'Giảm cân': 'lose',
    'Duy trì': 'maintain',
    'Tăng cân': 'gain',
  };

  @override
  void initState() {
    super.initState();
    
    // Initialize controllers with current profile values
    // Use nickname from profile, or fallback to empty string
    _nameController = TextEditingController(
      text: widget.profile.nickname ?? '',
    );
    _ageController = TextEditingController(
      text: widget.profile.age?.toString() ?? '',
    );
    _heightController = TextEditingController(
      text: widget.profile.heightCm?.toString() ?? '',
    );
    _currentWeightController = TextEditingController(
      text: widget.profile.weightKg?.toStringAsFixed(1) ?? '',
    );
    _targetWeightController = TextEditingController(
      text: widget.profile.targetWeight?.toStringAsFixed(1) ?? '',
    );
    
    // Initialize dropdown values
    // Map profile gender value to dropdown value, ensuring it's valid
    final profileGender = widget.profile.gender;
    if (profileGender != null && 
        _genderOptions.any((g) => g.value == profileGender)) {
      _selectedGender = profileGender; // Use canonical value ('male', 'female', 'other')
    } else {
      _selectedGender = null; // Invalid or missing gender - let user select
    }
    
    // Find activity level key from multiplier
    if (widget.profile.activityMultiplier != null) {
      _activityLevels.forEach((key, value) {
        if ((value - widget.profile.activityMultiplier!).abs() < 0.01) {
          _selectedActivityLevel = key;
        }
      });
    }
    _selectedActivityLevel ??= _activityLevels.keys.first;
    
    // Find goal type key from value
    if (widget.profile.goalType != null) {
      _goalTypes.forEach((key, value) {
        if (value == widget.profile.goalType) {
          _selectedGoalType = key;
        }
      });
    }
    _selectedGoalType ??= _goalTypes.keys.elementAt(1); // Default to maintain
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _currentWeightController.dispose();
    _targetWeightController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authState = ref.read(authStateProvider);
      final uid = authState.when(
        data: (user) => user?.uid,
        loading: () => null,
        error: (_, __) => null,
      );

      if (uid == null) {
        throw Exception('Bạn cần đăng nhập để cập nhật hồ sơ');
      }

      // Parse form values
      final name = _nameController.text.trim();
      final age = int.parse(_ageController.text.trim());
      final heightCm = int.parse(_heightController.text.trim());
      final currentWeight = double.parse(_currentWeightController.text.trim());
      final targetWeight = double.parse(_targetWeightController.text.trim());
      final activityMultiplier = _activityLevels[_selectedActivityLevel]!;
      final goalType = _goalTypes[_selectedGoalType]!;

      // Calculate BMI using shared BmiCalculator utility
      double? bmi;
      try {
        bmi = BmiCalculator.calculate(
          weightKg: currentWeight,
          heightCm: heightCm,
        );
      } catch (e) {
        // Invalid input, bmi remains null
        debugPrint('[EditProfileSheet] ⚠️ Could not calculate BMI: $e');
      }

      // Create updated profile
      final heightM = heightCm / 100.0;
      final updatedProfile = widget.profile.copyWith(
        nickname: name,
        age: age,
        heightCm: heightCm,
        height: heightM,
        weightKg: currentWeight,
        weight: currentWeight,
        targetWeight: targetWeight,
        gender: _selectedGender,
        activityLevel: _selectedActivityLevel,
        activityMultiplier: activityMultiplier,
        goalType: goalType,
        bmi: bmi,
      );

      // Update via repository (updates both profile nickname and user document displayName)
      final repository = ProfileRepository();
      await repository.updateCurrentProfileFromModel(uid, updatedProfile);
      await repository.updateUserDisplayName(uid, name);

      if (mounted) {
        // Invalidate providers to trigger refresh
        ref.invalidate(currentUserProfileDataProvider(uid));
        ref.invalidate(currentUserProfileProvider);
        // Also invalidate the UserProfile provider to refresh displayName
        ref.invalidate(currentProfileProvider(uid));
        
        Navigator.of(context).pop(true);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cập nhật hồ sơ thành công'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi cập nhật hồ sơ: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(Icons.edit_outlined, size: 28, color: Color(0xFFAAF0D1)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Chỉnh sửa hồ sơ',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Name field
                Text(
                  'Họ tên *',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'Ví dụ: Nguyễn Văn A',
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập họ tên';
                    }
                    final trimmed = value.trim();
                    if (trimmed.length < 2) {
                      return 'Họ tên phải có ít nhất 2 ký tự';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Gender dropdown
                Text(
                  'Giới tính *',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: _genderOptions.map((option) {
                    return DropdownMenuItem<String>(
                      value: option.value, // Use canonical value for storage
                      child: Text(option.label), // Display Vietnamese label
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedGender = value),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng chọn giới tính';
                    }
                    // Ensure value is one of the valid options
                    if (!_genderOptions.any((g) => g.value == value)) {
                      return 'Giá trị không hợp lệ';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Age
                Text(
                  'Tuổi *',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    hintText: 'Ví dụ: 25',
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập tuổi';
                    }
                    final age = int.tryParse(value.trim());
                    if (age == null || age < 15 || age > 100) {
                      return 'Tuổi phải từ 15-100';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Height
                Text(
                  'Chiều cao (cm) *',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _heightController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    hintText: 'Ví dụ: 170',
                    suffixText: 'cm',
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập chiều cao';
                    }
                    final height = int.tryParse(value.trim());
                    if (height == null || height < 120 || height > 220) {
                      return 'Chiều cao phải từ 120-220 cm';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Current Weight
                Text(
                  'Cân nặng hiện tại (kg) *',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _currentWeightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                  ],
                  decoration: InputDecoration(
                    hintText: 'Ví dụ: 65.5',
                    suffixText: 'kg',
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập cân nặng';
                    }
                    final weight = double.tryParse(value.trim());
                    if (weight == null || weight < 35 || weight > 200) {
                      return 'Cân nặng phải từ 35-200 kg';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Goal Type
                Text(
                  'Mục tiêu *',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedGoalType,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: _goalTypes.keys.map((goal) {
                    return DropdownMenuItem(value: goal, child: Text(goal));
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedGoalType = value),
                  validator: (value) => value == null ? 'Vui lòng chọn mục tiêu' : null,
                ),
                const SizedBox(height: 16),

                // Target Weight
                Text(
                  'Cân nặng mục tiêu (kg) *',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _targetWeightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                  ],
                  decoration: InputDecoration(
                    hintText: 'Ví dụ: 60.0',
                    suffixText: 'kg',
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập cân nặng mục tiêu';
                    }
                    final weight = double.tryParse(value.trim());
                    if (weight == null || weight < 35 || weight > 200) {
                      return 'Cân nặng phải từ 35-200 kg';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Activity Level
                Text(
                  'Mức độ hoạt động *',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedActivityLevel,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: _activityLevels.keys.map((level) {
                    return DropdownMenuItem(value: level, child: Text(level));
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedActivityLevel = value),
                  validator: (value) => value == null ? 'Vui lòng chọn mức độ hoạt động' : null,
                ),
                const SizedBox(height: 24),

                // Error message
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _errorMessage!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.red,
                          ),
                    ),
                  ),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Hủy'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFAAF0D1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Lưu'),
                      ),
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
}

