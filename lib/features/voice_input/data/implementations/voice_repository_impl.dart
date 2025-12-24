import 'package:flutter/foundation.dart';
import '../../domain/repositories/voice_repository.dart';
import '../../domain/entities/recognized_food.dart';
import '../remote/gemini_voice_api.dart';

/// Implementation of VoiceRepository using Gemini API
/// 
/// This is the data layer implementation that communicates with
/// the Gemini API to parse voice transcripts.
class VoiceRepositoryImpl implements VoiceRepository {
  final GeminiVoiceApi _api;

  VoiceRepositoryImpl({GeminiVoiceApi? api})
      : _api = api ?? GeminiVoiceApi();

  @override
  Future<RecognizedFood> parseTranscript(String transcript) async {
    if (transcript.trim().isEmpty) {
      throw Exception('Transcript cannot be empty');
    }

    try {
      debugPrint('[VoiceRepositoryImpl] 🔵 Parsing transcript: $transcript');
      
      // Call Gemini API to parse the transcript
      final jsonData = await _api.parseFoodTranscript(transcript);
      
      // Convert JSON to domain entity
      final recognizedFood = RecognizedFood.fromJson(jsonData);
      
      debugPrint('[VoiceRepositoryImpl] ✅ Parsed food: $recognizedFood');
      
      return recognizedFood;
    } catch (e, stackTrace) {
      debugPrint('[VoiceRepositoryImpl] ❌ Error parsing transcript: $e');
      debugPrint('[VoiceRepositoryImpl] Stack trace: $stackTrace');
      rethrow;
    }
  }
}

