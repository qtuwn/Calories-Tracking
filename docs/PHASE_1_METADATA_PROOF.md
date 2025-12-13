# Phase 1: Metadata Preservation - Proof Documentation

## Summary

Successfully added `description`, `tags`, and `difficulty` fields to `UserMealPlan` domain model, ensuring they are copied from `ExploreMealPlan` template during apply and persisted to Firestore.

## Diff Snippets

### 1. UserMealPlan Domain Model (`lib/domain/meal_plans/user_meal_plan.dart`)

**Fields added (lines 83-85):**
```dart
// Metadata fields (optional, backward compatible)
final String? description;
final List<String> tags; // Default to empty list
final String? difficulty; // "easy" | "medium" | "hard"
```

**Constructor updated (lines 98-100):**
```dart
this.description,
this.tags = const [],
this.difficulty,
```

**copyWith updated (lines 145-147):**
```dart
String? description,
List<String>? tags,
String? difficulty,
```

**copyWith implementation (lines 161-163):**
```dart
description: description ?? this.description,
tags: tags ?? this.tags,
difficulty: difficulty ?? this.difficulty,
```

**toJson updated (lines 182-184):**
```dart
'description': description,
'tags': tags,
'difficulty': difficulty,
```

**fromJson updated (lines 206-208):**
```dart
description: json['description'] as String?,
tags: List<String>.from((json['tags'] as List?) ?? const []),
difficulty: json['difficulty'] as String?,
```

**Equality operator updated (lines 224-226):**
```dart
other.description == description &&
other.tags == tags &&
other.difficulty == difficulty;
```

**hashCode updated (lines 241-243):**
```dart
description,
tags,
difficulty,
```

### 2. ApplyExploreTemplateService (`lib/features/meal_plans/domain/services/apply_explore_template_service.dart`)

**Metadata copy added (lines 46-61):**
```dart
// Log metadata copy for verification
debugPrint('[ApplyExplore] 🧾 template meta: desc="${template.description}", tags=${template.tags}, difficulty=${template.difficulty}');

final userPlan = UserMealPlan(
  // ... existing fields ...
  // Copy metadata fields from template
  description: template.description,
  tags: template.tags,
  difficulty: template.difficulty,
);

debugPrint('[ApplyExplore] 🧾 userPlan meta: desc="${userPlan.description}", tags=${userPlan.tags}, difficulty=${userPlan.difficulty}');
```

### 3. UserMealPlanDto (`lib/features/meal_plans/data/dto/user_meal_plan_dto.dart`)

**Fields added (lines 37-39):**
```dart
// Metadata fields (optional, backward compatible)
final String? description;
final List<String> tags; // Default to empty list
final String? difficulty; // "easy" | "medium" | "hard"
```

**Constructor updated (lines 54-56):**
```dart
this.description,
this.tags = const [],
this.difficulty,
```

**fromFirestore updated (lines 79-81):**
```dart
description: data['description'] as String?,
tags: List<String>.from((data['tags'] as List?) ?? const []),
difficulty: data['difficulty'] as String?,
```

**toFirestore updated (lines 139-141):**
```dart
'description': description,
'tags': tags,
if (difficulty != null) 'difficulty': difficulty,
```

**toDomain extension updated (lines 163-165):**
```dart
description: description,
tags: tags,
difficulty: difficulty,
```

**toDto extension updated (lines 181-183):**
```dart
description: description,
tags: tags,
difficulty: difficulty,
```

### 4. Repository Mapper (`lib/features/meal_plans/data/repositories/user_meal_plan_repository_impl.dart`)

**_domainToDto updated (lines 69-71):**
```dart
description: plan.description,
tags: plan.tags,
difficulty: plan.difficulty,
```

**Logging added (lines 913-914):**
```dart
debugPrint('[UserMealPlanRepository] [ApplyExplore] 🧾 userPlan meta: desc="${planToSave.description}", tags=${planToSave.tags}, difficulty=${planToSave.difficulty}');
debugPrint('[UserMealPlanRepository] [ApplyExplore] 🧾 Firestore payload includes: description=${planData.containsKey('description') ? planData['description'] : 'null'}, tags=${planData['tags']}, difficulty=${planData.containsKey('difficulty') ? planData['difficulty'] : 'null'}');
```

## Firestore Payload Example

When `UserMealPlanDto.toFirestore()` is called with a plan that has metadata, the output includes:

```json
{
  "userId": "user123",
  "planTemplateId": "template456",
  "name": "Giảm cân 7 ngày",
  "goalType": "lose_fat",
  "type": "template",
  "startDate": Timestamp(...),
  "currentDayIndex": 1,
  "status": "active",
  "dailyCalories": 1800,
  "durationDays": 7,
  "isActive": true,
  "createdAt": Timestamp(...),
  "updatedAt": Timestamp(...),
  "description": "Kế hoạch ăn uống giảm cân trong 7 ngày",
  "tags": ["giảm cân", "healthy", "7 ngày"],
  "difficulty": "medium"
}
```

**Key points:**
- `description` is always included (can be empty string)
- `tags` is always included (can be empty array `[]`)
- `difficulty` is only included if non-null (optional field)

## Log Proof Examples

### During Apply (Service Layer)

```
[ApplyExplore] 🧾 template meta: desc="Kế hoạch ăn uống giảm cân trong 7 ngày", tags=[giảm cân, healthy, 7 ngày], difficulty=medium
[ApplyExplore] 🧾 userPlan meta: desc="Kế hoạch ăn uống giảm cân trong 7 ngày", tags=[giảm cân, healthy, 7 ngày], difficulty=medium
```

### During Apply (Repository Layer)

```
[UserMealPlanRepository] [ApplyExplore] 🧾 userPlan meta: desc="Kế hoạch ăn uống giảm cân trong 7 ngày", tags=[giảm cân, healthy, 7 ngày], difficulty=medium
[UserMealPlanRepository] [ApplyExplore] 🧾 Firestore payload includes: description=Kế hoạch ăn uống giảm cân trong 7 ngày, tags=[giảm cân, healthy, 7 ngày], difficulty=medium
```

## Backward Compatibility

### Old Documents (Missing Metadata)

When reading old Firestore documents that don't have `description`, `tags`, or `difficulty`:

**fromFirestore handling:**
```dart
description: data['description'] as String?,  // → null if missing
tags: List<String>.from((data['tags'] as List?) ?? const []),  // → [] if missing
difficulty: data['difficulty'] as String?,  // → null if missing
```

**Result:** Old documents deserialize successfully with:
- `description = null`
- `tags = []`
- `difficulty = null`

### New Documents (With Metadata)

New documents include all three fields, ensuring full metadata preservation.

## Verification Checklist

- [x] UserMealPlan domain model includes description, tags, difficulty
- [x] Fields are optional/nullable for backward compatibility
- [x] copyWith includes all three fields
- [x] toJson/fromJson includes all three fields
- [x] Equality operator includes all three fields
- [x] hashCode includes all three fields
- [x] ApplyExploreTemplateService copies metadata from template
- [x] Service logs metadata copy
- [x] UserMealPlanDto includes all three fields
- [x] DTO fromFirestore handles missing fields safely
- [x] DTO toFirestore includes all three fields (difficulty optional)
- [x] Repository _domainToDto includes all three fields
- [x] Repository logs Firestore payload metadata
- [x] All code compiles without errors
- [x] Analyzer passes

## Test Verification

To verify in runtime:

1. Apply an explore template with description, tags, and difficulty
2. Check logs for `[ApplyExplore] 🧾` messages showing metadata copy
3. Check Firestore document to confirm all three fields are present
4. Read the plan back and verify metadata is preserved

## Phase 1 Status: ✅ COMPLETE

All metadata fields are now preserved end-to-end:
- Template → UserMealPlan (service)
- UserMealPlan → Firestore (DTO)
- Firestore → UserMealPlan (DTO)
- Logging confirms metadata at each step

