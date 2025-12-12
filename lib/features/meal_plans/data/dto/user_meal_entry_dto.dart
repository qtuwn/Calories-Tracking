import 'package:calories_app/features/meal_plans/data/dto/meal_item_dto.dart';

/// DTO for user meal entry (alias for MealItemDto)
/// 
/// User meal entries use the same Firestore structure as meal items.
/// This is a type alias for semantic clarity.
/// 
/// Mappers: Use MealItemDtoMapper and MealItemToDto extensions from meal_item_dto.dart
typedef UserMealEntryDto = MealItemDto;

