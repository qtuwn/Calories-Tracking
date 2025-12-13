import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuration class for Gemini API
/// 
/// Provides access to the Gemini API key from environment variables.
/// The API key must be set in the .env file as GEMINI_API_KEY.
class GeminiConfig {
  /// Get the Gemini API key from environment variables
  /// 
  /// Returns null if the key is not set or not loaded.
  static String? get apiKey => dotenv.env['GEMINI_API_KEY'];

  /// Check if the API key is configured
  static bool get isConfigured => apiKey != null && apiKey!.isNotEmpty;

  /// Validate that the API key is configured
  /// 
  /// Throws an exception if the key is not configured.
  static void validate() {
    if (!isConfigured) {
      throw Exception(
        'GEMINI_API_KEY is not configured. '
        'Please add GEMINI_API_KEY to your .env file.',
      );
    }
  }
}

