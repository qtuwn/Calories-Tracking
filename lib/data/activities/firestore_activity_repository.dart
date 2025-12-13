import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../domain/activities/activity.dart';
import '../../domain/activities/activity_repository.dart';
import 'activity_dto.dart';

/// Firestore implementation of ActivityRepository
/// 
/// Collection: activities (root collection)
/// 
/// Document structure:
/// - id: document ID
/// - name: activity name
/// - category: ActivityCategory enum value
/// - met: Metabolic Equivalent of Task (double)
/// - intensity: ActivityIntensity enum value
/// - description: optional description
/// - iconName: optional icon identifier
/// - isActive: boolean
/// - createdAt: Timestamp
/// - updatedAt: Timestamp (optional)
/// - deletedAt: Timestamp (optional, for soft delete)
class FirestoreActivityRepository implements ActivityRepository {
  final FirebaseFirestore _firestore;

  FirestoreActivityRepository({FirebaseFirestore? instance})
      : _firestore = instance ?? FirebaseFirestore.instance;

  @override
  Stream<List<Activity>> watchAll() {
    debugPrint('[FirestoreActivityRepository] 🔵 Watching all active activities');

    return _firestore
        .collection('activities')
        .where('isActive', isEqualTo: true)
        .where('deletedAt', isEqualTo: null)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      final activities = snapshot.docs
          .map((doc) => ActivityDto.fromFirestore(doc).toDomain())
          .toList();

      debugPrint(
          '[FirestoreActivityRepository] ✅ Retrieved ${activities.length} active activities');
      return activities;
    }).handleError((error) {
      debugPrint('[FirestoreActivityRepository] 🔥 Error watching activities: $error');
      throw error;
    });
  }

  @override
  Stream<List<Activity>> watchAllIncludingInactive() {
    debugPrint(
        '[FirestoreActivityRepository] 🔵 Watching all activities (including inactive)');

    return _firestore
        .collection('activities')
        .where('deletedAt', isEqualTo: null)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      final activities = snapshot.docs
          .map((doc) => ActivityDto.fromFirestore(doc).toDomain())
          .toList();

      debugPrint(
          '[FirestoreActivityRepository] ✅ Retrieved ${activities.length} activities');
      return activities;
    }).handleError((error) {
      debugPrint(
          '[FirestoreActivityRepository] 🔥 Error watching all activities: $error');
      throw error;
    });
  }

  @override
  Future<Activity?> getById(String id) async {
    try {
      debugPrint('[FirestoreActivityRepository] 🔵 Getting activity: $id');

      final doc = await _firestore.collection('activities').doc(id).get();

      if (!doc.exists) {
        debugPrint('[FirestoreActivityRepository] ℹ️ Activity not found: $id');
        return null;
      }

      final activity = ActivityDto.fromFirestore(doc).toDomain();
      debugPrint('[FirestoreActivityRepository] ✅ Retrieved activity: ${activity.name}');
      return activity;
    } catch (e, stackTrace) {
      debugPrint('[FirestoreActivityRepository] 🔥 Error getting activity: $e');
      debugPrint('[FirestoreActivityRepository] Stack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  Stream<List<Activity>> search({
    required String query,
    ActivityCategory? category,
  }) {
    if (query.trim().isEmpty) {
      return const Stream.empty();
    }

    debugPrint(
        '[FirestoreActivityRepository] 🔵 Searching activities: query="$query", category=${category?.name}');

    final queryLower = query.toLowerCase();
    final queryUpper = '$queryLower\uf8ff';

    Query queryRef = _firestore
        .collection('activities')
        .where('name', isGreaterThanOrEqualTo: queryLower)
        .where('name', isLessThan: queryUpper)
        .where('isActive', isEqualTo: true)
        .where('deletedAt', isEqualTo: null);

    if (category != null) {
      queryRef = queryRef.where('category', isEqualTo: category.name);
    }

    return queryRef.orderBy('name').limit(50).snapshots().map((snapshot) {
      final activities = snapshot.docs
          .map((doc) => ActivityDto.fromFirestore(doc).toDomain())
          .toList();

      debugPrint(
          '[FirestoreActivityRepository] ✅ Found ${activities.length} activities');
      return activities;
    }).handleError((error) {
      debugPrint('[FirestoreActivityRepository] 🔥 Error searching activities: $error');
      throw error;
    });
  }

  @override
  Future<Activity> create(Activity activity) async {
    try {
      debugPrint('[FirestoreActivityRepository] 🔵 Creating activity: ${activity.name}');

      final docRef = _firestore.collection('activities').doc();

      // Set ID in the activity
      final activityWithId = activity.copyWith(id: docRef.id);

      final dtoWithId = ActivityDto.fromDomain(activityWithId);
      await docRef.set(dtoWithId.toFirestore());

      debugPrint('[FirestoreActivityRepository] ✅ Created activity: ${docRef.id}');
      return activityWithId;
    } catch (e, stackTrace) {
      debugPrint('[FirestoreActivityRepository] 🔥 Error creating activity: $e');
      debugPrint('[FirestoreActivityRepository] Stack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> update(Activity activity) async {
    try {
      debugPrint('[FirestoreActivityRepository] 🔵 Updating activity: ${activity.id}');

      final dto = ActivityDto.fromDomain(activity);
      await _firestore
          .collection('activities')
          .doc(activity.id)
          .update(dto.toFirestore());

      debugPrint('[FirestoreActivityRepository] ✅ Updated activity: ${activity.id}');
    } catch (e, stackTrace) {
      debugPrint('[FirestoreActivityRepository] 🔥 Error updating activity: $e');
      debugPrint('[FirestoreActivityRepository] Stack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      debugPrint('[FirestoreActivityRepository] 🔵 Soft deleting activity: $id');

      await _firestore.collection('activities').doc(id).update({
        'deletedAt': FieldValue.serverTimestamp(),
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('[FirestoreActivityRepository] ✅ Soft deleted activity: $id');
    } catch (e, stackTrace) {
      debugPrint('[FirestoreActivityRepository] 🔥 Error deleting activity: $e');
      debugPrint('[FirestoreActivityRepository] Stack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> hardDelete(String id) async {
    try {
      debugPrint('[FirestoreActivityRepository] 🔵 Hard deleting activity: $id');

      await _firestore.collection('activities').doc(id).delete();

      debugPrint('[FirestoreActivityRepository] ✅ Hard deleted activity: $id');
    } catch (e, stackTrace) {
      debugPrint('[FirestoreActivityRepository] 🔥 Error hard deleting activity: $e');
      debugPrint('[FirestoreActivityRepository] Stack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> restore(String id) async {
    try {
      debugPrint('[FirestoreActivityRepository] 🔵 Restoring activity: $id');

      await _firestore.collection('activities').doc(id).update({
        'deletedAt': FieldValue.delete(),
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('[FirestoreActivityRepository] ✅ Restored activity: $id');
    } catch (e, stackTrace) {
      debugPrint('[FirestoreActivityRepository] 🔥 Error restoring activity: $e');
      debugPrint('[FirestoreActivityRepository] Stack trace: $stackTrace');
      rethrow;
    }
  }
}

