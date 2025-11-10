import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'ui/theme.dart';
import 'ui/screens/auth_screen.dart';
import 'ui/screens/account/account_screen.dart';
import 'ui/screens/account/edit_profile_screen.dart';
import 'ui/screens/account/edit_nickname.dart';
import 'ui/screens/account/edit_gender.dart';
import 'ui/screens/account/edit_dob.dart';
import 'ui/screens/account/edit_height.dart';
import 'ui/screens/account/setup_goal_intro.dart';
import 'ui/screens/account/setup_goal/choose_goal.dart';
import 'ui/screens/account/setup_goal/weight_picker.dart';
import 'ui/screens/account/setup_goal/activity_level.dart';
import 'ui/screens/account/setup_goal/summary.dart';
import 'ui/screens/account/settings_screen.dart';
import 'ui/screens/account/edit_email.dart';
import 'ui/screens/account/terms_screen.dart';
import 'ui/screens/account/privacy_screen.dart';
import 'ui/screens/account/report_screen.dart';
import 'ui/screens/account/share_journey_screen.dart';
import 'ui/screens/account/community_screen.dart';
import 'ui/screens/account/weekly_goal_screen.dart';
import 'ui/screens/account/activity_detail_screen.dart';
import 'providers/profile_provider.dart';
import 'providers/foods_provider.dart';
import 'providers/health_connect_provider.dart';
import 'providers/compare_journey_provider.dart';
import 'services/firebase_service.dart';
import 'services/profile_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase unconditionally (we want to use Firebase only).
  await FirebaseService.initFirebase();

  // Optionally run a smoke test in debug builds to verify connectivity.
  // This will sign in anonymously (if needed), write a small document and
  // upload a tiny blob to Storage and print results to the debug console.
  // We don't await this in release modes to avoid blocking startup.
  const bool runSmoke = bool.fromEnvironment(
    'RUN_FIREBASE_SMOKE',
    defaultValue: true,
  );
  if (runSmoke) {
    // run but don't block the UI startup for long; keep it awaited here so the
    // first-run developer sees the logs in the terminal.
    await FirebaseService.runSmokeTest();
  }

  // Ensure we have an authenticated UID. If not, sign in anonymously.
  String uid;
  try {
    final user = FirebaseService.auth.currentUser;
    if (user != null) {
      uid = user.uid;
    } else {
      final cred = await FirebaseService.auth.signInAnonymously();
      uid = cred.user?.uid ?? 'firebase-anon';
    }
  } catch (e) {
    // Fallback to a deterministic uid to avoid crashes; though in a properly
    // configured project this shouldn't happen.
    debugPrint('Auth check/sign-in failed: $e');
    uid = 'firebase-anon-fallback';
  }

  final profileService = await ProfileService.create();
  // firebaseAvailable flag is now always true in this startup flow
  final firebaseAvailable = true;

  runApp(
    MyApp(
      profileService: profileService,
      uid: uid,
      firebaseAvailable: firebaseAvailable,
    ),
  );
}

class MyApp extends StatelessWidget {
  final ProfileService profileService;
  final String uid;
  final bool firebaseAvailable;

  const MyApp({
    super.key,
    required this.profileService,
    required this.uid,
    required this.firebaseAvailable,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ProfileProvider>(
          create: (_) {
            final prov = ProfileProvider(uid: uid, service: profileService);
            prov.load();
            return prov;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final p = FoodsProvider();
            // seed sample foods so UI has reasonable defaults when running locally
            p.seedSampleData();
            return p;
          },
        ),
        ChangeNotifierProvider(create: (_) => HealthConnectProvider()),
        ChangeNotifierProvider(create: (_) => CompareJourneyProvider()),
      ],
      child: MaterialApp(
        title: 'Calories App',
        theme: AppTheme.lightTheme(),
        initialRoute: '/login',
        routes: {
          '/login': (context) => const AuthScreen(),
          '/account': (context) => const AccountScreen(),
          '/edit_profile': (context) => const EditProfileScreen(),
          '/edit_nickname': (context) => const EditNicknameScreen(),
          '/edit_gender': (context) => const EditGenderScreen(),
          '/edit_dob': (context) => const EditDobScreen(),
          '/edit_height': (context) => const EditHeightScreen(),
          '/settings': (context) => const SettingsScreen(),
          '/edit_email': (context) => const EditEmailScreen(),
          '/terms': (context) => const TermsScreen(),
          '/privacy': (context) => const PrivacyScreen(),
          '/report/nutrition': (context) =>
              const ReportScreen(title: 'Dinh dưỡng'),
          '/report/workout': (context) =>
              const ReportScreen(title: 'Tập luyện'),
          '/report/steps': (context) => const ReportScreen(title: 'Số bước'),
          '/report/weight': (context) => const ReportScreen(title: 'Cân nặng'),
          '/report/share': (context) => const ShareJourneyScreen(),
          '/community': (context) => const CommunityScreen(),
          '/weekly_goal': (context) => const WeeklyGoalScreen(),
          '/activity_detail': (context) => const ActivityDetailScreen(),
          '/setup_goal': (context) => const SetupGoalIntroScreen(),
          '/setup_goal/choose_goal': (context) => const ChooseGoalScreen(),
          '/setup_goal/weight': (context) => const WeightPickerScreen(),
          '/setup_goal/activity': (context) => const ActivityLevelScreen(),
          '/setup_goal/summary': (context) => const SetupSummaryScreen(),
          '/about': (context) => Scaffold(
            appBar: AppBar(title: const Text('About')),
            body: const Center(child: Text('About placeholder')),
          ),
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
