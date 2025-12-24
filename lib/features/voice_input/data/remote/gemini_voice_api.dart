import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:calories_app/shared/config/gemini_config.dart';

/// API client for Gemini REST API
/// 
/// Handles communication with Google's Gemini API to parse voice transcripts
/// into structured food information.
class GeminiVoiceApi {
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta';
  static const String _model = 'gemini-pro';
  
  final String _apiKey;

  GeminiVoiceApi({String? apiKey}) 
      : _apiKey = apiKey ?? GeminiConfig.apiKey ?? '' {
    if (_apiKey.isEmpty) {
      throw Exception(
        'Gemini API key is required. '
        'Set GEMINI_API_KEY in .env file or pass it to GeminiVoiceApi constructor.',
      );
    }
  }

  /// Parse a voice transcript into structured food data
  /// 
  /// Sends the transcript to Gemini API with a prompt to extract:
  /// - Food name
  /// - Estimated calories
  /// - Quantity/portion size
  /// 
  /// Returns a JSON map with the structured data.
  Future<Map<String, dynamic>> parseFoodTranscript(String transcript) async {
    if (transcript.trim().isEmpty) {
      throw Exception('Transcript cannot be empty');
    }

    final url = Uri.parse('$_baseUrl/models/$_model:generateContent?key=$_apiKey');

    // Construct the prompt for Gemini
    final prompt = _buildPrompt(transcript);

    final requestBody = {
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
    };

    try {
      debugPrint('[GeminiVoiceApi] 🔵 Sending request to Gemini API');
      debugPrint('[GeminiVoiceApi] Transcript: $transcript');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request to Gemini API timed out');
        },
      );

      if (response.statusCode != 200) {
        debugPrint('[GeminiVoiceApi] ❌ API error: ${response.statusCode}');
        debugPrint('[GeminiVoiceApi] Response body: ${response.body}');
        throw Exception(
          'Gemini API error: ${response.statusCode}. '
          '${response.body}',
        );
      }

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;
      
      // Extract the text response from Gemini
      final candidates = responseData['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        throw Exception('No response from Gemini API');
      }

      final firstCandidate = candidates[0] as Map<String, dynamic>;
      final parts = firstCandidate['parts'] as List?;
      if (parts == null || parts.isEmpty) {
        throw Exception('Invalid response format from Gemini API');
      }

      final textPart = parts[0] as Map<String, dynamic>;
      final text = textPart['text'] as String?;
      
      if (text == null || text.isEmpty) {
        throw Exception('Empty response from Gemini API');
      }

      debugPrint('[GeminiVoiceApi] ✅ Received response from Gemini');
      debugPrint('[GeminiVoiceApi] Response text: $text');

      // Parse the JSON response from Gemini
      // Gemini should return a JSON object, but it might be wrapped in markdown
      final jsonText = _extractJsonFromText(text);
      final parsedData = jsonDecode(jsonText) as Map<String, dynamic>;

      return parsedData;
    } catch (e, stackTrace) {
      debugPrint('[GeminiVoiceApi] ❌ Error calling Gemini API: $e');
      debugPrint('[GeminiVoiceApi] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Build the prompt for Gemini API
  String _buildPrompt(String transcript) {
    return '''
You are a nutrition assistant. Parse the following voice transcript about food intake and return a JSON object with the following structure:

{
  "name": "food name",
  "calories": estimated_calories_number,
  "quantity": "quantity description (e.g., '1 cup', '200g', '2 pieces')",
  "notes": "optional additional notes"
}

Transcript: "$transcript"

Rules:
1. Extract the food name clearly
2. Estimate calories based on common nutritional values (be reasonable)
3. Extract or infer the quantity/portion size mentioned
4. If quantity is not mentioned, use a reasonable default like "1 serving"
5. Return ONLY valid JSON, no markdown, no explanations, just the JSON object

Return the JSON object now:
''';
  }

  /// Extract JSON from text (handles markdown code blocks)
  String _extractJsonFromText(String text) {
    // Remove markdown code blocks if present
    String cleaned = text.trim();
    
    // Remove ```json or ``` markers
    if (cleaned.startsWith('```')) {
      final lines = cleaned.split('\n');
      if (lines.first.contains('```')) {
        lines.removeAt(0);
      }
      if (lines.last.trim() == '```') {
        lines.removeLast();
      }
      cleaned = lines.join('\n');
    }
    
    // Find JSON object boundaries
    final jsonStart = cleaned.indexOf('{');
    final jsonEnd = cleaned.lastIndexOf('}');
    
    if (jsonStart != -1 && jsonEnd != -1 && jsonEnd > jsonStart) {
      return cleaned.substring(jsonStart, jsonEnd + 1);
    }
    
    return cleaned;
  }
}

