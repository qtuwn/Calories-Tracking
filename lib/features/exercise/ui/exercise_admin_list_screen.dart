import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:calories_app/core/theme/theme.dart';
import 'package:calories_app/features/exercise/data/exercise_model.dart';
import 'package:calories_app/features/exercise/data/exercise_providers.dart';
import 'package:calories_app/features/exercise/widgets/exercise_card.dart';
import 'package:calories_app/features/exercise/ui/exercise_admin_edit_screen.dart';
import 'package:calories_app/shared/state/auth_providers.dart';

class ExerciseAdminListScreen extends ConsumerWidget {
  static const routeName = '/exercise-admin';

  const ExerciseAdminListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;

    // Guard: user must be signed in
    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.palePink,
        appBar: AppBar(
          backgroundColor: AppColors.palePink,
          title: const Text('Không có quyền truy cập'),
        ),
        body: const Center(child: Text('Vui lòng đăng nhập')),
      );
    }

    final profileAsync = ref.watch(currentProfileProvider(user.uid));
    final exercisesStream = ref
        .watch(exerciseRepositoryProvider)
        .getAllExercisesAdmin();

    return profileAsync.when(
      data: (profile) {
        // Check admin access using centralized provider
        final isAdmin = profile?.isAdmin ?? false;

        debugPrint(
          '[ExerciseAdminListScreen] 🔍 Admin check: uid=${user.uid}, role=${profile?.role}, isAdmin=$isAdmin',
        );

        if (!isAdmin) {
          return Scaffold(
            backgroundColor: AppColors.palePink,
            appBar: AppBar(
              backgroundColor: AppColors.palePink,
              title: const Text('Không có quyền truy cập'),
            ),
            body: const Center(
              child: Text('Bạn không có quyền truy cập tính năng này'),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.palePink,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(72),
            child: AppBar(
              backgroundColor: AppColors.palePink,
              elevation: 0,
              leadingWidth: 72,
              leading: Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: Center(
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).pop(),
                      child: const SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(
                          Icons.arrow_back,
                          size: 22,
                          color: AppColors.nearBlack,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              centerTitle: true,
              title: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.mintGreen.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Exercise Catalog',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppColors.nearBlack,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Admin',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.nearBlack,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: StreamBuilder<List<Exercise>>(
            stream: exercisesStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                String errorMessage = 'Có lỗi xảy ra: ${snapshot.error}';

                // Handle permission-denied errors specifically
                if (snapshot.error is FirebaseException) {
                  final firebaseError = snapshot.error as FirebaseException;
                  if (firebaseError.code == 'permission-denied') {
                    errorMessage =
                        'Bạn không có quyền admin để xem danh sách bài tập.';
                  }
                }

                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          errorMessage,
                          style: Theme.of(context).textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final exercises = snapshot.data ?? [];

              if (exercises.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.fitness_center,
                        size: 64,
                        color: AppColors.mediumGray.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Chưa có bài tập nào',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.mediumGray,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 16),
                itemCount: exercises.length,
                itemBuilder: (context, index) {
                  final exercise = exercises[index];
                  return ExerciseCard(
                    exercise: exercise,
                    onTap: () {
                      Navigator.of(context).pushNamed(
                        ExerciseAdminEditScreen.routeName,
                        arguments: exercise.id,
                      );
                    },
                  );
                },
              );
            },
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              Navigator.of(
                context,
              ).pushNamed(ExerciseAdminEditScreen.routeName, arguments: null);
            },
            backgroundColor: AppColors.mintGreen,
            foregroundColor: AppColors.nearBlack,
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            icon: const Icon(Icons.add, size: 20),
            label: const Text(
              'Add exercise',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.palePink,
          title: const Text('Error'),
        ),
        body: Center(child: Text('Error: $error')),
      ),
    );
  }
}
