import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../../domain/entities/recognized_food.dart';
import '../../../../domain/foods/food.dart';
import '../providers/voice_providers.dart';

/// Status enum for voice input state machine
enum VoiceStatus {
  idle,
  listening,
  processing,
  suggestionsReady,
  error,
}

/// State for voice input controller
class VoiceState {
  final VoiceStatus status;
  final RecognizedFood? recognizedFood;
  final String? errorMessage;
  final String? currentTranscript;
  final String? transcript; // Final transcript (renamed from finalTranscript for clarity)
  final List<Food> suggestions; // Changed from nullable to non-nullable with empty list default

  const VoiceState({
    this.status = VoiceStatus.idle,
    this.recognizedFood,
    this.errorMessage,
    this.currentTranscript,
    this.transcript,
    this.suggestions = const [],
  });

  VoiceState copyWith({
    VoiceStatus? status,
    RecognizedFood? recognizedFood,
    String? errorMessage,
    String? currentTranscript,
    String? transcript,
    List<Food>? suggestions,
    bool clearRecognizedFood = false,
    bool clearError = false,
    bool clearTranscript = false,
    bool clearFinalTranscript = false,
    bool clearSuggestions = false,
  }) {
    return VoiceState(
      status: status ?? this.status,
      recognizedFood: clearRecognizedFood
          ? null
          : (recognizedFood ?? this.recognizedFood),
      errorMessage: clearError
          ? null
          : (errorMessage ?? this.errorMessage),
      currentTranscript: clearTranscript
          ? null
          : (currentTranscript ?? this.currentTranscript),
      transcript: clearFinalTranscript
          ? null
          : (transcript ?? this.transcript),
      suggestions: clearSuggestions
          ? const []
          : (suggestions ?? this.suggestions),
    );
  }

  // Convenience getters for backward compatibility
  bool get isListening => status == VoiceStatus.listening;
  bool get isProcessing => status == VoiceStatus.processing;
  bool get isIdle => status == VoiceStatus.idle;
  bool get hasError => status == VoiceStatus.error || errorMessage != null;
  bool get hasResult => recognizedFood != null;
  bool get suggestionsReady => status == VoiceStatus.suggestionsReady && transcript != null;
  
  // Legacy getter for compatibility
  String? get finalTranscript => transcript;
}

/// Controller for voice input feature
/// 
/// Manages the state of voice recognition and processing.
/// Handles speech-to-text and integration with VoiceService.
class VoiceController extends Notifier<VoiceState> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;

  @override
  VoiceState build() {
    _initializeSpeech();
    return const VoiceState();
  }

  /// Initialize speech recognition
  Future<void> _initializeSpeech() async {
    if (_isInitialized) return;

    try {
      final available = await _speech.initialize(
        onError: (error) {
          debugPrint('[VoiceController] ❌ Speech recognition error: SpeechRecognitionError msg: ${error.errorMsg}, permanent: ${error.permanent}');
          
          // Check if the error is due to missing permission (error_network often indicates permission issue)
          if (error.errorMsg == 'error_network' && error.permanent) {
            _handlePermissionDeniedError();
          } else {
            state = state.copyWith(
              status: VoiceStatus.error,
              errorMessage: 'Không thể nhận dạng giọng nói. Vui lòng kiểm tra kết nối mạng.',
            );
          }
        },
        onStatus: (status) {
          debugPrint('[VoiceController] 🔵 Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            if (state.status == VoiceStatus.listening) {
              state = state.copyWith(status: VoiceStatus.idle);
            }
          }
        },
      );

      if (available) {
        _isInitialized = true;
        debugPrint('[VoiceController] ✅ Speech recognition initialized');
      } else {
        debugPrint('[VoiceController] ❌ Speech recognition not available');
        state = state.copyWith(
          status: VoiceStatus.error,
          errorMessage: 'Nhận dạng giọng nói không khả dụng trên thiết bị này.',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('[VoiceController] ❌ Error initializing speech: $e');
      debugPrint('[VoiceController] Stack trace: $stackTrace');
      state = state.copyWith(
        status: VoiceStatus.error,
        errorMessage: 'Không thể khởi tạo nhận dạng giọng nói.',
      );
    }
  }

  /// Ensure microphone permission is granted before starting speech recognition
  /// Returns true if permission is granted, false otherwise
  Future<bool> _ensureMicrophonePermission() async {
    try {
      debugPrint('[VoiceController] 🔵 Checking microphone permission...');
      
      final status = await Permission.microphone.status;
      debugPrint('[VoiceController] 🔵 Current permission status: $status');
      
      if (status.isGranted) {
        debugPrint('[VoiceController] ✅ Microphone permission already granted');
        return true;
      }
      
      // If permanently denied, show appropriate message
      if (status.isPermanentlyDenied) {
        debugPrint('[VoiceController] ❌ Microphone permission permanently denied');
        state = state.copyWith(
          status: VoiceStatus.error,
          errorMessage: 'Quyền Microphone bị tắt vĩnh viễn. Vui lòng bật trong Cài đặt.',
        );
        // Offer to open settings
        await openAppSettings();
        return false;
      }
      
      // Request permission
      debugPrint('[VoiceController] 🔵 Requesting microphone permission...');
      final result = await Permission.microphone.request();
      debugPrint('[VoiceController] 🔵 Permission request result: $result');
      
      if (result.isGranted) {
        debugPrint('[VoiceController] ✅ Microphone permission granted');
        return true;
      }
      
      // Permission denied
      if (result.isPermanentlyDenied) {
        debugPrint('[VoiceController] ❌ Microphone permission permanently denied after request');
        state = state.copyWith(
          status: VoiceStatus.error,
          errorMessage: 'Quyền Microphone bị tắt vĩnh viễn. Vui lòng bật trong Cài đặt.',
        );
        // Offer to open settings
        await openAppSettings();
      } else {
        debugPrint('[VoiceController] ❌ Microphone permission denied');
        state = state.copyWith(
          status: VoiceStatus.error,
          errorMessage: 'Cần quyền Microphone để nhận dạng giọng nói.',
        );
      }
      
      return false;
    } catch (e, stackTrace) {
      debugPrint('[VoiceController] ❌ Error checking microphone permission: $e');
      debugPrint('[VoiceController] Stack trace: $stackTrace');
      state = state.copyWith(
        status: VoiceStatus.error,
        errorMessage: 'Không thể kiểm tra quyền Microphone.',
      );
      return false;
    }
  }

  /// Handle permission denied error
  void _handlePermissionDeniedError() async {
    final status = await Permission.microphone.status;
    if (status.isPermanentlyDenied) {
      state = state.copyWith(
        status: VoiceStatus.error,
        errorMessage: 'Quyền Microphone bị tắt vĩnh viễn. Vui lòng bật trong Cài đặt.',
      );
    } else {
      state = state.copyWith(
        status: VoiceStatus.error,
        errorMessage: 'Cần quyền Microphone để nhận dạng giọng nói.',
      );
    }
  }

  /// Start listening for voice input
  /// 
  /// [onFoodRecognized] Optional callback that will be invoked when food is successfully recognized.
  Future<void> startListening({void Function(RecognizedFood food)? onFoodRecognized}) async {
    // CRITICAL: Check microphone permission BEFORE attempting to listen
    // This prevents the "error_network, permanent: true" error on Android
    debugPrint('[VoiceController] 🔵 Ensuring microphone permission before starting...');
    final hasPermission = await _ensureMicrophonePermission();
    
    if (!hasPermission) {
      debugPrint('[VoiceController] ❌ Cannot start listening: microphone permission not granted');
      // Error message already set by _ensureMicrophonePermission
      return;
    }
    
    if (!_isInitialized) {
      await _initializeSpeech();
      if (!_isInitialized) {
        debugPrint('[VoiceController] ❌ Cannot start listening: speech not initialized');
        return;
      }
    }

    if (state.status == VoiceStatus.listening || state.status == VoiceStatus.processing) {
      debugPrint('[VoiceController] ⚠️ Already listening or processing');
      return;
    }

    try {
      debugPrint('[VoiceController] 🔵 Starting listening...');
      
      state = state.copyWith(
        status: VoiceStatus.listening,
        errorMessage: null,
        clearError: true,
        clearTranscript: true,
        clearFinalTranscript: true,
        clearRecognizedFood: true,
        clearSuggestions: true,
      );

      await _speech.listen(
        onResult: (result) {
          debugPrint('[VoiceController] 🔵 Speech result: ${result.recognizedWords}');
          state = state.copyWith(currentTranscript: result.recognizedWords);
          
          // Automatically process when final result is detected
          if (result.finalResult) {
            final finalTranscript = result.recognizedWords;
            debugPrint('[VoiceController] ✅ Final transcript: $finalTranscript');
            // Update state with final transcript and trigger processing
            state = state.copyWith(
              transcript: finalTranscript,
              currentTranscript: finalTranscript,
            );
            // Automatically process the transcript
            processCurrentTranscript();
          }
        },
        localeId: 'vi_VN', // Vietnamese locale, can be made configurable
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.confirmation,
        ),
      );

      debugPrint('[VoiceController] ✅ Started listening');
    } catch (e, stackTrace) {
      debugPrint('[VoiceController] ❌ Error starting listening: $e');
      debugPrint('[VoiceController] Stack trace: $stackTrace');
      state = state.copyWith(
        status: VoiceStatus.error,
        errorMessage: 'Không thể bắt đầu nhận dạng giọng nói.',
      );
    }
  }

  /// Stop listening (without processing - processing happens automatically on final result)
  Future<void> stopListening() async {
    if (state.status != VoiceStatus.listening) {
      debugPrint('[VoiceController] ⚠️ Not currently listening');
      return;
    }

    try {
      debugPrint('[VoiceController] 🔵 Stopping listening...');
      await _speech.stop();
      
      // Wait a bit for final transcript to be captured
      await Future.delayed(const Duration(milliseconds: 300));

      final transcript = state.currentTranscript ?? state.transcript;
      if (transcript == null || transcript.trim().isEmpty) {
        debugPrint('[VoiceController] ⚠️ No transcript to process');
        state = state.copyWith(
          status: VoiceStatus.error,
          errorMessage: 'Không nhận dạng được giọng nói. Vui lòng thử lại.',
        );
        return;
      }

      // If we have a transcript but haven't processed it yet, process it now
      if (state.transcript == null || state.transcript != transcript) {
        state = state.copyWith(transcript: transcript);
        await processCurrentTranscript();
      } else if (state.status == VoiceStatus.idle && state.transcript != null) {
        // If we already have a transcript but haven't processed, process it
        await processCurrentTranscript();
      } else {
        // Just stop listening
        state = state.copyWith(status: VoiceStatus.idle);
      }
    } catch (e, stackTrace) {
      debugPrint('[VoiceController] ❌ Error stopping listening: $e');
      debugPrint('[VoiceController] Stack trace: $stackTrace');
      state = state.copyWith(
        status: VoiceStatus.error,
        errorMessage: 'Không thể dừng nhận dạng giọng nói.',
      );
    }
  }

  /// Process the current transcript to get food suggestions
  Future<void> processCurrentTranscript() async {
    final currentTranscript = state.transcript?.trim() ?? state.currentTranscript?.trim();
    if (currentTranscript == null || currentTranscript.isEmpty) {
      debugPrint('[VoiceController] ⚠️ No transcript to process');
      return;
    }

    try {
      state = state.copyWith(
        status: VoiceStatus.processing,
        errorMessage: null,
        clearError: true,
        transcript: currentTranscript,
      );

      debugPrint('[VoiceController] 🔍 Processing transcript: "$currentTranscript"');

      // Get services from providers
      final voiceMealService = ref.read(voiceMealServiceProvider);
      
      // Suggest foods based on transcript
      final suggestions = await voiceMealService.suggestFoodsForTranscript(currentTranscript);

      debugPrint('[VoiceController] 🔍 Suggestions found: ${suggestions.length}');

      state = state.copyWith(
        status: VoiceStatus.suggestionsReady,
        suggestions: suggestions,
      );

      debugPrint('[VoiceController] ✅ Suggestions ready for transcript: $currentTranscript');
    } catch (e, stackTrace) {
      debugPrint('[VoiceController] ❌ Failed to get suggestions: $e');
      debugPrint('[VoiceController] Stack trace: $stackTrace');
      state = state.copyWith(
        status: VoiceStatus.error,
        errorMessage: 'Không thể gợi ý món ăn, vui lòng thử lại.',
        suggestions: const [],
      );
    }
  }

  /// Cancel listening without processing
  Future<void> cancelListening() async {
    if (state.status == VoiceStatus.listening) {
      await _speech.stop();
      state = state.copyWith(
        status: VoiceStatus.idle,
        clearTranscript: true,
        clearFinalTranscript: true,
      );
      debugPrint('[VoiceController] ✅ Cancelled listening');
    }
  }

  /// Clear the current result and error
  void clearResult() {
    state = state.copyWith(
      clearRecognizedFood: true,
      clearError: true,
      clearTranscript: true,
      clearFinalTranscript: true,
      clearSuggestions: true,
    );
  }

  /// Reset to idle state
  void reset() {
    _speech.stop();
    state = const VoiceState(status: VoiceStatus.idle);
  }
}

/// Provider for VoiceController
final voiceControllerProvider =
    NotifierProvider<VoiceController, VoiceState>(
  VoiceController.new,
);

