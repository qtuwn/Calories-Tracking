import 'package:flutter/foundation.dart';
import '../domain/repositories/voice_repository.dart';
import '../domain/entities/recognized_food.dart';

/// Business logic service for voice input operations
/// 
/// This service coordinates between the repository and presentation layers.
/// It contains business logic for processing voice transcripts.
/// 
/// No dependencies on Flutter UI - pure business logic.
class VoiceService {
  final VoiceRepository _repository;

  VoiceService(this._repository);

  /// Process a voice transcript and return a RecognizedFood entity
  /// 
  /// This method:
  /// 1. Validates the transcript
  /// 2. Calls the repository to parse the transcript
  /// 3. Returns the structured food data
  /// 
  /// Throws an exception if processing fails.
  Future<RecognizedFood> processTranscript(String transcript) async {
    if (transcript.trim().isEmpty) {
      throw Exception('Transcript cannot be empty');
    }

    try {
      debugPrint('[VoiceService] 🔵 Processing transcript: $transcript');
      
      // Delegate to repository for parsing
      final recognizedFood = await _repository.parseTranscript(transcript);
      
      debugPrint('[VoiceService] ✅ Processed food: $recognizedFood');
      
      // TODO: Future integration point - Save to Meal Diary
      // This is where you would integrate with the DiaryRepository
      // to automatically add the recognized food to the user's diary.
      // Example:
      // final diaryRepo = ref.read(diaryRepositoryProvider);
      // await diaryRepo.addEntry(DiaryEntry(...));
      
      return recognizedFood;
    } catch (e, stackTrace) {
      debugPrint('[VoiceService] ❌ Error processing transcript: $e');
      debugPrint('[VoiceService] Stack trace: $stackTrace');
      rethrow;
    }
  }
}

