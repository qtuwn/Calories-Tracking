import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:calories_app/app/config/firebase_options.dart';
import 'package:calories_app/app/routing/intro_gate.dart';
import 'package:calories_app/core/theme/theme.dart';
import 'package:calories_app/core/bootstrap/startup_orchestrator.dart';
import 'package:calories_app/shared/state/profile_providers.dart';
import 'package:calories_app/features/auth/presentation/pages/auth_page.dart';
import 'package:calories_app/features/foods/ui/food_admin_page.dart';
import 'package:calories_app/features/admin_tools/presentation/admin_migrations_page.dart';
import 'package:calories_app/features/exercise/ui/exercise_list_screen.dart';
import 'package:calories_app/features/exercise/ui/exercise_admin_list_screen.dart';
import 'package:calories_app/features/exercise/ui/exercise_detail_screen.dart';
import 'package:calories_app/features/exercise/ui/exercise_admin_edit_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  // ========================================================================
  // CRITICAL PHASE - MINIMAL BLOCKING WORK ONLY
  // Goal: Get to runApp() as fast as possible (target < 4s)
  // Everything else moved to DEFERRED phase after first frame
  // ========================================================================
  
  StartupOrchestrator.markCriticalStart();
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables (lightweight, needed for config)
  try {
    await dotenv.load(fileName: '.env');
    debugPrint('[Main] ✅ Environment variables loaded');
  } catch (e) {
    debugPrint('[Main] ⚠️ Could not load .env file: $e');
  }
  
  // Initialize Firebase (required for auth/routing)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('[Main] ✅ Firebase initialized');
  
  // Preload SharedPreferences (CRITICAL: required for routing providers)
  // IntroGate -> ProfileGate -> onboardingCacheProvider needs this synchronously
  debugPrint('[Main] 🔵 Preloading SharedPreferences...');
  final preloadedPrefs = await SharedPreferences.getInstance();
  debugPrint('[Main] ✅ SharedPreferences preloaded');
  
  // ========================================================================
  // DEFERRED (moved to StartupOrchestrator after first frame):
  // - Intl locale & date formatting
  // - Firestore settings (persistence, cache)
  // - AppCheck activation (release-only)
  // - Local & Push notifications
  // - FCM token update
  // ========================================================================
  
  StartupOrchestrator.markRunApp();
  runApp(
    ProviderScope(
      overrides: [
        // Override SharedPreferences provider with preloaded instance
        // This ensures routing providers (ProfileGate, onboardingCache) can access it synchronously
        sharedPreferencesFutureProvider.overrideWithValue(
          AsyncValue.data(preloadedPrefs),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ăn Khỏe - Healthy Choice',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home:
          const IntroGate(), // Root: checks auth → shows intro or auth/onboarding flow
      routes: {
        '/intro': (context) =>
            const IntroGate(), // Intro route for logout navigation
        '/login': (context) => const AuthPage(), // Login route
        FoodAdminPage.routeName: (context) =>
            const FoodAdminPage(), // Food Admin route
        AdminMigrationsPage.routeName: (context) =>
            const AdminMigrationsPage(), // Admin migrations route
        ExerciseListScreen.routeName: (context) =>
            const ExerciseListScreen(), // Exercise list route
        ExerciseAdminListScreen.routeName: (context) =>
            const ExerciseAdminListScreen(), // Exercise Admin route
      },
      onGenerateRoute: (settings) {
        // Handle routes with arguments
        if (settings.name == ExerciseDetailScreen.routeName) {
          final exerciseId = settings.arguments as String?;
          if (exerciseId != null) {
            return MaterialPageRoute(
              builder: (_) => ExerciseDetailScreen(exerciseId: exerciseId),
            );
          }
        } else if (settings.name == ExerciseAdminEditScreen.routeName) {
          final exerciseId = settings.arguments as String?;
          return MaterialPageRoute(
            builder: (_) => ExerciseAdminEditScreen(exerciseId: exerciseId),
          );
        }
        return null; // Let Flutter handle other routes
      },
    );
  }
}
