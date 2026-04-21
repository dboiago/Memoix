# AGENTS.md - Context & Rules for Memoix

---

## 1. CRITICAL CONSTRAINTS (Non-Negotiable)

These rules apply to ALL code. Violations will require rework.

### 1.1 Security, Privacy & Input Validation

| Rule | Details |
|------|---------|
| **NO CLIPBOARD SNIFFING** | Never use `Clipboard.getData()` in the background or on app resume. All imports are manual/opt-in via the UI. |
| **SMART PASTE EXTRACTION** | URL text fields must accept raw text dumps and extract `memoix://` or `http://` links using strict Regex. |
| **HTTP RESPONSE LIMITS** | All HTTP fetches MUST enforce a **10 MB** limit via stream counting. Use `StreamedResponse` and abort if `bytesRead > _maxResponseBytes`. |
| **HTTP TIMEOUTS** | All HTTP requests MUST enforce a timeout (10 seconds max). Catch `TimeoutException` and abort cleanly. |
| **CONTENT-TYPE CHECK** | Reject binary types (`application/pdf`, `image/*`, `video/*`, `application/zip`) immediately upon header receipt. Do NOT download the body. |
| **URL SCHEME VALIDATION** | Only allow `http://`, `https://`, and `memoix://` schemes. Reject `file://`, `javascript://`, `content://`, `data://`. |
| **QR/DEEP LINK LIMITS** | Maximum encoded data length: **4,096 characters**. Reject oversized payloads before parsing. |
| **RECIPE VALIDATION** | Before saving imported recipes: `name.trim().isNotEmpty` AND (`ingredients.isNotEmpty` OR `directions.isNotEmpty`). |

### 1.2 Visual Design & Language

| Rule | Details |
|------|---------|
| **CANADIAN ENGLISH** | Use Canadian spelling (colour, flavour, savoury, centre) for ALL UI text, comments, and custom variables. Do NOT modify Flutter's underlying APIs (e.g., keep `Color()`). |
| **NO ICONS / NO EMOJIS** | Do not add decorative icons (🍕, 🗑️) to headers, titles, or buttons unless explicitly requested. |
| **MAINS IS BASELINE** | The "Mains" screen defines canonical spacing, padding, and font sizes. Do not "improve" layouts. |
| **DESTRUCTIVE ACTIONS** | Never use `Colors.red` or `error` for delete buttons. Use `theme.colorScheme.secondary` instead. |
| **CONTRAST** | Never place Primary Text on a Secondary Background. Use Secondary Text (in outlined containers). |

### 1.3 Code Quality & Database (Drift)

| Rule | Details |
|------|---------|
| **DRIFT UPSERTS** | Always use `onConflict: DoUpdate((old) => row, target: [table.uuid])` for tables keyed by UUID. UUID must be present and unique. Do not rely on default helpers that assume integer primary keys. |
| **COMPANION UUIDS** | When creating new entities, always assign `uuid: Value(const Uuid().v4())`. Never regenerate UUIDs for existing records during updates. |
| **SEARCH FIRST** | Before writing a helper, search the codebase for existing implementations. |
| **STRICT TYPING** | Avoid `dynamic`. Use explicit models. |

### 1.4 AI Integration

| Rule | Details |
|------|---------|
| **EXPLICIT INVOCATION** | AI must ONLY run from direct, deliberate user actions (e.g., tapping a specific button or long-press). |
| **NO BACKGROUND AI** | Do not trigger AI calls implicitly, via background tasks, or on app lifecycle events. |
| **FAIL CLEANLY** | Handle all API errors, rate limits, and missing keys gracefully without blocking core offline functionality. |

---

## 2. CORE PHILOSOPHY

**Memoix** is a professional-grade recipe management app for **chefs and serious hobbyists** (NOT casual home cooks).

* **Stack:** Flutter 3.x, Riverpod (State Management), Drift/SQLite (Offline DB), Google ML Kit (OCR)
* **Aesthetic:** Minimalist, data-dense, utilitarian. **NO decorative elements.**
* **Philosophy:** Offline-first, strictly opt-in privacy, no user accounts.

---

## 3. DATA & TEXT HANDLING (Single Source of Truth)

### 3.1 Text Normalization
**Location:** `lib/core/utils/text_normalizer.dart`

**ALWAYS** use `TextNormalizer` for:
- Title casing with lowercase connectors → `TextNormalizer.cleanName()`
- Fraction parsing (text + decimal to unicode) → `TextNormalizer.normalizeFractions()`

### 3.2 Pluralization & Mass Nouns
**Location:** `lib/features/shopping_list/models/shopping_list_item.dart` (or `ingredient_categorizer.dart`)

- Words ending in 's' are assumed to be already plural (e.g., bananas) or mass nouns (e.g., asparagus, molasses) and should **not** have 'es' appended.
- Uncountable herbs/spices (e.g., 'mint', 'garlic') must be added to the `_pluralExceptions` map with a `null` value to prevent pluralization.

### 3.3 Unit Normalization
**Location:** `lib/core/utils/unit_normalizer.dart`

**ALWAYS** use `UnitNormalizer` for standardizing measurement units:
```dart
UnitNormalizer.normalize('tablespoons')  // → "Tbsp"
UnitNormalizer.normalize('cups')         // → "C"
UnitNormalizer.normalize('grams')        // → "g"
```

### 3.4 Import Pipeline
All text from OCR, URL imports, QR codes, or deep links **MUST** pass through these normalizers before saving:
```text
Raw Input → TextNormalizer.cleanName() → UnitNormalizer.normalize() → Save to DB
```

---

## 4. UI COMPONENTS & DESIGN SYSTEM

### 4.1 Header Component
All detail views **MUST** use the shared `MemoixHeader` widget from `lib/shared/widgets/memoix_header.dart`.
**DO NOT:** Build inline headers or custom app bar actions in detail screens.

### 4.2 SnackBars (User Feedback)
All SnackBars **MUST** use `MemoixSnackBar` from `lib/core/widgets/memoix_snackbar.dart`.
**DO NOT:** Instantiate raw `SnackBar()` widgets or call `ScaffoldMessenger.of(context)` directly.

### 4.3 Colour System
Use `theme.colorScheme.primary` and `theme.colorScheme.secondary` (Mauve/Warm accents).
Use `MemoixColours` (note the Canadian spelling if refactored) for data-driven indicator dots.
**FORBIDDEN:** Hardcoded hex codes like `Color(0xFF4B5563)` or bare `Colors.red`.

---

## 5. VIEW ARCHITECTURE

### 5.1 Split/Side-by-Side View Layout
The split view uses a **fixed-height container** (`SizedBox`) to allow footer content (Notes, Gallery, Nutrition) to scroll below.
**DO NOT:** Use `Expanded` for the split container (prevents footer scrolling).

### 5.2 The "Physical Item" Input Pattern
**Applies to:** Wood (Smoking), Glass/Garnish (Drinks), Equipment (Modernist)
**Behaviour:** Autocomplete Dropdown + Free-form Entry. **NO Enums.**

---

## 6. FEATURE ARCHITECTURE

### 6.1 Recipe Pairing
Pairings use **parent-side storage only**.
* **Field:** `List<String> pairedRecipeIds = []` (Deprecated: `pairsWith`)
* **Display:** Detail screens show explicit AND inverse pairings.

### 6.2 Domain Schema Types
* **Type A (Standard):** Mains, Desserts, Drinks, Baking, Modernist, Smoking (Uses Directions List).
* **Type B (Component):** Pizzas, Sandwiches, Charcuterie (Uses Base + Components + Sub-recipes).

---

## 7. PROJECT STRUCTURE

### 7.1 Feature Pattern (Vertical Slice)
```text
lib/features/<feature_name>/
├── models/      # Drift Tables & DAOs
├── screens/     # Full page widgets (Scaffolds)
├── widgets/     # Feature-specific components
├── repository/  # Data access (Providers go here)
└── services/    # Business logic (Parsers, Validators)
```

### 7.2 Core Locations
| Path | Purpose |
|------|---------|
| `lib/app/theme/` | Theme and MemoixColours |
| `lib/core/database/` | Drift Database definition (`app_database.dart`) |
| `lib/core/utils/` | TextNormalizer, UnitNormalizer, IngredientParser |
| `lib/core/widgets/` | Shared widgets (MemoixSnackBar, etc.) |
| `lib/core/services/` | Shared services (url_importer.dart, deep_link_service.dart) |