import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:calories_app/features/foods/data/food_model.dart';
import 'package:calories_app/shared/utils/audit_logger.dart';

/// Repository for managing foods in Firestore
class FoodRepository {
  final FirebaseFirestore _firestore;

  FoodRepository({FirebaseFirestore? instance})
    : _firestore = instance ?? FirebaseFirestore.instance;

  /// Search foods by name (case-insensitive prefix search)
  /// Returns empty stream if query is empty
  Stream<List<Food>> searchFoods(String query) {
    if (query.trim().isEmpty) {
      return const Stream.empty();
    }

    final queryLower = query.toLowerCase();
    final queryUpper = '$queryLower\uf8ff';

    return _firestore
        .collection('foods')
        .where('nameLower', isGreaterThanOrEqualTo: queryLower)
        .where('nameLower', isLessThan: queryUpper)
        .limit(20)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Food.fromDoc(doc)).toList();
        });
  }

  /// Get all foods as a stream
  Stream<List<Food>> getAllFoods() {
    return _firestore.collection('foods').orderBy('nameLower').snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map((doc) => Food.fromDoc(doc)).toList();
    });
  }

  /// Create or update a food document
  /// If food.id is empty, creates a new document
  /// Otherwise updates the existing document
  /// [actorUid] - The UID of the admin performing the action (for audit logging)
  Future<void> createOrUpdateFood(Food food, String actorUid) async {
    try {
      final foodData = food.toMap();
      // Ensure nameLower is set
      foodData['nameLower'] = food.name.toLowerCase();

      if (food.id.isEmpty) {
        // Create new food
        final docRef = _firestore.collection('foods').doc();
        await docRef.set(foodData);
        debugPrint('[FoodRepository] ✅ Created food: ${docRef.id}');

        // Log the action
        await auditLogger.logAdminAction(
          actorUid,
          'create_food',
          'food:${docRef.id}',
          {'name': food.name, 'category': food.category},
        );
      } else {
        // Update existing food
        await _firestore
            .collection('foods')
            .doc(food.id)
            .set(foodData, SetOptions(merge: true));
        debugPrint('[FoodRepository] ✅ Updated food: ${food.id}');

        // Log the action
        await auditLogger.logAdminAction(
          actorUid,
          'update_food',
          'food:${food.id}',
          {'name': food.name, 'category': food.category},
        );
      }
    } catch (e, stackTrace) {
      debugPrint('[FoodRepository] 🔥 Error creating/updating food: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Delete a food document
  /// [actorUid] - The UID of the admin performing the action (for audit logging)
  Future<void> deleteFood(
    String id,
    String actorUid, {
    String? foodName,
  }) async {
    try {
      await _firestore.collection('foods').doc(id).delete();
      debugPrint('[FoodRepository] ✅ Deleted food: $id');

      // Log the action
      await auditLogger.logAdminAction(
        actorUid,
        'delete_food',
        'food:$id',
        foodName != null ? {'name': foodName} : null,
      );
    } catch (e, stackTrace) {
      debugPrint('[FoodRepository] 🔥 Error deleting food: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Get a single food by ID
  Future<Food?> getFoodById(String id) async {
    try {
      final doc = await _firestore.collection('foods').doc(id).get();
      if (doc.exists) {
        return Food.fromDoc(doc);
      }
      return null;
    } catch (e, stackTrace) {
      debugPrint('[FoodRepository] 🔥 Error getting food: $e');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }
}
