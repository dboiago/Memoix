# AGENTS.md - Context & Rules for Memoix

---

## 1. CRITICAL CONSTRAINTS (Non-Negotiable)

These rules apply to ALL code. Violating them will cause rework.

### 1.1 Security & Input Validation

| Rule | Details |
|------|---------|
| **HTTP RESPONSE LIMITS** | All HTTP fetches MUST enforce a **10 MB** limit via stream counting. Use `StreamedResponse` and abort if `bytesRead > _maxResponseBytes`. |
| **CONTENT-TYPE CHECK** | Reject binary types (`application/pdf`, `image/*`, `video/*`, `application/zip`) immediately upon header receipt. Do NOT download the body. |
| **URL SCHEME VALIDATION** | Only allow `http://` and `https://` schemes. Reject `file://`, `javascript://`, `content://`, `data://`. |
| **QR/DEEP LINK LIMITS** | Maximum encoded data length: **4,096 characters**. Reject oversized payloads before parsing. |
| **DECOMPRESSION BOMBS** | When decompressing gzip (share links), check: input ≤ 500 KB, output ≤ 5 MB. Abort if exceeded. |
| **RECIPE VALIDATION** | Before saving imported recipes: `name.trim().isNotEmpty` AND (`ingredients.isNotEmpty` OR `directions.isNotEmpty`). |

### 1.2 Visual Design

| Rule | Details |
|------|---------|
| **NO ICONS / NO EMOJIS** | Do not add decorative icons (🍕, 🗑️) to headers, titles, or buttons unless explicitly requested. |
| **MAINS IS BASELINE** | The "Mains" screen defines canonical spacing, padding, and font sizes. Do not "improve" layouts. |
| **DESTRUCTIVE ACTIONS** | Never use `Colors.red` or `error` for delete buttons. Use `theme.colorScheme.secondary` instead. |
| **CONTRAST** | Never place Primary Text on a Secondary Background. Use Secondary Text (in outlined containers). |

### 1.3 Code Quality

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

## 3. DATA & TEXT HANDLING (Single Source of Truth)

### 3.1 Text Normalization
**Location:** `lib/core/utils/text_normalizer.dart`

**ALWAYS** use `TextNormalizer` for:
- Title casing with lowercase connectors → `TextNormalizer.cleanName()`
- Simple title case → `TextNormalizer.toTitleCase()`
- Fraction parsing (text + decimal to unicode) → `TextNormalizer.normalizeFractions()`

```dart
// ✅ CORRECT
TextNormalizer.cleanName('olive oil, ');        // → "Olive Oil"
TextNormalizer.normalizeFractions('1/2 cup');   // → "½ cup"
TextNormalizer.normalizeFractions('0.333 tsp'); // → "⅓ tsp"

// ❌ FORBIDDEN - Do NOT write ad-hoc regex for these operations
text[0].toUpperCase() + text.substring(1)  // Use TextNormalizer instead
text.replaceAll('1/2', '½')                // Use TextNormalizer instead
```

### 3.2 Unit Normalization
**Location:** `lib/core/utils/unit_normalizer.dart`

**ALWAYS** use `UnitNormalizer` for standardizing measurement units:

```dart
UnitNormalizer.normalize('tablespoons')  // → "Tbsp"
UnitNormalizer.normalize('cups')         // → "C"
UnitNormalizer.normalize('grams')        // → "g"
UnitNormalizer.normalizeTime('1 hour 30 minutes')  // → "1h 30m"
UnitNormalizer.normalizeServes('Serves 4 people')  // → "4"
```

### 3.3 Import Pipeline
All text from OCR, URL imports, QR codes, or deep links **MUST** pass through these normalizers before saving:

```
Raw Input → TextNormalizer.cleanName() → UnitNormalizer.normalize() → Save to DB
```

**Key Files:**
- `lib/core/utils/ingredient_parser.dart` — Parsing coordinator (delegates to normalizers)
- `lib/core/services/url_importer.dart` — URL recipe extraction
- `lib/features/import/services/ocr_importer.dart` — OCR text processing

---

## 4. UI COMPONENTS & DESIGN SYSTEM

### 4.1 Header Component
All detail views **MUST** use the shared `MemoixHeader` widget from `lib/shared/widgets/memoix_header.dart`.

**DO NOT:**
* Build inline headers in detail screens
* Create custom app bar actions

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

### 4.2 SnackBars (User Feedback)
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

### 4.3 Color System

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
MemoixColors.forCuisine('Korean')
MemoixColors.forCourse('mains')
MemoixColors.forSpiritDot('Gin')
MemoixColors.forPizzaBaseDot('marinara')
MemoixColors.forSmokedItemDot('beef')
```

#### Forbidden Patterns
```dart
// ❌ FORBIDDEN
Colors.red / Colors.blue / Colors.green / Colors.orange
Color(0xFF4B5563)  // Hardcoded hex in widgets
theme.colorScheme.primary  // for domain data like cuisine dots
```

**Exception:** `Colors.grey` is acceptable as a fallback in `MemoixColors` lookup methods.

---

## 5. VIEW ARCHITECTURE

### 5.1 Split/Side-by-Side View Layout
The split view uses a **fixed-height container** (`SizedBox`) to allow footer content (Notes, Gallery, Nutrition) to scroll below.

**Height Calculation:**
* **Mobile (<600px):** ~70% of screen, clamped 300-550px
* **Tablet (≥600px):** ~75-85% of screen, clamped 400-700px

**Pattern:**
```dart
SizedBox(
  height: splitViewHeight,  // Fixed height, NOT Expanded
  child: Row(
    children: [
      Expanded(child: _IngredientsColumn(...)),  // Independent scroll
      VerticalDivider(...),
      Expanded(child: _DirectionsColumn(...)),   // Independent scroll
    ],
  ),
)
// Footer content sits BELOW the SizedBox
```

**DO NOT:**
* Use `Expanded` for the split container (prevents footer scrolling)
* Place footer sections inside the split columns

### 5.2 The "Physical Item" Input Pattern
**Applies to:** Wood (Smoking), Glass/Garnish (Drinks), Equipment (Modernist)

**UI Behavior:**
* **Autocomplete Dropdown:** User types, sees existing suggestions
* **Free-form Entry:** User can type a new item not in the list
* **Chip Display:** Selected items appear as actionable chips
* **NO Enums:** Never restrict these fields to a hardcoded Enum with an "Other" option

---

## 6. FEATURE ARCHITECTURE

### 6.1 Recipe Pairing
Pairings use **parent-side storage only**. Inverse logic is handled by the View.

* **Field:** `List<String> pairedRecipeIds = []`
* **Location:** `lib/features/recipes/models/recipe.dart`
* **Display:** Detail screens show both explicit pairings AND inverse pairings (recipes that link to the current recipe)

**DEPRECATED:** The `pairsWith` field is deprecated. Use `pairedRecipeIds` for all new code.

### 6.2 Kitchen Timer / Alarms
**Location:** `lib/features/tools/timer_service.dart`

* Alarms are managed by `TimerService` (singleton via Riverpod)
* Alarms must persist across app restarts (stored in SharedPreferences)
* UI in `lib/features/tools/kitchen_timer_screen.dart`

### 6.3 Domain Schema Types

#### Type A: Standard Recipe (Recipe Model)
* **Use for:** Mains, Desserts, Drinks, Baking, Modernist, Smoking
* **Base Fields:** name, ingredients (List), directions (List), serves, time
* **Expansion:** Add optional/nullable fields to Recipe model

#### Type B: Component Assembly (Pizza Model, etc.)
* **Use for:** Pizzas, Sandwiches, Charcuterie Boards
* **Concept:** No single "Directions" list - assembly of discrete sub-recipes
* **Structure:** `base` + `components` + optional `sub_recipes`

---

## 7. PROJECT STRUCTURE

### 7.1 Feature Pattern (Vertical Slice)
```text
lib/features/<feature_name>/
├── models/      # Isar collections (@collection)
├── screens/     # Full page widgets (Scaffolds)
├── widgets/     # Feature-specific components
├── repository/  # Data access (Providers go here)
└── services/    # Business logic (Parsers, Validators)
```

### 7.2 Core Locations
| Path | Purpose |
|------|---------|
| `lib/app/theme/` | Theme and MemoixColors |
| `lib/app/routes/router.dart` | Static routing helpers (AppRoutes) |
| `lib/core/database/database.dart` | MemoixDatabase schema registration |
| `lib/core/utils/` | **TextNormalizer, UnitNormalizer, IngredientParser** |
| `lib/core/widgets/` | Shared widgets (MemoixSnackBar, etc.) |
| `lib/core/services/` | Shared services (url_importer.dart, deep_link_service.dart) |
| `lib/shared/widgets/` | Cross-feature UI (MemoixHeader, etc.) |

### 7.3 Protocol for Adding New Features
1. **Create Structure:** Add `lib/features/<new_type>/`
2. **Define Model:** Create model with `@collection`
3. **Register Schema:** Add to `MemoixDatabase.initialize()` in `lib/core/database/database.dart`
4. **Define Routes:** Add static `to<Feature>List` and `to<Feature>Detail` methods in `AppRoutes`
5. **Assign Color:** Add domain color to `MemoixColors` in `colors.dart`
