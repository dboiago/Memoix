## Memoix v0.2.0-beta — 2026-01-12

### Added
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
- [Internal] Restructured code for provider-specific initialization and error handling in storage services
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