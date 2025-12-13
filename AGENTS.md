# AGENTS.md - AI Assistant Guidelines for Memoix

This file provides context and guidelines for AI coding assistants working on the Memoix project.

## Project Overview

**Memoix** is a cross-platform recipe management app built with Flutter, targeted at professional chefs and enthusiastic hobbyists. It allows users to:
- Browse a curated recipe collection (synced from GitHub)
- Create and manage personal recipes
- Manage specialized recipe types (Pizzas, Smoking) with unique schemas
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
│   ├── providers.dart       # Global Riverpod providers
│   └── services/            # GitHub sync, etc.
├── features/                 # Feature modules (vertical slices)
│   ├── home/                # Main screen with course grid
│   ├── recipes/             # Recipe CRUD, list, detail views
│   ├── pizzas/              # Pizza recipes (specialized schema)
│   ├── smoking/             # Smoking recipes (specialized schema)
│   ├── import/              # OCR and URL import
│   ├── sharing/             # QR codes, deep links
│   ├── statistics/          # Cooking stats tracking
│   ├── mealplan/            # Meal planning
│   ├── shopping/            # Shopping lists
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

### Database Access
- Use `ref.watch(databaseProvider)` to get the Isar instance
- Provider is defined in `lib/core/providers.dart`
- **Do NOT use `isarProvider`** - the correct name is `databaseProvider`

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

### Specialized Recipe Types

Some recipe categories have unique schemas that differ from standard recipes:

**Pizzas** (`lib/features/pizzas/`):
- `name`, `style` (Neapolitan, NY, Detroit, etc.)
- `dough` (embedded: flour, water%, yeast, salt, oil, sugar, fermentation)
- `sauce` (embedded: base, ingredients, notes)
- `cheeses` (list of cheese names)
- `toppings` (list of topping names)
- `bakingInstructions` (temp, time, method)

**Smoking** (`lib/features/smoking/`):
- `name` (what's being smoked: Brisket, Ribs, etc.)
- `temperature`, `time`
- `wood` (free-form text with autocomplete suggestions)
- `seasonings` (list with optional amounts)
- `directions`

When adding new specialized types, follow the pizza/smoking pattern.

## UI Patterns

### Outlined Secondary Styling
For highlighted UI elements (step numbers, ranking badges, selected chips), use the outlined secondary pattern:
```dart
Container(
  decoration: BoxDecoration(
    color: theme.colorScheme.secondary.withOpacity(0.15),
    shape: BoxShape.circle, // or borderRadius for rectangles
    border: Border.all(
      color: theme.colorScheme.secondary,
      width: 1.5,
    ),
  ),
  child: Text(
    'text',
    style: TextStyle(color: theme.colorScheme.secondary),
  ),
)
```

### Multi-Select Filters
For filter chips that allow multiple selections, use `Set<String>` instead of single `String?`:
```dart
Set<String> _selectedItems = {};
// Toggle on tap:
onSelected: (_) {
  setState(() {
    if (_selectedItems.contains(item)) {
      _selectedItems.remove(item);
    } else {
      _selectedItems.add(item);
    }
  });
}
```

### Free-Form Input with Suggestions
Avoid "Other" options in dropdowns. Instead, use `Autocomplete<String>` for free-form text with suggestions:
```dart
Autocomplete<String>(
  optionsBuilder: (value) => suggestions.where((s) => 
    s.toLowerCase().contains(value.text.toLowerCase())),
  fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      // ...
    );
  },
)
```

### Live Database Updates
Use `StreamProvider` instead of `FutureProvider` for data that should update in real-time:
```dart
final itemsProvider = StreamProvider<List<Item>>((ref) {
  return ref.watch(repositoryProvider).watchAll();
});
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

## UI Consistency Constraint (Standing)

The Mains screen defines the canonical layout, spacing, color usage,
and component hierarchy for the application.

All other screens (Cuisine, Recipe, Edit, etc.) MUST strictly follow
this pattern.

- Do not introduce layout, spacing, color, or stylistic changes
  unless explicitly instructed by the user.
- Do not "improve", "refine", or reinterpret the design.
- If a deviation seems beneficial, ask before applying it.

This constraint applies to all future UI-related work unless the user
explicitly revokes it.

### Adding a New Feature
1. Create folder under `lib/features/`
2. Add models, screens, widgets as needed
3. Create repository with Riverpod providers
4. Add route in `lib/app/routes/router.dart`
5. If it's a home screen category, update `home_screen.dart` routing

### Adding a Specialized Recipe Type (like Pizza/Smoking)
1. Create feature folder: `lib/features/your_type/`
2. Create model with `@collection` annotation
3. Create repository with CRUD + `databaseProvider`
4. Create list, detail, and edit screens
5. Register schema in `lib/core/database/database.dart`
6. Add routes in `lib/app/routes/router.dart`
7. Add category to `Category.defaults` with color
8. Update `home_screen.dart` to handle special routing and count

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

1. **Target Audience**: Professional chefs and enthusiastic hobbyists, not casual home cooks
2. **Offline-first**: App must work without internet after initial sync
3. **No user accounts**: Privacy-focused, anonymous usage
4. **Local storage**: User recipes stay on device only
5. **Sharing**: Uses encoded deep links, not cloud storage
6. **Proprietary**: Source available for personal use only, not for commercial redistribution
7. **Flexibility**: Avoid restrictive enums with "Other" - prefer free-form text with suggestions

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
