# Calories App

> A production-grade Flutter application for comprehensive calorie tracking, meal planning, and nutrition management built with Clean Architecture and Domain-Driven Design principles.

## Overview

Calories App is a sophisticated mobile application designed to help users track their daily nutrition, manage meal plans, and achieve their health goals. The application demonstrates enterprise-level software engineering practices, featuring a strict separation of concerns, testable business logic, and a scalable architecture that supports both online and offline functionality.

The project has undergone multiple refactoring phases to achieve a mature, maintainable codebase that adheres to SOLID principles and Domain-Driven Design patterns. Business logic is completely isolated from UI and infrastructure concerns, making the codebase highly testable and adaptable to changing requirements.

## Key Features

- **📊 Daily Calorie Tracking** - Track food consumption and exercise with real-time calorie calculations
- **🍽️ Meal Planning** - Create custom meal plans or explore curated templates
- **📝 Diary Management** - Log meals and exercises with automatic meal type classification
- **🎤 Voice Input** - Add foods to your diary using voice recognition powered by Google Gemini AI
- **💪 Exercise Logging** - Track workouts and activities with calorie burn calculations
- **📈 Statistics & Reports** - View detailed nutrition summaries and progress analytics
- **💧 Water & Weight Tracking** - Monitor hydration and body weight over time
- **🔔 Smart Notifications** - Receive reminders for meals and hydration goals
- **🏥 Health Connect Integration** - Sync with Android Health Connect for comprehensive health data
- **👤 User Profiles** - Personalized profiles with TDEE calculations and goal setting
- **🔐 Secure Authentication** - Firebase Authentication with Google Sign-In support
- **📱 Offline Support** - Hybrid cache-first architecture for instant loading and offline functionality

## Architecture

### Clean Architecture & Domain-Driven Design

The application follows a strict layered architecture that enforces separation of concerns:

```
┌─────────────────────────────────────┐
│     Presentation Layer              │
│  (UI, Widgets, Riverpod Providers)  │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│     Application Layer               │
│  (Services, Use Cases, Controllers) │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│     Domain Layer                    │
│  (Entities, Repository Interfaces)  │
│  Pure Dart - No Flutter/Firebase    │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│     Data Layer                      │
│  (DTOs, Firestore, Cache)           │
└─────────────────────────────────────┘
```

#### Domain Layer (`lib/domain/`)
- **Pure Dart entities** with no external dependencies
- Abstract repository interfaces defining contracts
- Business logic services that coordinate between repositories and caches
- Domain models are completely isolated from infrastructure concerns

#### Data Layer (`lib/data/`)
- **DTOs (Data Transfer Objects)** for Firestore schema mapping
- Firestore repository implementations
- SharedPreferences cache implementations
- Handles all data persistence and external API communication

#### Application Layer (`lib/features/*/application/`)
- Business logic services that orchestrate domain operations
- Coordinates between repositories and caches
- Implements use cases and application-specific workflows

#### Presentation Layer (`lib/features/*/presentation/`)
- Flutter UI widgets and screens
- Riverpod providers for state management
- Controllers that manage UI state and user interactions
- Completely decoupled from business logic

### Hybrid Cache-First Architecture

The application implements a sophisticated caching strategy that provides:

- **Instant Loading**: Data loads from local cache immediately, no waiting for network
- **Background Sync**: Firestore updates happen asynchronously, UI updates when ready
- **Offline Support**: Full functionality available without network connectivity
- **Cache Invalidation**: Smart cache management ensures data consistency

Services implement cache-first patterns:
```dart
// 1. Emit cached data immediately
// 2. Fetch from Firestore in background
// 3. Update cache and emit new data
// 4. UI reacts to stream updates
```

## Project Structure

```
lib/
├── app/                    # App-level configuration and routing
│   ├── config/            # Firebase configuration
│   └── routing/           # Navigation gates and guards
│
├── core/                   # Core functionality
│   ├── health/            # Health Connect integration
│   ├── notifications/     # Push and local notifications
│   ├── theme/             # App theming
│   └── utils/             # Utility functions
│
├── domain/                 # Domain layer (Pure Dart)
│   ├── activities/        # Activity domain models
│   ├── diary/             # Diary domain models and services
│   ├── foods/             # Food catalog domain models
│   ├── meal_plans/        # Meal plan domain models
│   └── profile/           # User profile domain models
│
├── data/                   # Data layer (Infrastructure)
│   ├── activities/        # Activity DTOs and repositories
│   ├── diary/             # Diary DTOs and Firestore repositories
│   ├── foods/             # Food DTOs and repositories
│   ├── meal_plans/        # Meal plan DTOs and repositories
│   └── profile/           # Profile DTOs and repositories
│
├── features/               # Feature modules (Presentation)
│   ├── auth/              # Authentication screens
│   ├── diary/             # Diary feature domain services
│   ├── exercise/          # Exercise tracking
│   ├── foods/             # Food management
│   ├── home/              # Dashboard and main screens
│   ├── meal_plans/        # Meal plan management
│   ├── onboarding/        # User onboarding flow
│   ├── settings/          # App settings
│   └── voice_input/       # Voice input feature
│       ├── application/   # Voice service layer
│       ├── data/          # Gemini API integration
│       ├── domain/         # Voice domain entities
│       └── presentation/  # Voice UI and controllers
│
└── shared/                 # Shared utilities and providers
    ├── config/            # Shared configuration
    ├── state/             # Shared Riverpod providers
    └── utils/             # Shared utilities
```

## Tech Stack

| Category | Technology | Purpose |
|----------|-----------|---------|
| **Framework** | Flutter 3.8+ | Cross-platform UI framework |
| **Language** | Dart 3.8+ | Programming language |
| **State Management** | Riverpod 3.0 | Reactive state management |
| **Backend** | Firebase | Backend-as-a-Service |
| **Authentication** | Firebase Auth | User authentication |
| **Database** | Cloud Firestore | NoSQL document database |
| **Storage** | Firebase Storage | File and image storage |
| **Analytics** | Firebase Analytics | Usage analytics |
| **Notifications** | FCM + Local | Push and local notifications |
| **AI/ML** | Google Gemini API | Voice input processing |
| **Health Data** | Health Connect (Android) | Health data integration |
| **Caching** | SharedPreferences | Local data persistence |
| **Environment** | flutter_dotenv | Environment variable management |

## Firebase Integration

The application uses Firebase as its Backend-as-a-Service platform:

### Authentication
- Email/password authentication
- Google Sign-In integration
- Secure session management

### Firestore Database
- Document-based data storage
- Real-time synchronization
- Optimistic updates with cache fallback

### Cloud Storage
- User profile image storage
- Secure file uploads with access control

### Cloud Messaging
- Push notifications for meal reminders
- Local notifications for hydration goals
- Background notification handling

### App Check
- API abuse prevention
- Bot protection
- Security enforcement

## Testing Philosophy

The architecture is designed for testability:

- **Domain Layer**: Pure Dart code can be unit tested without Flutter dependencies
- **Repository Interfaces**: Mock implementations enable isolated testing
- **Service Layer**: Business logic can be tested independently of UI and infrastructure
- **Test Coverage**: Focus on domain logic and critical business workflows

Current test structure:
```
test/
├── features/
│   └── meal_plans/
│       ├── domain/services/    # Domain service tests
│       └── data/               # Repository tests
└── services/                   # Utility service tests
```

## Getting Started

### Prerequisites

- Flutter SDK 3.8.1 or higher
- Dart SDK 3.8.1 or higher
- Android Studio / Xcode for mobile development
- Firebase project with Firestore, Auth, and Storage enabled
- Google Gemini API key (for voice input feature)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd Calories-App
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Place `google-services.json` in `android/app/`
   - Configure iOS Firebase in Xcode
   - Update `lib/app/config/firebase_options.dart` if needed

4. **Set up environment variables**
   ```bash
   cp .env.example .env
   # Edit .env and add your GEMINI_API_KEY
   ```

5. **Run the application**
   ```bash
   flutter run
   ```

### Environment Setup

Create a `.env` file in the project root:
```
GEMINI_API_KEY=your_gemini_api_key_here
```

The `.env` file is gitignored for security. See `.env.example` for the template.

## Project Philosophy

This project embodies several core engineering principles:

### Clean Code
- **SOLID Principles**: Single Responsibility, Open/Closed, Liskov Substitution, Interface Segregation, Dependency Inversion
- **DRY (Don't Repeat Yourself)**: Shared utilities and reusable components
- **Meaningful Names**: Self-documenting code with clear intent

### Architecture Decisions
- **Domain-Driven Design**: Business logic drives the architecture, not the database
- **Dependency Inversion**: High-level modules don't depend on low-level modules
- **Separation of Concerns**: Each layer has a single, well-defined responsibility
- **Testability**: Architecture enables comprehensive testing at all levels

### Code Quality
- **Type Safety**: Leveraging Dart's strong typing system
- **Null Safety**: Full null-safety compliance
- **Linting**: Strict linting rules enforced via `analysis_options.yaml`
- **Documentation**: Comprehensive inline documentation for complex logic

### Maintainability
- **Modular Structure**: Features are self-contained modules
- **Clear Boundaries**: Explicit interfaces between layers
- **Migration Path**: Legacy code is clearly marked and gradually migrated
- **Refactoring**: Continuous improvement through iterative refactoring

## Future Roadmap

### Planned Features
- [ ] Advanced meal plan templates with AI recommendations
- [ ] Social features for sharing meal plans
- [ ] Barcode scanning for food entry
- [ ] Enhanced analytics and insights
- [ ] Meal prep planning and shopping lists
- [ ] Integration with more health platforms
- [ ] Multi-language support expansion
- [ ] Dark mode theme enhancements

### Technical Improvements
- [ ] Complete migration of legacy code to DDD architecture
- [ ] Expanded test coverage for domain and application layers
- [ ] Performance optimizations for large datasets
- [ ] Enhanced offline synchronization strategies
- [ ] Advanced caching strategies with TTL management
- [ ] GraphQL API integration option
- [ ] Microservices architecture exploration

## Contributing

This is an academic and production-oriented project. Contributions should:

- Follow the existing architecture patterns
- Maintain Clean Architecture principles
- Include appropriate tests
- Update documentation as needed
- Follow the project's coding standards

## License

This project is developed for academic purposes. All rights reserved.

## Author
QuocTuan_dev_hcm
Developed as part of academic coursework with a focus on software engineering best practices, Clean Architecture, and Domain-Driven Design.

---

**Built with ❤️ using Flutter and Firebase**
