import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calories_app/domain/profile/profile.dart';
import 'package:calories_app/shared/state/profile_providers.dart' as profile_providers;
import 'package:calories_app/shared/state/auth_providers.dart';

/// Modal bottom sheet for customizing nutrition targets and macro distribution.
/// 
/// Allows user to set:
/// - Daily calorie target (kcal)
/// - Protein percentage (%)
/// - Carbs percentage (%)
/// - Fat percentage (%)
/// 
/// The sheet validates that percentages sum to 100% and calculates
/// derived grams based on standard calorie conversions:
/// - Protein: 4 kcal/gram
/// - Carbs: 4 kcal/gram
/// - Fat: 9 kcal/gram
/// 
/// Changes are persisted to Firestore and automatically update the UI
/// via currentUserProfileProvider stream.
class CustomizeNutritionSheet extends ConsumerStatefulWidget {
  const CustomizeNutritionSheet({
    super.key,
    required this.profile,
  });

  final Profile profile;

  @override
  ConsumerState<CustomizeNutritionSheet> createState() =>
      _CustomizeNutritionSheetState();
}

class _CustomizeNutritionSheetState
    extends ConsumerState<CustomizeNutritionSheet> {
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  late TextEditingController _caloriesController;
  late TextEditingController _proteinPercentController;
  late TextEditingController _carbPercentController;
  late TextEditingController _fatPercentController;
  
  bool _isLoading = false;
  String? _errorMessage;

  // Calculated grams (derived values)
  double _proteinGrams = 0.0;
  double _carbGrams = 0.0;
  double _fatGrams = 0.0;

  @override
  void initState() {
    super.initState();
    
    // Initialize controllers with current profile values
    _caloriesController = TextEditingController(
      text: widget.profile.targetKcal?.toStringAsFixed(0) ?? '2000',
    );
    _proteinPercentController = TextEditingController(
      text: widget.profile.proteinPercent?.toStringAsFixed(0) ?? '20',
    );
    _carbPercentController = TextEditingController(
      text: widget.profile.carbPercent?.toStringAsFixed(0) ?? '50',
    );
    _fatPercentController = TextEditingController(
      text: widget.profile.fatPercent?.toStringAsFixed(0) ?? '30',
    );
    
    // Calculate initial grams
    _calculateGrams();
    
    // Add listeners to recalculate grams on input change
    _caloriesController.addListener(_calculateGrams);
    _proteinPercentController.addListener(_calculateGrams);
    _carbPercentController.addListener(_calculateGrams);
    _fatPercentController.addListener(_calculateGrams);
  }

  @override
  void dispose() {
    _caloriesController.dispose();
    _proteinPercentController.dispose();
    _carbPercentController.dispose();
    _fatPercentController.dispose();
    super.dispose();
  }

  /// Calculate derived grams from percentages and total calories
  void _calculateGrams() {
    final calories = double.tryParse(_caloriesController.text.trim()) ?? 0.0;
    final proteinPercent = double.tryParse(_proteinPercentController.text.trim()) ?? 0.0;
    final carbPercent = double.tryParse(_carbPercentController.text.trim()) ?? 0.0;
    final fatPercent = double.tryParse(_fatPercentController.text.trim()) ?? 0.0;

    setState(() {
      // Protein: 4 kcal/gram
      _proteinGrams = (calories * proteinPercent / 100) / 4;
      // Carbs: 4 kcal/gram
      _carbGrams = (calories * carbPercent / 100) / 4;
      // Fat: 9 kcal/gram
      _fatGrams = (calories * fatPercent / 100) / 9;
    });
  }

  /// Validate that macro percentages sum to 100%
  String? _validateMacroSum() {
    final proteinPercent = double.tryParse(_proteinPercentController.text.trim()) ?? 0.0;
    final carbPercent = double.tryParse(_carbPercentController.text.trim()) ?? 0.0;
    final fatPercent = double.tryParse(_fatPercentController.text.trim()) ?? 0.0;
    
    final sum = proteinPercent + carbPercent + fatPercent;
    
    // Allow small floating point tolerance
    if ((sum - 100).abs() > 0.5) {
      return 'Tổng các chất phải bằng 100% (hiện tại: ${sum.toStringAsFixed(1)}%)';
    }
    
    return null;
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate macro sum
    final macroSumError = _validateMacroSum();
    if (macroSumError != null) {
      setState(() => _errorMessage = macroSumError);
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
        throw Exception('Bạn cần đăng nhập để cập nhật mục tiêu');
      }

      // Parse form values
      final targetKcal = double.parse(_caloriesController.text.trim());
      final proteinPercent = double.parse(_proteinPercentController.text.trim());
      final carbPercent = double.parse(_carbPercentController.text.trim());
      final fatPercent = double.parse(_fatPercentController.text.trim());

      // Calculate grams from percentages
      // Protein & Carbs: 4 kcal/g, Fat: 9 kcal/g
      final proteinKcal = targetKcal * proteinPercent / 100;
      final carbKcal = targetKcal * carbPercent / 100;
      final fatKcal = targetKcal * fatPercent / 100;

      final proteinGrams = proteinKcal / 4;
      final carbGrams = carbKcal / 4;
      final fatGrams = fatKcal / 9;

      // Update profile via ProfileService
      final service = ref.read(profile_providers.profileServiceProvider);
      
      // Get current profile ID
      final repository = ref.read(profile_providers.profileRepositoryProvider);
      final profiles = await repository.getUserProfiles(uid);
      final currentProfileDoc = profiles.firstWhere(
        (p) => p['isCurrent'] == true,
        orElse: () => profiles.first,
      );
      final currentProfileId = currentProfileDoc['id'] as String;
      
      // Update profile with new nutrition targets
      final updatedProfile = widget.profile.copyWith(
        targetKcal: targetKcal,
        proteinPercent: proteinPercent,
        carbPercent: carbPercent,
        fatPercent: fatPercent,
        proteinGrams: proteinGrams,
        carbGrams: carbGrams,
        fatGrams: fatGrams,
      );
      
      await service.updateProfile(uid, currentProfileId, updatedProfile);

      if (mounted) {
        // Invalidate providers to trigger refresh
        ref.invalidate(currentUserProfileDataProvider(uid));
        ref.invalidate(currentUserProfileProvider);
        
        Navigator.of(context).pop(true);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cập nhật mục tiêu dinh dưỡng thành công'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi cập nhật mục tiêu: ${e.toString()}';
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
                    const Icon(Icons.track_changes_outlined, size: 28, color: Color(0xFFAAF0D1)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Tùy chỉnh mục tiêu',
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
                const SizedBox(height: 8),
                Text(
                  'Thiết lập mục tiêu calo và phân bổ dinh dưỡng hàng ngày',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 24),

                // Daily Calories
                Text(
                  'Calo mục tiêu hàng ngày (kcal) *',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _caloriesController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    hintText: 'Ví dụ: 2000',
                    suffixText: 'kcal',
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập calo mục tiêu';
                    }
                    final calories = int.tryParse(value.trim());
                    if (calories == null || calories < 1000 || calories > 5000) {
                      return 'Calo phải từ 1000-5000 kcal';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Macro Distribution Title
                Text(
                  'Phân bổ dinh dưỡng đa lượng *',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tổng các phần trăm phải bằng 100%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 16),

                // Protein
                _buildMacroInput(
                  label: 'Chất đạm (Protein)',
                  controller: _proteinPercentController,
                  grams: _proteinGrams,
                  color: const Color(0xFF81C784),
                ),
                const SizedBox(height: 16),

                // Carbs
                _buildMacroInput(
                  label: 'Đường bột (Carbs)',
                  controller: _carbPercentController,
                  grams: _carbGrams,
                  color: const Color(0xFF64B5F6),
                ),
                const SizedBox(height: 16),

                // Fat
                _buildMacroInput(
                  label: 'Chất béo (Fat)',
                  controller: _fatPercentController,
                  grams: _fatGrams,
                  color: const Color(0xFFF48FB1),
                ),
                const SizedBox(height: 24),

                // Error message
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.red[900],
                                  ),
                            ),
                          ),
                        ],
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

  Widget _buildMacroInput({
    required String label,
    required TextEditingController controller,
    required double grams,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: controller,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: '20',
                  suffixText: '%',
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Bắt buộc';
                  }
                  final percent = int.tryParse(value.trim());
                  if (percent == null || percent < 0 || percent > 100) {
                    return '0-100%';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '≈ ${grams.toStringAsFixed(0)} g',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

