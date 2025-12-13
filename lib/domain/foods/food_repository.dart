import 'food.dart';

/// Abstract repository interface for Food operations
/// 
/// This is a pure domain interface with no dependencies on Flutter or Firebase.
/// Implementations should be in the data layer.
abstract class FoodRepository {
  /// Watch all foods as a stream
  Stream<List<Food>> watchAll();

  /// Search foods by name (case-insensitive prefix search)
  /// Returns empty stream if query is empty
  Stream<List<Food>> search(String query);

  /// Search foods by name and filter by goal type
  /// goalType: "lose_fat" | "muscle_gain" | "vegan" | "maintain"
  Stream<List<Food>> searchByGoal(String query, String goalType);

  /// Get all foods filtered by goal type
  Stream<List<Food>> getAllByGoal(String goalType);

  /// Get a single food by ID
  Future<Food?> getById(String id);

  /// Create or update a food document
  /// If food.id is empty, creates a new document
  /// Otherwise updates the existing document
  /// Returns the food ID
  Future<String> createOrUpdate(Food food, String actorUid);

  /// Delete a food document
  Future<void> delete(String id, String actorUid, {String? foodName});
}

