import 'package:flutter/material.dart';

/// Helper functions for difficulty display
class DifficultyHelper {
  /// Convert difficulty string to localized label
  /// 
  /// Returns null if difficulty is null or empty
  static String? difficultyToLabel(String? difficulty) {
    if (difficulty == null || difficulty.isEmpty) {
      return null;
    }
    
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return 'Dễ';
      case 'medium':
        return 'Trung bình';
      case 'hard':
        return 'Khó';
      default:
        return difficulty; // Return as-is if unknown
    }
  }
  
  /// Get color for difficulty badge
  static Color? difficultyToColor(String? difficulty) {
    if (difficulty == null || difficulty.isEmpty) {
      return null;
    }
    
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return const Color(0xFF4CAF50); // Green
      case 'medium':
        return const Color(0xFFFF9800); // Orange
      case 'hard':
        return const Color(0xFFF44336); // Red
      default:
        return null;
    }
  }
  
  /// Get icon for difficulty badge
  static IconData? difficultyToIcon(String? difficulty) {
    if (difficulty == null || difficulty.isEmpty) {
      return null;
    }
    
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Icons.sentiment_satisfied;
      case 'medium':
        return Icons.sentiment_neutral;
      case 'hard':
        return Icons.sentiment_very_dissatisfied;
      default:
        return null;
    }
  }
}

