import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:calories_app/shared/state/auth_providers.dart';
import 'package:calories_app/features/onboarding/domain/profile_model.dart';
import 'package:calories_app/data/firebase/profile_repository.dart';
import 'package:calories_app/features/home/presentation/controllers/avatar_upload_controller.dart';
import 'package:calories_app/features/home/presentation/pages/settings_page.dart';
import 'package:calories_app/features/home/presentation/widgets/edit_profile_sheet.dart';
import 'package:calories_app/features/home/presentation/widgets/customize_nutrition_sheet.dart';

class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use auth-aware profile provider that automatically updates when user changes
    // This ensures AccountPage always shows the correct profile after account switches
    final profileDataAsync = ref.watch(currentUserProfileProvider);
    
    // Also watch auth state to get user info for display
    final authStateAsync = ref.watch(authStateProvider);
    final user = authStateAsync.value;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Tài khoản',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.black87),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SettingsPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: profileDataAsync.when(
        data: (profile) {
          debugPrint('[AccountPage] Profile data received: ${profile != null ? "exists" : "null"}, user: ${user?.uid ?? "null"}');
          
          // If user is null, we're still loading auth state - show loading
          if (user == null) {
            debugPrint('[AccountPage] Waiting for auth state...');
            return const Center(child: CircularProgressIndicator());
          }
          
          // If we have a user but no profile, show empty state
          // This only happens when there is truly no profile document in Firestore
          if (profile == null) {
            debugPrint('[AccountPage] Showing empty state - user authenticated (uid=${user.uid}) but no profile found');
            return _buildNoProfileView(context, ref);
          }
          
          // We have both user and profile - show the full profile view
          debugPrint('[AccountPage] Showing profile view for user: ${profile.nickname ?? "unnamed"} (uid=${user.uid})');
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                children: [
                  // Profile Header
                  _buildProfileHeader(context, ref, user, profile),
                  const SizedBox(height: 24),

                  // Journey Card
                  _buildJourneyCard(context, profile),
                  const SizedBox(height: 20),

                  // Nutrition Goals Card
                  _buildNutritionGoalsCard(context, ref, profile),
                  const SizedBox(height: 20),

                  // Reports Section (optional)
                  _buildReportsSection(context),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
        loading: () {
          debugPrint('[AccountPage] Loading profile data...');
          return const Center(child: CircularProgressIndicator());
        },
        error: (error, stack) {
          debugPrint('[AccountPage] Error loading profile: $error');
          debugPrint('[AccountPage] Stack trace: $stack');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Lỗi tải dữ liệu',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // Invalidate the auth-aware provider
                    ref.invalidate(currentUserProfileProvider);
                  },
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNoProfileView(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Không tìm thấy hồ sơ',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Vui lòng hoàn thành quá trình đăng ký để tạo hồ sơ.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Navigate to onboarding/welcome screen
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/login',
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFAAF0D1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('Tạo hồ sơ'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(
    BuildContext context,
    WidgetRef ref,
    User? user,
    ProfileModel? profile,
  ) {
    // Use nickname from profile if available, otherwise fallback to displayName or default
    final displayName = profile?.nickname ?? 
                        user?.displayName ?? 
                        'Người dùng';
    final email = user?.email ?? 'user@example.com';
    final uploadState = ref.watch(avatarUploadControllerProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _pickAndUploadAvatar(context, ref, user, profile),
            child: Stack(
              children: [
                // Avatar circle
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: profile?.photoBase64 != null && profile!.photoBase64!.isNotEmpty
                        ? null
                        : const LinearGradient(
                            colors: [Color(0xFFAAF0D1), Color(0xFF7FD8BE)],
                          ),
                    color: profile?.photoBase64 != null && profile!.photoBase64!.isNotEmpty
                        ? Colors.transparent
                        : null,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: profile?.photoBase64 != null && profile!.photoBase64!.isNotEmpty
                      ? ClipOval(
                          child: Image.memory(
                            base64Decode(profile.photoBase64!),
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              debugPrint('[AccountPage] 🔥 Error decoding base64 image: $error');
                              return const Icon(Icons.person, size: 50, color: Colors.white);
                            },
                          ),
                        )
                      : const Icon(Icons.person, size: 50, color: Colors.white),
                ),
                // Camera icon overlay
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFAAF0D1),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
                // Uploading overlay
                if (uploadState.isUploading)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.5),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            displayName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(email, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              _navigateToEditProfile(context, profile);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFAAF0D1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('Chỉnh sửa hồ sơ'),
          ),
        ],
      ),
    );
  }

  /// Build "Hành trình của bạn" (Your Journey) card
  Widget _buildJourneyCard(BuildContext context, ProfileModel? profile) {
    final currentWeight = profile?.weightKg ?? 0.0;
    final targetWeight = profile?.targetWeight ?? 0.0;
    final goalType = profile?.goalType ?? 'maintain';
    
    // Estimate start weight based on goal type
    // For simplicity, we'll use current weight as start if no historical data
    double startWeight = currentWeight;
    if (goalType == 'lose' && targetWeight > 0 && currentWeight > targetWeight) {
      // Estimate start weight slightly higher than current for weight loss journey
      startWeight = currentWeight + (currentWeight - targetWeight) * 0.3;
    } else if (goalType == 'gain' && targetWeight > 0 && currentWeight < targetWeight) {
      // Estimate start weight slightly lower than current for weight gain journey
      startWeight = currentWeight - (targetWeight - currentWeight) * 0.3;
    }

    // Calculate progress (0.0 to 1.0)
    double progress = 0.0;
    if (startWeight != targetWeight && startWeight != currentWeight) {
      if (goalType == 'lose') {
        progress = (startWeight - currentWeight) / (startWeight - targetWeight);
      } else if (goalType == 'gain') {
        progress = (currentWeight - startWeight) / (targetWeight - startWeight);
      } else {
        // maintain: progress is based on how close current is to target
        progress = 1.0 - ((currentWeight - targetWeight).abs() / (startWeight * 0.1).clamp(0.1, 1.0));
      }
    }
    progress = progress.clamp(0.0, 1.0);

    // Determine subtitle based on goal type and progress
    String subtitle;
    if (goalType == 'lose') {
      subtitle = 'Bạn đang giảm cân, cố gắng lên!';
    } else if (goalType == 'gain') {
      subtitle = 'Bạn đang trong giai đoạn tăng cân lành mạnh!';
    } else {
      subtitle = 'Bạn đang duy trì cân nặng rất tốt!';
    }

    return GestureDetector(
      onTap: () {
        // TODO: Navigate to body/physical profile screen when implemented
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tính năng hồ sơ thể chất sẽ được cập nhật sau'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hành trình của bạn',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 20),
            // Progress slider
            LayoutBuilder(
              builder: (context, constraints) {
                final sliderWidth = constraints.maxWidth;
                final markerPosition = (progress * sliderWidth).clamp(8.0, sliderWidth - 8.0);
                
                return Stack(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFFAAF0D1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    // Current weight marker
                    Positioned(
                      left: markerPosition - 8,
                      top: -4,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: const Color(0xFFAAF0D1),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${startWeight.toStringAsFixed(1)} kg',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                Text(
                  '${targetWeight.toStringAsFixed(1)} kg',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build "Mục tiêu dinh dưỡng & đa lượng" (Nutrition Goals) card
  Widget _buildNutritionGoalsCard(BuildContext context, WidgetRef ref, ProfileModel? profile) {
    final targetKcal = profile?.targetKcal ?? 0.0;
    final proteinGrams = profile?.proteinGrams ?? 0.0;
    final carbGrams = profile?.carbGrams ?? 0.0;
    final fatGrams = profile?.fatGrams ?? 0.0;
    final proteinPercent = profile?.proteinPercent ?? 0.0;
    final carbPercent = profile?.carbPercent ?? 0.0;
    final fatPercent = profile?.fatPercent ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mục tiêu dinh dưỡng & đa lượng',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Circular chart for calorie target
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: CircularProgressIndicator(
                        value: 1.0,
                        strokeWidth: 10,
                        backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFAAF0D1)),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          targetKcal.toStringAsFixed(0),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                        ),
                        Text(
                          'kcal',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Macro rows
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMacroRow('Chất đạm', proteinPercent, proteinGrams, const Color(0xFF81C784)),
                    const SizedBox(height: 12),
                    _buildMacroRow('Đường bột', carbPercent, carbGrams, const Color(0xFF64B5F6)),
                    const SizedBox(height: 12),
                    _buildMacroRow('Chất béo', fatPercent, fatGrams, const Color(0xFFF48FB1)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _navigateToCustomizeNutrition(context, profile),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFAAF0D1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Tuỳ chỉnh mục tiêu'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroRow(String label, double percent, double grams, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        Text(
          '${percent.toStringAsFixed(0)}% (${grams.toStringAsFixed(0)}g)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  /// Build "Xem báo cáo thống kê" (View Reports) section
  Widget _buildReportsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Xem báo cáo thống kê',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildReportIconButton(
              context,
              icon: Icons.restaurant_menu,
              label: 'Dinh dưỡng',
              color: const Color(0xFFAAF0D1),
            ),
            _buildReportIconButton(
              context,
              icon: Icons.fitness_center,
              label: 'Tập luyện',
              color: const Color(0xFF81C784),
            ),
            _buildReportIconButton(
              context,
              icon: Icons.directions_walk,
              label: 'Số bước',
              color: const Color(0xFF64B5F6),
            ),
            _buildReportIconButton(
              context,
              icon: Icons.monitor_weight,
              label: 'Cân nặng',
              color: const Color(0xFFF48FB1),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReportIconButton(BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tính năng $label sẽ được cập nhật sau'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black87,
                  fontSize: 12,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }


  /// Pick image from gallery and upload to Firestore as base64
  Future<void> _pickAndUploadAvatar(
    BuildContext context,
    WidgetRef ref,
    User? user,
    ProfileModel? profile,
  ) async {
    debugPrint('[AccountPage] 🔵 Starting avatar pick and upload');

    // Check if user is signed in
    final uid = user?.uid;
    if (uid == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bạn cần đăng nhập để cập nhật ảnh hồ sơ'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Pick image from gallery
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );

    if (picked == null) {
      debugPrint('[AccountPage] ℹ️ User cancelled image picker');
      return;
    }

    debugPrint('[AccountPage] ✅ Image picked: ${picked.path}');

    // Get current profileId
    final repository = ProfileRepository();
    final profileId = await repository.getCurrentProfileId(uid);

    if (profileId == null) {
      debugPrint('[AccountPage] 🔥 No current profile found');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không tìm thấy hồ sơ. Vui lòng hoàn thành đăng ký.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Set uploading state
    ref.read(avatarUploadControllerProvider.notifier).setUploading(true);

    try {
      // Read bytes and convert to base64
      debugPrint('[AccountPage] 📤 Reading image bytes and encoding to base64...');
      final bytes = await picked.readAsBytes();
      final base64String = base64Encode(bytes);
      debugPrint('[AccountPage] ✅ Image encoded to base64 (${base64String.length} chars)');

      // Update Firestore with base64 string
      debugPrint('[AccountPage] 📝 Updating Firestore with photoBase64...');
      await repository.updateProfileAvatarBase64(
        uid: uid,
        profileId: profileId,
        photoBase64: base64String,
      );

      // Success - clear uploading state
      ref.read(avatarUploadControllerProvider.notifier).setUploading(false);

      debugPrint('[AccountPage] ✅ Avatar uploaded and updated successfully');

      // Invalidate the profile providers to force immediate refresh
      // This ensures the UI updates immediately even if Firestore snapshot has a slight delay
      ref.invalidate(currentUserProfileDataProvider(uid));
      ref.invalidate(currentUserProfileProvider);
      debugPrint('[AccountPage] 🔄 Invalidated profile providers to force refresh');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cập nhật ảnh đại diện thành công'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('[AccountPage] 🔥 Error uploading avatar: $e');
      debugPrint('[AccountPage] Stack trace: $stackTrace');

      // Set error state
      ref.read(avatarUploadControllerProvider.notifier).setError(e.toString());

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi cập nhật ảnh: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      // Ensure uploading state is cleared
      ref.read(avatarUploadControllerProvider.notifier).setUploading(false);
    }
  }

  // Navigation methods
  void _navigateToEditProfile(BuildContext context, ProfileModel? profile) {
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể chỉnh sửa hồ sơ. Vui lòng thử lại.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditProfileSheet(profile: profile),
    );
  }

  void _navigateToCustomizeNutrition(BuildContext context, ProfileModel? profile) {
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể tùy chỉnh mục tiêu. Vui lòng thử lại.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CustomizeNutritionSheet(profile: profile),
    );
  }

}
