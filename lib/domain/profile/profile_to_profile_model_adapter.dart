import 'profile.dart';
import '../../features/onboarding/domain/profile_model.dart' as legacy;

/// Temporary adapter to convert Profile (new domain) to ProfileModel (legacy)
/// 
/// This allows gradual migration while keeping existing services working.
/// NOTE: Still needed for meal plan services (kcal_calculator, etc.) that use ProfileModel.
/// Once those services are migrated to use Profile directly, this adapter can be removed.
class ProfileToProfileModelAdapter {
  /// Convert Profile to ProfileModel
  static legacy.ProfileModel toProfileModel(Profile? profile) {
    if (profile == null) {
      // Return a minimal ProfileModel with nulls
      return const legacy.ProfileModel();
    }

    // Create ProfileModel from Profile using fromMap
    final profileMap = profile.toJson();
    
    // Convert DateTime strings back to DateTime for ProfileModel.fromMap
    if (profile.goalDate != null) {
      profileMap['goalDate'] = profile.goalDate!.toIso8601String();
    }
    if (profile.createdAt != null) {
      profileMap['createdAt'] = profile.createdAt!.toIso8601String();
    }

    return legacy.ProfileModel.fromMap(profileMap);
  }
}

