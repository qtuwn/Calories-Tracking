import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calories_app/features/home/presentation/providers/weight_providers.dart';
import 'package:calories_app/shared/ui/app_toast.dart';

/// Modal bottom sheet for updating today's weight.
///
/// Allows user to enter their current weight in kilograms.
/// The weight is saved to Firestore and automatically syncs with the profile.
///
/// If a weight entry for today already exists, it will be updated.
/// Otherwise, a new entry will be created.
class UpdateWeightSheet extends ConsumerStatefulWidget {
  const UpdateWeightSheet({super.key, this.initialWeight});

  /// Initial weight value to pre-fill the form (e.g. last recorded weight)
  final double? initialWeight;

  @override
  ConsumerState<UpdateWeightSheet> createState() => _UpdateWeightSheetState();
}

class _UpdateWeightSheetState extends ConsumerState<UpdateWeightSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _weightController;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    // Initialize controller with initial weight or empty
    _weightController = TextEditingController(
      text: widget.initialWeight?.toStringAsFixed(1) ?? '',
    );
  }

  @override
  void dispose() {
    _weightController.dispose();
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
      final weightKg = double.parse(_weightController.text.trim());

      final controller = ref.read(weightControllerProvider.notifier);
      await controller.updateTodayWeight(weightKg);

      if (mounted) {
        // Invalidate providers to trigger refresh
        ref.invalidate(latestWeightProvider);
        ref.invalidate(recentWeights7DaysProvider);
        ref.invalidate(recentWeights30DaysProvider);

        Navigator.of(context).pop(true);

        showAppToast(
          context,
          message: 'Cập nhật cân nặng thành công',
          type: AppToastType.success,
          extraBottomOffset: 12,
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi cập nhật cân nặng: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cập nhật cân nặng',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Weight input
            Text(
              'Cân nặng (kg) *',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _weightController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
              ],
              enabled: !_isLoading,
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
                if (weight == null) {
                  return 'Cân nặng không hợp lệ';
                }
                if (weight <= 0) {
                  return 'Cân nặng phải lớn hơn 0';
                }
                if (weight > 500) {
                  return 'Cân nặng phải nhỏ hơn 500 kg';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Error message
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red[700], fontSize: 14),
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
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Hủy'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFAAF0D1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text('Lưu'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
