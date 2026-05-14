## Memoix - v2.0.0+11 - 2026-05-14
 
### Added
 
- FTS5 full-text search across all recipe domains; five contentless virtual tables with `unicode61` tokenizer and diacritic preservation (`remove_diacritics 0`)
- BM25 weighted result ranking with per-domain column weights; recipe name ranked above ingredients, notes ranked above structural fields
- Ingredient prep notes (`ingredients.notes`) now included in search queries; covers substitutions and alternatives stored inline
- Contribute Recipes: opt-in telemetry pipeline transmitting anonymized recipe data across all 7 domains to a developer-operated Supabase corpus
- PII scrubber applied to all free-text fields before transmission; redacts emails, phone numbers, Canadian SINs, US SSNs, UK National Insurance numbers, IBANs, and IPv4 addresses
- PII scrubber also applied to all Supabase backup serializers (`_recipeToRow`, `_pizzaToRow`, `_sandwichToRow`, `_cellarEntryToRow`, `_cheeseEntryToRow`, `_smokingRecipeToRow`)
- Hidden recipe toggle (eye icon) in recipe edit and import review screens; recipes marked hidden are unconditionally excluded from Contribute Recipes transmission
- Contribute Recipes opt-in prompt shown automatically once a minimum recipe collection exists; eligibility based on recipe count, cook count, and favourite count
- `deviceLocale` (`Platform.localeName`) added to Contribute Recipes metadata payload alongside `appVersion` and `buildNumber`
- Pending deletions queue (`PendingDeletions` table); recipes deleted while offline are reliably synced to Supabase on next connection, with per-domain coverage across all 9 entity types
- Orphaned local image cleanup service runs on deferred startup after image migration; removes `.jpg`/`.png` files in `recipe_images/` not referenced by any table across all 8 image-bearing domains
- Omnibar cuisine browse mode: queries containing a recognised cuisine term without meal-context words return a course-card layout filtered to matched cuisines rather than a suggestion list
- Multi-cuisine detection in Omnibar; all matched cuisine terms collected and resolved via parallel retrieval queries with deduplication by name and course
- Walk-in chip in Omnibar automatically disables and greys out when device is offline; mode auto-exits to Saved Recipes on connectivity loss
- `MemoixFilterChip.onSelected` made nullable; Flutter's native `FilterChip` disabled state used for semantic correctness
- [Internal] `ContinentMapping.cuisineToCountry` (231 cuisine keys) wired as the detection source for Omnibar intent classification

### Changed
 
- Search replaced LIKE-based queries with FTS5 `MATCH` + `bm25()` across all DAOs (`recipe_dao`, `catalogue_dao`, `cellar_dao`); in-memory text filter removed from `recipe_list_screen`; debounced `customSelect` replaces the stream-provided list during active queries
- FTS5 query builder strips all reserved characters (`"*+-:^{}.[]\`) and appends `*` per token for prefix matching; prevents syntax errors on punctuation and special character input
- Contribute Recipes backfill (`backfillOnOptIn`) sends in batches of 25 per network request rather than one HTTP call per recipe; all 7 domain transmission clients implement typed batch methods
- Master switch (Contribute Recipes toggle) startup race condition resolved; `ContributeToIntelligenceNotifier` now exposes a readiness completer that `RagTelemetryService` awaits before executing the gate check
- Unified AI service layer; `IngredientReferenceService` duplicate provider dispatch loop removed and consolidated under `AiService.sendMessage()`; `temperature: 0.2` preserved via new optional `AiRequest.temperature` field
- `MemoixClient` wired as a first-party AI provider; participates in auto-select priority chain when `useMemoixHosted` is enabled; user-configured providers always take precedence; `baseUrl` configurable for future hosted endpoint
- Hidden recipe toggle now unconditional in recipe detail screen; `contributeToIntelligenceProvider` watch removed from both layout builders
- `isShared` preserved on recipe update; `toggleShared` is the only permitted mutation path; edit screen cannot inadvertently overwrite the flag
- Omnibar results fire only on explicit submit (`onSubmitted` or arrow button); replaced `SearchDelegate`-based `OmnibarDelegate` with `OmnibarScreen` (`ConsumerStatefulWidget`)
- [Internal] `SupabaseTransmissionClient` batch insert methods use single `.insert(List<Map>)` PostgREST call per chunk; `payloads.isEmpty` guard prevents empty requests
- [Internal] `_buildMetadata()` called once per backfill run and shared across all 7 domain blocks
- [Internal] Schema bumped from v7 to v11 across this branch; migrations are sequential and skip-version safe

### Fixed
 
- `isFavourite` spelling corrected across all 6 Drift tables, 36 files, and all serialization paths; schema migration renames `is_favorite` column via `ALTER TABLE … RENAME COLUMN` with `PRAGMA table_info` idempotency guard
- FTS5 tables recreated with `remove_diacritics 0` tokenizer; accented characters no longer fold to base equivalents causing false-positive search matches
- Modernist recipes now correctly indexed and searched via FTS5; `ModernistRepository.save()` calls `upsertRecipeFts` after ingredient write; `search()` routes through `recipeDao.searchRecipes()` with `recipeType` post-filter
- `PendingDeletions` table column renamed from `tableName` to `entityType` to avoid clash with Drift's reserved `Table.tableName` getter
- `ShoppingListService` menu action deletion path now notifies Supabase; previously only the card dismiss path was wired
- Supabase transmission client insert calls now active with PII scrubbing confirmed end-to-end in Supabase table

### Removed
 
- In-memory text search block removed from `_filterRecipesInMemory` in `recipe_list_screen`; cuisine chip filter retained
- Duplicate provider dispatch logic removed from `IngredientReferenceService` (`_selectProvider`, `_classifyError`, `_providerLabel`, direct `AiKeyStorage` access)


## Memoix - v1.2.0+10 - 2026-05-05

### Added

- Full Android share integration (text, URLs, single/multiple images) via platform `MethodChannel`
- `ShareHandlerService` for unified handling of cold/warm share flows and navigation dispatch
- Low-confidence ingredient recovery pipeline when primary parsing fails (fallback extraction with review flag)
- Sendable SVG asset pipeline to prevent isolate crashes and cache poisoning in release builds

### Changed

- Web import fallback logic expanded; now detects bot-block responses (403/429/503 + challenge markers) and escalates immediately
- HTTP header set modernised to match current Chrome fingerprinting expectations
- WebView fallback behaviour refined:
  - Full-viewport rendering to satisfy anti-bot viewport checks
  - Cookie + cache clearing before load to avoid persistent blocks
  - Extended JS challenge wait window to allow async verification to complete
- Share flow refactored to a single controlled lifecycle (dialog, parsing, navigation sequencing)
- Android launch mode changed to `singleTask` to prevent multiple app instances from share intents
- URL validation moved ahead of all WebView/controller initialisation (prevents resource leaks)
- Default import timeout increased to 30s to account for challenge resolution delays

### Fixed

- Ingredient parsing edge cases:
  - Anchor-wrapped headings no longer terminate traversal
  - Non-section utility headings no longer prematurely stop extraction
  - Added guarded parent traversal fallback for malformed DOM structures
- Runtime type error in ingredient heading detection (`.any` → explicit loop)
- Share error UX: all errors now persistent with copyable output for debugging
- Cold-start share race condition (queued events now drained after navigator readiness)
- SVG rendering crash in AOT/release due to non-sendable `AssetBundle` futures
- Keyboard overlap in `ScratchPadScreen` via `resizeToAvoidBottomInset`

### Removed

- Redundant / ineffective WebView media playback override (platform-restricted API)
- Partial anti-bot bypass attempts that did not generalise beyond niche sites


## Memoix - v1.1.1+8 - 2026-04-30

### Added

- Multi-select filtering for milk across relevant lists; empty set shows all, chips toggle membership
- SVG-based logo rendering in Settings and empty states; removed raster tint pipeline
- Cook Map upgraded to rolling-velocity model with decay and dynamic chip count per screen width
- Play Store and Privacy Policy links in Settings (About section)
- Full data wipe now includes on-disk media directories and secure stores (AI keys, Supabase session)

### Changed

- Unified `MemoixFilterChip` across 10 screens; removed per-screen styling overrides in favour of centralised behaviour
- `MemoixSearchBar` icons now theme-aware; removed hardcoded `const Icon(...)`
- Replaced `SyncNotifier` flow with stateless `LocalDataSeeder`; seeding now invoked from init and background paths
- Settings “Sync & Updates” restructured; Play Store builds bypass GitHub checks entirely
- Recipe domain mapping renamed `_toDomainRecipe`; all Isar-era naming and comments removed
- Card title text now scales via `FittedBox` across all list cards to prevent overflow
- Bottom safe-area padding applied to list/detail/cooking views without breaking edge-to-edge layout
- Drinks logging now writes subcategory (spirit) into `recipeCuisine` for colour fidelity; course-specific colour resolution aligned with card logic
- Database clear now wipes all 16 tables including `recipe_images`

### Fixed

- Cook Map exclusion for modernist, pizza, sandwich, and smoking logs due to null `recipeCuisine`
- UUID constraint violations in `cooking_logs` by generating v4 UUID per insert
- Dismissible assertion in lists by implementing `confirmDismiss` with snap-back behaviour and meal-plan action
- Text truncation/overflow across all cards under constrained widths
- Bottom navigation overlap issues on edge-to-edge devices
- Stale launcher icon config and unused assets removed
- Various residual Isar references in comments and documentation


## Memoix - v1.1.0+7 - 2026-04-28

### Added
- Implemented Android 15+ edge-to-edge system window support and free-form resizing (`resizeableActivity="true"`)
- Complied with Google Play Store native library requirements by aligning `.so` ELF segments to 16 KB via NDK r27
- Added database-level `LIKE` query pre-filtering for paired recipes and ingredient searches to eliminate Dart-side full table scans

### Fixed
- Resolved a critical battery drain issue where `WakelockPlus` was leaking when navigating away from the Recipe Detail screen
- Fixed UI thread freezing during recipe autocomplete by replacing full-model loads with direct, lightweight SQLite limits
- Fixed a state bleed bug where Modernist and Smoking configurations persisted across different recipe edit sessions
- Resolved "0 count" UI flashes and missing SVG icons on startup by strictly gating the initialisation lifecycle and pre-caching assets
- Fixed active search results wiping out when background database writes (like cook counts) occurred
- Capped high-resolution network images to `cacheWidth`/`cacheHeight` to prevent excessive memory decoding on step-by-step photos

### Changed
- Massively reduced app startup time by offloading SQLite initialisation to a background isolate and deferring 10MB GZip metadata parsing
- Optimised SQLite for mobile via `WAL` (Write-Ahead Logging) and `mmap` PRAGMAs to allow concurrent reads and bypass slow storage drives
- Refactored home screen and list providers to memoise O(N) computations, eliminating thousands of redundant list iterations per scroll frame
- Consolidated 15+ independent SQLite watch streams on the Home Screen into a single grouped Riverpod stream
- Replaced N+1 sequential read-modify-write loops with atomic SQL updates (`customUpdate`) for all cook counts and favourite toggles
- Optimised bulk recipe syncing by batching UUID checks and wrapping inserts in single transaction boundaries


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


## Memoix - v1.0.0 - 2026-04-22

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


## Memoix - v0.2.0-beta - 2026-03-05

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
