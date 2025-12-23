# System Architecture – Calories App

## Architectural Overview

Calories App is built using Clean Architecture principles combined with Domain-Driven Design (DDD) to achieve a scalable, testable, and maintainable codebase. The architecture enforces strict separation of concerns through layered boundaries, ensuring that business logic remains independent of UI frameworks, databases, and external services.

The primary architectural goals are:

- **Testability**: Business logic can be tested in isolation without Flutter or Firebase dependencies
- **Maintainability**: Clear boundaries make the codebase easy to understand and modify
- **Scalability**: Modular structure supports growth and feature additions
- **Flexibility**: Infrastructure can be swapped without affecting business logic

## Architecture Diagram

The system follows a layered architecture with unidirectional dependency flow:

```
┌─────────────────────────────────────────────────────┐
│              Presentation Layer                      │
│         (Flutter UI, Riverpod Providers)             │
│                                                       │
│  • Widgets and Screens                               │
│  • State Management (Riverpod)                       │
│  • UI Controllers                                     │
│         │                                             │
│         └─── Depends on ───┐                         │
└────────────────────────────┼─────────────────────────┘
                              │
┌─────────────────────────────▼─────────────────────────┐
│            Application Layer                          │
│      (Use Cases, Orchestration, Services)            │
│                                                       │
│  • Business Workflows                                 │
│  • Use Case Implementation                           │
│  • Service Coordination                               │
│         │                                             │
│         └─── Depends on ───┐                         │
└────────────────────────────┼─────────────────────────┘
                              │
┌─────────────────────────────▼─────────────────────────┐
│              Domain Layer                            │
│        (Pure Dart - No Dependencies)                 │
│                                                       │
│  • Entities (Business Models)                        │
│  • Repository Interfaces (Contracts)                  │
│  • Domain Services (Business Logic)                   │
│                                                       │
│  ←─── Implemented by ────┐                           │
└──────────────────────────┼───────────────────────────┘
                           │
┌──────────────────────────▼───────────────────────────┐
│              Data Layer                               │
│    (Firestore, DTOs, Cache, External APIs)          │
│                                                       │
│  • Repository Implementations                         │
│  • Data Transfer Objects (DTOs)                      │
│  • Firestore Integration                             │
│  • Local Cache (SharedPreferences)                   │
└───────────────────────────────────────────────────────┘
```

### Dependency Direction

Dependencies flow **inward** toward the Domain layer:

- Presentation depends on Application
- Application depends on Domain
- Data implements Domain interfaces
- Domain has **zero dependencies** on external frameworks

This ensures that business logic remains pure and testable, independent of infrastructure choices.

## Layer Responsibilities

### Domain Layer

**Location**: `lib/domain/`

The Domain layer contains the core business logic and is completely isolated from external dependencies.

**Components**:

- **Entities**: Pure Dart classes representing business concepts (User, Meal, DiaryEntry, etc.)
- **Repository Interfaces**: Abstract contracts defining data access operations
- **Domain Services**: Business logic that coordinates between multiple repositories
- **Value Objects**: Immutable objects representing domain concepts

**Key Characteristics**:

- Pure Dart code with no Flutter, Firebase, or other framework dependencies
- Business rules and validation logic
- Completely testable without mocking complex infrastructure
- Defines the "what" of the system, not the "how"

**Example Structure**:
```
lib/domain/
├── diary/
│   ├── diary_entry.dart          # Entity
│   ├── diary_repository.dart      # Interface
│   └── diary_service.dart         # Domain service
├── meal_plans/
│   ├── meal_plan.dart            # Entity
│   └── meal_plan_repository.dart # Interface
└── profile/
    └── user_profile.dart          # Entity
```

### Application Layer

**Location**: `lib/features/*/application/` or `lib/features/*/data/services/`

The Application layer orchestrates business workflows and coordinates between the Domain and Data layers.

**Components**:

- **Use Cases**: Specific business operations (e.g., "Create Meal Plan", "Log Food Entry")
- **Application Services**: Services that coordinate multiple domain operations
- **Workflow Orchestration**: Complex business processes that span multiple domain entities

**Key Characteristics**:

- Implements use cases defined by business requirements
- Coordinates between repositories and domain services
- Handles application-specific logic (not core business rules)
- May depend on Domain interfaces and Data implementations

### Data Layer

**Location**: `lib/data/`

The Data layer handles all external data persistence and retrieval operations.

**Components**:

- **Repository Implementations**: Concrete implementations of Domain repository interfaces
- **DTOs (Data Transfer Objects)**: Data structures for Firestore schema mapping
- **Firestore Repositories**: Cloud Firestore integration
- **Cache Implementations**: Local storage using SharedPreferences
- **API Clients**: External service integrations (e.g., Gemini API)

**Key Characteristics**:

- Implements Domain repository interfaces
- Handles data transformation between Domain entities and DTOs
- Manages caching strategies
- Handles network communication and error handling

**Example Structure**:
```
lib/data/
├── diary/
│   ├── diary_entry_dto.dart           # DTO
│   └── firestore_diary_repository.dart # Implementation
└── meal_plans/
    ├── meal_plan_dto.dart
    └── firestore_meal_plan_repository.dart
```

### Presentation Layer

**Location**: `lib/features/*/presentation/`

The Presentation layer handles all user interface and user interaction concerns.

**Components**:

- **Screens**: Full-page UI components
- **Widgets**: Reusable UI components
- **Riverpod Providers**: State management and dependency injection
- **Controllers**: UI logic that coordinates between widgets and application services

**Key Characteristics**:

- Completely decoupled from business logic
- Uses Riverpod for state management and dependency injection
- Handles user input and displays data
- Delegates business operations to Application layer

**Example Structure**:
```
lib/features/diary/presentation/
├── screens/
│   └── diary_screen.dart
├── widgets/
│   └── diary_entry_card.dart
└── controllers/
    └── diary_controller.dart
```

## Module-Based Feature Architecture

The codebase is organized by **feature modules** rather than purely by technical layers. Each feature module contains its own presentation, application, and data components, promoting high cohesion and loose coupling.

**Feature Module Structure**:
```
lib/features/
├── diary/                    # Diary feature module
│   ├── presentation/        # UI for diary
│   ├── application/         # Diary use cases
│   └── data/                # Diary data access
├── meal_plans/              # Meal plans feature module
│   ├── presentation/
│   ├── application/
│   └── data/
└── voice_input/             # Voice input feature module
    ├── presentation/
    ├── application/
    ├── data/
    └── domain/              # Feature-specific domain
```

**Benefits of Module Organization**:

- Features are self-contained and easier to locate
- Teams can work on different features with minimal conflicts
- Features can be developed, tested, and maintained independently
- Clear boundaries prevent feature coupling

## State Management Strategy

The application uses **Riverpod** for state management and dependency injection.

### Why Riverpod?

- **Type Safety**: Compile-time safety for providers and dependencies
- **Testability**: Easy to mock and test providers
- **Performance**: Efficient rebuilds and caching
- **Dependency Injection**: Clean dependency management without global state

### State Categories

**UI State**: Managed by Riverpod providers in the Presentation layer
- Form inputs, loading indicators, error messages
- Transient state that doesn't need persistence

**Domain State**: Managed through Domain services and repositories
- Business entities, user data, application state
- Persisted in Firestore and local cache

**Separation**: UI state is separate from domain state, allowing UI to be rebuilt without affecting business logic.

## Cache-First & Offline Strategy

The application implements a **hybrid cache-first architecture** that provides instant loading and full offline functionality.

### Cache-First Pattern

1. **Immediate Response**: Data is loaded from local cache instantly when requested
2. **Background Sync**: Firestore is queried asynchronously in the background
3. **Cache Update**: Fresh data from Firestore updates the cache
4. **UI Update**: UI reacts to stream updates, showing cached data first, then fresh data

### Offline Support

- **Full Functionality**: All features work without network connectivity
- **Local Persistence**: Data is stored in SharedPreferences cache
- **Automatic Sync**: When connectivity is restored, data syncs automatically
- **Conflict Resolution**: Last-write-wins strategy for data conflicts

### Implementation Pattern

Services implement a consistent pattern:

```dart
// 1. Emit cached data immediately (synchronous)
final cachedData = await cache.getData();

// 2. Fetch from Firestore in background (asynchronous)
firestoreRepository.getData().then((freshData) {
  // 3. Update cache
  cache.saveData(freshData);
  // 4. Emit fresh data via stream
  streamController.add(freshData);
});
```

This ensures users always see data immediately, with updates arriving seamlessly in the background.

## Dependency Rules

### Allowed Dependencies

- **Presentation → Application**: Presentation can call Application services
- **Presentation → Domain**: Presentation can use Domain entities (read-only)
- **Application → Domain**: Application can use Domain entities and interfaces
- **Data → Domain**: Data implements Domain interfaces
- **All Layers → Core**: All layers can use Core utilities

### Forbidden Dependencies

- **Domain → Any External Framework**: Domain must remain pure Dart
- **Domain → Flutter**: No Flutter dependencies in Domain
- **Domain → Firebase**: No Firebase dependencies in Domain
- **Domain → Data**: Domain cannot depend on Data implementations
- **Presentation → Data**: Presentation cannot directly access Data layer
- **Application → Presentation**: Application cannot depend on UI

### Rules Summary

1. **Dependency Inversion**: High-level modules (Domain) do not depend on low-level modules (Data)
2. **Interface Segregation**: Domain defines interfaces; Data implements them
3. **Single Responsibility**: Each layer has one clear responsibility
4. **Pure Domain**: Domain layer has zero external dependencies
5. **Unidirectional Flow**: Dependencies flow inward, never outward from Domain

## Architecture Benefits

### Testability

- **Pure Domain Logic**: Business logic can be unit tested without Flutter or Firebase
- **Mockable Interfaces**: Repository interfaces enable easy mocking for tests
- **Isolated Testing**: Each layer can be tested independently
- **Fast Tests**: Domain tests run quickly without infrastructure setup

### Maintainability

- **Clear Boundaries**: Well-defined layers make code easy to locate and modify
- **Single Responsibility**: Each component has one clear purpose
- **Reduced Coupling**: Changes in one layer don't cascade to others
- **Self-Documenting**: Architecture structure documents the system design

### Scalability

- **Modular Growth**: New features can be added as independent modules
- **Team Parallelization**: Teams can work on different features simultaneously
- **Infrastructure Flexibility**: Data layer can be swapped without affecting business logic
- **Performance Optimization**: Caching and optimization can be added at appropriate layers

### Team Collaboration

- **Clear Ownership**: Feature modules provide clear ownership boundaries
- **Onboarding**: New team members can understand the system quickly
- **Code Review**: Architecture rules make code review straightforward
- **Documentation**: Architecture serves as living documentation

## Conclusion

The Clean Architecture and Domain-Driven Design approach provides a solid foundation for building a maintainable, testable, and scalable mobile application. By enforcing strict dependency rules and layer separation, the codebase remains flexible and adaptable to changing requirements while maintaining high code quality standards.

