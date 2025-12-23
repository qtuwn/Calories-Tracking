import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Anti-regression guard tests
/// 
/// These tests fail CI if forbidden patterns return to the codebase.
void main() {
  group('Forbidden Patterns Guard', () {
    test('no servingSize: 1.0 outside migration repo', () {
      final libDir = Directory('lib');
      if (!libDir.existsSync()) {
        fail('lib directory does not exist');
      }

      final violations = <String>[];

      libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .forEach((file) {
        // Skip migration repository (allowed)
        if (file.path.contains('explore_template_migration_repository.dart')) {
          return;
        }

        final content = file.readAsStringSync();
        
        // Check for servingSize: 1.0 pattern
        final pattern = RegExp(r'servingSize\s*:\s*1\.0');
        if (pattern.hasMatch(content)) {
          violations.add(file.path);
        }
      });

      if (violations.isNotEmpty) {
        fail(
          'Found servingSize: 1.0 outside migration repo in:\n'
          '${violations.join('\n')}',
        );
      }
    });

    test('no foodId ?? "" pattern', () {
      final libDir = Directory('lib');
      if (!libDir.existsSync()) {
        fail('lib directory does not exist');
      }

      final violations = <String>[];

      libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .forEach((file) {
        final content = file.readAsStringSync();
        
        // Check for foodId ?? '' pattern
        final pattern = RegExp("foodId\\s*\\?\\?\\s*['\"]{2}");
        if (pattern.hasMatch(content)) {
          violations.add(file.path);
        }
      });

      if (violations.isNotEmpty) {
        fail(
          'Found foodId ?? "" pattern in:\n'
          '${violations.join('\n')}',
        );
      }
    });

    test('no manual nutrition math outside domain calculator', () {
      final libDir = Directory('lib');
      if (!libDir.existsSync()) {
        fail('lib directory does not exist');
      }

      final violations = <String>[];

      libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .forEach((file) {
        // Allow only in domain calculator
        if (file.path.contains('meal_nutrition_calculator.dart')) {
          return;
        }

        // Allow in statistics providers (diary entries, different domain)
        if (file.path.contains('statistics_providers.dart')) {
          return;
        }

        final content = file.readAsStringSync();
        
        // Check for manual nutrition accumulation patterns
        final patterns = [
          RegExp(r'totalCalories\s*\+='),
          RegExp(r'totalProtein\s*\+='),
          RegExp(r'totalCarb\s*\+='),
          RegExp(r'totalFat\s*\+='),
        ];

        for (final pattern in patterns) {
          if (pattern.hasMatch(content)) {
            violations.add(file.path);
            break; // Only report file once
          }
        }
      });

      if (violations.isNotEmpty) {
        fail(
          'Found manual nutrition math outside domain calculator in:\n'
          '${violations.join('\n')}\n'
          'All nutrition math must use MealNutritionCalculator.',
        );
      }
    });
  });
}
