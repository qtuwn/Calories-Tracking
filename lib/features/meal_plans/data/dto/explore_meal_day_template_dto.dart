import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:calories_app/features/meal_plans/domain/models/explore/explore_meal_day_template.dart';
import 'package:calories_app/features/meal_plans/domain/models/shared/macros_summary.dart';

/// DTO for explore meal day template in Firestore
/// 
/// Firestore document structure:
/// Collection: meal_plans/{templateId}/days/{dayId}
/// 
/// Fields:
/// - dayIndex: number
/// - totalCalories: number
/// - protein: number
/// - carb: number
/// - fat: number
class ExploreMealDayTemplateDto {
  final String id;
  final int dayIndex;
  final double totalCalories;
  final double protein;
  final double carb;
  final double fat;

  const ExploreMealDayTemplateDto({
    required this.id,
    required this.dayIndex,
    required this.totalCalories,
    required this.protein,
    required this.carb,
    required this.fat,
  });

  /// Create from Firestore DocumentSnapshot
  factory ExploreMealDayTemplateDto.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ExploreMealDayTemplateDto(
      id: doc.id,
      dayIndex: (data['dayIndex'] as num?)?.toInt() ?? 0,
      totalCalories: (data['totalCalories'] as num?)?.toDouble() ?? 0.0,
      protein: (data['protein'] as num?)?.toDouble() ?? 0.0,
      carb: (data['carb'] as num?)?.toDouble() ?? 0.0,
      fat: (data['fat'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Create from Map (for testing or manual construction)
  factory ExploreMealDayTemplateDto.fromMap(Map<String, dynamic> map, String id) {
    return ExploreMealDayTemplateDto(
      id: id,
      dayIndex: (map['dayIndex'] as num?)?.toInt() ?? 0,
      totalCalories: (map['totalCalories'] as num?)?.toDouble() ?? 0.0,
      protein: (map['protein'] as num?)?.toDouble() ?? 0.0,
      carb: (map['carb'] as num?)?.toDouble() ?? 0.0,
      fat: (map['fat'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'dayIndex': dayIndex,
      'totalCalories': totalCalories,
      'protein': protein,
      'carb': carb,
      'fat': fat,
    };
  }
}

/// Mapper between ExploreMealDayTemplateDto (Firestore) and ExploreMealDayTemplate (domain)
extension ExploreMealDayTemplateDtoMapper on ExploreMealDayTemplateDto {
  /// Convert DTO to domain model
  ExploreMealDayTemplate toDomain() {
    return ExploreMealDayTemplate(
      id: id,
      dayIndex: dayIndex,
      macros: MacrosSummary(
        calories: totalCalories,
        protein: protein,
        carb: carb,
        fat: fat,
      ),
    );
  }
}

/// Mapper from domain model to DTO
extension ExploreMealDayTemplateToDto on ExploreMealDayTemplate {
  /// Convert domain model to DTO
  ExploreMealDayTemplateDto toDto() {
    return ExploreMealDayTemplateDto(
      id: id,
      dayIndex: dayIndex,
      totalCalories: macros.calories,
      protein: macros.protein,
      carb: macros.carb,
      fat: macros.fat,
    );
  }
}

