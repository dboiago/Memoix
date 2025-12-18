#### AGENTS.md - Context & Rules for Memoix

## 1. Project Context
**Memoix** is a professional-grade recipe management app for **chefs and serious hobbyists** (NOT casual home cooks).
* **Stack:** Flutter 3.x, Riverpod (State Management), Isar (Offline DB), Google ML Kit (OCR).
* **Aesthetic:** Minimalist, data-dense, utilitarian. **NO decorative elements.**
* **Philosophy:** Offline-first, privacy-focused, no user accounts.

## 2. CRITICAL RULES (Non-Negotiable)

### 2.1 Visual Design & UI
* **NO ICONS / NO EMOJIS:** Do not add decorative icons (e.g., 🍕, 🗑️) to headers, titles, or buttons unless explicitly requested.
* **MAINS IS BASELINE:** The "Mains" screen defines canonical spacing, padding, and font sizes. Do not "improve" layouts by adding cards or changing margins without instruction.
* **DESTRUCTIVE ACTIONS:**
    * **Never use Red:** Do not use `Colors.red` or `error` color for delete buttons (it is too aggressive).
    * **Use Secondary:** Use `Theme.of(context).colorScheme.secondary` for delete/remove actions.
* **CONTRAST:** Never place Primary Text on a Secondary Background. Use Secondary Text (often in an outlined container).

### 2.2 Color Usage (Strict Separation)
* **UI Elements (Buttons, Backgrounds):** Use `Theme.of(context).colorScheme`.
* **Domain Data (Cuisines, Courses, Tags):** Use **`MemoixColors`** from `lib/app/theme/colors.dart`.
    * *Example:* `MemoixColors.forCuisine('Korean')` or `MemoixColors.spiritGin`.
    * *Never* hardcode hex values or standard `Colors.blue`.
* **FilterChip Pattern:** FilterChips are UI elements - use `theme.colorScheme.secondary` for `selectedColor`, `side`, and `labelStyle`. To show domain color, add an `avatar` with a colored dot using `MemoixColors`. See `smoking_list_screen.dart` for reference.

### 2.3 Code Efficiency
* **Search First:** Before writing a helper, search the codebase.
* **Strict Typing:** Avoid `dynamic`. Use explicit models (`Recipe`, `Pizza`, `Ingredient`).
* **Providers:**
    * Use `databaseProvider` for Isar instances (NOT `isarProvider`).
    * Use `ref.read` for actions, `ref.watch` for build methods.

## 3. Project Structure

### 3.1 Feature Pattern (Vertical Slice)
* **All features (e.g., `recipes`, `pizzas`, `shopping`) follow this structure:**
```text
lib/features/<feature_name>/
├── models/      # Isar collections (@collection)
├── screens/     # Full page widgets (Scaffolds)
├── widgets/     # Feature-specific components
├── repository/  # Data access (Providers go here)
└── services/    # Business logic (Parsers, Validators)
```

### 3.2 Core Locations
* **Theme/Colors:** lib/app/theme/ (See colors.dart for domain palette)
* **Navigation:** lib/app/routes/router.dart (Static routing helpers)
* **Database Init:** lib/core/database/database.dart (Schema registration)
* **Shared Logic:** lib/core/services/ (e.g., url_importer.dart)

## 4. Architecture & Patterns

### 4.1 URL Import (Strategy Pattern)
*   **Goal:** Prevent monolithic files. Support generic and site-specific logic. The Pattern:
```dart
abstract class RecipeParser {
  /// Returns score 0-1. 1 = Perfect match (e.g. YouTube), 0 = Cannot parse
  double canParse(String url); 
  
  /// Returns the recipe or throws exception
  Future<Recipe> parse(String html, String url);
}
```
* **Implementation Priority:**
    * Specific Strategy: (e.g., YouTubeParser) if the site requires unique handling (API calls, transcripts).
    * Generic Strategy: (e.g., JsonLdParser, MicrodataParser) for standard sites.
    * Fallback Strategy: (HtmlHeuristicParser) as a last resort.

### 4.2 The "Physical Item" Input Pattern
* **Applies to:** Wood (Smoking), Glass/Garnish (Drinks), Equipment (Modernist). UI Behavior:
* **Autocomplete Dropdown:** User types, sees existing suggestions.
* **Free-form Entry:** User can type a new item not in the list.
* **Chip Display:** Selected items appear as actionable chips.
* **NO Enums:** Never restrict these fields to a hardcoded Enum with an "Other" option.

## 5. Domain Schemas & Future Expansion
* The app distinguishes between "Standard Recipes" (list of steps) and "Component Assemblies" (list of parts). When adding a NEW cuisine type, determine which model it fits.

### 5.1 Type A: Standard Recipe (Recipe Model)
* **Use this for:** Mains, Desserts, Drinks, Baking, Modernist, Smoking.
* **Base Fields:** name, ingredients (List), directions (List), serves, time.
* **How to Expand:**
    * Add new fields to Recipe model (optional/nullable).
    * Use the Recipe collection.
    * *Example:* Baking adds bakerPercent, Drinks adds glass.

### 5.2 Type B: Component Assembly (Pizza Model, etc.)
* **Use this for:** Pizzas, Sandwiches, Charcuterie Boards.
* **Concept:** No single "Directions" list. It is an assembly of discrete sub-recipes or items.
* **Structure:**
    * *base:* Enum or String (Sauce, Bread)
    * *components:* Lists of Strings/Objects (Toppings, Cheeses, Condiments)
    * *sub_recipes:* Embedded objects (Dough, Spread)

### 5.3 Protocol for Adding New Features
* **Create Structure:** Add lib/features/<new_type>/.
* **Define Model:** Create model with @collection.
* **Register Schema:** Add to MemoixDatabase.initialize() in lib/core/database/database.dart.
* **Define Routes:** Add static to<Feature>List and to<Feature>Detail methods in AppRoutes (lib/app/routes/router.dart).
* **Assign Color:** Add domain color to MemoixColors in colors.dart.

## 6. Shared UI Patterns

### 6.1 Header Component
All detail views **MUST** use the shared `MemoixHeader` widget from `lib/shared/widgets/memoix_header.dart`.

**DO NOT:**
* Build inline headers in detail screens
* Use the deprecated `RecipeHeader` widget (scheduled for removal)

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

The header is model-agnostic - it accepts primitive values (strings, bools, callbacks) rather than model types, allowing it to be used across Recipe, Modernist, Pizza, Sandwich, Smoking, Cellar, and Cheese detail screens.

### 6.2 Split/Side-by-Side View Layout
The split view uses a fixed-height container strategy to allow footer content (Notes, Gallery, Nutrition) to scroll below.

**Pattern:**
```dart
SizedBox(
  height: splitViewHeight, // 85% of screen, clamped 400-900px
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
* Use Expanded for the split container (prevents footer scrolling)
* Place footer sections inside the split columns

### 6.3 Recipe Pairing
Recipe pairings are stored in pairedRecipeIds on the Recipe model (and ModernistRecipe).

* Field: List<String> pairedRecipeIds = []
* Location: recipe.dart
* Bidirectional: Detail screens show both explicit pairings AND inverse pairings (recipes that link to the current recipe)

**DEPRECATED:** The pairsWith field is deprecated. Use pairedRecipeIds for all new code.

### 6.4 SnackBars (User Feedback)
All SnackBars **MUST** use the centralized `MemoixSnackBar` helper from `lib/core/widgets/memoix_snackbar.dart`.

**STRICTLY FORBIDDEN:**
* Do NOT instantiate raw `SnackBar()` widgets
* Do NOT call `ScaffoldMessenger.of(context).showSnackBar()` directly

**REQUIRED - Always use MemoixSnackBar methods:**
```dart
// Simple message (auto-dismiss 2s)
MemoixSnackBar.show('Item added to list');

// Success message
MemoixSnackBar.showSuccess('Recipe imported!');

// Error message
MemoixSnackBar.showError('Failed to save');

// With action button (auto-dismiss 2s)
MemoixSnackBar.showWithAction(
  message: 'Recipe deleted',
  actionLabel: 'Undo',
  onAction: () => ...,
);

// Specialized: "I made this" pattern
MemoixSnackBar.showLoggedCook(
  recipeName: recipe.name,
  onViewStats: () => AppRoutes.toStatistics(context),
);

// Specialized: After save pattern
MemoixSnackBar.showSaved(
  itemName: recipe.name,
  actionLabel: 'View',
  onView: () => AppRoutes.toRecipeDetail(context, uuid: recipe.uuid),
);
```

**Why:** The helper uses a global `ScaffoldMessengerKey` that survives navigation, includes manual Timer-based auto-dismiss for reliability, and ensures consistent styling.

## 7. Strict Color Conventions

### 7.1 UI Elements (Theme Colors)
For all UI chrome (buttons, backgrounds, borders, text):
```dart
// ✅ CORRECT
Theme.of(context).colorScheme.primary
Theme.of(context).colorScheme.secondary
Theme.of(context).colorScheme.surface
Theme.of(context).colorScheme.onSurface
Theme.of(context).colorScheme.onSurfaceVariant
Theme.of(context).colorScheme.outline
```

### 7.2 Domain Data (MemoixColors)
For data-driven visual indicators (cuisine dots, course badges, spirit colors):
```dart
// ✅ CORRECT - Use MemoixColors static methods
MemoixColors.forCuisine('Korean')           // Cuisine-specific color
MemoixColors.forContinentDot('Japanese')    // Continent-grouped dot color
MemoixColors.forCourse('mains')             // Course category color
MemoixColors.forSpiritDot('Gin')            // Drink spirit color
MemoixColors.forPizzaBaseDot('marinara')    // Pizza sauce color
MemoixColors.forSmokedItemDot('beef')       // Smoking category color
MemoixColors.forModernistType('technique')  // Modernist type color
MemoixColors.forProteinDot('chicken')       // Protein type color

// ✅ CORRECT - Direct color constants
MemoixColors.spiritGin
MemoixColors.continentAsian
MemoixColors.pizzaMarinara
```

### 7.3 Forbidden Patterns
```dart
// ❌ FORBIDDEN - Hardcoded Material colors
Colors.red
Colors.blue
Colors.green
Colors.orange

// ❌ FORBIDDEN - Hardcoded hex values in widgets
Color(0xFF4B5563)  // Define in theme or MemoixColors instead

// ❌ FORBIDDEN - Using theme colors for domain data
theme.colorScheme.primary  // for a cuisine indicator dot
```

### 7.4 Exception: Semantic Status Colors
For universal status indicators (success/error states during import, confidence scores), use theme semantic colors:
```dart
// ✅ ACCEPTABLE for status indicators only
theme.colorScheme.error          // For errors
theme.colorScheme.errorContainer // For error backgrounds
// Consider adding MemoixColors.success / MemoixColors.warning for consistency
```
