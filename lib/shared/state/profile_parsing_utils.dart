import 'package:flutter/foundation.dart';
import 'package:calories_app/features/onboarding/domain/profile_model.dart';

/// Shared utility functions for parsing profile data from Firestore.
/// 
/// This utility centralizes the logic for converting Firestore profile maps
/// to ProfileModel instances, ensuring consistency across all providers.
class ProfileParsingUtils {
  ProfileParsingUtils._(); // Private constructor to prevent instantiation

  /// Parse ProfileModel from a Firestore profile map.
  /// 
  /// Removes the 'id' field (which is metadata, not part of ProfileModel)
  /// and handles parsing errors gracefully.
  /// 
  /// Returns null if profileMap is null or parsing fails.
  /// 
  /// Example:
  /// ```dart
  /// final profile = ProfileParsingUtils.parseProfileMap(profileMap);
  /// if (profile != null) {
  ///   // Use profile
  /// }
  /// ```
  static ProfileModel? parseProfileMap(
    Map<String, dynamic>? profileMap, {
    String? context, // Optional context for logging (e.g., provider name)
  }) {
    if (profileMap == null) {
      if (context != null) {
        debugPrint('[$context] ℹ️ No profile data found');
      }
      return null;
    }

    try {
      // Remove 'id' field before parsing (it's metadata, not part of ProfileModel)
      final data = Map<String, dynamic>.from(profileMap);
      data.remove('id');

      final profile = ProfileModel.fromMap(data);
      if (context != null) {
        debugPrint('[$context] ✅ Successfully parsed profile');
      }
      return profile;
    } catch (e, stackTrace) {
      if (context != null) {
        debugPrint('[$context] 🔥 Error parsing profile data: $e');
        debugPrintStack(stackTrace: stackTrace);
      }
      return null;
    }
  }
}

