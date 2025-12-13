import 'package:flutter_test/flutter_test.dart';
import 'package:calories_app/data/meal_plans/explore_meal_plan_query_exception.dart';

/// Regression test: Verify ExploreMealPlanQueryException structure
/// 
/// This ensures that when Firestore throws FAILED_PRECONDITION,
/// we can surface a clear error message to users.
/// 
/// The actual provider error handling is tested indirectly through
/// integration tests or widget tests. This unit test verifies the
/// exception type is correctly structured.
void main() {
  group('ExploreMealPlanQueryException', () {
    test('exception includes clear message for missing index', () {
      final exception = ExploreMealPlanQueryException(
        'Firestore index required for published plans query. '
        'Create composite index: isPublished ASC, isEnabled ASC, name ASC.',
        firebaseErrorCode: 'failed-precondition',
        queryContext: 'published plans query',
      );
      
      expect(exception.message, contains('Firestore index required'));
      expect(exception.firebaseErrorCode, equals('failed-precondition'));
      expect(exception.queryContext, equals('published plans query'));
      
      // toString should include all context
      final string = exception.toString();
      expect(string, contains('Firestore index required'));
      expect(string, contains('failed-precondition'));
    });
    
    test('exception handles null optional fields', () {
      final exception = ExploreMealPlanQueryException(
        'Generic query error',
      );
      
      expect(exception.message, equals('Generic query error'));
      expect(exception.firebaseErrorCode, isNull);
      expect(exception.queryContext, isNull);
      
      // toString should still work
      final string = exception.toString();
      expect(string, contains('Generic query error'));
    });
  });
}