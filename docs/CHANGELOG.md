## Memoix - v1.0.1+3 - 2026-04-24

### Added
- Implemented `SupabaseSecureStorage` using `flutter_secure_storage` for encrypted JWT/session persistence
- Added `maxLength` enforcement across all recipe, pizza, and sandwich edit screens (120 chars for titles, 4000 for notes)
- Enforced 4096-char payload limits and added double-initialisation guards in guards in `DeepLinkService`

### Fixed
- Resolved PostgreSQL Error 21000 by implementing Dart-side payload deduplication before upserts
- Added `try/catch` isolation loops to JSON parsing and Drift database insertions to prevent batch-processing crashes
- Tightened URI host matching to prevent unrecognised deep links from triggering the recipe handler
- Eliminated legacy Google boilerplate and removed deprecated UI debt

### Changed
- Rebuilt Light Mode for better accessibility and contrast; set Dark Mode as the system default
- Refactored `syncRecipesProvider` to delegate to `SyncNotifier` for centralised parallel execution
- Migrated to a "Copy-on-Write" local seed database model for better offline reliability


## Memoix v1.0.0 — 2026-04-22

### Added
- Added comprehensive data access layer (DAOs) to handle complex relational queries via Drift
- Added image migration service to safely transition legacy file paths and blob data into the new database
- Added strict `.env` file environment configuration for all API keys and OAuth credentials
- Integrated deep linking infrastructure to route `memoix://` URIs internally
- Added dynamic manual link-entry fallback to the QR scanner for desktop/web or when camera access is denied
- Added new reusable core UI components: card shell, filter chip, and themed search bar
- [Internal] Added 5-second debounce timer to background sync triggers to prevent excessive network calls

### Fixed
- Fixed critical database integrity issue by enforcing strict UUID preservation during Drift `DoUpdate` upsert operations
- Fixed PostgreSQL `bytea` base64 encoding bug that caused failures in Supabase cloud sync
- Fixed Supabase query filtering by correctly mapping Dart lists to PostgREST CSVs
- Fixed OneDrive token persistence issues by properly clearing secure storage upon sign-out
- Fixed Google Drive OAuth scoping by migrating to account-wide `driveScope` to prevent false matches on nested folders
- Fixed Dark Mode status bar icon contrast logic to correctly support Material 3 surfaces
- Fixed GitHub auto-update crash that occurred when encountering pre-release tags
- Fixed memory leaks by disposing dangling text controllers in the import review screens
- [Internal] Resolved Dart analyzer warnings, including resolving API deprecations and enforcing strict `mounted` checks across async UI operations

### Changed
- Migrated the entire offline-first local database architecture from Isar to Drift (SQLite)
- Rewrote Supabase cloud sync conflict resolution to fully support Drift's relational structure (`insertOrIgnore` and `DoUpdate`)
- Updated OneDrive repository switching to use stable, ID-based resolution instead of fragile name lookups
- Upgraded sharing engine to `SharePlus` (v12.0.1) and refactored call sites with robust error handling
- [Internal] Optimized app startup sequence to initialize core databases in parallel and defer non-critical tasks to post-frame callbacks
- [Internal] Shifted heavy data parsing to background isolates using `compute()` to prevent main thread blocking

### Removed
- Removed automatic clipboard sniffing on app resume to strictly enforce a privacy-first, opt-in data model
- Removed Isar database engine and all related dependencies (`isar`, `isar_flutter_libs`, `isar_generator`)
- Removed all hardcoded dev API keys and OAuth credentials from local configuration files


## Memoix v0.2.0-beta — 2026-03-05

### Added
- Added quick-start timers accessible from direction long-press actions
- Added preset egg timers (soft-boiled and hard-boiled)
- Added ingredient scaling system allowing recipes to be dynamically scaled by servings
- Added ingredient long-press actions with optional AI-powered ingredient reference and substitution lookup
- Added AI-assisted recipe import option for difficult sources (e.g. cookbook photos) where OCR or URL parsing fails
- Implemented side-by-side recipe comparison feature with selection system and three entry points (tools menu, recipe detail, import preview)
- Integrated Scratch Pad with structured data model (DraftIngredient, structuredIngredients, structuredDirections)
- Added swipe gestures and inline undo for swipe deletes across lists
- Added "Compare" option to MemoixHeader and ImportReviewScreen for eligible recipes
- Added "Compare" button to ImportReviewScreen and RecipeEditScreen for streamlined comparison entry
- Refactored draft editor screen for to match standard edit screen
- Added support for multiple email invitations in repository sharing, with improved validation and feedback
- Added Google Drive provider selection and connection logic to external storage screen
- Added OneDrive provider selection and connection logic to external storage screen

### Fixed
- Fixed repository switching and sync status updates for Google Drive and OneDrive
- Fixed ingredient search to ensure ingredients are properly included in results
- Fixed issues where the Compare button appeared for non-comparable courses (e.g., Pizzas, Drinks)
- Fixed comparison state reset logic to ensure a fresh start when navigating to the comparison screen
- Fixed various UI and logic bugs in recipe, meal plan, and import screens

### Changed
- Updated recipe detail screen to support dynamic ingredient scaling
- Updated direction interaction model to support timer shortcuts via long press
- Refactored Recipe model to use `comments` field (serializes as 'notes' for compatibility); updated all screens and importers to use `comments`
- Refactored draft and scratch pad screens to use service-level deletion management and improved parsing via IngredientParser
- Updated all recipe screens (detail, edit, split view) and importers to use `comments` for recipe-level notes
- Updated swipe-to-delete and undo logic for consistency across lists
- Updated repository management UI for clearer status, actionable sync messages, and improved menu options
- Updated external storage logic to support multi-repository management, migration, and verification states
- Updated deep link handling for shared repositories with clear status and retry logic
- Refactored RecipeListScreen to use repository search with course filtering, improving performance and accuracy
- Refactored Compare button logic to use a strict allow-list and unified assignment method for slot selection
- Updated comparison screen to reset state only when appropriate, preserving in-progress work during import flows
- Updated navigation and state management for recipe comparison to use RouteObserver and RouteAware for reliable resets.
- Updated draft and scratch pad screens to improve provider refresh and tab handling
- Updated application ID from `com.example.memoix` to `io.github.dboiago.memoix`
- [Internal] Restructured code for provider-specific initialisation and error handling in storage services
- [Internal] Cleaned up duplicate code and improved debug logging in import and storage modules
- [Internal] Restructured Compare button UI to group elements for more reliable reactive hiding/showing
- [Internal] Updated save/convert functions in draft editor for consistency with edit screen

### Removed
- Removed GitHub and iCloud options from external storage provider selection UI
- Removed deprecated icons and black icon assets from project
- Removed unused and duplicate code in picker and import modules
- Removed Apple icons from launcher assets due to build limitations
- Removed deprecated `ingredient.dart` model from recipes feature

- Removed references to unused variables and dead code in edit and comparison screens