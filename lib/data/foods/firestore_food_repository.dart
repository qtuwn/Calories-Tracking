import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../domain/foods/food.dart';
import '../../domain/foods/food_repository.dart';
import 'food_dto.dart';
import '../../../shared/utils/audit_logger.dart';

/// Firestore implementation of FoodRepository
class FirestoreFoodRepository implements FoodRepository {
  final FirebaseFirestore _firestore;
  final String _collectionPath = 'foods';

  FirestoreFoodRepository({FirebaseFirestore? instance})
      : _firestore = instance ?? FirebaseFirestore.instance;

  @override
  Stream<List<Food>> watchAll() {
    debugPrint('[FirestoreFoodRepository] 🔵 Watching all foods');
    return _firestore
        .collection(_collectionPath)
        .orderBy('nameLower')
        .snapshots()
        .map((snapshot) {
      final foods = snapshot.docs
          .map((doc) => FoodDto.fromFirestore(doc).toDomain())
          .toList();
      debugPrint('[FirestoreFoodRepository] ✅ Found ${foods.length} foods');
      return foods;
    }).handleError((error, stackTrace) {
      debugPrint('[FirestoreFoodRepository] 🔥 Error watching all foods: $error');
      debugPrintStack(stackTrace: stackTrace);
      return <Food>[];
    });
  }

  @override
  Stream<List<Food>> search(String query) {
    if (query.trim().isEmpty) {
      return const Stream.empty();
    }

    debugPrint('[FirestoreFoodRepository] 🔵 Searching foods: query="$query"');
    final queryLower = query.toLowerCase();
    final queryUpper = '$queryLower\uf8ff';

    return _firestore
        .collection(_collectionPath)
        .where('nameLower', isGreaterThanOrEqualTo: queryLower)
        .where('nameLower', isLessThan: queryUpper)
        .limit(20)
        .snapshots()
        .map((snapshot) {
      final foods = snapshot.docs
          .map((doc) => FoodDto.fromFirestore(doc).toDomain())
          .toList();
      debugPrint('[FirestoreFoodRepository] ✅ Found ${foods.length} foods for search');
      return foods;
    }).handleError((error, stackTrace) {
      debugPrint('[FirestoreFoodRepository] 🔥 Error searching foods: $error');
      debugPrintStack(stackTrace: stackTrace);
      return <Food>[];
    });
  }

  @override
  Stream<List<Food>> searchByGoal(String query, String goalType) {
    if (query.trim().isEmpty) {
      return const Stream.empty();
    }

    debugPrint('[FirestoreFoodRepository] 🔵 Searching foods by goal: query="$query", goalType="$goalType"');
    final queryLower = query.toLowerCase();
    final queryUpper = '$queryLower\uf8ff';

    final baseQuery = _firestore
        .collection(_collectionPath)
        .where('nameLower', isGreaterThanOrEqualTo: queryLower)
        .where('nameLower', isLessThan: queryUpper)
        .limit(20);

    return baseQuery.snapshots().map((snapshot) {
      var foods = snapshot.docs
          .map((doc) => FoodDto.fromFirestore(doc).toDomain())
          .toList();

      // Filter by goal type
      if (goalType == 'vegan') {
        foods = foods.where((food) {
          final category = food.category?.toLowerCase() ?? '';
          if (category.contains('meat') ||
              category.contains('chicken') ||
              category.contains('pork') ||
              category.contains('beef') ||
              category.contains('fish') ||
              category.contains('seafood') ||
              category.contains('egg') ||
              category.contains('dairy') ||
              category.contains('milk')) {
            return false;
          }
          return true;
        }).toList();
      }

      debugPrint('[FirestoreFoodRepository] ✅ Found ${foods.length} foods for goal search');
      return foods;
    }).handleError((error, stackTrace) {
      debugPrint('[FirestoreFoodRepository] 🔥 Error searching foods by goal: $error');
      debugPrintStack(stackTrace: stackTrace);
      return <Food>[];
    });
  }

  @override
  Stream<List<Food>> getAllByGoal(String goalType) {
    debugPrint('[FirestoreFoodRepository] 🔵 Getting all foods by goal: goalType="$goalType"');
    final baseQuery = _firestore
        .collection(_collectionPath)
        .orderBy('nameLower')
        .limit(100);

    return baseQuery.snapshots().map((snapshot) {
      var foods = snapshot.docs
          .map((doc) => FoodDto.fromFirestore(doc).toDomain())
          .toList();

      if (goalType == 'vegan') {
        foods = foods.where((food) {
          final category = food.category?.toLowerCase() ?? '';
          if (category.contains('meat') ||
              category.contains('chicken') ||
              category.contains('pork') ||
              category.contains('beef') ||
              category.contains('fish') ||
              category.contains('seafood') ||
              category.contains('egg') ||
              category.contains('dairy') ||
              category.contains('milk')) {
            return false;
          }
          return true;
        }).toList();
      }

      debugPrint('[FirestoreFoodRepository] ✅ Found ${foods.length} foods for goal');
      return foods;
    }).handleError((error, stackTrace) {
      debugPrint('[FirestoreFoodRepository] 🔥 Error getting foods by goal: $error');
      debugPrintStack(stackTrace: stackTrace);
      return <Food>[];
    });
  }

  @override
  Future<Food?> getById(String id) async {
    debugPrint('[FirestoreFoodRepository] 🔵 Getting food by ID: $id');
    try {
      final doc = await _firestore.collection(_collectionPath).doc(id).get();
      if (doc.exists) {
        debugPrint('[FirestoreFoodRepository] ✅ Found food: ${doc.id}');
        return FoodDto.fromFirestore(doc).toDomain();
      }
      debugPrint('[FirestoreFoodRepository] ℹ️ Food not found: $id');
      return null;
    } catch (e, stackTrace) {
      debugPrint('[FirestoreFoodRepository] 🔥 Error getting food by ID $id: $e');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  @override
  Future<String> createOrUpdate(Food food, String actorUid) async {
    debugPrint('[FirestoreFoodRepository] 🔵 Creating/updating food: ${food.name}');
    try {
      final dto = FoodDto.fromDomain(food);
      final foodData = dto.toFirestore();
      // Ensure nameLower is set
      foodData['nameLower'] = food.name.toLowerCase();

      if (food.id.isEmpty) {
        // Create new food
        final docRef = _firestore.collection(_collectionPath).doc();
        await docRef.set(foodData);
        debugPrint('[FirestoreFoodRepository] ✅ Created food: ${docRef.id}');

        // Log the action
        await auditLogger.logAdminAction(
          actorUid,
          'create_food',
          'food:${docRef.id}',
          {'name': food.name, 'category': food.category},
        );
        return docRef.id;
      } else {
        // Update existing food
        await _firestore
            .collection(_collectionPath)
            .doc(food.id)
            .set(foodData, SetOptions(merge: true));
        debugPrint('[FirestoreFoodRepository] ✅ Updated food: ${food.id}');

        // Log the action
        await auditLogger.logAdminAction(
          actorUid,
          'update_food',
          'food:${food.id}',
          {'name': food.name, 'category': food.category},
        );
        return food.id;
      }
    } catch (e, stackTrace) {
      debugPrint('[FirestoreFoodRepository] 🔥 Error creating/updating food: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> delete(String id, String actorUid, {String? foodName}) async {
    debugPrint('[FirestoreFoodRepository] 🔵 Deleting food: $id');
    try {
      await _firestore.collection(_collectionPath).doc(id).delete();
      debugPrint('[FirestoreFoodRepository] ✅ Deleted food: $id');

      // Log the action
      await auditLogger.logAdminAction(
        actorUid,
        'delete_food',
        'food:$id',
        foodName != null ? {'name': foodName} : null,
      );
    } catch (e, stackTrace) {
      debugPrint('[FirestoreFoodRepository] 🔥 Error deleting food: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }
}

