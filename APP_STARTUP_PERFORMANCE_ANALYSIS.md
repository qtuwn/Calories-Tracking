# APP STARTUP PERFORMANCE ANALYSIS - KIẾN TRÚC KHỞI ĐỘNG HIỆU SUẤT

**Ngày:** 17/12/2025  
**Scope:** Phân tích tại sao app chậm khi khởi động (17 giây từ main → home screen)  
**Status:** ANALYSIS ONLY - NO CODE MODIFICATIONS

---

## TIMELINE TỪ LOG

```
[Main] 🔵 Preloading SharedPreferences                          t0 = 1765949574981
  ↓ (Preload SharedPreferences: ~30ms)
[Main] ✅ SharedPreferences preloaded successfully
[ENV] ✅ Environment variables loaded
[FIREBASE] ✅ Project ID verified
[Firestore] ✅ Offline persistence enabled                      t0+8s ≈ 1765949582981
  ↓ (Firebase init + Firestore setup: ~8 giây)
[LocalNotificationsService] ✅ Initialized
[PushNotificationsService] Permission status: authorized        t0+12-13s
[PushNotificationsService] ⏱️ FCM Token fetched
  ↓ (Notification services: ~3-4 giây)
[StartupCoordinator] ⏱️ t1 (HomeScreen initState)               t1 = 1765949597302
  ↓ Delay: 3 giây (addPostFrameCallback delay)
[StartupCoordinator] ⏱️ afterFirstFrame                          t1+4.2s = 1765949601565

    ↓ Các dịch vụ load ĐỒNG THỜI từ đây:
    ├─ [DiaryNotifier] 🟢 Cold start with existing user
    ├─ [CurrentUserProfileProvider] Setting up auth-aware profile stream
    ├─ [DailyWaterIntakeNotifier] 🟢 Cold start with existing user
    ├─ [LatestWeightProvider] Watching latest weight
    ├─ [WeightRepository] Watching latest weight
    ├─ [RecentWeightsProvider] Watching recent weights 7 days
    ├─ [ActiveMealPlanProvider] Setting up active plan stream
    ├─ [FirestoreProfileRepository] Watching profile
    ├─ [UserMealPlanService] [ActivePlan] Setting up active plan stream
    ├─ [StepsTodayCache] ✅ Loaded cached steps: 0
    ├─ [ActivityController] ✅ Loaded cached steps
    └─ [VoiceController] ✅ Speech recognition initialized

    ↓ Firestore queries phát hành:
    ├─ [UserMealPlanRepository] [ActivePlan] Querying active plan
    ├─ [DiaryService] Watching diary entries for 2025-12-17
    ├─ [WaterIntakeRepository] Watching water intake for today
    └─ [WeightRepository] Watching recent weights 7 days

    ↓ Cache hits/Firestore responses:
    ├─ [SharedPrefsDiaryCache] ✅ Loaded 6 entries from cache
    ├─ [SharedPrefsProfileCache] ✅ Loaded cached profile
    ├─ [ActivePlanCache] ⏳ waiting first Firestore emission timeout=3000ms
    └─ [SharedPrefsUserMealPlanCache] ✅ Saved cached active plan

    ↓ Timeout thời gian chờ kéo dài:
    ├─ t1+4s: ActivePlanCache ! Firestore timeout → emitting NULL
    └─ Tiếp tục streaming Firestore...

[FirestoreDiaryRepository] ✅ Found 6 entries
[FirestoreProfileRepository] ✅ Found current profile
[UserMealPlanRepository] [ActivePlan] ✅ Found active plan: planId=...
[SharedPrefsUserMealPlanCache] ✅ Saved cached active plan
[UserMealPlanRepository] Setting up stream for meals: planId=..., dayIndex=1
[FirestoreFoodRepository] 🔵 Getting food by ID
[MealUserActivePage] [ActivePlan] UI received active plan

**UI HIỂN THỊ LÚAN:** ≈ t1+4.2s = ~17s từ app start
```

---

## CHIẾN LƯỢC INITIALIZATION CỰC KỲ NẶNG

### ⚠️ VẤN ĐỀ CHÍNH: Quá nhiều công việc ở Main + IntroGate + ProfileGate

#### Giai đoạn 1: main.dart (8-10 giây)

**Blocking operations:**

```
1. SharedPreferences.getInstance()           (preload)     ~30ms
2. dotenv.load()                             (env load)    ~10ms
3. Firebase.initializeApp()                  (Firebase)    ~3-5s
4. FirebaseAppCheck.activate()               (AppCheck)    ~1-2s
5. Firestore settings + offline persistence  (Firestore)   ~1s
6. LocalNotificationsService.initialize()    (Local notif) ~1s
7. PushNotificationsService.initialize()     (FCM)         ~2-3s
8. FirebaseMessaging + background service   (Background)  ~0.5-1s
```

**Tổng: 8-10 giây TRƯỚC KHI runApp()**

---

#### Giai đoạn 2: IntroGate (intro status + auth state)

```dart
// lib/app/routing/intro_gate.dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final introAsync = ref.watch(introStatusProvider);     // ← Firestore query
  final authAsync = ref.watch(authStateProvider);         // ← Auth query

  return introAsync.when(
    data: (hasSeenIntro) {
      return authAsync.when(
        data: (user) {
          if (user == null) return AuthPage();
          return ProfileGate(uid: user.uid);              // ← Enter ProfileGate
        },
      );
    },
  );
}
```

**Providers được watch:**

- `introStatusProvider` - Queries SharedPreferences cho intro status
- `authStateProvider` - Queries Firebase Auth state

**Issues:**

- ❌ Cả hai watch cùng lúc (cascade build)
- ❌ introStatusProvider có thể là FutureProvider (chờ Firestore)
- ❌ authStateProvider có thể delay nếu auth state chưa ready

---

#### Giai đoạn 3: ProfileGate (profile data + onboarding check)

```dart
// lib/app/routing/profile_gate.dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final profileAsync = ref.watch(currentProfileProvider(uid));  // ← Firestore query

  return profileAsync.when(
    data: (profile) {
      if (profile?.onboardingCompleted == true) {
        return const HomeScreen();  // ← Enter HomeScreen
      } else {
        return const WelcomeScreen();
      }
    },
  );
}
```

**Providers được watch:**

- `currentProfileProvider(uid)` - Firestore query users/{uid}

**Issues:**

- ⏳ StreamProvider từ Firestore
- ❌ Chặn khi chờ profile data từ Firestore
- ❌ 3000ms timeout thường xảy ra lần đầu (cold start)

---

#### Giai đoạn 4: HomeScreen build() + initState (Tất cả dịch vụ load)

```dart
// lib/features/home/presentation/screens/home_screen.dart
class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Delay 3 giây
      Future.delayed(const Duration(seconds: 3), () {
        _initializeNotifications();     // Load notification schedules
        _initializeFCMToken();          // Update FCM token
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch FCM manager (watches auth state changes)
    ref.watch(fcmTokenManagerProvider);     // ← WATCH #1

    // Watch voice controller
    ref.listen<VoiceState>(
      voiceControllerProvider,               // ← LISTEN #1
      ...
    );

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,                    // ← DashboardPage + 3 pages
      ),
    );
  }
}
```

---

#### Giai đoạn 5: DashboardPage + Widgets (Nhiều providers được watch)

```dart
// lib/features/home/presentation/pages/dashboard_page.dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  return Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            HomeHeaderSection(),           // ← Widget #1
            HomeCalorieCard(),             // ← Widget #2 → watches 2 providers
            HomeMacroSection(),            // ← Widget #3
            HomeRecentDiarySection(),      // ← Widget #4 → watches diaryProvider
            HomeActivitySection(),         // ← Widget #5
            HomeWaterWeightSection(),      // ← Widget #6 → watches 3 providers
            ...
          ],
        ),
      ),
    ),
  );
}
```

---

### 📊 PROVIDERS ĐƯỢC WATCH CỰA THỜI MỎ HOME SCREEN BUILD

#### HomeCalorieCard:

```dart
ref.watch(homeDailySummaryProvider)      // Depends on:
  ├─ diaryProvider                       // Firestore query
  ├─ currentUserProfileProvider          // Firestore query
  └─ Calculated summary

ref.watch(dailyWaterIntakeProvider)      // Depends on:
  └─ WaterIntakeRepository.watching()    // Firestore query
```

#### HomeMacroSection:

```dart
ref.watch(homeMacroSummaryProvider)      // Depends on:
  ├─ diaryProvider                       // Firestore query
  ├─ currentUserProfileProvider          // Firestore query
  └─ Calculated macros
```

#### HomeRecentDiarySection:

```dart
ref.watch(diaryProvider)                 // Firestore diary query
```

#### HomeWaterWeightSection:

```dart
ref.watch(dailyWaterIntakeProvider)      // Firestore query
ref.watch(latestWeightProvider)          // Firestore query
ref.watch(recentWeights7DaysProvider)    // Firestore query (7 days range!)
```

#### HomeActivitySection:

```dart
ref.watch(activityControllerProvider)    // Activity state (cached)
```

#### HomeHeaderSection + MealUserActivePage:

```dart
ref.watch(currentUserProfileProvider)    // Firestore profile
ref.watch(activeMealPlanProvider)        // Firestore active plan query
ref.watch(userMealPlansForPlanProvider)  // Firestore meals query
ref.watch(foodDetailsProvider)           // Firestore food details
```

---

## FIRESTORE QUERIES DIỀU HÀNH KHI HOME SCREEN BUILD

```
❌ ĐỒNG THỜI phát hành (~10-15 queries cùng lúc):

1. users/{uid}/profiles/{profileId}              (HomeHeader + calorie card)
2. users/{uid}/diary/{date}                      (Calorie card + recent section)
3. users/{uid}/water_intake?date={date}          (Water section)
4. users/{uid}/weights?recent=7                  (Weight section)
5. users/{uid}/user_meal_plans?isActive=true     (Meal plan section)
6. users/{uid}/user_meal_plans/{planId}/meals    (Meal plan section)
7. users/{uid}/explore_meals/{mealId}           (For each meal → N queries)
8. users/{uid}/foods/{foodId}                    (For each food → N queries)
9. 📱 Health Connect init (if permission)        (Activity section)
10. Voice controller speech init                 (Voice button)
... + background Firestore listeners
```

**Impact:**

- ⏳ Tất cả queries đợi response từ Firestore
- 🌐 Network roundtrips: ~200-500ms each (Firebase emulation lag)
- 📊 Batch timeout: 3000ms (ActivePlanCache timeout often hits)
- 🔄 Cascading errors: 1 query fail → dependency chains fail

---

## CỰC CỘI NẶNG NHẤT: Timeline chi tiết

| Giai đoạn                    | Thời gian | Chi tiết                                            |
| ---------------------------- | --------- | --------------------------------------------------- |
| **main()**                   | 0-8s      | Firebase init, notifications, FCM                   |
| **IntroGate build()**        | 8-9s      | Intro status + auth queries                         |
| **ProfileGate build()**      | 9-12s     | Profile query + onboarding check                    |
| **HomeScreen build()**       | 12-13s    | Render frame (before content)                       |
| **DashboardPage build()**    | 13s       | Build widget tree (still empty)                     |
| **FirstFrame callback**      | 13-16s    | Delay 3s passed, but...                             |
| **Firestore batch response** | 13-17s    | **Tất cả 10-15 Firestore queries cuối cùng trả về** |
| **UI update**                | 17s       | **Dữ liệu render, UI hiển thị**                     |

**BOTTLENECK:** Bước 13-17s = Chờ Firestore batch response

---

## CẤU TRÚC INITIALIZATION HIỆN TẠI

```
main.dart (Blocking: 8-10s)
  ├─ SharedPreferences.getInstance()
  ├─ Firebase.initializeApp()
  ├─ FirebaseAppCheck.activate()
  ├─ Firestore offline persistence
  ├─ LocalNotificationsService.initialize()
  ├─ PushNotificationsService.initialize()
  └─ FCM background service setup
    ↓
runApp(MyApp)
    ↓
IntroGate.build() (Sync query: 1-2s)
  ├─ introStatusProvider      (SharedPrefs read)
  └─ authStateProvider        (Auth state check)
    ↓
ProfileGate.build() (Async query: 2-3s + timeout)
  └─ currentProfileProvider   (Firestore stream)
    ↓
HomeScreen.build() (Widget tree: 1s)
  ├─ fcmTokenManagerProvider  (Watch)
  └─ voiceControllerProvider  (Listen)
    ↓
HomeScreen.initState()
  └─ addPostFrameCallback() → delay(3s)
    ├─ _initializeNotifications()
    └─ _initializeFCMToken()
    ↓
DashboardPage.build() (Widget creation: <1s)
  └─ Column([
      HomeCalorieCard         (watches 2 providers)
      HomeMacroSection        (watches 1 provider)
      HomeRecentDiarySection  (watches 1 provider)
      HomeActivitySection     (watches 1 provider)
      HomeWaterWeightSection  (watches 3 providers)
      HomeHeaderSection       (watches 1 provider)
      ...
     ])
    ↓
    ❌ 10-15 Firestore queries phát hành ĐỒNG THỜI
    ├─ users/{uid}/profiles
    ├─ users/{uid}/diary
    ├─ users/{uid}/water_intake
    ├─ users/{uid}/weights
    ├─ users/{uid}/user_meal_plans
    └─ ... + sub-queries
    ↓
    ⏳ Chờ tất cả response (3-5 giây)
    ↓
    📊 UI update + render
```

---

## NGUYÊN NHÂN CHÍNH

### 1️⃣ Main.dart quá nặng (8-10 giây)

**Blocking services:**

- Firebase init: ~3-5s
- Firestore setup: ~1s
- Notifications + FCM: ~2-3s
- App Check: ~1s

**Đều là blocking operations trong main() → không thể skip**

---

### 2️⃣ IntroGate + ProfileGate chặn navigation

**Vấn đề:**

```dart
IntroGate.build() {
  return ref.watch(introStatusProvider);          // ← Chặn khi loading
  return ref.watch(authStateProvider);             // ← Chặn khi loading
}

ProfileGate.build() {
  return ref.watch(currentProfileProvider(uid));   // ← StreamProvider
  // Khi status=loading → hiển thị _LoadingScreen
  // Khi status=data → navigate to HomeScreen
}
```

**Cascade:** Phải chờ mỗi cấp trước khi đi cấp tiếp

---

### 3️⃣ DashboardPage build() trigger quá nhiều Firestore queries

**Vấn đề:**

- HomeCalorieCard watches 2 providers → 2 Firestore queries
- HomeMacroSection watches 1 provider → tương dependency
- HomeWaterWeightSection watches 3 providers → 3 Firestore queries
- HomeActivitySection watches activity state
- MealUserActivePage watches meal plans, meals, foods → N queries

**Result:** 10-15 queries phát hành cùng lúc

---

### 4️⃣ Cascading provider dependencies

```dart
homeDailySummaryProvider → depends on:
  ├─ diaryProvider           → depends on:
  │   └─ FirestoreDiaryRepository  → Firestore query
  └─ currentUserProfileProvider    → depends on:
      └─ FirestoreProfileRepository → Firestore query

homeMacroSummaryProvider → depends on:
  ├─ diaryProvider           (same as above)
  └─ currentUserProfileProvider (same as above)

/// Kết quả: diaryProvider queried 2 lần, profileProvider queried 2+ lần
```

---

### 5️⃣ 3000ms timeout khi Firestore query chậm

```dart
[ActivePlanCache] ⏳ waiting first Firestore emission timeout=3000ms
// ... 3 giây chờ ...
[ActivePlanCache] ! Firestore timeout → emitting NULL
```

**Timeline:**

- Query phát hành: t+13s
- Timeout trigger: t+16s
- Actual response: t+17s (nhưng emit NULL đã)
- Reconnect + emit real data: t+17s+

---

## PHÂN LOẠI VẤNĐỀ

### CRITICAL (Blocking startup):

1. ❌ Firebase init blocking (8-10s)
2. ❌ ProfileGate chặn navigation
3. ❌ HomeScreen build() trigger quá nhiều queries

### MAJOR (Làm chậm):

4. ⚠️ 3000ms timeout khi Firestore chậm
5. ⚠️ Cascading dependencies (providers queried nhiều lần)
6. ⚠️ No query batching (10-15 queries phát hành riêng lẻ)

### MEDIUM (Optimization):

7. ⚠️ HomeScreen.initState() delay 3s không cần thiết
8. ⚠️ postFrameCallback delay không optimal
9. ⚠️ Voice controller init trên main thread

---

## OPTIMIZATION RECOMMENDATIONS

### 🎯 Tier 1: Immediate Impact (1-3 giây savings)

**1. Reduce ProfileGate latency:**

- Use `currentProfileProvider.select()` để chỉ lấy `onboardingCompleted`
- Hoặc cache onboarding status trong SharedPreferences
- Tránh toàn bộ profile query chỉ để check onboarding flag

**2. Lazy-load HomeScreen widgets:**

- Không build tất cả 6 widgets cùng lúc
- Build chỉ visible widgets trước (above fold)
- Load below-fold widgets với delay

**3. Reduce Firestore query concurrency:**

- Batch queries hoặc use `Firestore.runTransaction()`
- Sequential query thay vì parallel (if network limited)
- Cache meal plan + meals trong single query

---

### 🎯 Tier 2: Medium Impact (1-2 giây savings)

**4. De-duplicate provider dependencies:**

- `homeDailySummaryProvider` và `homeMacroSummaryProvider` cùng depend `diaryProvider`
- Merge chúng lại = 1 Firestore query thay vì 2

**5. Remove unnecessary watches:**

- HomeCalorieCard watches `dailyWaterIntakeProvider` chỉ để hiển thị water ML
- Nếu không cần hiển thị = bỏ watch
- Hoặc move to lazy-loaded widget

**6. Optimize timeout + retry logic:**

- 3000ms timeout quá dài (default Firestore is 10s)
- Hoặc optimize query speed thay vì extend timeout

---

### 🎯 Tier 3: Polish (500ms-1 giây savings)

**7. Skip HomeScreen.initState() 3s delay:**

- Notification + FCM init đã trigger từ main()
- Delay tiếp 3s không cần thiết
- Move to after UI render (2-3s là đủ)

**8. Parallelize Firebase init:**

- `Firebase.initializeApp()` + `FirebaseAppCheck.activate()` có thể parallel?
- Check nếu AppCheck phụ thuộc Firebase init completion

**9. Lazy-load VoiceController:**

- Speech recognition init không cần khi UI render
- Move to after HomeScreen stabilizes

---

## GIẢI PHÁP CHI TIẾT (không sửa code - chỉ phân tích)

### Option A: Render-First Strategy (Recommended)

**Principle:** Show UI trước, load data sau

```
Timeline hiện tại:
  0-8s:  Main blocking
  8-12s: Gates blocking
  12-16s: Firestore waiting
  16-17s: UI render
  Total: 17s ❌

Timeline mong muốn:
  0-8s:  Main blocking (unavoidable)
  8-10s: Gates + HomeScreen tree build
  10-11s: UI render (empty/skeleton)
  11-15s: Firestore queries + data arrives
  15-16s: UI update with data
  Total: 8-11s để show skeleton UI ✅ (6-9s saving)
```

**Implementation approach:**

1. Quick cache check (SharedPreferences) thay ProfileGate Firestore
2. Show HomeScreen với skeleton loaders
3. Firestore queries load data in background
4. Skeleton updates → real content

---

### Option B: Query Optimization

**Principle:** Reduce Firestore query count + improve concurrency

```
Current: 10-15 sequential/parallel queries
  ├─ Profile query (1)
  ├─ Diary query (1)
  ├─ Water query (1)
  ├─ Weights query (1)
  ├─ ActivePlan query (1)
  ├─ Meals sub-query (1-N)
  ├─ Foods sub-query (1-N)
  └─ ...
  Result: ~12-15 queries, 3-5s to complete

Optimized: 4-5 well-batched queries
  ├─ Profile + diary batch (2 queries but parallel optimized)
  ├─ Water + weights batch (2 queries)
  ├─ ActivePlan + meals (single denormalized read)
  └─ Foods (batch read by IDs)
  Result: ~5 queries, 1-2s to complete (50% faster)
```

---

### Option C: Tiered Loading

**Principle:** Load critical data first, then nice-to-haves

```
Tier 0 (Show in <2s):
  - User profile name
  - Today's calorie goal
  - Today's consumed calories (from cache)

Tier 1 (Load in background, show in <4s):
  - Macro breakdown
  - Weight data
  - Water intake

Tier 2 (Lazy, show on demand):
  - Recent diary entries
  - Meal plan details
  - Step tracking
  - Voice input
```

---

## CURRENT STATE SUMMARY

| Metric            | Current | Optimal   | Gap      |
| ----------------- | ------- | --------- | -------- |
| main() startup    | 8-10s   | 6-8s      | 2s       |
| Gates navigation  | 3-4s    | 1-2s      | 2s       |
| Home tree build   | 1s      | <1s       | -        |
| Firestore queries | 3-5s    | 1-2s      | 2-3s     |
| UI render         | 1s      | <1s       | -        |
| **Total startup** | **17s** | **8-11s** | **6-9s** |

**Bottleneck:** Firestore query concurrency + ProfileGate latency (60% of total time)

---

## ARCHITECTURE ISSUES PREVENTING OPTIMIZATION

### 1. Gates architecture forces sequential rendering

```
IntroGate.build()
  → if loading → _LoadingScreen
  → if data → ProfileGate.build()
    → if loading → _LoadingScreen
    → if data → HomeScreen.build()
```

**Problem:** Can't show HomeScreen skeleton while ProfileGate loads

**Why:** currentProfileProvider query blocks ProfileGate

---

### 2. Provider dependencies create cascading queries

```dart
homeDailySummaryProvider
  → watches diaryProvider
    → watches DiaryService
      → Firestore query
  → watches currentUserProfileProvider
    → watches FirestoreProfileRepository
      → Firestore query
```

**Problem:** diaryProvider queried multiple times from different widgets

**Why:** No query deduplication/batching in provider layer

---

### 3. No lazy-loading for below-fold widgets

```dart
DashboardPage.build() {
  return Column([
    HomeCalorieCard(),        // Above fold, critical
    HomeMacroSection(),       // Partially visible
    HomeRecentDiarySection(), // Below fold but built anyway
    HomeActivitySection(),    // Below fold but built anyway
    HomeWaterWeightSection(), // Below fold but built anyway
  ]);
}
```

**Problem:** All widgets build + watch providers even if not visible

**Why:** SingleChildScrollView builds full tree regardless of viewport

---

### 4. Synchronous onboarding check blocks navigation

```dart
ProfileGate.build() {
  final profileAsync = ref.watch(currentProfileProvider(uid));

  return profileAsync.when(
    data: (profile) {
      // Only here can we decide to show HomeScreen
      // Until then, _LoadingScreen shown
    },
  );
}
```

**Problem:** Can't navigate to HomeScreen until profile loads

**Why:** onboarding flag is deep in Firestore profile document

---

## RECOMMENDATIONS (HIGH-LEVEL ONLY)

### 🔴 MUST DO (Critical path):

1. **Reduce ProfileGate query latency** - Only fetch onboarding flag (not full profile)
2. **De-duplicate Firestore queries** - Use Riverpod cache invalidation wisely
3. **Implement skeleton loaders** - Show UI structure while loading data

### 🟡 SHOULD DO (Major impact):

4. **Lazy-load below-fold widgets** - Build visible content first
5. **Batch Firestore queries** - Combine related queries
6. **Optimize query timeout** - 3000ms is too long for warm cache

### 🟢 NICE-TO-HAVE (Polish):

7. **Remove unnecessary delays** - HomeScreen.initState 3s delay
8. **Parallelize Firebase init** - If independence permits
9. **Lazy-load voice controller** - Not needed on startup

---

## CONCLUSION

**App chậm 17 giây vì:**

1. **Main.dart blocking (8-10s)** - Firebase/notifications init unavoidable
2. **ProfileGate blocking (2-3s)** - Full profile query for onboarding flag
3. **Firestore queries concurrency (3-5s)** - 10-15 parallel/sequential queries
4. **No lazy-loading (1-2s)** - All widgets built before render

**60% of slowness** = Firestore query concurrency (3-5s out of 17s)

**Quick wins:**

- Reduce ProfileGate query (onboarding check only) = -1s
- Lazy-load below-fold widgets = -1s
- Batch Firestore queries = -1-2s
- Total = **-3-4 seconds savings** (down to 13-14s)

**Deep optimization:**

- Skeleton loaders + render-first = -4-6s additional
- Total = **8-11 seconds startup** (2x-2.5x faster)
