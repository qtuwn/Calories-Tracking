import 'package:flutter/material.dart';
import '../../../../domain/foods/food.dart';

/// Bottom sheet widget for displaying voice input food suggestions
/// 
/// Shows the transcript and a list of suggested foods that the user can add to their diary.
class VoiceSuggestionsBottomSheet extends StatelessWidget {
  final String transcript;
  final List<Food> suggestions;
  final void Function(Food food) onAddFood;
  final VoidCallback? onRetry;

  const VoiceSuggestionsBottomSheet({
    super.key,
    required this.transcript,
    required this.suggestions,
    required this.onAddFood,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // Transcript display
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                const Icon(Icons.mic, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bạn vừa nói: "$transcript"',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Suggestions list or empty state
          if (suggestions.isEmpty)
            _buildEmptyState()
          else
            _buildSuggestionsList(context),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Builder(
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Không tìm thấy món ăn phù hợp',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Vui lòng nói lại món ăn bạn đã dùng',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop(); // Close bottom sheet
                  onRetry?.call(); // Trigger retry
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsList(BuildContext context) {
    return Flexible(
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          final food = suggestions[index];
          return _buildFoodItem(context, food);
        },
      ),
    );
  }

  Widget _buildFoodItem(BuildContext context, Food food) {
    // Calculate calories for default portion
    final defaultCalories = (food.caloriesPer100g * food.defaultPortionGram / 100);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          food.name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(Icons.local_fire_department, size: 16, color: Colors.orange[700]),
              const SizedBox(width: 4),
              Text(
                '${defaultCalories.toStringAsFixed(0)} kcal',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              if (food.defaultPortionName.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  '• ${food.defaultPortionGram.toStringAsFixed(0)}g (${food.defaultPortionName})',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.add_circle, color: Colors.green),
          onPressed: () => onAddFood(food),
          tooltip: 'Thêm vào nhật ký',
        ),
      ),
    );
  }
}

