import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../domain/foods/food.dart';
import '../../../../domain/foods/food_repository.dart';

/// Business logic service for voice meal suggestions
/// 
/// This service coordinates between voice transcripts and food search.
/// It normalizes transcripts and searches for matching foods.
/// 
/// No dependencies on Flutter UI - pure business logic.
class VoiceMealService {
  final FoodRepository _foodRepository;

  VoiceMealService(this._foodRepository);

  /// Normalize a transcript by removing filler words and cleaning it
  /// 
  /// Removes common Vietnamese filler words like "ngon", "alo", etc.
  String _normalizeTranscript(String transcript) {
    String normalized = transcript.toLowerCase().trim();
    
    // Remove common filler words
    final fillerWords = [
      'ngon',
      'alo',
      'à',
      'ạ',
      'ơi',
      'nha',
      'nhé',
      'đi',
      'thôi',
      'vậy',
      'thì',
      'là',
      'của',
      'một',
      'hai',
      'ba',
      'bốn',
      'năm',
    ];
    
    for (final filler in fillerWords) {
      // Remove filler word with surrounding spaces
      normalized = normalized.replaceAll(RegExp('\\b$filler\\b'), '');
    }
    
    // Clean up multiple spaces
    normalized = normalized.replaceAll(RegExp('\\s+'), ' ').trim();
    
    return normalized;
  }

  /// Suggest foods based on a voice transcript
  /// 
  /// This method:
  /// 1. Normalizes the transcript
  /// 2. Searches the food repository for matching foods
  /// 3. Returns a list of suggested foods
  /// 
  /// Returns an empty list if no foods are found or if the transcript is invalid.
  Future<List<Food>> suggestFoodsForTranscript(String transcript) async {
    if (transcript.trim().isEmpty) {
      debugPrint('[VoiceMealService] ⚠️ Empty transcript, returning empty list');
      return [];
    }

    try {
      // Normalize the transcript
      final normalizedQuery = _normalizeTranscript(transcript);
      debugPrint('[VoiceMealService] Normalized query="$normalizedQuery" (from transcript: "$transcript")');
      
      if (normalizedQuery.isEmpty) {
        debugPrint('[VoiceMealService] ⚠️ Normalized query is empty, returning empty list');
        return [];
      }

      // Search for foods using the repository
      // The repository returns a stream, so we need to get the first result
      final foodsStream = _foodRepository.search(normalizedQuery);
      
      // Take the first emission from the stream
      final foods = await foodsStream.first.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('[VoiceMealService] ⚠️ Food search timed out');
          return <Food>[];
        },
      );

      debugPrint('[VoiceMealService] Found ${foods.length} suggestions');
      
      return foods;
    } catch (e, stackTrace) {
      debugPrint('[VoiceMealService] ❌ Error suggesting foods: $e');
      debugPrint('[VoiceMealService] Stack trace: $stackTrace');
      // Return empty list instead of throwing to prevent crashes
      return [];
    }
  }
}

