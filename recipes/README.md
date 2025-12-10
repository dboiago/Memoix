# Memoix Recipe Data

This folder contains the official Memoix recipe collection.

## Structure

```
recipes/
├── index.json          # List of all recipe files
├── version.json        # Current data version for sync
├── mains.json          # Main course recipes
├── apps.json           # Appetizers
├── soups.json          # Soups
├── sides.json          # Side dishes
├── desserts.json       # Desserts
├── brunch.json         # Brunch recipes
├── breads.json         # Bread recipes
├── sauces.json         # Sauces and dressings
├── pickles.json        # Pickles and brines
└── ...                 # Other categories
```

## Adding Recipes

1. Edit the appropriate category JSON file
2. Follow the recipe schema (see below)
3. Increment version in `version.json`
4. Commit and push to GitHub

## Recipe Schema

```json
{
  "uuid": "unique-id-here",
  "name": "Recipe Name",
  "course": "mains",
  "cuisine": "Korean",
  "subcategory": null,
  "serves": "4-5 people",
  "time": "40 min",
  "pairsWith": ["KFC Sauce"],
  "notes": "Optional notes",
  "ingredients": [
    {
      "name": "Ingredient Name",
      "amount": "1 cup",
      "preparation": "diced",
      "alternative": "alt: other ingredient",
      "isOptional": false,
      "section": "For the sauce"
    }
  ],
  "directions": [
    "Step 1...",
    "Step 2..."
  ],
  "sourceUrl": null,
  "imageUrl": null,
  "tags": ["quick", "easy"],
  "version": 1
}
```
