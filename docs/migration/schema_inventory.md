# Phase 1 — Detailed Field Inventory

Here is the audit of all fields in the `@Collection` class in the file `cellar_entry.dart`:

| Class Name   | Field Name     | Dart Type         | Nullable | Annotations                          |
|--------------|----------------|-------------------|----------|---------------------------------------|
| CellarEntry  | id             | Id                | No       | @Id                                   |
| CellarEntry  | uuid           | String            | No       | @Index(unique: true, replace: true)   |
| CellarEntry  | name           | String            | No       | @Index(type: IndexType.value)         |
| CellarEntry  | producer       | String?           | Yes      |                                       |
| CellarEntry  | category       | String?           | Yes      |                                       |
| CellarEntry  | buy            | bool              | No       |                                       |
| CellarEntry  | tastingNotes   | String?           | Yes      |                                       |
| CellarEntry  | abv            | String?           | Yes      |                                       |
| CellarEntry  | ageVintage     | String?           | Yes      |                                       |
| CellarEntry  | priceRange     | int?              | Yes      |                                       |
| CellarEntry  | imageUrl       | String?           | Yes      |                                       |
| CellarEntry  | source         | CellarSource      | No       | @Enumerated(EnumType.name)            |
| CellarEntry  | isFavorite     | bool              | No       |                                       |
| CellarEntry  | createdAt      | DateTime          | No       |                                       |
| CellarEntry  | updatedAt      | DateTime          | No       |                                       |
| CellarEntry  | version        | int               | No       |                                       |

No `@Embedded` classes were found in this file.

Here is the audit of all fields in the `@Collection` class in the file `cheese_entry.dart`:

| Class Name   | Field Name     | Dart Type         | Nullable | Annotations                          |
|--------------|----------------|-------------------|----------|---------------------------------------|
| CheeseEntry  | id             | Id                | No       | @Id                                   |
| CheeseEntry  | uuid           | String            | No       | @Index(unique: true, replace: true)   |
| CheeseEntry  | name           | String            | No       | @Index(type: IndexType.value)         |
| CheeseEntry  | country        | String?           | Yes      |                                       |
| CheeseEntry  | milk           | String?           | Yes      |                                       |
| CheeseEntry  | texture        | String?           | Yes      |                                       |
| CheeseEntry  | type           | String?           | Yes      |                                       |
| CheeseEntry  | buy            | bool              | No       |                                       |
| CheeseEntry  | flavour        | String?           | Yes      |                                       |
| CheeseEntry  | priceRange     | int?              | Yes      |                                       |
| CheeseEntry  | imageUrl       | String?           | Yes      |                                       |
| CheeseEntry  | source         | CheeseSource      | No       | @Enumerated(EnumType.name)            |
| CheeseEntry  | isFavorite     | bool              | No       |                                       |
| CheeseEntry  | createdAt      | DateTime          | No       |                                       |
| CheeseEntry  | updatedAt      | DateTime          | No       |                                       |
| CheeseEntry  | version        | int               | No       |                                       |

No `@Embedded` classes were found in this file.

Here is the audit of all fields in the `@Collection` and `@Embedded` classes in the file `meal_plan.dart`:

| Class Name   | Field Name     | Dart Type         | Nullable | Annotations                          |
|--------------|----------------|-------------------|----------|---------------------------------------|
| PlannedMeal  | instanceId     | String?           | Yes      |                                       |
| PlannedMeal  | recipeId       | String?           | Yes      |                                       |
| PlannedMeal  | recipeName     | String?           | Yes      |                                       |
| PlannedMeal  | course         | String?           | Yes      |                                       |
| PlannedMeal  | notes          | String?           | Yes      |                                       |
| PlannedMeal  | servings       | int?              | Yes      |                                       |
| PlannedMeal  | cuisine        | String?           | Yes      |                                       |
| PlannedMeal  | recipeCategory | String?           | Yes      |                                       |
| MealPlan     | id             | Id                | No       | @Id                                   |
| MealPlan     | date           | String            | No       | @Index(unique: true)                  |
| MealPlan     | meals          | List<PlannedMeal> | No       |                                       |

No additional `@Embedded` or `@Collection` classes were found in this file.

Here is the audit of all fields in the `@Collection` and `@Embedded` classes in the file `scratch_pad.dart`:

| Class Name        | Field Name             | Dart Type              | Nullable | Annotations                          |
|-------------------|------------------------|------------------------|----------|---------------------------------------|
| ScratchPad        | id                    | Id                     | No       | @Id                                   |
| ScratchPad        | quickNotes            | String                 | No       |                                       |
| ScratchPad        | updatedAt             | DateTime               | No       |                                       |
| DraftIngredient   | name                  | String                 | No       |                                       |
| DraftIngredient   | quantity              | String?                | Yes      |                                       |
| DraftIngredient   | unit                  | String?                | Yes      |                                       |
| DraftIngredient   | preparation           | String?                | Yes      |                                       |
| RecipeDraft       | id                    | Id                     | No       | @Id                                   |
| RecipeDraft       | uuid                  | String                 | No       | @Index(unique: true, replace: true)   |
| RecipeDraft       | name                  | String                 | No       |                                       |
| RecipeDraft       | imagePath             | String?                | Yes      |                                       |
| RecipeDraft       | serves                | String?                | Yes      |                                       |
| RecipeDraft       | time                  | String?                | Yes      |                                       |
| RecipeDraft       | course                | String                 | No       |                                       |
| RecipeDraft       | structuredIngredients | List<DraftIngredient>  | No       |                                       |
| RecipeDraft       | structuredDirections  | List<String>           | No       |                                       |
| RecipeDraft       | legacyIngredients     | String?                | Yes      |                                       |
| RecipeDraft       | legacyDirections      | String?                | Yes      |                                       |
| RecipeDraft       | notes                 | String                 | No       |                                       |
| RecipeDraft       | stepImages            | List<String>           | No       |                                       |
| RecipeDraft       | stepImageMap          | List<String>           | No       |                                       |
| RecipeDraft       | pairedRecipeIds       | List<String>           | No       |                                       |
| RecipeDraft       | createdAt             | DateTime               | No       |                                       |
| RecipeDraft       | updatedAt             | DateTime               | No       |                                       |
| RecipeDraft       | ingredients           | String                 | No       | @ignore                               |
| RecipeDraft       | directions            | String                 | No       | @ignore                               |
| RecipeDraft       | comments              | String                 | No       | @ignore                               |

Here is the audit of all fields in the `@Collection` and `@Embedded` classes in the file `pizza.dart`:

| Class Name   | Field Name     | Dart Type         | Nullable | Annotations                          |
|--------------|----------------|-------------------|----------|---------------------------------------|
| Pizza        | id             | Id                | No       | @Id                                   |
| Pizza        | uuid           | String            | No       | @Index(unique: true, replace: true)   |
| Pizza        | name           | String            | No       | @Index(type: IndexType.value)         |
| Pizza        | base           | PizzaBase         | No       | @Enumerated(EnumType.name)            |
| Pizza        | cheeses        | List<String>      | No       |                                       |
| Pizza        | proteins       | List<String>      | No       |                                       |
| Pizza        | vegetables     | List<String>      | No       |                                       |
| Pizza        | notes          | String?           | Yes      |                                       |
| Pizza        | imageUrl       | String?           | Yes      |                                       |
| Pizza        | source         | PizzaSource       | No       | @Enumerated(EnumType.name)            |
| Pizza        | isFavorite     | bool              | No       |                                       |
| Pizza        | cookCount      | int               | No       |                                       |
| Pizza        | rating         | int               | No       |                                       |
| Pizza        | tags           | List<String>      | No       |                                       |
| Pizza        | createdAt      | DateTime          | No       |                                       |
| Pizza        | updatedAt      | DateTime          | No       |                                       |
| Pizza        | version        | int               | No       |                                       |

No `@Embedded` classes were found in this file.

Here is the audit of all fields in the `@Collection` and `@Embedded` classes in the file `course.dart`:

| Class Name   | Field Name  | Dart Type | Nullable | Annotations                          |
|--------------|-------------|-----------|----------|---------------------------------------|
| Course       | id          | Id        | No       | @Id                                   |
| Course       | slug        | String    | No       | @Index(unique: true, replace: true)   |
| Course       | name        | String    | No       |                                       |
| Course       | iconName    | String?   | Yes      |                                       |
| Course       | sortOrder   | int       | No       |                                       |
| Course       | colorValue  | int       | No       |                                       |
| Course       | isVisible   | bool      | No       |                                       |
| Course       | color       | Color     | No       | @ignore                               |

No `@Embedded` classes were found in this file.

Here is the audit of all fields in the `@Collection` and `@Embedded` classes in the file `shopping_list.dart`:

| Class Name     | Field Name     | Dart Type         | Nullable | Annotations                          |
|----------------|----------------|-------------------|----------|---------------------------------------|
| ShoppingItem   | uuid           | String            | No       |                                       |
| ShoppingItem   | name           | String            | No       |                                       |
| ShoppingItem   | amount         | String?           | Yes      |                                       |
| ShoppingItem   | unit           | String?           | Yes      |                                       |
| ShoppingItem   | category       | String?           | Yes      |                                       |
| ShoppingItem   | recipeSource   | String?           | Yes      |                                       |
| ShoppingItem   | isChecked      | bool              | No       |                                       |
| ShoppingItem   | manualNotes    | String?           | Yes      |                                       |
| ShoppingList   | id             | Id                | No       | @Id                                   |
| ShoppingList   | uuid           | String            | No       | @Index(unique: true, replace: true)   |
| ShoppingList   | name           | String            | No       |                                       |
| ShoppingList   | items          | List<ShoppingItem>| No       |                                       |
| ShoppingList   | createdAt      | DateTime          | No       |                                       |
| ShoppingList   | completedAt    | DateTime?         | Yes      |                                       |
| ShoppingList   | recipeIds      | List<String>      | No       |                                       |
| ShoppingList   | groupedItems   | Map<String, List<ShoppingItem>> | No | @ignore                               |

No additional `@Embedded` or `@Collection` classes were found in this file.

Here is the audit of all fields in the `@Collection` and `@Embedded` classes in the file `cooking_stats.dart`:

| Class Name   | Field Name     | Dart Type   | Nullable | Annotations         |
|--------------|----------------|-------------|----------|---------------------|
| CookingLog   | id             | Id          | No       | @Id                |
| CookingLog   | recipeId       | String      | No       | @Index             |
| CookingLog   | recipeName     | String      | No       |                     |
| CookingLog   | recipeCourse   | String?     | Yes      |                     |
| CookingLog   | recipeCuisine  | String?     | Yes      |                     |
| CookingLog   | cookedAt       | DateTime    | No       | @Index             |
| CookingLog   | notes          | String?     | Yes      |                     |
| CookingLog   | servingsMade   | int?        | Yes      |                     |

No `@Embedded` classes were found in this file.

Here is the audit of all fields in the `@Collection` and `@Embedded` classes in the file `sandwich.dart`:

| Class Name   | Field Name     | Dart Type         | Nullable | Annotations                          |
|--------------|----------------|-------------------|----------|---------------------------------------|
| Sandwich     | id             | Id                | No       | @Id                                   |
| Sandwich     | uuid           | String            | No       | @Index(unique: true, replace: true)   |
| Sandwich     | name           | String            | No       | @Index(type: IndexType.value)         |
| Sandwich     | bread          | String            | No       |                                       |
| Sandwich     | proteins       | List<String>      | No       |                                       |
| Sandwich     | vegetables     | List<String>      | No       |                                       |
| Sandwich     | cheeses        | List<String>      | No       |                                       |
| Sandwich     | condiments     | List<String>      | No       |                                       |
| Sandwich     | notes          | String?           | Yes      |                                       |
| Sandwich     | imageUrl       | String?           | Yes      |                                       |
| Sandwich     | source         | SandwichSource    | No       | @Enumerated(EnumType.name)            |
| Sandwich     | isFavorite     | bool              | No       |                                       |
| Sandwich     | cookCount      | int               | No       |                                       |
| Sandwich     | rating         | int               | No       |                                       |
| Sandwich     | tags           | List<String>      | No       |                                       |
| Sandwich     | createdAt      | DateTime          | No       |                                       |
| Sandwich     | updatedAt      | DateTime          | No       |                                       |
| Sandwich     | version        | int               | No       |                                       |

No `@Embedded` classes were found in this file.