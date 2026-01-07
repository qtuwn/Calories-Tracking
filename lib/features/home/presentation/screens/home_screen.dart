import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calories_app/features/home/presentation/pages/dashboard_page.dart';
import 'package:calories_app/features/home/presentation/pages/diary_page.dart';
import 'package:calories_app/features/home/presentation/pages/menu_page.dart';
import 'package:calories_app/features/home/presentation/pages/profile_page.dart';
import 'package:calories_app/core/notifications/fcm_token_provider.dart';
import 'package:calories_app/core/bootstrap/startup_orchestrator.dart';
import 'package:calories_app/features/voice_input/presentation/widgets/voice_input_button.dart';
import 'package:calories_app/features/voice_input/domain/entities/recognized_food.dart';
import 'package:calories_app/features/voice_input/presentation/controllers/voice_controller.dart';
import 'package:calories_app/features/voice_input/presentation/widgets/voice_suggestions_bottom_sheet.dart';
import 'package:calories_app/domain/foods/food.dart';
import 'package:calories_app/shared/state/diary_providers.dart';
import 'package:calories_app/features/home/presentation/providers/weight_providers.dart';
import 'package:calories_app/features/diary/domain/services/meal_time_classifier.dart';
import 'package:calories_app/shared/ui/voice_toast.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  bool _fcmInitialized = false;

  @override
  void initState() {
    super.initState();

    // PHASE A: Mark first frame and start deferred initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StartupOrchestrator.markFirstFrame();

      // OPTIMIZATION: Defer FCM token manager to after first frame
      // This prevents blocking the initial render
      if (!_fcmInitialized) {
        _fcmInitialized = true;
        ref.read(fcmTokenManagerProvider);
        debugPrint('[HomeScreen] ✅ FCM token manager initialized (post-frame)');
      }

      // Delay background services by 5-10 seconds to allow UI to stabilize
      Future.delayed(const Duration(seconds: 5), () {
        StartupOrchestrator.ensureDeferredInitialized(ref);
      });
    });
  }

  // OPTIMIZATION: Build pages lazily only when navigated to
  // This prevents creating all 4 pages and their providers during first frame
  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return DashboardPage(
          onNavigateToDiary: () {
            setState(() {
              _currentIndex = 1; // Diary tab index
            });
          },
        );
      case 1:
        return const DiaryPage();
      case 2:
        return MenuPage(
          onNavigateToHome: () {
            setState(() {
              _currentIndex = 0; // Home tab index
            });
          },
        );
      case 3:
        return const AccountPage();
      default:
        return DashboardPage(
          onNavigateToDiary: () {
            setState(() {
              _currentIndex = 1;
            });
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // OPTIMIZATION: FCM token manager moved to postFrameCallback
    // No longer blocking initial build

    // Listen to voice controller state changes
    ref.listen<VoiceState>(voiceControllerProvider, (previous, next) {
      // Show bottom sheet when suggestions are ready
      if (previous?.status != VoiceStatus.suggestionsReady &&
          next.status == VoiceStatus.suggestionsReady) {
        final transcript = next.transcript ?? '';
        final suggestions = next.suggestions;

        // Show bottom sheet with suggestions
        _showVoiceSuggestionsBottomSheet(context, transcript, suggestions);
      }

      // Handle errors
      if (previous?.status != VoiceStatus.error &&
          next.status == VoiceStatus.error &&
          next.errorMessage != null) {
        final errorMsg = next.errorMessage!;
        // Check if it's a network-related error
        if (errorMsg.contains('error_network') ||
            errorMsg.contains('network')) {
          showVoiceToast(
            context,
            message:
                'Không thể nhận dạng giọng nói. Vui lòng kiểm tra kết nối mạng và thử lại.',
            type: VoiceToastType.error,
          );
        } else if (errorMsg.contains('permission') ||
            errorMsg.contains('microphone')) {
          showVoiceToast(
            context,
            message: 'Cần quyền truy cập microphone để sử dụng tính năng này.',
            type: VoiceToastType.error,
          );
        } else if (errorMsg.isNotEmpty &&
            !errorMsg.contains('No speech detected')) {
          // Only show generic error for non-empty, non-user-friendly errors
          showVoiceToast(
            context,
            message: errorMsg.length > 50
                ? '${errorMsg.substring(0, 50)}...'
                : errorMsg,
            type: VoiceToastType.error,
          );
        }
      }
    });

    return Scaffold(
      extendBody: true,
      body: _buildPage(_currentIndex),
      floatingActionButton: VoiceInputButton(
        onFoodRecognized: (RecognizedFood food) {
          // This callback is kept for backward compatibility
          // The new flow uses suggestions instead
          debugPrint(
            '[HomeScreen] 🎤 Food recognized: ${food.name}, ${food.calories} kcal, ${food.quantity}',
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: Colors.white,
        elevation: 8,
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Left side: Home and Diary tabs
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavItem(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home,
                      label: 'Trang chủ',
                      index: 0,
                    ),
                    _buildNavItem(
                      icon: Icons.book_outlined,
                      activeIcon: Icons.book,
                      label: 'Nhật Ký',
                      index: 1,
                    ),
                  ],
                ),
              ),
              // Center space for floating action button (mic)
              const SizedBox(width: 48),
              // Right side: Meal Plan and Account tabs
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavItem(
                      icon: Icons.restaurant_menu_outlined,
                      activeIcon: Icons.restaurant_menu,
                      label: 'Thực Đơn',
                      index: 2,
                    ),
                    _buildNavItem(
                      icon: Icons.person_outlined,
                      activeIcon: Icons.person,
                      label: 'Tài khoản',
                      index: 3,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? const Color(0xFFAAF0D1) : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? const Color(0xFFAAF0D1) : Colors.grey,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show bottom sheet with voice input food suggestions
  void _showVoiceSuggestionsBottomSheet(
    BuildContext context,
    String transcript,
    List<Food> suggestions,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VoiceSuggestionsBottomSheet(
        transcript: transcript,
        suggestions: suggestions,
        onAddFood: (Food food) => _handleAddFoodToDiary(context, food),
        onRetry: () {
          // Retry by starting listening again
          ref.read(voiceControllerProvider.notifier).startListening();
        },
      ),
    );
  }

  /// Handle adding a food to the diary from voice input
  Future<void> _handleAddFoodToDiary(BuildContext context, Food food) async {
    try {
      // Get current user ID
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) {
        showVoiceToast(
          context,
          message: 'Bạn cần đăng nhập để thêm món ăn',
          type: VoiceToastType.error,
        );
        return;
      }

      // Get diary service
      final diaryService = ref.read(diaryServiceProvider);

      // Add food entry with automatic meal type classification
      await diaryService.addFoodEntryFromVoice(
        userId: userId,
        food: food,
        timestamp: DateTime.now(),
      );

      // Determine meal type for display message
      final timestamp = DateTime.now();
      final mealType = MealTimeClassifier.classifyMealType(timestamp);

      debugPrint(
        '[Voice→Diary] Adding ${food.name} as ${mealType.name} at $timestamp',
      );

      // Close bottom sheet
      if (context.mounted) {
        Navigator.of(context).pop();

        // Show success message with localized meal type
        showVoiceToast(
          context,
          message: 'Đã thêm ${food.name} vào ${mealType.displayName}',
          type: VoiceToastType.success,
        );
      }

      // Clear voice controller state
      ref.read(voiceControllerProvider.notifier).clearResult();

      debugPrint(
        '[HomeScreen] ✅ Added ${food.name} to diary (${mealType.name})',
      );
    } catch (e, stackTrace) {
      debugPrint('[Voice→Diary] ❌ Failed to add food: $e');
      debugPrint('[Voice→Diary] Stack trace: $stackTrace');

      if (context.mounted) {
        showVoiceToast(
          context,
          message: 'Không thể thêm món ăn, vui lòng thử lại.',
          type: VoiceToastType.error,
        );
      }
    }
  }
}
