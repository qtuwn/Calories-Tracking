import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calories_app/core/theme/theme.dart';
import 'package:calories_app/features/exercise/data/exercise_model.dart';
import 'package:calories_app/features/exercise/data/exercise_providers.dart';
import 'package:calories_app/features/exercise/widgets/exercise_card.dart';
import 'package:calories_app/features/exercise/ui/exercise_detail_screen.dart';

class ExerciseListScreen extends ConsumerStatefulWidget {
  static const routeName = '/exercises';

  const ExerciseListScreen({super.key});

  @override
  ConsumerState<ExerciseListScreen> createState() => _ExerciseListScreenState();
}

class _ExerciseListScreenState extends ConsumerState<ExerciseListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = ref.watch(exerciseSearchProvider);

    // Use search stream if query exists, otherwise use all exercises
    final exercisesStream = searchQuery.isNotEmpty
        ? ref.watch(exerciseRepositoryProvider).searchExercises(searchQuery)
        : ref.watch(exerciseRepositoryProvider).getAllExercises();

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
          title: const Text('Bài tập'),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.palePink,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm bài tập...',
                prefixIcon: const Icon(Icons.search, color: AppColors.mediumGray),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.mediumGray),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(exerciseSearchProvider.notifier).clear();
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                ref.read(exerciseSearchProvider.notifier).setQuery(value);
              },
            ),
          ),
          // Exercise list
          Expanded(
            child: StreamBuilder<List<Exercise>>(
              stream: exercisesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
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
                        Text(
                          'Có lỗi xảy ra: ${snapshot.error}',
                          style: Theme.of(context).textTheme.bodyLarge,
                          textAlign: TextAlign.center,
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
                          searchQuery.isNotEmpty
                              ? Icons.search_off
                              : Icons.fitness_center,
                          size: 64,
                          color: AppColors.mediumGray.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          searchQuery.isNotEmpty
                              ? 'Không tìm thấy bài tập nào'
                              : 'Chưa có bài tập nào',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: AppColors.mediumGray,
                              ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: exercises.length,
                  itemBuilder: (context, index) {
                    final exercise = exercises[index];
                    return ExerciseCard(
                      exercise: exercise,
                      onTap: () {
                        Navigator.of(context).pushNamed(
                          ExerciseDetailScreen.routeName,
                          arguments: exercise.id,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

