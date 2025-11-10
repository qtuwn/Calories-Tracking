import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/recipes_provider.dart';
import '../../../providers/foods_provider.dart';
import '../../../models/food.dart';
// models imported via providers

class RecipeDetailScreen extends StatelessWidget {
  final String recipeId;
  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  Widget build(BuildContext context) {
    final recipesProv = Provider.of<RecipesProvider>(context);
    final foodsProv = Provider.of<FoodsProvider>(context, listen: false);
    final recipe = recipesProv.getById(recipeId);
    if (recipe == null) {
      return Scaffold(body: Center(child: Text('Recipe not found')));
    }

    Food? lookupFood(String id) {
      final idx = foodsProv.items.indexWhere((f) => f.id == id);
      if (idx == -1) return null;
      return foodsProv.items[idx];
    }

    final macros = recipe.computeMacros(lookupFood);

    return Scaffold(
      appBar: AppBar(title: Text(recipe.name)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (recipe.imageUrl != null)
              Image.network(
                recipe.imageUrl!,
                height: 240,
                width: double.infinity,
                fit: BoxFit.cover,
              )
            else
              Container(
                height: 240,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Center(child: Icon(Icons.restaurant_menu, size: 56)),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Servings: ${recipe.servings}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ingredients',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...recipe.items.map((it) {
                    final food = lookupFood(it.foodId);
                    final kcal = (food != null)
                        ? (food.kcalPer100g * it.grams / 100.0)
                        : 0.0;
                    return ListTile(
                      title: Text(food != null ? food.name : it.foodId),
                      subtitle: Text(
                        '${it.grams} g • ${kcal.toStringAsFixed(0)} kcal',
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  Text(
                    'Instructions',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    recipe.instructions ?? '-',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Macros',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Kcal: ${macros['kcal']!.toStringAsFixed(0)}',
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Protein: ${macros['protein']!.toStringAsFixed(1)} g',
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Carb: ${macros['carb']!.toStringAsFixed(1)} g',
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Fat: ${macros['fat']!.toStringAsFixed(1)} g',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: () {
                      recipesProv.addToDiary(recipeId, 1);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Added to diary')),
                      );
                    },
                    child: const Text('Ghi vào nhật ký'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
