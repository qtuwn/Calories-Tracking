/// Typed exception for explore meal plan query errors
/// 
/// Used to surface Firestore query errors (e.g., missing composite index) 
/// with user-friendly messages.
class ExploreMealPlanQueryException implements Exception {
  final String message;
  final String? firebaseErrorCode;
  final String? queryContext;

  ExploreMealPlanQueryException(
    this.message, {
    this.firebaseErrorCode,
    this.queryContext,
  });

  @override
  String toString() {
    final parts = <String>[message];
    if (firebaseErrorCode != null) {
      parts.add('(code: $firebaseErrorCode)');
    }
    if (queryContext != null) {
      parts.add('context: $queryContext');
    }
    return parts.join(' ');
  }
}
