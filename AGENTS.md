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
