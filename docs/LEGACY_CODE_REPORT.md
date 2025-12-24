# Legacy Code Report - Meal Plans Refactoring

**Date:** December 23, 2025  
**Status:** Still actively used (not safe to delete yet)  
**Branch:** feature/home_module_madeby_tuan

---

## Summary

Dự án đang trong quá trình refactor từ cấu trúc **layer-based** (`lib/data/`, `lib/domain/`) sang cấu trúc **feature-based** (`lib/features/*/`). **CẢNH BÁO:** Mặc dù có phiên bản mới ở `lib/features/`, các file cũ ở `lib/data/` **vẫn đang được sử dụng tích cực** trong codebase và **không thể xoá được hiện tại**.

---

## 📋 File Cũ Đang Được Sử Dụng (lib/data/meal_plans/)

### 1. ❌ **explore_meal_plan_dto.dart**
- **Vị trí:** [lib/data/meal_plans/explore_meal_plan_dto.dart](lib/data/meal_plans/explore_meal_plan_dto.dart)
- **Kích thước:** ~250 dòng
- **Chứa:** `ExploreMealPlanDto`, `MealPlanDayDto`, `MealSlotDto`
- **Trạng thái:** ⚠️ **ĐANG DÙNG - CÓ PHIÊN BẢN MỚI**

**Nơi sử dụng:**
- [test/features/meal_plans/explore_meal_slot_serving_size_test.dart](test/features/meal_plans/explore_meal_slot_serving_size_test.dart) - Line 3
- [test/data/meal_plans/explore_meal_plan_dto_metadata_test.dart](test/data/meal_plans/explore_meal_plan_dto_metadata_test.dart) - Line 3

**Phiên bản mới:** Đã tách thành các file riêng ở:
- [lib/features/meal_plans/data/dto/explore_meal_plan_template_dto.dart](lib/features/meal_plans/data/dto/explore_meal_plan_template_dto.dart)
- [lib/features/meal_plans/data/dto/explore_meal_day_template_dto.dart](lib/features/meal_plans/data/dto/explore_meal_day_template_dto.dart)
- [lib/features/meal_plans/data/dto/explore_meal_entry_template_dto.dart](lib/features/meal_plans/data/dto/explore_meal_entry_template_dto.dart)
- [lib/features/meal_plans/data/dto/meal_item_dto.dart](lib/features/meal_plans/data/dto/meal_item_dto.dart)

**Ghi chú:** File cũ chứa cả 3 DTO trong một file, phiên bản mới tách thành từng file riêng.

---

### 2. ❌ **explore_meal_plan_query_exception.dart**
- **Vị trí:** [lib/data/meal_plans/explore_meal_plan_query_exception.dart](lib/data/meal_plans/explore_meal_plan_query_exception.dart)
- **Kích thước:** ~50 dòng
- **Chứa:** Exception class cho query errors
- **Trạng thái:** ⚠️ **ĐANG DÙNG - CÓ THAY THẾ TƯƠNG ĐƯƠNG**

**Nơi sử dụng:**
- [test/features/meal_plans/published_plans_error_ui_test.dart](test/features/meal_plans/published_plans_error_ui_test.dart) - Line 2
- [lib/features/meal_plans/presentation/pages/meal_explore_page.dart](lib/features/meal_plans/presentation/pages/meal_explore_page.dart) - Line 7

**Phiên bản mới:** Không có phiên bản mới rõ ràng, nhưng exception handling được xử lý trong:
- [lib/features/meal_plans/data/repositories/user_meal_plan_repository_impl.dart](lib/features/meal_plans/data/repositories/user_meal_plan_repository_impl.dart) - `MealPlanApplyException`

**Ghi chú:** Có thể cần tạo file exception mới ở `lib/features/meal_plans/domain/` hoặc `lib/features/meal_plans/data/`

---

### 3. ❌ **firestore_explore_meal_plan_repository.dart**
- **Vị trí:** [lib/data/meal_plans/firestore_explore_meal_plan_repository.dart](lib/data/meal_plans/firestore_explore_meal_plan_repository.dart)
- **Kích thước:** ~541 dòng
- **Chứa:** `FirestoreExploreMealPlanRepository` (implements ExploreMealPlanRepository)
- **Trạng thái:** ⚠️ **ĐANG DÙNG - WRAPPER LEGACY**

**Nơi sử dụng:**
- [lib/shared/state/explore_meal_plan_providers.dart](lib/shared/state/explore_meal_plan_providers.dart) - Line 8 (được inject vào provider)
- [lib/features/meal_plans/data/repositories/user_meal_plan_repository_impl.dart](lib/features/meal_plans/data/repositories/user_meal_plan_repository_impl.dart) - Line 9

**Phiên bản mới:** Chưa có phiên bản mới hoàn toàn, vẫn đang được sử dụng để quản lý explore meal plans

**Ghi chú:** Đây là repository chính cho feature explore meal plans. Nên refactor vào `lib/features/meal_plans/data/repositories/` nhưng hiện tại vẫn cần giữ lại.

---

### 4. ❌ **firestore_user_meal_plan_repository.dart**
- **Vị trị:** [lib/data/meal_plans/firestore_user_meal_plan_repository.dart](lib/data/meal_plans/firestore_user_meal_plan_repository.dart)
- **Kích thước:** ~153 dòng
- **Chứa:** `FirestoreUserMealPlanRepository` (implements UserMealPlanRepository) - **WRAPPER ADAPTER**
- **Trạng thái:** ⚠️ **ĐANG DÙNG - WRAPPER LEGACY**

**Nơi sử dụng:**
- [lib/shared/state/user_meal_plan_providers.dart](lib/shared/state/user_meal_plan_providers.dart) - Line 8 (được inject vào provider)

**Phiên bản mới:** 
- [lib/features/meal_plans/data/repositories/user_meal_plan_repository_impl.dart](lib/features/meal_plans/data/repositories/user_meal_plan_repository_impl.dart) - **PHIÊN BẢN MỚI THẬT SỰ**

**Ghi chú:** File này chỉ là wrapper adapter mà wrap lại `UserMealPlanRepositoryImpl` từ features. Có thể xoá nếu cập nhật providers trỏ trực tiếp tới `UserMealPlanRepositoryImpl`.

---

### 5. ❌ **shared_prefs_user_meal_plan_cache.dart**
- **Vị trí:** [lib/data/meal_plans/shared_prefs_user_meal_plan_cache.dart](lib/data/meal_plans/shared_prefs_user_meal_plan_cache.dart)
- **Kích thước:** ~phần nào (chưa kiểm tra)
- **Chứa:** `SharedPrefsUserMealPlanCache` (implements UserMealPlanCache)
- **Trạng thái:** ⚠️ **ĐANG DÙNG - VẪN CẦN GIỮ**

**Nơi sử dụng:**
- [lib/shared/state/user_meal_plan_providers.dart](lib/shared/state/user_meal_plan_providers.dart) - Line 9

**Phiên bản mới:** Chưa có

**Ghi chú:** Cache implementation hiện tại vẫn được dùng trong provider.

---

### 6. ❌ **shared_prefs_explore_meal_plan_cache.dart**
- **Vị trí:** [lib/data/meal_plans/shared_prefs_explore_meal_plan_cache.dart](lib/data/meal_plans/shared_prefs_explore_meal_plan_cache.dart)
- **Chứa:** `SharedPrefsExploreMealPlanCache` (implements ExploreMealPlanCache)
- **Trạng thái:** ⚠️ **ĐANG DÙNG - VẪN CẦN GIỮ**

**Nơi sử dụng:**
- [lib/shared/state/explore_meal_plan_providers.dart](lib/shared/state/explore_meal_plan_providers.dart) - Line 9

**Phiên bản mới:** Chưa có

**Ghi chú:** Cache implementation hiện tại vẫn được dùng trong provider.

---

## 📊 Tổng Kết Imports từ lib/data/meal_plans/

| File | Dùng ở | Có phiên bản mới? | An toàn xoá? |
|------|--------|-------------------|-------------|
| explore_meal_plan_dto.dart | 2 test files | ✅ Có (tách ra từng file) | ❌ Không |
| explore_meal_plan_query_exception.dart | 2 files | ❌ Không rõ | ❌ Không |
| firestore_explore_meal_plan_repository.dart | 2 files | ❌ Chưa | ❌ Không |
| firestore_user_meal_plan_repository.dart | 1 provider | ✅ Có (UserMealPlanRepositoryImpl) | ⚠️ Có thể |
| shared_prefs_user_meal_plan_cache.dart | 1 provider | ❌ Chưa | ❌ Không |
| shared_prefs_explore_meal_plan_cache.dart | 1 provider | ❌ Chưa | ❌ Không |

---

## 🚀 Các bước để hoàn thành refactoring

### Phase 1: Di chuyển repositories
1. Move `firestore_explore_meal_plan_repository.dart` → `lib/features/meal_plans/data/repositories/`
2. Move cache files → `lib/features/meal_plans/data/repositories/` hoặc `lib/features/meal_plans/data/cache/`
3. Update imports trong `lib/shared/state/` trỏ tới vị trí mới

### Phase 2: Consolidate DTOs
1. Quyết định: giữ file riêng hay gộp lại?
2. Move toàn bộ DTOs → `lib/features/meal_plans/data/dto/`
3. Update imports trong test files

### Phase 3: Exception handling
1. Tạo exception file mới ở `lib/features/meal_plans/domain/exceptions/`
2. Move `explore_meal_plan_query_exception.dart` hoặc tạo thay thế
3. Update imports

### Phase 4: Cleanup
1. Xoá `lib/data/meal_plans/` khi đã migrate hết
2. Xoá `lib/domain/meal_plans/` khi đã migrate hết (nếu chỉ dành cho meal plans)

---

## ⚠️ Cảnh báo quan trọng

1. **Không xoá các file này ngay lập tức** - vẫn đang được build app sử dụng
2. **Cần cập nhật lib/shared/state/ trước** - đây là nơi DI injection xảy ra
3. **Test files cũng cần cập nhật** - đảm bảo test vẫn chạy được
4. **Các dependencies của firestore_explore_meal_plan_repository.dart phức tạp** - cần careful refactoring

---

## 📂 Cấu trúc Đã Tồn Tại ở lib/features/meal_plans/

```
lib/features/meal_plans/
├── data/
│   ├── dto/
│   │   ├── explore_meal_plan_template_dto.dart ✅
│   │   ├── explore_meal_day_template_dto.dart ✅
│   │   ├── explore_meal_entry_template_dto.dart ✅
│   │   ├── meal_item_dto.dart ✅
│   │   ├── user_meal_plan_dto.dart ✅
│   │   ├── user_meal_day_dto.dart ✅
│   │   ├── user_meal_entry_dto.dart ✅
│   │   └── [THIẾU: explore_meal_plan_query_exception]
│   └── repositories/
│       └── user_meal_plan_repository_impl.dart ✅
├── domain/
│   ├── models/
│   │   ├── explore/
│   │   │   ├── explore_meal_day_template.dart
│   │   │   ├── explore_meal_entry_template.dart
│   │   │   └── explore_meal_plan_template.dart
│   │   ├── user/
│   │   │   ├── user_meal_plan.dart
│   │   │   ├── user_meal_day.dart
│   │   │   └── user_meal_entry.dart
│   │   └── shared/
│   │       ├── meal_type.dart
│   │       ├── macros_summary.dart
│   │       └── goal_type.dart
│   ├── repositories/
│   │   ├── explore_meal_plan_repository.dart
│   │   └── user_meal_plan_repository.dart
│   └── services/
│       ├── apply_explore_template_service.dart
│       ├── apply_custom_meal_plan_service.dart
│       ├── meal_plan_validation_service.dart
│       ├── macros_summary_service.dart
│       └── kcal_calculator.dart
└── presentation/
    ├── pages/
    │   ├── meal_custom_root.dart
    │   ├── meal_custom_editor_page.dart
    │   ├── meal_explore_page.dart
    │   ├── meal_detail_page.dart
    │   └── ...
    └── ...
```

---

## 🎯 Tiếp theo

1. **Quyết định:** Xoá hay cập nhật providers để sử dụng phiên bản mới?
2. **Nếu cập nhật:** Cập nhật [lib/shared/state/user_meal_plan_providers.dart](lib/shared/state/user_meal_plan_providers.dart) và [lib/shared/state/explore_meal_plan_providers.dart](lib/shared/state/explore_meal_plan_providers.dart)
3. **Nếu xoá:** Cần di chuyển toàn bộ DTOs và exceptions trước
4. **Test:** Chạy `flutter build apk` sau mỗi thay đổi để đảm bảo không break

