import 'package:flutter/material.dart';
import 'package:calories_app/core/theme/app_colors.dart';

/// List of known food categories
const foodCategories = <String>[
  'All',
  'Rice',
  'Meat',
  'Vegetable',
  'Fruit',
  'Drink',
  'Snack',
];

/// Maps a category string to a pastel color
/// Uses low opacity to maintain the pastel aesthetic
Color categoryColor(String? category) {
  if (category == null || category.isEmpty) {
    return Colors.grey;
  }

  switch (category.toLowerCase()) {
    case 'rice':
      return AppColors.charmingGreen;
    case 'meat':
      return Colors.redAccent;
    case 'vegetable':
      return AppColors.mintGreen;
    case 'fruit':
      return Colors.orangeAccent;
    case 'drink':
      return Colors.blueAccent;
    case 'snack':
      return Colors.purpleAccent;
    default:
      return Colors.grey;
  }
}
