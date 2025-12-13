import '../../domain/meal_plans/user_meal_plan.dart';
import '../../domain/meal_plans/user_meal_plan_repository.dart';
import '../../domain/meal_plans/user_meal_plan_repository.dart' as domain_repo show MealItem, MealPlanDay;
import '../../domain/meal_plans/explore_meal_plan.dart';
import '../../features/meal_plans/data/repositories/user_meal_plan_repository_impl.dart';

/// Firestore implementation of UserMealPlanRepository using the new domain structure
/// 
/// This wraps the existing UserMealPlanRepositoryImpl and adapts between
/// legacy models and new domain models.
class FirestoreUserMealPlanRepository implements UserMealPlanRepository {
  final UserMealPlanRepositoryImpl _legacyRepository;

  FirestoreUserMealPlanRepository({UserMealPlanRepositoryImpl? legacyRepository})
      : _legacyRepository = legacyRepository ?? UserMealPlanRepositoryImpl();

  @override
  Stream<UserMealPlan?> getActivePlan(String userId) {
    // Legacy repository already returns domain UserMealPlan, so pass through
    return _legacyRepository.getActivePlan(userId);
  }

  @override
  Stream<List<UserMealPlan>> getPlansForUser(String userId) {
    // Legacy repository already returns domain UserMealPlan, so pass through
    return _legacyRepository.getPlansForUser(userId);
  }

  @override
  Future<UserMealPlan?> getPlanById(String planId, String userId) async {
    // Legacy repository already returns domain UserMealPlan, so pass through
    return await _legacyRepository.getPlanById(planId, userId);
  }

  @override
  Future<void> savePlan(UserMealPlan plan) async {
    // Legacy repository already accepts domain UserMealPlan, so pass through
    await _legacyRepository.savePlan(plan);
  }

  @override
  Future<void> deletePlan(String planId, String userId) async {
    await _legacyRepository.deletePlan(planId, userId);
  }

  @override
  Future<void> setActivePlan({required String userId, required String planId}) async {
    await _legacyRepository.setActivePlan(userId: userId, planId: planId);
  }

  @override
  Future<void> savePlanAndSetActive({
    required UserMealPlan plan,
    required String userId,
  }) async {
    // Legacy repository already accepts domain UserMealPlan, so pass through
    await _legacyRepository.savePlanAndSetActive(plan: plan, userId: userId);
  }

  @override
  Future<void> updatePlanProgress({
    required String planId,
    required String userId,
    required int currentDayIndex,
  }) async {
    await _legacyRepository.updatePlanProgress(
      planId: planId,
      userId: userId,
      currentDayIndex: currentDayIndex,
    );
  }

  @override
  Future<void> updatePlanStatus({
    required String planId,
    required String userId,
    required String status,
  }) async {
    await _legacyRepository.updatePlanStatus(
      planId: planId,
      userId: userId,
      status: status,
    );
  }

  @override
  Future<domain_repo.MealPlanDay?> getDay(String planId, String userId, int dayIndex) async {
    // The legacy repository already returns domain MealPlanDay, so we can return it directly
    return await _legacyRepository.getDay(planId, userId, dayIndex);
  }

  @override
  Stream<List<domain_repo.MealItem>> getDayMeals(
    String planId,
    String userId,
    int dayIndex,
  ) {
    // Legacy repository already returns domain MealItem, so pass through
    return _legacyRepository.getDayMeals(planId, userId, dayIndex);
  }

  @override
  Future<bool> saveDayMealsBatch({
    required String planId,
    required String userId,
    required int dayIndex,
    required List<domain_repo.MealItem> mealsToSave,
    required List<String> mealsToDelete,
  }) async {
    // Legacy repository already accepts domain MealItem, so pass through
    return await _legacyRepository.saveDayMealsBatch(
      planId: planId,
      userId: userId,
      dayIndex: dayIndex,
      mealsToSave: mealsToSave,
      mealsToDelete: mealsToDelete,
    );
  }

  @override
  Future<UserMealPlan> applyExploreTemplateAsActivePlan({
    required String userId,
    required String templateId,
    required ExploreMealPlan template,
    required Map<String, dynamic> profileData,
  }) async {
    // The legacy repository already accepts domain ExploreMealPlan and Map<String, dynamic> profileData
    // So we can call it directly without conversion
    final domainPlan = await _legacyRepository.applyExploreTemplateAsActivePlan(
      userId: userId,
      templateId: templateId,
      template: template,
      profileData: profileData,
    );
    
    // The legacy repository already returns domain UserMealPlan, so return it directly
    return domainPlan;
  }

  @override
  Future<UserMealPlan> applyCustomPlanAsActive({
    required String userId,
    required String planId,
  }) async {
    // Legacy repository already returns domain UserMealPlan, so pass through
    return await _legacyRepository.applyCustomPlanAsActive(
      userId: userId,
      planId: planId,
    );
  }
}

