class WeightUnits {
  static int toHalfKg(double kg) => (kg * 2).round();

  static double fromHalfKg(int halfKg) => halfKg / 2.0;

  static String fmt(int halfKg) => fromHalfKg(halfKg).toStringAsFixed(1);

  static int clampHalfKg(int halfKg) {
    const minHalfKg = 70;
    const maxHalfKg = 400;
    return halfKg.clamp(minHalfKg, maxHalfKg);
  }

  static int clampAndConvert(double kg) {
    const minKg = 35.0;
    const maxKg = 200.0;
    final clamped = kg.clamp(minKg, maxKg);
    return toHalfKg(clamped);
  }
}
