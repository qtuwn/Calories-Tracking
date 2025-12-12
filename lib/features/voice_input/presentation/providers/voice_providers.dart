import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/voice_repository.dart';
import '../../data/implementations/voice_repository_impl.dart';
import '../../application/voice_service.dart';
import '../../application/voice_meal_service.dart';
import '../../../../shared/state/food_providers.dart';

/// Provider for VoiceRepository implementation
final voiceRepositoryProvider = Provider<VoiceRepository>((ref) {
  return VoiceRepositoryImpl();
});

/// Provider for VoiceService
/// 
/// This service coordinates between the repository and presentation layers.
final voiceServiceProvider = Provider<VoiceService>((ref) {
  final repository = ref.read(voiceRepositoryProvider);
  return VoiceService(repository);
});

/// Provider for VoiceMealService
/// 
/// This service handles food suggestions based on voice transcripts.
final voiceMealServiceProvider = Provider<VoiceMealService>((ref) {
  final foodRepository = ref.read(foodRepositoryProvider);
  return VoiceMealService(foodRepository);
});

