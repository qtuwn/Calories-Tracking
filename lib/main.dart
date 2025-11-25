import 'package:flutter/foundation.dart' show kIsWeb;
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
import 'package:calories_app/features/auth/presentation/pages/auth_page.dart';
import 'package:calories_app/features/foods/ui/food_admin_page.dart';
import 'package:calories_app/features/exercise/ui/exercise_list_screen.dart';
import 'package:calories_app/features/exercise/ui/exercise_admin_list_screen.dart';
import 'package:calories_app/features/exercise/ui/exercise_detail_screen.dart';
import 'package:calories_app/features/exercise/ui/exercise_admin_edit_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'vi_VN';
  await initializeDateFormatting('vi');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('[Firebase] Running in CLOUD mode (no emulator configured)');

  // Enable Firestore offline persistence for demo scenarios (non-web only)
  if (!kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
    debugPrint('[Firestore] ✅ Offline persistence enabled');
  }

  // Activate Firebase App Check with Play Integrity for Android
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.playIntegrity,
  );

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
