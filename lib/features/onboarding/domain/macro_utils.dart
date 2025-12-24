/// Utility functions for macro percentage normalization and validation
class MacroUtils {
  /// Normalize macro percentages to ensure they total exactly 100%
  /// 
  /// Strategy:
  /// 1. Clamp values between 0-100
  /// 2. Round to 1 decimal place
  /// 3. Force the final macro (fat) to absorb rounding error so total = exactly 100
  /// 
  /// Returns a Map with normalized proteinPercent, carbPercent, and fatPercent
  static Map<String, double> normalizeMacros({
    required double proteinPercent,
    required double carbPercent,
    required double fatPercent,
  }) {
    // Clamp values to valid range
    var protein = proteinPercent.clamp(0.0, 100.0);
    var carb = carbPercent.clamp(0.0, 100.0);
    var fat = fatPercent.clamp(0.0, 100.0);

    // Round to 1 decimal place
    protein = (protein * 10).round() / 10;
    carb = (carb * 10).round() / 10;
    fat = (fat * 10).round() / 10;

    // Force fat to absorb rounding error to make total exactly 100
    fat = 100.0 - protein - carb;
    fat = fat.clamp(0.0, 100.0);

    // Final rounding to ensure clean values
    protein = (protein * 10).round() / 10;
    carb = (carb * 10).round() / 10;
    fat = (fat * 10).round() / 10;

    // Debug assertion to verify total is exactly 100
    assert(
      (protein + carb + fat - 100.0).abs() < 0.01,
      'Macro normalization failed: total = ${protein + carb + fat}',
    );

    return {
      'proteinPercent': protein,
      'carbPercent': carb,
      'fatPercent': fat,
    };
  }

  /// Validate macro percentages
  /// 
  /// Returns true if macros are valid (non-negative, finite, total ~100%)
  static bool isValidMacros({
    required double proteinPercent,
    required double carbPercent,
    required double fatPercent,
  }) {
    // Check for non-finite values
    if (!proteinPercent.isFinite ||
        !carbPercent.isFinite ||
        !fatPercent.isFinite) {
      return false;
    }

    // Check for negative values
    if (proteinPercent < 0 || carbPercent < 0 || fatPercent < 0) {
      return false;
    }

    // Check total is approximately 100% (with ±1% tolerance)
    final total = proteinPercent + carbPercent + fatPercent;
    return (total - 100.0).abs() <= 1.0;
  }

  /// Get macro total for validation
  static double getMacroTotal({
    required double proteinPercent,
    required double carbPercent,
    required double fatPercent,
  }) {
    return proteinPercent + carbPercent + fatPercent;
  }
}

