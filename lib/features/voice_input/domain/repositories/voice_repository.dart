import '../entities/recognized_food.dart';

/// Abstract repository interface for voice input operations
/// 
/// This is a pure domain interface with no dependencies on Flutter or external services.
/// Implementations should be in the data layer.
abstract class VoiceRepository {
  /// Parse a voice transcript into a structured RecognizedFood entity
  /// 
  /// Takes a raw text transcript from speech recognition and uses AI
  /// (e.g., Gemini API) to extract structured food information.
  /// 
  /// Returns a RecognizedFood entity with parsed food name, calories, and quantity.
  /// Throws an exception if parsing fails or the transcript cannot be understood.
  Future<RecognizedFood> parseTranscript(String transcript);
}

