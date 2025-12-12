import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/voice_controller.dart';
import '../../domain/entities/recognized_food.dart';

/// A circular microphone button for voice input
/// 
/// Features:
/// - Long press to start listening
/// - Release to stop listening and process transcript
/// - Visual feedback for different states (idle, listening, processing, error, success)
class VoiceInputButton extends ConsumerWidget {
  /// Callback when food is successfully recognized
  /// 
  /// TODO: Integrate with Meal Diary to automatically add the recognized food
  final void Function(RecognizedFood)? onFoodRecognized;

  /// Size of the button (default: 64.0)
  final double size;

  /// Color of the button when idle
  final Color? idleColor;

  /// Color of the button when listening
  final Color? listeningColor;

  /// Color of the button when processing
  final Color? processingColor;

  const VoiceInputButton({
    super.key,
    this.onFoodRecognized,
    this.size = 64.0,
    this.idleColor,
    this.listeningColor,
    this.processingColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(voiceControllerProvider);
    final controller = ref.read(voiceControllerProvider.notifier);

    // Listen for successful recognition (backup callback via state change)
    ref.listen<VoiceState>(
      voiceControllerProvider,
      (previous, next) {
        if (next.hasResult && next.recognizedFood != null) {
          // This is a backup - the primary callback is passed to startListening
          onFoodRecognized?.call(next.recognizedFood!);
        }
      },
    );

    // Determine button color based on state
    Color buttonColor;
    IconData iconData;
    double scale = 1.0;

    if (state.isProcessing) {
      buttonColor = processingColor ?? Colors.orange;
      iconData = Icons.hourglass_empty;
    } else if (state.isListening) {
      buttonColor = listeningColor ?? Colors.red;
      iconData = Icons.mic;
      scale = 1.1; // Slightly larger when listening
    } else if (state.hasError) {
      buttonColor = Colors.grey;
      iconData = Icons.error_outline;
    } else {
      buttonColor = idleColor ?? Theme.of(context).primaryColor;
      iconData = Icons.mic_none;
    }

    return GestureDetector(
      onTap: () async {
        if (state.isListening) {
          debugPrint('[VoiceInputButton] 🔵 Stopping listening...');
          await controller.stopListening();
        } else {
          debugPrint('[VoiceInputButton] 🔵 Starting listening...');
          await controller.startListening(onFoodRecognized: onFoodRecognized);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size * scale,
        height: size * scale,
        decoration: BoxDecoration(
          color: buttonColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: buttonColor.withValues(alpha: 0.3),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          iconData,
          color: Colors.white,
          size: size * 0.4,
        ),
      ),
    );
  }
}

/// Widget to display the recognized food result
/// 
/// Shows the recognized food information in a card format.
/// Can be used to preview the result before adding to diary.
class RecognizedFoodCard extends ConsumerWidget {
  const RecognizedFoodCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(voiceControllerProvider);
    final controller = ref.read(voiceControllerProvider.notifier);

    if (!state.hasResult || state.recognizedFood == null) {
      return const SizedBox.shrink();
    }

    final food = state.recognizedFood!;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recognized Food',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => controller.clearResult(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Food', food.name),
            _buildInfoRow('Quantity', food.quantity),
            _buildInfoRow('Calories', '${food.calories.toStringAsFixed(0)} kcal'),
            if (food.notes != null && food.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildInfoRow('Notes', food.notes!),
            ],
            const SizedBox(height: 16),
            // TODO: Add button to add to Meal Diary
            // ElevatedButton(
            //   onPressed: () {
            //     // Add to diary logic here
            //   },
            //   child: const Text('Add to Diary'),
            // ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}

