import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calories_app/features/home/presentation/screens/home_screen.dart';
import 'package:calories_app/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:calories_app/shared/state/auth_providers.dart';
import 'package:calories_app/shared/state/onboarding_cache_provider.dart';

/// ProfileGate - Returns HomeScreen if onboarding completed, otherwise OnboardingFlow
/// 
/// PHASE B: Render-first approach - checks SharedPreferences cache first,
/// then syncs with Firestore in background.
/// 
/// Flow:
/// 1. Check cache → if cached says completed → show HomeScreen immediately
/// 2. Start Firestore stream in background
/// 3. When Firestore arrives, reconcile and redirect if needed
class ProfileGate extends ConsumerStatefulWidget {
  final String uid;

  const ProfileGate({super.key, required this.uid});

  @override
  ConsumerState<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends ConsumerState<ProfileGate> {
  @override
  Widget build(BuildContext context) {
    // PHASE B: Render-first - check cache first (synchronous, fast)
    final cache = ref.read(onboardingCacheProvider);
    final cachedStatus = cache.getCachedStatus(widget.uid);
    
    // Start Firestore stream in background (don't block UI)
    final profileAsync = ref.watch(currentProfileProvider(widget.uid));
    
    // If we have cached status, use it immediately
    if (cachedStatus != null) {
      // Sync cache with Firestore in background
      profileAsync.whenData((profile) {
        final completed = profile?.onboardingCompleted ?? false;
        if (cachedStatus != completed) {
          // Update cache if Firestore differs
          cache.setCachedStatus(widget.uid, completed);
        }
      });
      
      // Render immediately based on cache
      if (cachedStatus) {
        return const HomeScreen();
      } else {
        return const WelcomeScreen();
      }
    }

    // No cache - wait for Firestore (fallback to original behavior)
    return profileAsync.when(
      data: (profile) {
        final completed = profile?.onboardingCompleted ?? false;
        // Update cache when Firestore data arrives
        cache.setCachedStatus(widget.uid, completed);
        
        if (completed) {
          return const HomeScreen();
        } else {
          return const WelcomeScreen();
        }
      },
      loading: () => const _SkeletonHomeScreen(),
      error: (error, stack) {
        debugPrint('[ProfileGate] ⚠️ Error reading profile: $error');
        // On error, show onboarding (safe default)
        return const WelcomeScreen();
      },
    );
  }
}

/// Lightweight skeleton screen shown while loading (if no cache)
class _SkeletonHomeScreen extends StatelessWidget {
  const _SkeletonHomeScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header skeleton
              Container(
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 24),
              // Calorie card skeleton
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text('Đang tải...', style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
