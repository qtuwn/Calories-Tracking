import 'profile.dart';

/// Temporary adapter to convert Profile (new domain) to ProfileModel (legacy)
///
/// DEPRECATED: This adapter is no longer used. All code has migrated to use Profile directly.
/// Safe to remove once all services have been migrated to use Profile entity instead of ProfileModel.
@Deprecated('No longer used. Migrate to use Profile domain entity directly.')
class ProfileToProfileModelAdapter {
  /// This method is deprecated and should not be used
  @Deprecated('Convert Profile directly; ProfileModel is deprecated')
  static dynamic toProfileModel(Profile? profile) {
    throw UnsupportedError(
      'ProfileToProfileModelAdapter.toProfileModel is deprecated. '
      'Use Profile domain entity directly instead.',
    );
  }
}
