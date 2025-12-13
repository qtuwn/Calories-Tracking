import 'package:flutter/material.dart';

/// BMI (Body Mass Index) calculation utility.
/// 
/// BMI formula: weight (kg) / height (m)²
/// 
/// This utility provides a simple, reusable BMI calculation function
/// that can be used across the app without importing the full GoalCalculator.
class BmiCalculator {
  BmiCalculator._(); // Private constructor to prevent instantiation

  /// Calculate BMI from weight in kg and height in cm.
  /// 
  /// Returns the BMI value. Throws [ArgumentError] if heightCm <= 0.
  /// 
  /// Example:
  /// ```dart
  /// final bmi = BmiCalculator.calculate(weightKg: 70.0, heightCm: 175);
  /// // Returns: 22.86
  /// ```
  static double calculate({
    required double weightKg,
    required int heightCm,
  }) {
    if (heightCm <= 0) {
      throw ArgumentError('Height must be greater than 0');
    }
    if (weightKg <= 0) {
      throw ArgumentError('Weight must be greater than 0');
    }
    final heightM = heightCm / 100.0;
    return weightKg / (heightM * heightM);
  }

  /// Calculate BMI from weight in kg and height in meters.
  /// 
  /// Returns the BMI value. Throws [ArgumentError] if heightM <= 0.
  /// 
  /// Example:
  /// ```dart
  /// final bmi = BmiCalculator.calculateFromMeters(weightKg: 70.0, heightM: 1.75);
  /// // Returns: 22.86
  /// ```
  static double calculateFromMeters({
    required double weightKg,
    required double heightM,
  }) {
    if (heightM <= 0) {
      throw ArgumentError('Height must be greater than 0');
    }
    if (weightKg <= 0) {
      throw ArgumentError('Weight must be greater than 0');
    }
    return weightKg / (heightM * heightM);
  }

  /// Get BMI category label based on BMI value.
  /// 
  /// Categories (WHO standard thresholds):
  /// - Underweight: BMI < 18.5
  /// - Normal: 18.5 ≤ BMI < 25
  /// - Overweight: 25 ≤ BMI < 30
  /// - Obese: BMI ≥ 30
  static String getCategory(double bmi) {
    if (bmi < 18.5) {
      return 'Thiếu cân';
    } else if (bmi < 25) {
      return 'Bình thường';
    } else if (bmi < 30) {
      return 'Thừa cân';
    } else {
      return 'Béo phì';
    }
  }

  /// Get color for BMI category based on BMI value.
  /// 
  /// Uses WHO standard thresholds (18.5, 25, 30) for consistency.
  /// Color mapping:
  /// - Underweight (< 18.5): Orange (warning)
  /// - Normal (18.5-25): Green (success)
  /// - Overweight (25-30): Blue (info)
  /// - Obese (≥ 30): Red (danger)
  static Color getColorForCategory(double bmi) {
    if (bmi < 18.5) {
      return Colors.orange; // Warning
    } else if (bmi < 25) {
      return Colors.green; // Success
    } else if (bmi < 30) {
      return Colors.blue; // Info
    } else {
      return Colors.red; // Danger
    }
  }
}

