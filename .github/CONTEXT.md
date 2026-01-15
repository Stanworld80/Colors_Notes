# Project Context & Vibe

## "Vibe Coding" Philosophy
This project embraces a "vibe coding" approach: prioritizing intuitive design, vibrant aesthetics, and a fluid user experience while maintaining robust engineering standards. We aim for code that is clean, readable, and self-documenting, reflecting the creativity of the app itself.

## Environment Setup
The project operates across three distinct environments to ensure safe development and deployment:

- **Dev**: Sandbox for active development and experimentation.
- **Staging**: Pre-production environment for testing release candidates.
- **Prod**: Live production environment for end-users.

This triplet structure applies to both:
- **Firebase/Firestore**: Separate projects/databases to isolate data.
- **Google Play Console**: Distinct tracks or application IDs (if applicable) for managing releases.

## Core Features
- **Journaling**: Color-coded daily entries.
- **Palettes**: Custom and predefined color palettes for journals.
- **Security**: Robust Firestore rules and client-side validation.

## Architectural Decisions
- **MVVM Pattern**: transition towards MVVM (e.g., `CreateJournalViewModel`) to separate UI from business logic.
- **Service Layer**: Centralized services (`FirestoreService`, `AuthService`) for external interactions.
- **Validation**: "Trust but verify" - Client-side validation complements server-side security rules.

## Deployment & DevOps
- **Scripted Deployment**: `build_deploy.sh` handles building (Web/Android APK/AAB) and deploying to Firebase Hosting and App Distribution.
    - Usage: `./build_deploy.sh -e [dev|staging|prod] -p [web|android]`
- **Data Sync**: `sync_firestore_env.sh` facilitates syncing Firestore data and Auth users between environments (e.g., Prod -> Staging).
- **Versioning**: Semantic versioning managed in `pubspec.yaml` (automatically incremented by build script).

## Testing Strategy
- **Unit Tests**: Focus on ViewModels (`create_journal_view_model_test.dart`) and Services (`firestore_service_test.dart`) using `mockito` for dependencies.
- **Widget Tests**: Smoke tests for UI components.
- **Integration Tests**: (Planned) End-to-end flows.

## Codebase Organization
- **`lib/viewmodels/`**: State management and business logic (Provider/ChangeNotifier).
- **`lib/services/`**: Data access and external APIs (Firestore, Auth).
- **`lib/models/`**: Data classes with JSON serialization.
- **`lib/screens/`**: UI implementations (StatelessWidgets observing ViewModels).
