# Memoix Tools

Scripts and utilities for managing Memoix recipe data.

## sheets_to_json.py

Converts Google Sheets CSV exports into the JSON format used by Memoix.

### Installation

```bash
pip install pandas  # Optional, for advanced features
```

### Usage

#### Export from Google Sheets

1. Open your Google Sheets recipe document
2. Go to **File → Download → Comma Separated Values (.csv)**
3. Save each sheet as a separate CSV file

#### Convert Single File

```bash
# Standard recipe format
python sheets_to_json.py mains.csv --type mains --output ../recipes/mains.json

# Special formats
python sheets_to_json.py pizzas.csv --type pizzas --output ../recipes/pizzas.json
python sheets_to_json.py smoking.csv --type smoking --output ../recipes/smoking.json
python sheets_to_json.py cheese.csv --type cheese --output ../recipes/cheese.json
python sheets_to_json.py sandwiches.csv --type sandwiches --output ../recipes/sandwiches.json

# Pretty-print output
python sheets_to_json.py mains.csv --type mains --output mains.json --pretty
```

#### Convert All Sheets (Batch Mode)

```bash
# Place all CSVs in a folder, then:
python sheets_to_json.py ./csv_exports/ --batch --output ../recipes/
```

#### Multi-Row Format

If your spreadsheet has ingredients on separate rows below each recipe:

```bash
python sheets_to_json.py mains.csv --type mains --multirow --output mains.json
```

### Supported Sheet Types

| Type | Headers | Description |
|------|---------|-------------|
| `standard` | Name, Serves, Time, Pairs With, Notes, Directions | Most recipe categories |
| `pizzas` | Base, Cheese, Toppings, Notes | Pizza combinations |
| `smoking` | Food, Temp, Time, Wood, Seasoning, Notes | Smoking/BBQ guide |
| `cheese` | Name, Country, Milk, Texture, Type, Buy, Flavour | Cheese reference |
| `sandwiches` | Name, Bread, Toppings, Cheese, Condiments | Sandwich recipes |
| `scratch` | Any | Ideas and notes |

### Standard Recipe Format

Your spreadsheet should look like this:

```
| Name               | Serves    | Time   | Pairs With | Notes | Directions |
|--------------------|-----------|--------|------------|-------|------------|
| Korean             |           |        |            |       |            | ← Cuisine header
| Korean Fried Chicken | 4-5 people |        | KFC Sauce  |       |            |
| Chicken Wings      | 1 lb      |        |            |       | - Step 1   |
| Flour              | 1 cup     |        |            |       | - Step 2   |
| ...                |           |        |            |       |            |
```

The script auto-detects:
- **Cuisine headers**: Rows with only a name (Korean, French, etc.)
- **Subcategory headers**: Regional groupings (European, Asian, etc.)
- **Ingredients**: Rows below a recipe with amounts in the Serves column
- **Directions**: Text prefixed with `-` in the Directions column

### Output Format

```json
{
  "uuid": "auto-generated",
  "name": "White Bean Cassoulet",
  "course": "mains",
  "cuisine": "French",
  "subcategory": "European",
  "serves": "4-6",
  "time": "2 hr",
  "pairsWith": [],
  "notes": null,
  "ingredients": [
    {
      "name": "White Beans",
      "amount": "1 Can",
      "preparation": null,
      "alternative": null,
      "isOptional": false,
      "section": null
    }
  ],
  "directions": [
    "Melt butter; sauté onion...",
    "Add veg ham + sausage..."
  ],
  "tags": [],
  "version": 1
}
```

### Tips

1. **Clean your data first**: Remove empty rows, fix typos
2. **Consistent formatting**: Use the same format for times (e.g., "30 min", "1 hr")
3. **Ingredient amounts**: Put amounts at the start (e.g., "2 tbsp butter")
4. **Alternatives**: Use "alt: ..." format (e.g., "alt: olive oil")
5. **Optional ingredients**: Include "(optional)" in the name

### Troubleshooting

**Empty output?**
- Check that your CSV has the expected headers
- Ensure the file is UTF-8 encoded

**Missing cuisines?**
- Cuisine headers must be alone in a row (no other columns filled)
- Check spelling matches expected values

**Garbled characters?**
- Re-save CSV as UTF-8
- The script handles BOM markers automatically
