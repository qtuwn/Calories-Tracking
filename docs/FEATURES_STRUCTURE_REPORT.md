# 📊 Báo Cáo Cấu Trúc Chức Năng - Calories App

**Ngày tạo:** 7 Tháng 1, 2026  
**Dự án:** Calories Tracking Application  
**Kiến trúc:** Clean Architecture + Domain-Driven Design

---

## 📋 Tóm Tắt Chung

| Tiêu Chỉ                         | Giá Trị                      |
| -------------------------------- | ---------------------------- |
| **Tổng số chức năng (Features)** | **14**                       |
| **Chức năng chính (Core)**       | 7                            |
| **Chức năng quản trị (Admin)**   | 3                            |
| **Chức năng hỗ trợ**             | 4                            |
| **Lớp kiến trúc**                | Domain / Data / Presentation |

---

## 🎯 Danh Sách Chi Tiết 14 Chức Năng

### **NHÓM 1: CHỨC NĂNG CHÍNH (7)**

#### 1️⃣ **Home (Dashboard)**

- **Mô tả:** Màn hình chính - tổng quan dinh dưỡng hôm nay
- **Vị trí:** `lib/features/home/`
- **Cấu trúc:**
  ```
  home/
  ├── domain/           # Domain services & entities
  └── presentation/     # UI screens & widgets
  ```
- **Chức năng:**
  - Hiển thị tổng calories tiêu thụ
  - Theo dõi nước & cân nặng
  - Hiển thị thông tin hôm nay
- **Screenshots:** `dashboard.png`

---

#### 2️⃣ **Diary (Nhật Ký)**

- **Mô tả:** Ghi lại các bữa ăn và tập luyện
- **Vị trí:** `lib/features/diary/`
- **Cấu trúc:**
  ```
  diary/
  └── domain/           # Domain services (dairy_service.dart)
  ```
- **Chức năng:**
  - Tạo & chỉnh sửa mục nhập diary
  - Phân loại bữa ăn tự động
  - Lưu trữ trong Firestore
- **Screenshots:** `diary.png`

---

#### 3️⃣ **Foods (Quản Lý Thực Phẩm)**

- **Mô tả:** Quản lý kho thực phẩm, tìm kiếm & thêm thực phẩm
- **Vị trị:** `lib/features/foods/`
- **Cấu trúc:**
  ```
  foods/
  ├── data/             # Food DTOs & Firestore repositories
  │   └── firestore_food_repository.dart
  ├── ui/               # UI screens (food_admin_page.dart)
  └── [no domain layer] # Business logic in UI
  ```
- **Chức năng:**
  - Tìm kiếm thực phẩm từ CSDL
  - Thêm thực phẩm tùy chỉnh
  - Quản lý thành phần dinh dưỡng
- **Screenshots:** N/A

---

#### 4️⃣ **Meal Plans (Kế Hoạch Bữa Ăn)**

- **Mô tả:** Tạo & theo dõi kế hoạch bữa ăn
- **Vị trí:** `lib/features/meal_plans/`
- **Cấu trúc:**
  ```
  meal_plans/
  ├── data/             # Meal plan DTOs & repositories
  ├── domain/           # Meal plan domain models
  ├── presentation/     # UI & controllers
  └── state/            # Riverpod providers
  ```
- **Chức năng:**
  - Khám phá meal plans có sẵn
  - Tạo meal plans tùy chỉnh
  - Theo dõi tiến độ
- **Screenshots:** `meal-plans.png`

---

#### 5️⃣ **Voice Input (Nhập Giọng Nói)**

- **Mô tả:** Thêm thực phẩm bằng giọng nói qua Google Gemini AI
- **Vị trí:** `lib/features/voice_input/`
- **Cấu trúc:**
  ```
  voice_input/
  ├── application/      # Voice service layer
  ├── data/             # Gemini API integration
  ├── domain/           # Voice domain entities
  └── presentation/     # Voice UI & controllers
  ```
- **Chức năng:**
  - Ghi âm & xử lý giọng nói
  - Kết nối API Gemini
  - Nhận dạng thực phẩm tự động
- **Screenshots:** `voice-input.png`

---

#### 6️⃣ **Exercise (Tập Luyện)**

- **Mô tả:** Theo dõi hoạt động thể chất & tập luyện
- **Vị trí:** `lib/features/exercise/`
- **Cấu trúc:**
  ```
  exercise/
  ├── data/             # Exercise DTOs & repositories
  ├── domain/           # Exercise domain models
  ├── ui/               # UI screens
  │   ├── exercise_list_screen.dart
  │   ├── exercise_detail_screen.dart
  │   ├── exercise_admin_list_screen.dart
  │   └── exercise_admin_edit_screen.dart
  └── widgets/          # Reusable widgets
  ```
- **Chức năng:**
  - Ghi lại các bài tập luyện
  - Tính toán calories đốt cháy
  - Quản lý danh sách tập luyện
- **Screenshots:** N/A

---

#### 7️⃣ **Activity (Hoạt Động)**

- **Mô tả:** Theo dõi hoạt động hàng ngày (steps, movement)
- **Vị trí:** `lib/features/activity/`
- **Cấu trúc:**
  ```
  activity/
  └── data/             # Activity DTOs & repositories
  ```
- **Chức năng:**
  - Tích hợp với Health Connect
  - Đồng bộ dữ liệu bước chân
  - Tính toán hoạt động hàng ngày
- **Screenshots:** N/A

---

### **NHÓM 2: CHỨC NĂNG QUẢN TRỊ (3)**

#### 8️⃣ **Admin Tools (Công Cụ Quản Trị)**

- **Mô tả:** Công cụ quản lý dữ liệu & migration
- **Vị trí:** `lib/features/admin_tools/`
- **Cấu trúc:**
  ```
  admin_tools/
  ├── data/             # Admin data repositories
  ├── domain/           # Admin domain logic
  ├── presentation/     # Admin UI pages
  │   └── admin_migrations_page.dart
  └── state/            # Admin Riverpod providers
  ```
- **Chức năng:**
  - Migration dữ liệu Firestore
  - Quản lý dữ liệu hệ thống
  - Công cụ debugging & testing
- **Screenshots:** N/A

---

#### 9️⃣ **Admin Activities (Quản Lý Hoạt Động)**

- **Mô tả:** Quản trị danh sách hoạt động & tập luyện
- **Vị trí:** `lib/features/admin_activities/`
- **Cấu trúc:**
  ```
  admin_activities/
  └── presentation/     # Admin UI for activities
  ```
- **Chức năng:**
  - Tạo/chỉnh sửa danh sách hoạt động
  - Quản lý thông tin tập luyện
  - CRUD operations
- **Screenshots:** N/A

---

#### 🔟 **Admin Explore Meal Plans (Quản Lý Meal Plans)**

- **Mô tả:** Quản trị meal plans được khám phá
- **Vị trí:** `lib/features/admin_explore_meal_plans/`
- **Cấu trúc:**
  ```
  admin_explore_meal_plans/
  └── presentation/     # Admin UI for meal plans
  ```
- **Chức năng:**
  - Tạo meal plans mẫu
  - Quản lý danh sách khám phá
  - Cập nhật thông tin dinh dưỡng
- **Screenshots:** N/A

---

### **NHÓM 3: CHỨC NĂNG HỖ TRỢ (4)**

#### 1️⃣1️⃣ **Auth (Xác Thực)**

- **Mô tả:** Đăng nhập/đăng ký & quản lý tài khoản
- **Vị trí:** `lib/features/auth/`
- **Cấu trúc:**
  ```
  auth/
  ├── data/             # Auth DTOs & repositories
  ├── presentation/     # Auth UI pages
  │   ├── pages/
  │   │   └── auth_page.dart
  │   ├── screens/
  │   └── theme/
  ```
- **Chức năng:**
  - Đăng nhập với email/mật khẩu
  - Đăng nhập qua Google
  - Quản lý phiên
- **Screenshots:** N/A

---

#### 1️⃣2️⃣ **Onboarding (Hướng Dẫn Sử Dụng)**

- **Mô tả:** Quy trình onboarding người dùng mới
- **Vị trí:** `lib/features/onboarding/`
- **Cấu trúc:**
  ```
  onboarding/
  ├── data/             # Onboarding data repositories
  ├── domain/           # Onboarding logic
  ├── presentation/     # Onboarding UI screens
  └── onboarding.dart   # Main onboarding file
  ```
- **Chức năng:**
  - Hướng dẫn cài đặt ban đầu
  - Nhập thông tin cá nhân
  - Thiết lập mục tiêu
- **Screenshots:** N/A

---

#### 1️⃣3️⃣ **Settings (Cài Đặt)**

- **Mô tả:** Quản lý tùy chọn cài đặt ứng dụng
- **Vị trí:** `lib/features/settings/`
- **Cấu trúc:**
  ```
  settings/
  └── data/             # Settings data repositories
  ```
- **Chức năng:**
  - Cài đặt hồ sơ người dùng
  - Tùy chỉnh ứng dụng
  - Quản lý thông báo
- **Screenshots:** N/A

---

#### 1️⃣4️⃣ **Admin (Trang Quản Trị Chung)**

- **Mô tả:** Trang quản trị chung hệ thống
- **Vị trí:** `lib/features/admin/`
- **Cấu trúc:**
  ```
  admin/
  ├── data/             # Admin data repositories
  ├── domain/           # Admin domain logic
  └── ui/               # Admin UI pages
  ```
- **Chức năng:**
  - Dashboard quản trị
  - Quản lý người dùng
  - Thống kê hệ thống
- **Screenshots:** N/A

---

## 🏗️ Cấu Trúc Kiến Trúc (Architecture Layers)

### **Domain Layer (Pure Dart)**

```
lib/domain/
├── activities/        # Activity entities & repository interfaces
├── diary/             # Diary entities & services
├── foods/             # Food entities & repository interfaces
├── meal_plans/        # Meal plan entities
├── profile/           # Profile entities
└── images/            # Image handling
```

**Điặc điểm:**

- ✅ Pure Dart - không phụ thuộc Flutter/Firebase
- ✅ Business logic độc lập
- ✅ Repository interfaces (contracts)
- ✅ Domain services (tính toán, xử lý logic)

---

### **Data Layer (Infrastructure)**

```
lib/data/
├── activities/        # Activity DTOs & Firestore repositories
├── diary/             # Diary DTOs, Firestore repos, cache
├── foods/             # Food DTOs, Firestore repos, cache
├── meal_plans/        # Meal plan DTOs & repositories
├── profile/           # Profile DTOs & repositories
├── firebase/          # Firebase services (Analytics, Auth)
├── cloudinary/        # Image upload services
└── images/            # Image storage repositories
```

**Đặc điểm:**

- 🔥 Firestore repositories - CRUD operations
- 💾 SharedPreferences cache - offline support
- 🖼️ Cloudinary integration - image storage
- 📊 Firebase Analytics

---

### **Presentation Layer (UI)**

```
lib/features/*/presentation/
├── pages/             # Full-screen pages
├── screens/           # Reusable screens
├── widgets/           # UI widgets
├── controllers/       # Business logic controllers
└── theme/             # Feature-specific theming
```

**Đặc điểm:**

- 🎨 Flutter widgets
- 📱 Riverpod providers (state management)
- 🎯 Controllers (UI logic)
- 🌍 Localization support

---

## 🗂️ Phân Tích Chi Tiết Cấu Trúc Các Features

| Feature              | Domain | Data | Presentation | Trạng Thái             |
| -------------------- | ------ | ---- | ------------ | ---------------------- |
| **Home**             | ✅     | ❌   | ✅           | Partial (Domain-light) |
| **Diary**            | ✅     | ❌   | ❌           | Domain only            |
| **Foods**            | ❌     | ✅   | ✅           | Legacy (No Domain)     |
| **Meal Plans**       | ✅     | ✅   | ✅           | **✨ Complete**        |
| **Voice Input**      | ✅     | ✅   | ✅           | **✨ Complete**        |
| **Exercise**         | ✅     | ✅   | ✅           | **✨ Complete**        |
| **Activity**         | ✅     | ✅   | ❌           | Partial                |
| **Auth**             | ❌     | ✅   | ✅           | Legacy                 |
| **Onboarding**       | ✅     | ✅   | ✅           | **✨ Complete**        |
| **Settings**         | ❌     | ✅   | ❌           | Legacy                 |
| **Admin**            | ✅     | ✅   | ✅           | **✨ Complete**        |
| **Admin Tools**      | ✅     | ✅   | ✅           | **✨ Complete**        |
| **Admin Activities** | ❌     | ❌   | ✅           | Minimal                |
| **Admin Meal Plans** | ❌     | ❌   | ✅           | Minimal                |

---

## 📈 Thống Kê Kiến Trúc

### **Tuân Thủ Clean Architecture**

```
✨ Hoàn toàn tuân thủ (Domain + Data + Presentation)
├── Voice Input
├── Meal Plans
├── Exercise
├── Onboarding
├── Admin Tools
└── Admin

⚠️ Một phần tuân thủ
├── Home (Domain + Presentation)
├── Diary (Domain only)
└── Activity (Domain + Data)

❌ Không tuân thủ (Legacy code)
├── Foods (Data + Presentation)
├── Auth (Data + Presentation)
├── Settings (Data only)
├── Admin (phần UI minimal)
├── Admin Activities (Presentation only)
└── Admin Meal Plans (Presentation only)
```

---

## 🔄 Dependencies Giữa Features

```
┌─────────────────────────────────────────────────┐
│            Presentation Layer                    │
│  (Home, Diary, Exercise, Meal Plans, Voice...) │
└──────────────────┬──────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────┐
│        Domain Layer (Business Logic)            │
│  • Diary Services   • Meal Plan Services        │
│  • Exercise Logic   • Voice Processing          │
└──────────────────┬──────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────┐
│        Data Layer (Infrastructure)              │
│  • Firestore Repositories                       │
│  • SharedPreferences Cache                      │
│  • Cloudinary Storage  • Firebase Analytics     │
└─────────────────────────────────────────────────┘
```

---

## 📊 Lưu Trữ Dữ Liệu (Data Storage)

| Dữ Liệu            | Nơi Lưu Trữ    | Cache       | Offline |
| ------------------ | -------------- | ----------- | ------- |
| **Meals & Foods**  | Firestore      | SharedPrefs | ✅      |
| **Exercises**      | Firestore      | SharedPrefs | ✅      |
| **Meal Plans**     | Firestore      | SharedPrefs | ✅      |
| **User Profile**   | Firestore      | SharedPrefs | ✅      |
| **Activity/Steps** | Health Connect | Device      | ✅      |
| **Images**         | Cloudinary     | Cache       | ❌      |

---

## 🎯 Tóm Tắt Chức Năng

### **7 Chức Năng Chính**

1. 🏠 **Home** - Dashboard tổng quan
2. 📔 **Diary** - Ghi lại bữa ăn & tập luyện
3. 🍎 **Foods** - Quản lý thực phẩm
4. 📋 **Meal Plans** - Kế hoạch bữa ăn
5. 🎤 **Voice Input** - AI voice recognition
6. 💪 **Exercise** - Theo dõi tập luyện
7. 📊 **Activity** - Theo dõi hoạt động (Health Connect)

### **3 Chức Năng Quản Trị**

8. 🔧 **Admin Tools** - Migration & công cụ
9. ⚙️ **Admin Activities** - Quản lý tập luyện
10. 📋 **Admin Meal Plans** - Quản lý kế hoạch

### **4 Chức Năng Hỗ Trợ**

11. 🔐 **Auth** - Xác thực người dùng
12. 🚀 **Onboarding** - Hướng dẫn sử dụng
13. ⚙️ **Settings** - Cài đặt ứng dụng
14. 👨‍💼 **Admin** - Dashboard quản trị

---

## 🚀 Ghi Chú & Khuyến Nghị

### **Điểm Mạnh**

- ✅ 6 features tuân thủ hoàn toàn Clean Architecture
- ✅ Cache-first pattern cho offline support
- ✅ Firestore real-time synchronization
- ✅ Riverpod state management

### **Cần Cải Thiện (Legacy Code)**

- ⚠️ Foods feature cần refactor (thêm Domain layer)
- ⚠️ Auth feature cần tách business logic
- ⚠️ Settings cần hoàn thiện implementation
- ⚠️ Admin sections cần consolidation

### **Kiến Nghị Tiếp Theo**

1. **Refactor Foods** - Tạo FoodService & domain models
2. **Extract Auth Logic** - Tạo AuthService trong domain
3. **Complete Settings** - Thêm presentation layer
4. **Consolidate Admin** - Gộp admin features thành 1
5. **Add More Tests** - Feature-based test structure

---

## 📁 Tham Khảo Đường Dẫn Tệp

```
lib/
├── main.dart                      # Entry point
├── app/                           # App configuration
├── core/                          # Core services
├── domain/                        # 📊 Domain layer
├── data/                          # 🗄️ Data layer
├── features/                      # 🎯 Presentation layer
│   ├── home/
│   ├── diary/
│   ├── foods/
│   ├── meal_plans/
│   ├── voice_input/
│   ├── exercise/
│   ├── activity/
│   ├── auth/
│   ├── onboarding/
│   ├── settings/
│   ├── admin/
│   ├── admin_tools/
│   ├── admin_activities/
│   └── admin_explore_meal_plans/
└── shared/                        # Shared utilities

docs/screenshots/
├── dashboard.png                  # Home feature
├── diary.png                      # Diary feature
├── meal-plans.png                 # Meal Plans
├── voice-input.png                # Voice Input
└── statistics.png                 # Stats/Analytics
```

---

**Báo cáo được tạo tự động: 7 Tháng 1, 2026**  
**Phiên bản ứng dụng: Flutter 3.38.5 | Dart 3.5.0**
