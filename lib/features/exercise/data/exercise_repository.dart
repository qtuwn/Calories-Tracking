import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:calories_app/features/exercise/data/exercise_model.dart';
import 'package:calories_app/shared/utils/audit_logger.dart';

/// Repository for managing exercises in Firestore
///
/// Collection: exercises (root collection)
///
/// Security Rules:
/// - Normal users: can read only exercises where isEnabled == true
/// - Admin users: full CRUD access (read all, create, update, delete)
///
/// To enable admin features in development:
/// Set the user document in Firestore: users/{uid}.role = 'admin'
class ExerciseRepository {
  final FirebaseFirestore _firestore;

  ExerciseRepository({FirebaseFirestore? instance})
    : _firestore = instance ?? FirebaseFirestore.instance;

  /// Search exercises by name (case-insensitive prefix search)
  /// Returns empty stream if query is empty
  /// 
  /// IMPORTANT: This query uses the same composite index as getAllExercises:
  /// Collection: exercises
  /// Fields: isEnabled (Ascending), nameLower (Ascending)
  /// 
  /// The index is defined in firestore.indexes.json
  Stream<List<Exercise>> searchExercises(String query) {
    if (query.trim().isEmpty) {
      return const Stream.empty();
    }

    final queryLower = query.toLowerCase();
    final queryUpper = '$queryLower\uf8ff';

    return _firestore
        .collection('exercises')
        .where('nameLower', isGreaterThanOrEqualTo: queryLower)
        .where('nameLower', isLessThan: queryUpper)
        .where('isEnabled', isEqualTo: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Exercise.fromDoc(doc)).toList();
        });
  }

  /// Get all enabled exercises as a stream
  /// Available to all signed-in users
  /// 
  /// IMPORTANT: This query requires a Firestore composite index:
  /// Collection: exercises
  /// Fields: isEnabled (Ascending), nameLower (Ascending)
  /// 
  /// The index is defined in firestore.indexes.json
  /// After modifying indexes, deploy with:
  ///   firebase deploy --only firestore:indexes
  Stream<List<Exercise>> getAllExercises() {
    debugPrint(
      '[ExerciseRepository] 🔵 getAllExercises: Starting query for enabled exercises',
    );

    return _firestore
        .collection('exercises')
        .where('isEnabled', isEqualTo: true)
        .orderBy('nameLower')
        .snapshots()
        .map((snapshot) {
          final exercises = snapshot.docs
              .map((doc) => Exercise.fromDoc(doc))
              .toList();
          debugPrint(
            '[ExerciseRepository] ✅ getAllExercises: Retrieved ${exercises.length} enabled exercises',
          );
          return exercises;
        })
        .handleError((error) {
          debugPrint(
            '[ExerciseRepository] 🔥 getAllExercises: Error fetching exercises: $error',
          );
          throw error;
        });
  }

  /// Get all exercises (including disabled) - for admin use
  /// Requires admin permissions in Firestore rules
  Stream<List<Exercise>> getAllExercisesAdmin() {
    debugPrint(
      '[ExerciseRepository] 🔵 getAllExercisesAdmin: Starting query for all exercises (admin)',
    );

    return _firestore
        .collection('exercises')
        .orderBy('nameLower')
        .snapshots()
        .map((snapshot) {
          final exercises = snapshot.docs
              .map((doc) => Exercise.fromDoc(doc))
              .toList();
          debugPrint(
            '[ExerciseRepository] ✅ getAllExercisesAdmin: Retrieved ${exercises.length} exercises',
          );
          return exercises;
        })
        .handleError((error) {
          debugPrint(
            '[ExerciseRepository] 🔥 getAllExercisesAdmin: Error fetching exercises: $error',
          );
          throw error;
        });
  }

  /// Get a single exercise by ID
  Future<Exercise?> getExerciseById(String id) async {
    try {
      final doc = await _firestore.collection('exercises').doc(id).get();
      if (doc.exists) {
        return Exercise.fromDoc(doc);
      }
      return null;
    } catch (e, stackTrace) {
      debugPrint('[ExerciseRepository] 🔥 Error getting exercise: $e');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  /// Create a new exercise document
  /// [actorUid] - The UID of the admin performing the action (for audit logging)
  Future<String> createExercise(Exercise exercise, String actorUid) async {
    try {
      final exerciseData = exercise.toMap();
      // Ensure nameLower is set
      exerciseData['nameLower'] = exercise.name.toLowerCase();

      final docRef = _firestore.collection('exercises').doc();
      await docRef.set(exerciseData);
      debugPrint('[ExerciseRepository] ✅ Created exercise: ${docRef.id}');

      // Log the action
      await auditLogger.logAdminAction(
        actorUid,
        'create_exercise',
        'exercise:${docRef.id}',
        {'name': exercise.name, 'unit': exercise.unit},
      );

      return docRef.id;
    } catch (e, stackTrace) {
      debugPrint('[ExerciseRepository] 🔥 Error creating exercise: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Update an existing exercise document
  /// [actorUid] - The UID of the admin performing the action (for audit logging)
  Future<void> updateExercise(Exercise exercise, String actorUid) async {
    try {
      if (exercise.id.isEmpty) {
        throw ArgumentError('Exercise ID cannot be empty for update');
      }

      final exerciseData = exercise.toMap();
      // Ensure nameLower is set
      exerciseData['nameLower'] = exercise.name.toLowerCase();

      await _firestore
          .collection('exercises')
          .doc(exercise.id)
          .set(exerciseData, SetOptions(merge: true));
      debugPrint('[ExerciseRepository] ✅ Updated exercise: ${exercise.id}');

      // Log the action
      await auditLogger.logAdminAction(
        actorUid,
        'update_exercise',
        'exercise:${exercise.id}',
        {'name': exercise.name, 'unit': exercise.unit},
      );
    } catch (e, stackTrace) {
      debugPrint('[ExerciseRepository] 🔥 Error updating exercise: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Delete an exercise document
  /// [actorUid] - The UID of the admin performing the action (for audit logging)
  Future<void> deleteExercise(
    String id,
    String actorUid, {
    String? exerciseName,
  }) async {
    try {
      await _firestore.collection('exercises').doc(id).delete();
      debugPrint('[ExerciseRepository] ✅ Deleted exercise: $id');

      // Log the action
      await auditLogger.logAdminAction(
        actorUid,
        'delete_exercise',
        'exercise:$id',
        exerciseName != null ? {'name': exerciseName} : null,
      );
    } catch (e, stackTrace) {
      debugPrint('[ExerciseRepository] 🔥 Error deleting exercise: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }
}
