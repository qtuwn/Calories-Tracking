import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State for avatar upload
class AvatarUploadState {
  final bool isUploading;
  final String? errorMessage;

  const AvatarUploadState({
    this.isUploading = false,
    this.errorMessage,
  });

  AvatarUploadState copyWith({
    bool? isUploading,
    String? errorMessage,
  }) {
    return AvatarUploadState(
      isUploading: isUploading ?? this.isUploading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Notifier for avatar upload state
class AvatarUploadController extends Notifier<AvatarUploadState> {
  @override
  AvatarUploadState build() {
    return const AvatarUploadState();
  }

  void setUploading(bool uploading) {
    state = state.copyWith(isUploading: uploading, errorMessage: null);
  }

  void setError(String? error) {
    state = state.copyWith(isUploading: false, errorMessage: error);
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

/// Provider for avatar upload controller
final avatarUploadControllerProvider =
    NotifierProvider<AvatarUploadController, AvatarUploadState>(
  AvatarUploadController.new,
);

