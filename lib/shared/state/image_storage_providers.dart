import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/images/image_storage_repository.dart';
import '../../domain/images/use_cases/upload_user_avatar_use_case.dart';
import '../../domain/images/use_cases/upload_sport_icon_use_case.dart';
import '../../domain/images/use_cases/upload_sport_cover_use_case.dart';
import '../../data/images/cloudinary_image_storage_repository.dart';

/// Provider for ImageStorageRepository implementation
final imageStorageRepositoryProvider = Provider<ImageStorageRepository>((ref) {
  return CloudinaryImageStorageRepository.createDefault();
});

/// Provider for UploadUserAvatarUseCase
final uploadUserAvatarUseCaseProvider = Provider<UploadUserAvatarUseCase>((ref) {
  final repository = ref.watch(imageStorageRepositoryProvider);
  return UploadUserAvatarUseCase(repository);
});

/// Provider for UploadSportIconUseCase
final uploadSportIconUseCaseProvider = Provider<UploadSportIconUseCase>((ref) {
  final repository = ref.watch(imageStorageRepositoryProvider);
  return UploadSportIconUseCase(repository);
});

/// Provider for UploadSportCoverUseCase
final uploadSportCoverUseCaseProvider = Provider<UploadSportCoverUseCase>((ref) {
  final repository = ref.watch(imageStorageRepositoryProvider);
  return UploadSportCoverUseCase(repository);
});

