import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calories_app/data/firebase/water_intake_repository.dart';
import 'package:calories_app/features/home/domain/water_intake_entry.dart';
import 'package:calories_app/shared/state/auth_providers.dart';

/// Provider for WaterIntakeRepository
final waterIntakeRepositoryProvider = Provider<WaterIntakeRepository>((ref) {
  return WaterIntakeRepository();
});

/// State class for daily water intake
class DailyWaterIntakeState {
  final List<WaterIntakeEntry> entries;
  final int totalMl;
  final int goalMl;
  final bool isLoading;
  final String? errorMessage;

  const DailyWaterIntakeState({
    required this.entries,
    required this.totalMl,
    required this.goalMl,
    this.isLoading = false,
    this.errorMessage,
  });

  double get progress => goalMl > 0 ? (totalMl / goalMl).clamp(0, 1) : 0.0;

  DailyWaterIntakeState copyWith({
    List<WaterIntakeEntry>? entries,
    int? totalMl,
    int? goalMl,
    bool? isLoading,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return DailyWaterIntakeState(
      entries: entries ?? this.entries,
      totalMl: totalMl ?? this.totalMl,
      goalMl: goalMl ?? this.goalMl,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Notifier for managing daily water intake state
class DailyWaterIntakeNotifier extends Notifier<DailyWaterIntakeState> {
  WaterIntakeRepository? _repository;
  StreamSubscription<List<WaterIntakeEntry>>? _entriesSubscription;
  String? _currentUid;
  DateTime _selectedDate = DateTime.now();

  @override
  DailyWaterIntakeState build() {
    // Initialize repository
    _repository = ref.read(waterIntakeRepositoryProvider);
    
    // Default water goal in ml (can be customized per user in the future)
    const defaultGoalMl = 2200;
    
    // Initialize state
    final initialState = DailyWaterIntakeState(
      entries: [],
      totalMl: 0,
      goalMl: defaultGoalMl,
      isLoading: true,
    );
    
    // CRITICAL FIX: Read initial auth state synchronously on cold start
    // ref.listen only fires on CHANGES, not on initial value
    final initialAuthState = ref.read(authStateProvider);
    debugPrint('[DailyWaterIntakeNotifier] 🔵 Initial auth state in build(): ${initialAuthState.hasValue ? "has data" : "loading/error"}');
    
    // Handle initial auth state immediately
    initialAuthState.whenData((user) {
      if (user != null) {
        final uid = user.uid;
        debugPrint('[DailyWaterIntakeNotifier] 🟢 Cold start with existing user (uid=$uid), starting watch immediately');
        _currentUid = uid;
        // Use Future.microtask to avoid modifying state during build
        Future.microtask(() => _watchEntriesForDate(_selectedDate, uid: uid));
      }
    });
    
    // Watch for future auth state changes
    _watchAuthState();
    
    return initialState;
  }

  /// Watch auth state and start/stop Firestore subscription accordingly
  void _watchAuthState() {
    // Watch auth state provider and react to FUTURE changes
    // NOTE: ref.listen does NOT fire on initial value, only on changes!
    ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
      debugPrint('[DailyWaterIntakeNotifier] 🔔 Auth state changed (via ref.listen)');
      _handleAuthStateChange(next);
    });
  }

  /// Handle auth state change
  void _handleAuthStateChange(AsyncValue<User?> authState) {
    authState.when(
      data: (user) {
        final uid = user?.uid;
        
        // If uid changed, update subscription
        if (uid != _currentUid) {
          _currentUid = uid;
          
          // Cancel previous Firestore subscription
          _entriesSubscription?.cancel();
          
          if (uid == null) {
            // No user signed in
            debugPrint(
              '[DailyWaterIntakeNotifier] ⚠️ No user signed in, clearing state',
            );
            state = state.copyWith(
              entries: [],
              totalMl: 0,
              isLoading: false,
              clearErrorMessage: true,
            );
          } else {
            // User is signed in, start watching entries
            debugPrint(
              '[DailyWaterIntakeNotifier] ✅ User signed in (uid=$uid), starting water intake watch',
            );
            _watchEntriesForDate(_selectedDate, uid: uid);
          }
        }
      },
      loading: () {
        // Auth is still loading
        debugPrint('[DailyWaterIntakeNotifier] ⏳ Auth state loading...');
        if (_currentUid == null) {
          state = state.copyWith(
            isLoading: true,
            clearErrorMessage: true,
          );
        }
      },
      error: (error, stackTrace) {
        debugPrint('[DailyWaterIntakeNotifier] 🔥 Auth state error: $error');
        // On auth error, clear state
        _currentUid = null;
        _entriesSubscription?.cancel();
        state = state.copyWith(
          entries: [],
          totalMl: 0,
          isLoading: false,
          errorMessage: 'Lỗi xác thực: $error',
        );
      },
    );
  }

  /// Watch Firestore entries for a specific date and update state
  void _watchEntriesForDate(DateTime date, {required String uid}) {
    // Cancel previous subscription
    _entriesSubscription?.cancel();

    try {
      state = state.copyWith(isLoading: true, clearErrorMessage: true);
      
      _entriesSubscription = _repository!
          .watchWaterIntakeForDate(uid: uid, date: date)
          .listen(
        (entries) {
          debugPrint(
            '[DailyWaterIntakeNotifier] 📊 Received ${entries.length} water intake entries',
          );
          
          // Calculate total ml
          final totalMl = entries.fold<int>(
            0,
            (sum, entry) => sum + entry.amountMl,
          );

          debugPrint(
            '[DailyWaterIntakeNotifier] 📊 Total water intake: ${totalMl}ml',
          );

          // Update state
          state = state.copyWith(
            entries: entries,
            totalMl: totalMl,
            isLoading: false,
            clearErrorMessage: true,
          );
        },
        onError: (error, stackTrace) {
          debugPrint(
            '[DailyWaterIntakeNotifier] 🔥 Error watching entries: $error',
          );
          debugPrint(
            '[DailyWaterIntakeNotifier] Stack trace: $stackTrace',
          );
          
          // Check if this is a permission-denied error
          final isPermissionDenied = error.toString().contains('permission-denied');
          final hasValidUser = _currentUid != null;
          
          if (isPermissionDenied && !hasValidUser) {
            // Permission denied but no user - likely auth still initializing
            debugPrint(
              '[DailyWaterIntakeNotifier] ⚠️ Permission denied but no user - waiting for auth',
            );
            state = state.copyWith(
              entries: [],
              totalMl: 0,
              isLoading: false,
              clearErrorMessage: true,
            );
          } else {
            // Real error - show it
            state = state.copyWith(
              entries: [],
              totalMl: 0,
              isLoading: false,
              errorMessage: 'Lỗi tải dữ liệu: $error',
            );
          }
        },
        cancelOnError: false,
      );
    } catch (e, stackTrace) {
      debugPrint('[DailyWaterIntakeNotifier] 🔥 Exception setting up stream: $e');
      debugPrint('[DailyWaterIntakeNotifier] Stack trace: $stackTrace');
      state = state.copyWith(
        entries: [],
        totalMl: 0,
        isLoading: false,
        errorMessage: 'Lỗi khởi tạo kết nối: $e',
      );
    }
  }

  /// Set selected date (for future date navigation feature)
  void setSelectedDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    _selectedDate = normalized;
    
    if (_currentUid != null) {
      _watchEntriesForDate(normalized, uid: _currentUid!);
    }
  }

  /// Add water intake
  Future<void> addWater(int amountMl) async {
    // Use cached UID from auth state watcher
    final uid = _currentUid;
    if (uid == null) {
      throw Exception('Bạn cần đăng nhập để ghi nhật ký uống nước');
    }

    if (amountMl <= 0) {
      throw Exception('Lượng nước phải lớn hơn 0');
    }

    if (amountMl > 5000) {
      throw Exception('Lượng nước không được quá 5000ml');
    }

    try {
      debugPrint(
        '[DailyWaterIntakeNotifier] 🔵 Adding water: ${amountMl}ml',
      );

      await _repository!.addWaterForToday(amountMl: amountMl);

      debugPrint('[DailyWaterIntakeNotifier] ✅ Water added successfully');
    } catch (e, stackTrace) {
      debugPrint('[DailyWaterIntakeNotifier] 🔥 Error adding water: $e');
      debugPrint('[DailyWaterIntakeNotifier] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Quick add 250ml
  Future<void> addQuick250() => addWater(250);

  /// Quick add 500ml
  Future<void> addQuick500() => addWater(500);

  /// Delete a water intake entry
  Future<void> deleteEntry(String entryId) async {
    try {
      await _repository!.deleteWaterIntake(entryId);
      debugPrint(
        '[DailyWaterIntakeNotifier] ✅ Deleted water intake entry: $entryId',
      );
    } catch (e, stackTrace) {
      debugPrint(
        '[DailyWaterIntakeNotifier] 🔥 Error deleting water intake entry: $e',
      );
      debugPrint('[DailyWaterIntakeNotifier] Stack trace: $stackTrace');
      rethrow;
    }
  }
}

/// Provider for daily water intake state
final dailyWaterIntakeProvider =
    NotifierProvider<DailyWaterIntakeNotifier, DailyWaterIntakeState>(
  DailyWaterIntakeNotifier.new,
);

