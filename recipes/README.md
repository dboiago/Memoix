# Memoix Recipe Data

This folder contains the official Memoix recipe collection.

## Structure

```
recipes/
├── index.json          # List of all recipe files
├── version.json        # Current data version for sync
├── mains.json          # Main course recipes
├── apps.json           # Appetizers
├── soup.json           # Soups
├── sides.json          # Side dishes
├── desserts.json       # Desserts
├── brunch.json         # Brunch recipes
├── breads.json         # Bread recipes
├── sauces.json         # Sauces and dressings
├── rubs.json           # Spice rubs
├── pickles.json        # Pickles and brines
├── pizzas.json         # Pizza recipes
├── sandwiches.json     # Sandwiches
├── smoking.json        # Smoked recipes
├── cheese.json         # Cheese recipes
├── modernist.json      # Modernist gastronomy
├── vegn.json           # Vegetarian/vegan
├── salad.json          # Salads
├── drinks.json         # Drinks & cocktails
└── scratch.json        # Scratch pad/notes
```

## Adding Recipes

1. Edit the appropriate category JSON file
2. Follow the recipe schema (see below)
3. Increment version in `version.json`
4. Commit and push to GitHub

---

## Recipe Schema (Food)

```json
{
  "uuid": "unique-uuid-v4",
  "name": "Recipe Name",
  "course": "mains",
  "cuisine": "KR",
  "subcategory": "Szechuan",
  "serves": "4-5 people",
  "time": "40 min",
  "pairsWith": ["KFC Sauce", "Rice"],
  "notes": "Optional notes or tips",
  "ingredients": [
    {
      "name": "Ingredient Name",
      "amount": "1 cup",
      "unit": null,
      "preparation": "diced",
      "alternative": "or use X",
      "isOptional": false,
      "section": "For the Sauce"
    }
  ],
  "directions": [
    "Step 1 instruction...",
    "Step 2 instruction..."
  ],
  "sourceUrl": null,
  "imageUrl": null,
  "source": "memoix",
  "colorValue": null,
  "isFavorite": false,
  "rating": 0,
  "cookCount": 0,
  "lastCookedAt": null,
  "tags": ["quick", "easy"],
  "createdAt": "2025-12-10T00:00:00.000000",
  "updatedAt": "2025-12-10T00:00:00.000000",
  "version": 1
}
```

---

## Recipe Schema (Drinks/Cocktails)

For drinks, use `subcategory` to specify the **base spirit type**:

```json
{
  "uuid": "unique-uuid-v4",
  "name": "Negroni",
  "course": "drinks",
  "cuisine": "IT",
  "subcategory": "Gin",
  "serves": "1",
  "time": "5 min",
  "pairsWith": [],
  "notes": "Classic Italian aperitivo",
  "ingredients": [
    {
      "name": "Gin",
      "amount": "1 oz",
      "unit": null,
      "preparation": null,
      "alternative": null,
      "isOptional": false,
      "section": null
    },
    {
      "name": "Campari",
      "amount": "1 oz",
      "unit": null,
      "preparation": null,
      "alternative": null,
      "isOptional": false,
      "section": null
    },
    {
      "name": "Sweet Vermouth",
      "amount": "1 oz",
      "unit": null,
      "preparation": null,
      "alternative": null,
      "isOptional": false,
      "section": null
    },
    {
      "name": "Orange peel",
      "amount": "1",
      "unit": null,
      "preparation": "garnish",
      "alternative": null,
      "isOptional": true,
      "section": null
    }
  ],
  "directions": [
    "Add gin, Campari, and sweet vermouth to a mixing glass with ice",
    "Stir until well-chilled",
    "Strain into a rocks glass over a large ice cube",
    "Garnish with an orange peel"
  ],
  "sourceUrl": null,
  "imageUrl": null,
  "source": "memoix",
  "colorValue": null,
  "isFavorite": false,
  "rating": 0,
  "cookCount": 0,
  "lastCookedAt": null,
  "tags": ["classic", "stirred"],
  "createdAt": "2025-12-10T00:00:00.000000",
  "updatedAt": "2025-12-10T00:00:00.000000",
  "version": 1
}
```

---

## Field Reference

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `uuid` | string | ✅ | Unique identifier (UUID v4) |
| `name` | string | ✅ | Recipe name |
| `course` | string | ✅ | Category slug (see Course Values below) |
| `cuisine` | string | ❌ | 2-letter country code (see Cuisine Codes below) |
| `subcategory` | string | ❌ | For food: regional variation. For drinks: spirit type |
| `serves` | string | ❌ | Serving size (e.g., "4-5", "2 people", "1 cocktail") |
| `time` | string | ❌ | Total time (e.g., "40 min", "2 hr") |
| `pairsWith` | array | ❌ | Recipe names this pairs with |
| `notes` | string | ❌ | Tips, variations, or additional notes |
| `ingredients` | array | ✅ | List of ingredient objects |
| `directions` | array | ✅ | List of step strings |
| `sourceUrl` | string | ❌ | Original recipe URL if imported |
| `imageUrl` | string | ❌ | Image URL |
| `source` | string | ❌ | "memoix", "personal", "imported", "ocr", "url" |
| `colorValue` | int | ❌ | Custom color override (hex as int) |
| `isFavorite` | bool | ❌ | Default: false |
| `rating` | int | ❌ | 0-5 stars, default: 0 |
| `cookCount` | int | ❌ | Times cooked, default: 0 |
| `lastCookedAt` | string | ❌ | ISO 8601 datetime |
| `tags` | array | ❌ | String tags for filtering |
| `createdAt` | string | ❌ | ISO 8601 datetime |
| `updatedAt` | string | ❌ | ISO 8601 datetime |
| `version` | int | ❌ | For sync conflict resolution |

### Ingredient Object

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | ✅ | Ingredient name |
| `amount` | string | ❌ | Quantity with unit (e.g., "2 cups", "1 Tbsp") |
| `unit` | string | ❌ | Separate unit (optional, can be in amount) |
| `preparation` | string | ❌ | How to prep (e.g., "diced", "minced") |
| `alternative` | string | ❌ | Substitution note |
| `isOptional` | bool | ❌ | Default: false |
| `section` | string | ❌ | Group header (e.g., "For the Sauce") |

---

## Course Values

Use lowercase slug format for `course`:

| Slug | Display Name |
|------|-------------|
| `apps` | Apps |
| `soup` | Soups |
| `mains` | Mains |
| `vegn` | Veg'n |
| `sides` | Sides |
| `desserts` | Desserts |
| `brunch` | Brunch |
| `drinks` | Drinks |
| `breads` | Breads |
| `sauces` | Sauces |
| `rubs` | Rubs |
| `pickles` | Pickles |
| `modernist` | Modernist |
| `pizzas` | Pizzas |
| `sandwiches` | Sandwiches |
| `smoking` | Smoking |
| `cheese` | Cheese |
| `salad` | Salads |
| `scratch` | Scratch |

---

## Cuisine Codes (2-letter)

Use 2-letter country codes for `cuisine`. The app displays them as adjectives (e.g., "KR" → "Korean").

### Asian
| Code | Country | Display |
|------|---------|---------|
| `KR` | Korea | Korean |
| `JP` | Japan | Japanese |
| `CN` | China | Chinese |
| `TH` | Thailand | Thai |
| `VN` | Vietnam | Vietnamese |
| `IN` | India | Indian |
| `PH` | Philippines | Filipino |
| `ID` | Indonesia | Indonesian |
| `MY` | Malaysia | Malaysian |
| `SG` | Singapore | Singaporean |
| `TW` | Taiwan | Taiwanese |
| `PK` | Pakistan | Pakistani |
| `NP` | Nepal | Nepali |
| `LK` | Sri Lanka | Sri Lankan |
| `BD` | Bangladesh | Bangladeshi |
| `MM` | Myanmar | Burmese |
| `KH` | Cambodia | Cambodian |
| `LA` | Laos | Laotian |
| `MN` | Mongolia | Mongolian |

### European
| Code | Country | Display |
|------|---------|---------|
| `FR` | France | French |
| `IT` | Italy | Italian |
| `ES` | Spain | Spanish |
| `DE` | Germany | German |
| `GB` | United Kingdom | British |
| `GR` | Greece | Greek |
| `PT` | Portugal | Portuguese |
| `PL` | Poland | Polish |
| `RU` | Russia | Russian |
| `SE` | Sweden | Swedish |
| `HU` | Hungary | Hungarian |
| `UA` | Ukraine | Ukrainian |
| `AT` | Austria | Austrian |
| `BE` | Belgium | Belgian |
| `HR` | Croatia | Croatian |
| `CZ` | Czech Republic | Czech |
| `DK` | Denmark | Danish |
| `NL` | Netherlands | Dutch |
| `FI` | Finland | Finnish |
| `IE` | Ireland | Irish |
| `NO` | Norway | Norwegian |
| `RO` | Romania | Romanian |
| `RS` | Serbia | Serbian |
| `CH` | Switzerland | Swiss |
| `GE` | Georgia | Georgian |

### Americas
| Code | Country | Display |
|------|---------|---------|
| `US` | United States | American |
| `MX` | Mexico | Mexican |
| `BR` | Brazil | Brazilian |
| `AR` | Argentina | Argentine |
| `PE` | Peru | Peruvian |
| `CA` | Canada | Canadian |
| `CL` | Chile | Chilean |
| `CO` | Colombia | Colombian |
| `VE` | Venezuela | Venezuelan |

### Caribbean
| Code | Country | Display |
|------|---------|---------|
| `JM` | Jamaica | Jamaican |
| `CU` | Cuba | Cuban |
| `HT` | Haiti | Haitian |
| `DO` | Dominican Republic | Dominican |
| `PR` | Puerto Rico | Puerto Rican |
| `TT` | Trinidad & Tobago | Trinidadian |
| `BB` | Barbados | Barbadian |

### African
| Code | Country | Display |
|------|---------|---------|
| `ET` | Ethiopia | Ethiopian |
| `MA` | Morocco | Moroccan |
| `ZA` | South Africa | South African |
| `EG` | Egypt | Egyptian |
| `NG` | Nigeria | Nigerian |
| `GH` | Ghana | Ghanaian |
| `KE` | Kenya | Kenyan |
| `TN` | Tunisia | Tunisian |

### Middle Eastern
| Code | Country | Display |
|------|---------|---------|
| `TR` | Turkey | Turkish |
| `LB` | Lebanon | Lebanese |
| `IL` | Israel | Israeli |
| `IR` | Iran | Persian |
| `IQ` | Iraq | Iraqi |
| `SY` | Syria | Syrian |
| `JO` | Jordan | Jordanian |
| `PS` | Palestine | Palestinian |
| `SA` | Saudi Arabia | Saudi |
| `YE` | Yemen | Yemeni |
| `AF` | Afghanistan | Afghan |

### Oceanian
| Code | Country | Display |
|------|---------|---------|
| `AU` | Australia | Australian |
| `NZ` | New Zealand | New Zealand |
| `FJ` | Fiji | Fijian |

---

## Spirit Types (for Drinks)

Use these values for `subcategory` when `course` is `drinks`:

### Spirits (Base Liquors)
| Value | Description |
|-------|-------------|
| `Gin` | Gin-based cocktails |
| `Vodka` | Vodka-based cocktails |
| `Whiskey` | General whiskey |
| `Bourbon` | Bourbon whiskey |
| `Rye` | Rye whiskey |
| `Scotch` | Scotch whisky |
| `Rum` | Rum-based cocktails |
| `Tequila` | Tequila-based cocktails |
| `Mezcal` | Mezcal-based cocktails |
| `Brandy` | Brandy/Cognac |
| `Cognac` | Cognac specifically |
| `Pisco` | Pisco-based |
| `Cachaça` | Cachaça-based |
| `Absinthe` | Absinthe-based |
| `Sake` | Sake-based |
| `Soju` | Soju-based |

### Wine & Fortified
| Value | Description |
|-------|-------------|
| `Prosecco` | Prosecco-based (spritz, sbagliato) |
| `Champagne` | Champagne cocktails |
| `Sparkling Wine` | Other sparkling wine |
| `Red Wine` | Red wine cocktails |
| `White Wine` | White wine cocktails |
| `Vermouth` | Vermouth-forward drinks |
| `Sherry` | Sherry-based |
| `Port` | Port-based |

### Liqueurs
| Value | Description |
|-------|-------------|
| `Liqueur` | Liqueur-forward drinks |
| `Amaro` | Amaro-based |
| `Aperitif` | Aperitif-style (Aperol, Campari) |

### Beer
| Value | Description |
|-------|-------------|
| `Beer` | Beer cocktails |
| `Cider` | Cider-based |

### Non-Alcoholic
| Value | Description |
|-------|-------------|
| `Tea` | Tea-based beverages |
| `Coffee` | Coffee-based beverages |
| `Mocktail` | Non-alcoholic cocktails |
| `Smoothie` | Smoothies |
| `Juice` | Juice-based drinks |

---

## Examples

### Korean Barley Tea (Non-Alcoholic)
```json
{
  "uuid": "c66ad8c7-86cd-400c-b2ff-1b0b43dec587",
  "name": "Boricha (Barley Tea)",
  "course": "drinks",
  "cuisine": "KR",
  "subcategory": "Tea",
  "serves": "10",
  "time": "15 min"
}
```

### Negroni Sbagliato (Prosecco-based, Italian)
```json
{
  "uuid": "d7da7b20-44e1-4a24-9f30-d7670e25ce8a",
  "name": "Negroni Sbagliato",
  "course": "drinks",
  "cuisine": "IT",
  "subcategory": "Prosecco",
  "serves": "1"
}
```

### Gibson (Gin Cocktail, no specific origin)
```json
{
  "uuid": "...",
  "name": "Gibson",
  "course": "drinks",
  "cuisine": null,
  "subcategory": "Gin",
  "serves": "1"
}
```

### Korean Fried Chicken (Food)
```json
{
  "uuid": "...",
  "name": "Korean Fried Chicken",
  "course": "mains",
  "cuisine": "KR",
  "subcategory": null,
  "serves": "4-5"
}
```

---

## Version File

`version.json` tracks the current data version for app sync:

```json
{
  "version": 1,
  "updatedAt": "2025-12-12T00:00:00.000000"
}
```

Increment `version` whenever you update any recipe file.

---

## Index File

`index.json` lists all recipe files to load:

```json
{
  "files": [
    "mains.json",
    "apps.json",
    "soup.json",
    "sides.json",
    "desserts.json",
    "brunch.json",
    "breads.json",
    "sauces.json",
    "rubs.json",
    "pickles.json",
    "pizzas.json",
    "sandwiches.json",
    "smoking.json",
    "cheese.json",
    "modernist.json",
    "vegn.json",
    "salad.json",
    "drinks.json",
    "scratch.json"
  ]
}
```
