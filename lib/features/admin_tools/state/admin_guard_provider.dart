import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calories_app/shared/state/auth_providers.dart';

/// Admin guard provider
/// 
/// Returns true only if:
/// - User is authenticated
/// - User's role == 'admin'
/// 
/// Returns false (deny access) if:
/// - User is not authenticated
/// - User's role != 'admin'
/// - Any error occurs (fail-safe: deny by default)
final adminGuardProvider = StreamProvider<bool>((ref) async* {
  try {
    // Watch auth state
    final authAsync = ref.watch(authStateProvider);
    
    yield* authAsync.when(
      data: (user) {
        if (user == null) {
          return Stream.value(false);
        }
        
        // Watch user profile to check role
        final profileAsync = ref.watch(currentProfileProvider(user.uid));
        
        return profileAsync.when(
          data: (profile) {
            if (profile == null) {
              return Stream.value(false);
            }
            return Stream.value(profile.isAdmin);
          },
          loading: () => Stream.value(false), // Deny while loading
          error: (_, __) => Stream.value(false), // Deny on error (fail-safe)
        );
      },
      loading: () => Stream.value(false), // Deny while auth loading
      error: (_, __) => Stream.value(false), // Deny on auth error (fail-safe)
    );
  } catch (e) {
    // Any exception => deny access (fail-safe)
    yield false;
  }
});
