import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/recipes_provider.dart';
import '../../../ui/components/recipe_card.dart';
import 'add_edit_recipe_screen.dart';
import 'recipe_detail_screen.dart';

class RecipesListScreen extends StatelessWidget {
  const RecipesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final recipesProv = Provider.of<RecipesProvider>(context);
    final items = recipesProv.visibleRecipes();

    return Scaffold(
      appBar: AppBar(title: const Text('Recipes')),
      body: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, i) {
          final r = items[i];
          return RecipeCard(
            recipe: r,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RecipeDetailScreen(recipeId: r.id!),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AddEditRecipeScreen())),
        child: const Icon(Icons.add),
      ),
    );
  }
}
