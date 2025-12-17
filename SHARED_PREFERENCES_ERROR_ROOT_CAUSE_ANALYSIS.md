# "Bad state: SharedPreferences not yet loaded" - ROOT CAUSE ANALYSIS

**Ngày:** 17/12/2025  
**Lỗi:** `StateError: Bad state: SharedPreferences not yet loaded`  
**Phạm vi:** Riverpod provider lifecycle + app startup sequence  
**Status:** ANALYSIS ONLY - NO CODE MODIFICATIONS

---

## CHÍNH XÁC NGUYÊN NHÂN LỖI

### 🔴 ROOT CAUSE: `sharedPreferencesProvider` được watch/read quá sớm

**Vị trí lỗi:**

```dart
// lib/shared/state/profile_providers.dart (Line 33-48)
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  final asyncValue = ref.watch(sharedPreferencesFutureProvider);  // ← Watch async provider
  return asyncValue.when(
    data: (prefs) => prefs,
    loading: () => throw StateError(
      'SharedPreferences not yet loaded. This should not happen if StartupOrchestrator.ensureDeferredInitialized() '
      'is called properly after first frame.'
    ),  // ← THROWS THIS ERROR
    error: (error, stack) => throw StateError(
      'Failed to load SharedPreferences: $error'
    ),
  );
});
```

**Nguyên nhân chi tiết:**

1. `sharedPreferencesProvider` là `Provider<SharedPreferences>` (synchronous)
2. Nó watch `sharedPreferencesFutureProvider` (async/future provider)
3. Khi `sharedPreferencesFutureProvider` vẫn loading → throw StateError
4. Các provider khác watch `sharedPreferencesProvider` mà chưa ready

---

## PROVIDERS ĐANG GỌI SHARED PREFERENCES QUẢSỚM

### 1. 🔴 CRITICAL: `onboardingCacheProvider`

**File:** `lib/shared/state/onboarding_cache_provider.dart` (Line 11)

```dart
final onboardingCacheProvider = Provider<OnboardingCache>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);  // ← Watch at build time
  return OnboardingCache(prefs);
});
```

**Nơi được gọi:**

- `lib/app/routing/profile_gate.dart` (Line 29) → `ref.read(onboardingCacheProvider)`
  ```dart
  final cache = ref.read(onboardingCacheProvider);  // ← Called during ProfileGate build
  final cachedStatus = cache.getCachedStatus(widget.uid);
  ```

**Timeline:**

```
t0:    main() starts
       └─ Firebase.initializeApp() (quick)
       └─ runApp() → IntroGate renders

t1:    IntroGate.build()
       └─ ref.watch(introStatusProvider)
       └─ ref.watch(authStateProvider)
       └─ User logged in → ProfileGate(uid)

t2:    ProfileGate.build()
       └─ ref.read(onboardingCacheProvider)  ← ❌ PROBLEM HERE
         └─ ref.watch(sharedPreferencesProvider)
           └─ ref.watch(sharedPreferencesFutureProvider)
             └─ asyncValue.when(loading: () => throw StateError)  ← EXCEPTION!
```

---

### 2. 🔴 CRITICAL: `diaryCacheProvider`

**File:** `lib/shared/state/diary_providers.dart` (Line 16)

```dart
final diaryCacheProvider = Provider<DiaryCache>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);  // ← Watch at build time
  return SharedPrefsDiaryCache(prefs);
});
```

**Nơi được gọi:**

- `lib/shared/state/diary_providers.dart` (Line 26) → `diaryServiceProvider`
  ```dart
  final diaryServiceProvider = Provider<DiaryService>((ref) {
    final cache = ref.read(diaryCacheProvider);  // ← Watched by diaryEntriesForDayProvider
  });
  ```

**Cascade:**

- `DashboardPage` watches `diaryProvider` (or related)
- → triggers `diaryServiceProvider`
- → triggers `diaryCacheProvider`
- → triggers `sharedPreferencesProvider`
- → throws if not ready

---

### 3. 🔴 CRITICAL: `profileCacheProvider`

**File:** `lib/shared/state/profile_providers.dart` (Line 49)

```dart
final profileCacheProvider = Provider<ProfileCache>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);  // ← Watch at build time
  return SharedPrefsProfileCache(prefs);
});
```

**Nơi được gọi:**

- `lib/shared/state/profile_providers.dart` (Line 66) → `profileServiceProvider`

---

### 4. 🔴 CRITICAL: `userMealPlanCacheProvider`

**File:** `lib/shared/state/user_meal_plan_providers.dart` (Line 17)

```dart
final userMealPlanCacheProvider = Provider<UserMealPlanCache>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);  // ← Watch at build time
  return SharedPrefsUserMealPlanCache(prefs);
});
```

**Nơi được gọi:**

- `userMealPlanServiceProvider` → `activeMealPlanProvider`

---

### 5. 🔴 CRITICAL: `foodCacheProvider`

**File:** `lib/shared/state/food_providers.dart` (Line 15)

```dart
final foodCacheProvider = Provider<FoodCache>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);  // ← Watch at build time
  return SharedPrefsFoodCache(prefs);
});
```

---

### 6. 🔴 CRITICAL: `exploreMealPlanCacheProvider`

**File:** `lib/shared/state/explore_meal_plan_providers.dart` (Line 15)

```dart
final exploreMealPlanCacheProvider = Provider<ExploreMealPlanCache>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);  // ← Watch at build time
  return SharedPrefsExploreMealPlanCache(prefs);
});
```

---

### 7. ⚠️ Additional: `health_providers.dart`

**File:** `lib/core/health/health_providers.dart` (Line 32)

```dart
final prefs = ref.watch(sharedPreferencesProvider);
```

**Nơi được gọi:**

- Health repository initialization

---

### 8. ⚠️ Additional: `notification_scheduler.dart`

**File:** `lib/core/notifications/notification_scheduler.dart` (Line 151)

```dart
final prefs = ref.read(sharedPreferencesProvider);  // ← Called from notifier method
```

---

## GIẢI THÍCH VÌ SAO LỖI XẢY RA

### Startup Order Tỉ Mỉ

```
TIMELINE:
=========

[Phase: Critical]
t0:    main() async starts
       └─ WidgetsFlutterBinding.ensureInitialized()
       └─ await Firebase.initializeApp()
       └─ StartupOrchestrator.markRunApp()
       └─ runApp(ProviderScope(child: MyApp()))
           ↓
[Phase: UI Build]
t0+100ms: MyApp.build()
          └─ MaterialApp home: IntroGate()
              ↓
t0+150ms: IntroGate.build()
          └─ ref.watch(introStatusProvider)           (loading...)
          └─ ref.watch(authStateProvider)             (loading...)
          └─ Wait for user from authStateProvider
              ↓
t0+200ms: authStateProvider ready → user found
          └─ ProfileGate(uid: user.uid)
              ↓
t0+250ms: ProfileGate.build()
          └─ ref.read(onboardingCacheProvider)        ← ❌ WATCH sharedPreferencesProvider
            └─ ref.watch(sharedPreferencesProvider)
              └─ ref.watch(sharedPreferencesFutureProvider)
                └─ asyncValue = AsyncValue.loading (FutureProvider still fetching)
                └─ asyncValue.when(
                     loading: () => throw StateError(
                       'SharedPreferences not yet loaded. This should not happen...'
                     )
                   )

          🔥 EXCEPTION THROWN! ❌

[Phase: Deferred - NOT REACHED YET]
t0+5000ms: HomeScreen.initState() calls:
           └─ WidgetsBinding.instance.addPostFrameCallback()
             └─ Future.delayed(5 seconds)
               └─ StartupOrchestrator.ensureDeferredInitialized(ref)
                 └─ _initializeSharedPreferences()
                   └─ StartupOrchestrator._sharedPreferences = await SharedPreferences.getInstance()
                   ↓
                   Lúc này đã quá muộn! App đã crash ở t0+250ms
```

---

## VÌ SAO DEFERRED INITIALIZATION KHÔNG GIẢI ĐƯỢC

### Thứ tự khởi động:

```
main.dart:
  1. Firebase init (quick)
  2. runApp() → immediately renders IntroGate

IntroGate:
  3. Checks auth state → shows ProfileGate

ProfileGate:
  4. IMMEDIATELY watches onboardingCacheProvider
  5. onboardingCacheProvider watches sharedPreferencesProvider
  6. sharedPreferencesProvider throws (FutureProvider loading)

  ❌ CRASHES HERE (t0+250ms)

HomeScreen:
  7. Would call ensureDeferredInitialized() after first frame (t0+5000ms)
  8. Would initialize SharedPreferences (t0+5000ms + async time)

  ❌ NEVER REACHED because ProfileGate crashed at step 6
```

---

## CẤP ĐỘ SEVERITY

| Provider                       | Severity    | Used In               | Impact                    |
| ------------------------------ | ----------- | --------------------- | ------------------------- |
| `onboardingCacheProvider`      | 🔴 CRITICAL | ProfileGate (routing) | Blocks ProfileGate render |
| `profileCacheProvider`         | 🔴 CRITICAL | Profile loading       | Blocks profile fetch      |
| `diaryCacheProvider`           | 🔴 CRITICAL | DashboardPage         | Blocks diary display      |
| `userMealPlanCacheProvider`    | 🔴 CRITICAL | Meal plan display     | Blocks meal plan render   |
| `foodCacheProvider`            | 🔴 CRITICAL | Food searching        | Blocks food data          |
| `exploreMealPlanCacheProvider` | 🔴 CRITICAL | Explore plans         | Blocks template display   |
| `health_providers`             | ⚠️ MAJOR    | Health tracking       | May crash health features |
| `notification_scheduler`       | ⚠️ MEDIUM   | Notifications         | Only called after init    |

---

## CHÍ TẾT LỖI: Provider Watch Timing

### Vấn đề chính:

```dart
// ❌ WRONG - Watches sharedPreferencesProvider at build time
final onboardingCacheProvider = Provider<OnboardingCache>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);  // Watch during provider build()
  return OnboardingCache(prefs);
});

// Why it fails:
// 1. ProfileGate.build() calls ref.read(onboardingCacheProvider)
// 2. onboardingCacheProvider.build() is called
// 3. Inside build(), it watches sharedPreferencesProvider
// 4. sharedPreferencesProvider.build() is called
// 5. Inside build(), it watches sharedPreferencesFutureProvider
// 6. sharedPreferencesFutureProvider is still loading (AsyncValue.loading)
// 7. asyncValue.when() hits loading() case → throws StateError
// 8. Exception propagates up the entire widget tree
// 9. App crashes before UI renders
```

---

## GIẢI PHÁP ĐƯỢC ĐỀ XUẤT

### ✅ Solution 1: PREFERRED - Pre-provide SharedPreferences

**Approach:**

- Load SharedPreferences trước `runApp()`
- Pass instance vào `ProviderScope.overrides`
- Tất cả provider read from cache instance

**Advantages:**

- ✅ Synchronous access (no async/loading states)
- ✅ No StateError possible
- ✅ Minimal code changes
- ✅ Most stable approach

**Implementation:**

```dart
// In main.dart - CRITICAL PHASE (before runApp)
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Preload SharedPreferences BEFORE runApp
  final sharedPrefs = await SharedPreferences.getInstance();  ← NEW

  await Firebase.initializeApp(...);

  runApp(
    ProviderScope(
      overrides: [
        // Override sharedPreferencesFutureProvider to return preloaded instance
        sharedPreferencesFutureProvider.overrideWithValue(
          AsyncValue.data(sharedPrefs)
        ),
      ],
      child: MyApp(),
    ),
  );
}
```

**Result:**

- ✅ `sharedPreferencesProvider` immediately returns data (not loading)
- ✅ All cache providers can safely watch it
- ✅ ProfileGate renders without crashing

---

### ✅ Solution 2: Guard with Synchronous Check

**Approach:**

- Check if instance available before watching
- Fall back to default/null if not ready

**Code:**

```dart
// In profile_providers.dart
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  // Check if already loaded (from StartupOrchestrator)
  if (StartupOrchestrator.sharedPreferences != null) {
    return StartupOrchestrator.sharedPreferences!;
  }

  // If not ready, this will still throw
  final asyncValue = ref.watch(sharedPreferencesFutureProvider);
  return asyncValue.when(
    data: (prefs) => prefs,
    loading: () => throw StateError(...),  // Still bad, but less likely
    error: (error, stack) => throw StateError(...),
  );
});
```

**Disadvantage:**

- Still may throw if accessed before `StartupOrchestrator.sharedPreferences` set
- Less reliable than Solution 1

---

### ✅ Solution 3: Lazy Deferred Providers

**Approach:**

- Make cache providers `family` or `autoDispose`
- Only build them when actually needed
- Add early guard in ProfileGate

**Code:**

```dart
// In profile_gate.dart
final cache = ref.watch(onboardingCacheProvider).whenData((c) => c);
// Or skip onboarding cache on first ProfileGate render
```

**Disadvantage:**

- Requires more refactoring
- May miss cache benefits

---

## RECOMMENDED SOLUTION (LEAST MODIFICATIONS)

### Solution: Override at ProviderScope Level

**Why:**

- ✅ Only modify `main.dart` (1 file)
- ✅ No changes to provider definitions
- ✅ No changes to cache initialization logic
- ✅ Guaranteed synchronous access
- ✅ Maintains all existing code

**Steps:**

1. **In `main.dart`:** Preload SharedPreferences (CRITICAL PHASE)

   ```dart
   void main() async {
     WidgetsFlutterBinding.ensureInitialized();

     // NEW: Preload before runApp
     final sharedPrefs = await SharedPreferences.getInstance();

     await Firebase.initializeApp(...);

     runApp(
       ProviderScope(
         overrides: [
           sharedPreferencesFutureProvider.overrideWithValue(
             AsyncValue.data(sharedPrefs)
           ),
         ],
         child: MyApp(),
       ),
     );
   }
   ```

2. **Result:**
   - ProfileGate can safely call `ref.read(onboardingCacheProvider)`
   - `sharedPreferencesProvider` gets data (not loading)
   - No crashes

---

## ALTERNATIVE: Remove AsyncValue Wrapper

**Approach:**

- Change `sharedPreferencesFutureProvider` to be synchronous
- Store in `StartupOrchestrator` early
- Access via getter

**Code:**

```dart
// In profile_providers.dart
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  // Get from orchestrator cache (set early in main)
  final cachedInstance = StartupOrchestrator.sharedPreferences;

  if (cachedInstance != null) {
    return cachedInstance;  // Already available
  }

  // Fallback (should not happen if main.dart does preload correctly)
  throw StateError('SharedPreferences not initialized. '
    'Ensure main.dart preloads SharedPreferences before runApp()');
});
```

**Requires:**

- Setting `StartupOrchestrator.sharedPreferences` in `main.dart` (not deferred)

---

## SUMMARY TABLE

| Approach                      | Files Modified                       | Code Lines | Risk     | Stability  |
| ----------------------------- | ------------------------------------ | ---------- | -------- | ---------- |
| **Override at ProviderScope** | 1 (main.dart)                        | +4 lines   | Very Low | ⭐⭐⭐⭐⭐ |
| Remove AsyncValue             | 3 (profile_providers + main)         | +5 lines   | Low      | ⭐⭐⭐⭐   |
| Guard in ProfileGate          | 2 (profile_gate + profile_providers) | +3 lines   | Medium   | ⭐⭐⭐     |
| Lazy cache providers          | 6 (all cache providers)              | +20 lines  | High     | ⭐⭐       |

---

## FINAL RECOMMENDATION

### 🎯 Use Solution: Override at ProviderScope

**Rational:**

1. Preload SharedPreferences in main.dart (CRITICAL PHASE) before any UI build
2. Override `sharedPreferencesFutureProvider` in `ProviderScope`
3. All cache providers get synchronous data (no StateError)
4. Deferred initialization continues to load other heavy services

**Implementation:**

- Modify: `lib/main.dart` only
- Add 4-5 lines before `runApp()`
- No changes to provider definitions
- No changes to cache logic
- Fully backward compatible

**Result:**

- ✅ No "SharedPreferences not yet loaded" error
- ✅ ProfileGate renders successfully
- ✅ App reaches HomeScreen
- ✅ Deferred services load in background

---

## VERIFICATION CHECKLIST

After implementing solution:

- [ ] `main.dart` preloads SharedPreferences before `runApp()`
- [ ] `ProviderScope.overrides` contains `sharedPreferencesFutureProvider` override
- [ ] ProfileGate renders without crashing
- [ ] App reaches HomeScreen
- [ ] Onboarding cache works (cached status loaded)
- [ ] Diary entries display (diary cache works)
- [ ] Meal plans display (meal plan cache works)
- [ ] No "not yet loaded" errors in console
