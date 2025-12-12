import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:calories_app/app/config/firebase_options.dart';
import 'package:calories_app/app/routing/intro_gate.dart';
import 'package:calories_app/core/theme/theme.dart';
import 'package:calories_app/core/notifications/local_notifications_service.dart';
import 'package:calories_app/core/notifications/push_notifications_service.dart';
import 'package:calories_app/core/notifications/notification_scheduler.dart';
import 'package:calories_app/features/auth/presentation/pages/auth_page.dart';
import 'package:calories_app/features/foods/ui/food_admin_page.dart';
import 'package:calories_app/features/exercise/ui/exercise_list_screen.dart';
import 'package:calories_app/features/exercise/ui/exercise_admin_list_screen.dart';
import 'package:calories_app/features/exercise/ui/exercise_detail_screen.dart';
import 'package:calories_app/features/exercise/ui/exercise_admin_edit_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables from .env file
  try {
    await dotenv.load(fileName: '.env');
    debugPrint('[ENV] ✅ Environment variables loaded successfully');
  } catch (e) {
    debugPrint('[ENV] ⚠️ Warning: Could not load .env file: $e');
    debugPrint('[ENV] ⚠️ Make sure .env file exists in the root directory');
  }
  
  Intl.defaultLocale = 'vi_VN';
  await initializeDateFormatting('vi');
  // Initialize Firebase with production options ONLY
  // This uses the production Firebase project defined in google-services.json
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Verify production Firebase connection
  final firestore = FirebaseFirestore.instance;
  final projectId = firestore.app.options.projectId;
  debugPrint('[FIREBASE] Connected to project: $projectId');
  debugPrint('[FIREBASE] Expected project: calories-app-da7fb');
  if (projectId != 'calories-app-da7fb') {
    debugPrint('[FIREBASE] ⚠️ WARNING: Project ID mismatch! Expected calories-app-da7fb, got $projectId');
    throw Exception('Firebase project ID mismatch - check Firebase initialization');
  } else {
    debugPrint('[FIREBASE] ✅ Project ID verified: production Firebase');
  }
  
  debugPrint('[FIREBASE] ✅ Running in PRODUCTION mode (no emulator)');

  // Enable Firestore offline persistence with unlimited cache for robust offline support
  // This allows the app to work seamlessly in low-connectivity environments
  if (!kIsWeb) {
    firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    debugPrint('[Firestore] ✅ Offline persistence enabled with unlimited cache');
  }

  // Activate Firebase App Check with Play Integrity for Android
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.playIntegrity,
  );

  // Initialize notification services (non-web only)
  if (!kIsWeb) {
    try {
      await LocalNotificationsService().init();
      debugPrint('[Notifications] ✅ Local notifications initialized');
    } catch (e) {
      debugPrint('[Notifications] 🔥 Error initializing local notifications: $e');
    }

    try {
      await PushNotificationsService().init();
      debugPrint('[Notifications] ✅ Push notifications initialized');
    } catch (e) {
      debugPrint('[Notifications] 🔥 Error initializing push notifications: $e');
    }

    // Initialize default notification schedules
    try {
      final container = ProviderContainer();
      final scheduler = container.read(notificationSchedulerProvider);
      await scheduler.initDefaultSchedules();
      container.dispose();
      debugPrint('[Notifications] ✅ Default notification schedules initialized');
    } catch (e) {
      debugPrint('[Notifications] 🔥 Error initializing notification schedules: $e');
    }

    // Debug: Test notification (only in debug mode)
    if (kDebugMode) {
      Future.delayed(const Duration(seconds: 5), () {
        LocalNotificationsService().showInstantNotification(
          title: 'Debug test',
          body: 'Local notification works!',
        );
      });
    }
  }

  runApp(const ProviderScope(child: MyApp()));
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
