/// Domain entity representing a food item recognized from voice input
/// 
/// This is a pure domain entity with no dependencies on Flutter or external services.
/// It represents the structured data extracted from a voice transcript by the Gemini API.
class RecognizedFood {
  /// The name of the food item
  final String name;
  
  /// Estimated calories for the food item
  final double calories;
  
  /// Quantity of the food (e.g., "1 cup", "200g", "2 pieces")
  final String quantity;
  
  /// Optional: Additional notes or details about the food
  final String? notes;

  const RecognizedFood({
    required this.name,
    required this.calories,
    required this.quantity,
    this.notes,
  });

  /// Create a RecognizedFood from a JSON map (typically from Gemini API response)
  factory RecognizedFood.fromJson(Map<String, dynamic> json) {
    return RecognizedFood(
      name: json['name'] as String? ?? '',
      calories: (json['calories'] as num?)?.toDouble() ?? 0.0,
      quantity: json['quantity'] as String? ?? '',
      notes: json['notes'] as String?,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'calories': calories,
      'quantity': quantity,
      if (notes != null) 'notes': notes,
    };
  }

  @override
  String toString() {
    return 'RecognizedFood(name: $name, calories: $calories, quantity: $quantity, notes: $notes)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RecognizedFood &&
        other.name == name &&
        other.calories == calories &&
        other.quantity == quantity &&
        other.notes == notes;
  }

  @override
  int get hashCode {
    return Object.hash(name, calories, quantity, notes);
  }
}

