# AGENTS.md - AI Assistant Guidelines for Memoix

This file provides context and guidelines for AI coding assistants working on the Memoix project.

## Project Overview

**Memoix** is a cross-platform recipe management app built with Flutter. It allows users to:
- Browse a curated recipe collection (synced from GitHub)
- Create and manage personal recipes
- Import recipes via OCR (photo scanning) or URL parsing
- Share recipes via QR codes and deep links

## Tech Stack

| Technology | Purpose |
|------------|---------|
| **Flutter 3.2+** | Cross-platform UI framework |
| **Dart** | Programming language |
| **Riverpod** | State management |
| **Isar** | Local database (offline-first) |
| **Google ML Kit** | OCR text recognition |
| **HTTP + HTML parsing** | URL recipe import |

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── app/                      # App-level configuration
│   ├── app.dart             # MaterialApp widget
│   ├── routes/              # Navigation
│   └── theme/               # Theming (colors.dart, theme.dart)
├── core/                     # Shared infrastructure
│   ├── database/            # Isar database setup
│   └── services/            # GitHub sync, etc.
├── features/                 # Feature modules (vertical slices)
│   ├── home/                # Main screen with tabs
│   ├── recipes/             # Recipe CRUD, list, detail views
│   ├── import/              # OCR and URL import
│   ├── sharing/             # QR codes, deep links
│   └── settings/            # App settings
└── shared/                   # Reusable widgets

recipes/                      # Recipe data (JSON files)
├── index.json               # Lists all recipe files
├── version.json             # Sync versioning
└── *.json                   # Category recipe files
```

## Architecture Patterns

### State Management
- Use **Riverpod** for all state management
- Prefer `StreamProvider` for database watches
- Use `StateNotifier` for complex state with actions
- Keep providers in the relevant feature's repository file

### Database
- **Isar** is the local database
- Models use `@collection` and `@embedded` annotations
- Generated files: `*.g.dart` (run `dart run build_runner build`)
- All database operations go through repository classes

### Feature Structure
Each feature follows this pattern:
```
feature_name/
├── models/          # Data classes
├── screens/         # Full-page widgets
├── widgets/         # Feature-specific components
├── repository/      # Data access layer
└── services/        # Business logic
```

## Coding Conventions

### Dart/Flutter Style
- Use `const` constructors wherever possible
- Prefer single quotes for strings
- Use trailing commas for better formatting
- Follow official [Dart style guide](https://dart.dev/guides/language/effective-dart/style)

### Naming
- Files: `snake_case.dart`
- Classes: `PascalCase`
- Variables/functions: `camelCase`
- Constants: `camelCase` (not SCREAMING_SNAKE)
- Private members: prefix with `_`

### Widgets
- Prefer `StatelessWidget` when possible
- Use `ConsumerWidget` / `ConsumerStatefulWidget` for Riverpod
- Extract reusable widgets to `widgets/` folder
- Keep build methods focused (<50 lines ideally)

## Data Models

### Recipe Model
Key fields based on the original Google Sheets structure:
- `name`, `course`, `cuisine`, `subcategory`
- `serves`, `time`, `pairsWith`
- `ingredients` (List of Ingredient)
- `directions` (List of String)
- `source` (memoix, personal, imported, ocr, url)
- `notes`, `tags`, `isFavorite`

### Recipe Sources
```dart
enum RecipeSource {
  memoix,    // From GitHub collection
  personal,  // User-created
  imported,  // Shared/imported from others
  ocr,       // Scanned from photo
  url,       // Imported from website
}
```

## Color System

The app uses a color-coding system matching the original spreadsheet:
- **Course colors**: Each category (Mains, Soups, Desserts, etc.) has a distinct color
- **Cuisine colors**: Cuisines (Korean, French, etc.) have background highlight colors
- See `lib/app/theme/colors.dart` for the full palette

## Recipe Data (GitHub)

Official recipes are stored as JSON in `/recipes/`:
- Fetched from GitHub raw URLs on app sync
- Format documented in `recipes/README.md`
- Users cannot edit these; they're read-only in the app

## Common Tasks

### Adding a New Feature
1. Create folder under `lib/features/`
2. Add models, screens, widgets as needed
3. Create repository with Riverpod providers
4. Add route in `lib/app/routes/router.dart`

### Adding a New Recipe Category
1. Add color to `lib/app/theme/colors.dart`
2. Add to `Category.defaults` in `lib/features/recipes/models/category.dart`
3. Create JSON file in `/recipes/` and update `index.json`

### Modifying Database Schema
1. Edit model in `lib/features/recipes/models/`
2. Run `dart run build_runner build --delete-conflicting-outputs`
3. Handle migrations if needed (Isar auto-migrates simple changes)

## Testing

- Unit tests go in `test/` mirroring `lib/` structure
- Widget tests for complex UI components
- Integration tests in `integration_test/`

## Important Notes

1. **Offline-first**: App must work without internet after initial sync
2. **No user accounts**: Privacy-focused, anonymous usage
3. **Local storage**: User recipes stay on device only
4. **Sharing**: Uses encoded deep links, not cloud storage
5. **Proprietary**: Source available for personal use only, not for commercial redistribution

## Dependencies to Know

| Package | Usage |
|---------|-------|
| `flutter_riverpod` | State management |
| `isar` / `isar_flutter_libs` | Local database |
| `google_mlkit_text_recognition` | OCR |
| `html` | URL recipe parsing |
| `share_plus` | System share sheet |
| `qr_flutter` | QR code generation |
| `mobile_scanner` | QR code scanning |
| `app_links` | Deep link handling |

## Links

- [Flutter Docs](https://docs.flutter.dev/)
- [Riverpod Docs](https://riverpod.dev/)
- [Isar Docs](https://isar.dev/)
- [Material 3 Guidelines](https://m3.material.io/)
