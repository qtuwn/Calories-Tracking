import 'package:calories_app/features/meal_plans/data/dto/meal_item_dto.dart';

/// DTO for explore meal entry template (alias for MealItemDto)
/// 
/// Explore meal entries use the same Firestore structure as meal items.
/// This is a type alias for semantic clarity.
/// 
/// Mappers: Use MealItemDtoMapper and MealItemToDto extensions from meal_item_dto.dart
typedef ExploreMealEntryTemplateDto = MealItemDto;

