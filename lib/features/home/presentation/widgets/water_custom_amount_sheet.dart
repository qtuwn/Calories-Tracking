import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calories_app/core/theme/theme.dart';
import 'package:calories_app/features/home/presentation/providers/water_intake_provider.dart';

/// A modal bottom sheet for adding a custom amount of water intake.
/// 
/// Allows the user to:
/// - Input a custom amount in ml using a numeric text field
/// - Select from common preset amounts (330ml, 500ml, 1000ml)
/// - Validate input (positive, max 5000ml)
/// - Save or cancel the water intake entry
class WaterCustomAmountSheet extends ConsumerStatefulWidget {
  const WaterCustomAmountSheet({super.key});

  @override
  ConsumerState<WaterCustomAmountSheet> createState() =>
      _WaterCustomAmountSheetState();
}

class _WaterCustomAmountSheetState
    extends ConsumerState<WaterCustomAmountSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  /// Handle preset amount button tap
  void _handlePresetAmount(int amountMl) {
    _amountController.text = amountMl.toString();
  }

  /// Handle save button tap
  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final amountMl = int.parse(_amountController.text.trim());

      await ref.read(dailyWaterIntakeProvider.notifier).addWater(amountMl);

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi khi thêm nước: ${e.toString()}';
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
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.mintGreen.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.water_drop,
                        size: 28,
                        color: AppColors.mintGreen,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Thêm lượng nước',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Nhập số lượng tùy chỉnh',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: AppColors.mediumGray,
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      color: AppColors.mediumGray,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Amount input field
                Text(
                  'Lượng nước (ml) *',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.nearBlack,
                      ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Ví dụ: 750',
                    suffixText: 'ml',
                    filled: true,
                    fillColor: AppColors.nearBlack.withValues(alpha: 0.04),
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
                      return 'Vui lòng nhập lượng nước';
                    }
                    final amount = int.tryParse(value.trim());
                    if (amount == null || amount <= 0) {
                      return 'Lượng nước phải lớn hơn 0';
                    }
                    if (amount > 5000) {
                      return 'Lượng nước không được quá 5000ml';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Preset amounts
                Text(
                  'Số lượng phổ biến',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.nearBlack,
                      ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PresetButton(
                      label: '330 ml',
                      subtitle: 'Lon',
                      icon: Icons.local_drink_outlined,
                      onTap: () => _handlePresetAmount(330),
                    ),
                    _PresetButton(
                      label: '500 ml',
                      subtitle: 'Chai',
                      icon: Icons.water_outlined,
                      onTap: () => _handlePresetAmount(500),
                    ),
                    _PresetButton(
                      label: '1000 ml',
                      subtitle: 'Bình',
                      icon: Icons.sports_bar_outlined,
                      onTap: () => _handlePresetAmount(1000),
                    ),
                  ],
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
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: BorderSide(
                            color: AppColors.mediumGray.withValues(alpha: 0.5),
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
                          backgroundColor: AppColors.mintGreen,
                          foregroundColor: AppColors.nearBlack,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.nearBlack,
                                ),
                              )
                            : const Text('Thêm'),
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

/// A preset amount button widget
class _PresetButton extends StatelessWidget {
  const _PresetButton({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.nearBlack.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.mediumGray.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: AppColors.mintGreen,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.nearBlack,
                      ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.mediumGray,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

