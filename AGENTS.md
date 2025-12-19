# AGENTS.md - Context & Rules for Memoix

---

## 1. CRITICAL CONSTRAINTS (Non-Negotiable)

These rules apply to ALL code. Violating them will cause rework.

### 1.1 Visual Design
| Rule | Details |
|------|---------|
| **NO ICONS / NO EMOJIS** | Do not add decorative icons (🍕, 🗑️) to headers, titles, or buttons unless explicitly requested. |
| **MAINS IS BASELINE** | The "Mains" screen defines canonical spacing, padding, and font sizes. Do not "improve" layouts by adding cards or changing margins. |
| **DESTRUCTIVE ACTIONS** | Never use `Colors.red` or `error` for delete buttons. Use `theme.colorScheme.secondary` instead. |
| **CONTRAST** | Never place Primary Text on a Secondary Background. Use Secondary Text (in outlined containers). |

### 1.2 Code Quality
| Rule | Details |
|------|---------|
| **SEARCH FIRST** | Before writing a helper, search the codebase for existing implementations. |
| **STRICT TYPING** | Avoid `dynamic`. Use explicit models (`Recipe`, `Pizza`, `Ingredient`). |
| **PROVIDERS** | Use `databaseProvider` for Isar (NOT `isarProvider`). Use `ref.read` for actions, `ref.watch` for builds. |

---

## 2. CORE PHILOSOPHY

**Memoix** is a professional-grade recipe management app for **chefs and serious hobbyists** (NOT casual home cooks).

* **Stack:** Flutter 3.x, Riverpod (State Management), Isar (Offline DB), Google ML Kit (OCR)
* **Aesthetic:** Minimalist, data-dense, utilitarian. **NO decorative elements.**
* **Philosophy:** Offline-first, privacy-focused, no user accounts

---

## 3. UI COMPONENTS & DESIGN SYSTEM

### 3.1 Header Component
All detail views **MUST** use the shared `MemoixHeader` widget from `lib/shared/widgets/memoix_header.dart`.

**DO NOT:**
* Build inline headers in detail screens

**Usage:**
```dart
MemoixHeader(
  title: recipe.name,
  isFavorite: recipe.isFavorite,
  headerImage: recipe.headerImage,
  onFavoritePressed: () => ...,
  onLogCookPressed: () => ...,
  onSharePressed: () => ...,
  onEditPressed: () => ...,
  onDuplicatePressed: () => ...,
  onDeletePressed: () => ...,
)
```

The header is model-agnostic - it accepts primitive values (strings, bools, callbacks), allowing use across Recipe, Modernist, Pizza, Sandwich, Smoking, Cellar, and Cheese detail screens.

### 3.2 SnackBars (User Feedback)
All SnackBars **MUST** use `MemoixSnackBar` from `lib/core/widgets/memoix_snackbar.dart`.

**STRICTLY FORBIDDEN:**
* Do NOT instantiate raw `SnackBar()` widgets
* Do NOT call `ScaffoldMessenger.of(context).showSnackBar()` directly

**Available Methods:**
```dart
MemoixSnackBar.show('Item added to list');           // Simple (2s)
MemoixSnackBar.showSuccess('Recipe imported!');      // Success (2s)
MemoixSnackBar.showError('Failed to save');          // Error (2s)

MemoixSnackBar.showWithAction(                       // With action (2s + timer)
  message: 'Recipe deleted',
  actionLabel: 'Undo',
  onAction: () => ...,
);

MemoixSnackBar.showLoggedCook(                       // "I made this" pattern
  recipeName: recipe.name,
  onViewStats: () => AppRoutes.toStatistics(context),
);

MemoixSnackBar.showSaved(                            // After save pattern
  itemName: recipe.name,
  actionLabel: 'View',
  onView: () => AppRoutes.toRecipeDetail(context, uuid: recipe.uuid),
);
```

**Why:** Uses global `rootScaffoldMessengerKey` that survives navigation. Includes Timer-based auto-dismiss for SnackBars with action buttons (workaround for Material 3 bug).

### 3.3 Color System

#### UI Elements (Theme Colors)
For all UI chrome (buttons, backgrounds, borders, text):
```dart
Theme.of(context).colorScheme.primary
Theme.of(context).colorScheme.secondary
Theme.of(context).colorScheme.surface
Theme.of(context).colorScheme.onSurface
Theme.of(context).colorScheme.onSurfaceVariant
Theme.of(context).colorScheme.outline
```

#### Domain Data (MemoixColors)
For data-driven visual indicators (cuisine dots, course badges, spirit colors):
```dart
// Static lookup methods
MemoixColors.forCuisine('Korean')
MemoixColors.forContinentDot('Japanese')
MemoixColors.forCourse('mains')
MemoixColors.forSpiritDot('Gin')
MemoixColors.forPizzaBaseDot('marinara')
MemoixColors.forSmokedItemDot('beef')
MemoixColors.forModernistType('technique')
MemoixColors.forProteinDot('chicken')

// Direct constants
MemoixColors.spiritGin
MemoixColors.continentAsian
MemoixColors.pizzaMarinara
```

#### Semantic Status Colors
For status indicators (confidence scores, validation states):
```dart
MemoixColors.success           // Green
MemoixColors.warning           // Orange  
MemoixColors.successContainer  // Light green bg
MemoixColors.warningContainer  // Light orange bg
MemoixColors.errorContainer    // Light red bg
MemoixColors.favorite          // Soft red heart
MemoixColors.rating            // Amber star
```

#### Import Method Colors
```dart
MemoixColors.importManual      // Muted blue
MemoixColors.importCamera      // Sage green
MemoixColors.importMultiPage   // Ocean teal
MemoixColors.importGallery     // Warm orange
```

#### Forbidden Patterns
```dart
// ❌ FORBIDDEN
Colors.red / Colors.blue / Colors.green / Colors.orange
Color(0xFF4B5563)  // Hardcoded hex in widgets
theme.colorScheme.primary  // for domain data like cuisine dots
```

**Exception:** `Colors.grey` is acceptable as a fallback in `MemoixColors` lookup methods when no match is found.

#### FilterChip Pattern
FilterChips are UI elements - use `theme.colorScheme.secondary` for `selectedColor`, `side`, and `labelStyle`. To show domain color, add an `avatar` with a colored dot using `MemoixColors`. See `smoking_list_screen.dart` for reference.

---

## 4. VIEW ARCHITECTURE

### 4.1 Split/Side-by-Side View Layout
The split view uses a fixed-height container strategy to allow footer content (Notes, Gallery, Nutrition) to scroll below.

**Height Calculation (Responsive):**
* **Mobile (<600px):** 55% of screen, clamped 200-400px - ensures footer visibility on small screens
* **Tablet (≥600px):** 75% of screen, clamped 400-700px - more room for content

The split view also uses content-aware sizing: if the actual content (ingredients + directions) is shorter than the max height, it shrinks to fit.

**Pattern:**
```dart
SizedBox(
  height: splitViewHeight, // Responsive: mobile=55%, tablet=75%
  child: Row(
    children: [
      Expanded(child: _IngredientsColumn(...)),  // Independent scroll
      VerticalDivider(...),
      Expanded(child: _DirectionsColumn(...)),   // Independent scroll
    ],
  ),
)
```

**DO NOT:**
* Use `Expanded` for the split container (prevents footer scrolling)
* Place footer sections inside the split columns

### 4.2 The "Physical Item" Input Pattern
**Applies to:** Wood (Smoking), Glass/Garnish (Drinks), Equipment (Modernist)

**UI Behavior:**
* **Autocomplete Dropdown:** User types, sees existing suggestions
* **Free-form Entry:** User can type a new item not in the list
* **Chip Display:** Selected items appear as actionable chips
* **NO Enums:** Never restrict these fields to a hardcoded Enum with an "Other" option

---

## 5. DATA & MODELS

### 5.1 Recipe Pairing
Recipe pairings are stored in `pairedRecipeIds` on the Recipe model (and ModernistRecipe).

* **Field:** `List<String> pairedRecipeIds = []`
* **Location:** `lib/features/recipes/models/recipe.dart`
* **Bidirectional:** Detail screens show both explicit pairings AND inverse pairings (recipes that link to the current recipe)

**DEPRECATED:** The `pairsWith` field is deprecated. Use `pairedRecipeIds` for all new code.

### 5.2 Domain Schema Types
The app distinguishes between "Standard Recipes" (list of steps) and "Component Assemblies" (list of parts).

#### Type A: Standard Recipe (Recipe Model)
* **Use for:** Mains, Desserts, Drinks, Baking, Modernist, Smoking
* **Base Fields:** name, ingredients (List), directions (List), serves, time
* **Expansion:** Add optional/nullable fields to Recipe model

#### Type B: Component Assembly (Pizza Model, etc.)
* **Use for:** Pizzas, Sandwiches, Charcuterie Boards
* **Concept:** No single "Directions" list - assembly of discrete sub-recipes
* **Structure:**
  * `base`: Enum or String (Sauce, Bread)
  * `components`: Lists of Strings/Objects (Toppings, Cheeses, Condiments)
  * `sub_recipes`: Embedded objects (Dough, Spread)

---

## 6. PROJECT STRUCTURE

### 6.1 Feature Pattern (Vertical Slice)
All features follow this structure:
```text
lib/features/<feature_name>/
├── models/      # Isar collections (@collection)
├── screens/     # Full page widgets (Scaffolds)
├── widgets/     # Feature-specific components
├── repository/  # Data access (Providers go here)
└── services/    # Business logic (Parsers, Validators)
```

### 6.2 Core Locations
| Path | Purpose |
|------|---------|
| `lib/app/theme/` | Theme and MemoixColors |
| `lib/app/routes/router.dart` | Static routing helpers (AppRoutes) |
| `lib/core/database/database.dart` | MemoixDatabase schema registration |
| `lib/core/widgets/` | Shared widgets (MemoixSnackBar, etc.) |
| `lib/core/services/` | Shared services (url_importer.dart) |
| `lib/shared/widgets/` | Cross-feature UI (MemoixHeader, etc.) |

### 6.3 Protocol for Adding New Features
1. **Create Structure:** Add `lib/features/<new_type>/`
2. **Define Model:** Create model with `@collection`
3. **Register Schema:** Add to `MemoixDatabase.initialize()` in `lib/core/database/database.dart`
4. **Define Routes:** Add static `to<Feature>List` and `to<Feature>Detail` methods in `AppRoutes`
5. **Assign Color:** Add domain color to `MemoixColors` in `colors.dart`
