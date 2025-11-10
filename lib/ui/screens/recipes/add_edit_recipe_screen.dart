import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../models/recipe.dart';
import '../../../providers/recipes_provider.dart';
import '../../../providers/foods_provider.dart';

class AddEditRecipeScreen extends StatefulWidget {
  final String? recipeId;
  const AddEditRecipeScreen({super.key, this.recipeId});

  @override
  State<AddEditRecipeScreen> createState() => _AddEditRecipeScreenState();
}

class _AddEditRecipeScreenState extends State<AddEditRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _servingsController = TextEditingController(text: '1');
  final _instructionsController = TextEditingController();
  String? _imagePath;

  final List<_IngredientRow> _rows = [];

  @override
  void initState() {
    super.initState();
    if (widget.recipeId != null) {
      // load existing recipe later if wiring is present
    }
    _ensureOneRow();
  }

  void _ensureOneRow() {
    if (_rows.isEmpty) _rows.add(_IngredientRow());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _servingsController.dispose();
    _instructionsController.dispose();
    for (final r in _rows) {
      r.gramsController.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
    );
    if (x == null) return;
    if (!mounted) return;
    setState(() => _imagePath = x.path);
  }

  void _addRow() {
    setState(() => _rows.add(_IngredientRow()));
  }

  void _removeRow(int idx) {
    setState(() {
      _rows[idx].gramsController.dispose();
      _rows.removeAt(idx);
      _ensureOneRow();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final recipesProv = Provider.of<RecipesProvider>(context, listen: false);

    final name = _nameController.text.trim();
    final servings = int.tryParse(_servingsController.text) ?? 1;
    final instructions = _instructionsController.text.trim();

    final items = <RecipeItem>[];
    for (final r in _rows) {
      if (r.selectedFoodId == null) continue;
      final grams = double.tryParse(r.gramsController.text) ?? 0.0;
      if (grams <= 0) continue;
      items.add(RecipeItem(foodId: r.selectedFoodId!, grams: grams));
    }

    final recipe = Recipe(
      name: name,
      imageUrl: _imagePath,
      items: items,
      servings: servings,
      instructions: instructions,
      authorId: recipesProv.currentUserId,
      isApproved: false,
      createdAt: DateTime.now().toUtc(),
    );

    await recipesProv.createRecipe(recipe);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final foodsProv = Provider.of<FoodsProvider>(context);
    final foods = foodsProv.items;

    return Scaffold(
      appBar: AppBar(title: const Text('Add / Edit Recipe')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _servingsController,
                      decoration: const InputDecoration(labelText: 'Servings'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.image),
                    label: const Text('Image'),
                  ),
                ],
              ),
              if (_imagePath != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Image.file(
                    File(_imagePath!),
                    height: 160,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 12),
              const Text(
                'Ingredients',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ..._rows.asMap().entries.map((e) {
                final idx = e.key;
                final row = e.value;
                return Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        initialValue: row.selectedFoodId,
                        items: foods
                            .map(
                              (f) => DropdownMenuItem(
                                value: f.id,
                                child: Text(f.name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => row.selectedFoodId = v),
                        decoration: const InputDecoration(labelText: 'Food'),
                        validator: (v) => v == null ? 'Select' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: row.gramsController,
                        decoration: const InputDecoration(labelText: 'Grams'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.remove_circle),
                      onPressed: () => _removeRow(idx),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _addRow,
                icon: const Icon(Icons.add),
                label: const Text('Add ingredient'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _instructionsController,
                decoration: const InputDecoration(labelText: 'Instructions'),
                maxLines: 4,
              ),
              const SizedBox(height: 18),
              ElevatedButton(onPressed: _save, child: const Text('Save')),
            ],
          ),
        ),
      ),
    );
  }
}

class _IngredientRow {
  String? selectedFoodId;
  final TextEditingController gramsController = TextEditingController();
}
