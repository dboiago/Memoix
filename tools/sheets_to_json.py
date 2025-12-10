#!/usr/bin/env python3
"""
Memoix Google Sheets to JSON Converter

This script converts exported Google Sheets CSV files into the JSON format
used by the Memoix app. It handles both standard recipe formats and special
formats like Pizzas, Smoking, Cheese, and Sandwiches.

Usage:
    python sheets_to_json.py input.csv --type mains --output ../recipes/mains.json
    python sheets_to_json.py input.csv --type pizzas --output ../recipes/pizzas.json
    
    # Process entire folder of CSVs
    python sheets_to_json.py ./exports/ --batch --output ../recipes/

Requirements:
    pip install pandas uuid
"""

import argparse
import csv
import json
import os
import re
import uuid
from pathlib import Path
from typing import Any

# =============================================================================
# CONFIGURATION
# =============================================================================

# Map sheet names to their types
SHEET_TYPE_MAP = {
    'mains': 'standard',
    'apps': 'standard',
    'appetizers': 'standard',
    'soups': 'standard',
    'brunch': 'standard',
    'sides': 'standard',
    'desserts': 'standard',
    'breads': 'standard',
    'rubs': 'standard',
    'sauces': 'standard',
    'pickles': 'standard',
    'pickles/brines': 'standard',
    'molecular': 'standard',
    'not meat': 'standard',
    'pizzas': 'pizza',
    'smoking': 'smoking',
    'cheese': 'cheese',
    'sandwiches': 'sandwich',
    'scratch': 'scratch',
}

# Standard recipe headers (from your spreadsheet image)
STANDARD_HEADERS = ['name', 'serves', 'time', 'pairs_with', 'notes', 'directions']

# =============================================================================
# PARSERS FOR DIFFERENT SHEET TYPES
# =============================================================================

def generate_uuid(name: str, course: str) -> str:
    """Generate a deterministic UUID based on name and course."""
    # Use a namespace UUID for consistency
    namespace = uuid.UUID('6ba7b810-9dad-11d1-80b4-00c04fd430c8')
    return str(uuid.uuid5(namespace, f"{course}:{name}"))


def parse_ingredients_column(text: str) -> list[dict]:
    """Parse ingredients from a multi-line text column."""
    if not text or not text.strip():
        return []
    
    ingredients = []
    lines = text.strip().split('\n')
    current_section = None
    
    for line in lines:
        line = line.strip()
        if not line or line.startswith('-'):
            continue
        
        # Check if this is a section header (ends with : or is all caps)
        if line.endswith(':') or (line.isupper() and len(line) < 30):
            current_section = line.rstrip(':')
            continue
        
        ingredient = parse_ingredient_line(line)
        if current_section:
            ingredient['section'] = current_section
        ingredients.append(ingredient)
    
    return ingredients


def parse_ingredient_line(line: str) -> dict:
    """Parse a single ingredient line into structured data."""
    ingredient = {
        'name': '',
        'amount': None,
        'preparation': None,
        'alternative': None,
        'isOptional': False,
        'section': None,
    }
    
    # Check for optional marker
    if '(optional)' in line.lower() or 'optional' in line.lower():
        ingredient['isOptional'] = True
        line = re.sub(r'\(?\s*optional\s*\)?', '', line, flags=re.IGNORECASE).strip()
    
    # Check for alternative (alt: ...)
    alt_match = re.search(r'alt:\s*(.+?)(?:$|\)|,)', line, re.IGNORECASE)
    if alt_match:
        ingredient['alternative'] = f"alt: {alt_match.group(1).strip()}"
        line = re.sub(r',?\s*alt:\s*.+?(?:$|\)|,)', '', line, flags=re.IGNORECASE).strip()
    
    # Check for preparation notes (usually after comma: "diced", "minced", etc.)
    prep_match = re.search(r',\s*(diced|minced|cubed|chopped|sliced|grated|crushed|melted|softened|room temp|cold|warm|hot|to taste|beaten|whisked).*$', line, re.IGNORECASE)
    if prep_match:
        ingredient['preparation'] = prep_match.group(0).lstrip(', ').strip()
        line = line[:prep_match.start()].strip()
    
    # Try to extract amount (number + optional unit at the start)
    amount_pattern = r'^([\d½¼¾⅓⅔⅛⅜⅝⅞]+(?:\s*[-–]\s*[\d½¼¾⅓⅔⅛⅜⅝⅞]+)?)\s*(?:(cups?|tbsp|tsp|oz|lb|lbs|g|kg|ml|l|pound|pounds|ounce|ounces|teaspoons?|tablespoons?|c\.|t\.|can|cans|bunch|bunches|cloves?|heads?|stalks?|pieces?|slices?|pinch|pinches|dash|dashes)\.?\s+)?(.+)'
    match = re.match(amount_pattern, line, re.IGNORECASE)
    
    if match:
        amount_num = match.group(1)
        amount_unit = match.group(2) or ''
        ingredient['amount'] = f"{amount_num} {amount_unit}".strip()
        ingredient['name'] = match.group(3).strip()
    else:
        # No amount found, entire line is the ingredient name
        ingredient['name'] = line.strip()
    
    return ingredient


def parse_directions_column(text: str) -> list[str]:
    """Parse directions from a multi-line or dash-prefixed text column."""
    if not text or not text.strip():
        return []
    
    directions = []
    
    # Check if directions are prefixed with dashes (like your spreadsheet)
    if '- ' in text:
        lines = text.split('- ')
        for line in lines:
            line = line.strip().rstrip('-').strip()
            if line:
                directions.append(line)
    else:
        # Split by numbered steps or double newlines
        lines = re.split(r'\n\s*\n|\n\d+[\.\)]\s*', text)
        for line in lines:
            line = line.strip()
            if line:
                directions.append(line)
    
    return directions


def parse_pairs_with(text: str) -> list[str]:
    """Parse 'pairs with' field into a list."""
    if not text or not text.strip():
        return []
    
    # Split by comma or newline
    items = re.split(r'[,\n]', text)
    return [item.strip() for item in items if item.strip()]


# =============================================================================
# STANDARD RECIPE PARSER
# =============================================================================

def parse_standard_recipe(row: dict, course: str, cuisine: str = None, subcategory: str = None) -> dict:
    """Parse a standard recipe row from the spreadsheet."""
    name = row.get('name', row.get('Name', '')).strip()
    if not name:
        return None
    
    recipe = {
        'uuid': generate_uuid(name, course),
        'name': name,
        'course': course.lower(),
        'cuisine': cuisine,
        'subcategory': subcategory,
        'serves': row.get('serves', row.get('Serves', '')).strip() or None,
        'time': row.get('time', row.get('Time', '')).strip() or None,
        'pairsWith': parse_pairs_with(row.get('pairs_with', row.get('Pairs With', row.get('pairsWith', '')))),
        'notes': row.get('notes', row.get('Notes', '')).strip() or None,
        'ingredients': [],  # Will be parsed from ingredients column or rows below
        'directions': parse_directions_column(row.get('directions', row.get('Directions', ''))),
        'sourceUrl': None,
        'imageUrl': None,
        'tags': [],
        'version': 1,
    }
    
    # Parse ingredients if in a single column
    if 'ingredients' in row or 'Ingredients' in row:
        recipe['ingredients'] = parse_ingredients_column(row.get('ingredients', row.get('Ingredients', '')))
    
    return recipe


# =============================================================================
# PIZZA PARSER
# =============================================================================

def parse_pizza_recipe(row: dict) -> dict:
    """Parse a pizza recipe with Base, Cheese, Toppings, Notes format."""
    name = row.get('name', row.get('Name', '')).strip()
    if not name:
        return None
    
    # Build ingredients from the structured columns
    ingredients = []
    
    base = row.get('base', row.get('Base', '')).strip()
    if base:
        ingredients.append({
            'name': base,
            'amount': None,
            'preparation': None,
            'alternative': None,
            'isOptional': False,
            'section': 'Base',
        })
    
    cheese = row.get('cheese', row.get('Cheese', '')).strip()
    if cheese:
        # Could be multiple cheeses
        for c in cheese.split(','):
            c = c.strip()
            if c:
                ingredients.append({
                    'name': c,
                    'amount': None,
                    'preparation': None,
                    'alternative': None,
                    'isOptional': False,
                    'section': 'Cheese',
                })
    
    toppings = row.get('toppings', row.get('Toppings', '')).strip()
    if toppings:
        for t in toppings.split(','):
            t = t.strip()
            if t:
                ingredients.append({
                    'name': t,
                    'amount': None,
                    'preparation': None,
                    'alternative': None,
                    'isOptional': False,
                    'section': 'Toppings',
                })
    
    return {
        'uuid': generate_uuid(name, 'pizzas'),
        'name': name,
        'course': 'pizzas',
        'cuisine': 'Italian',
        'subcategory': None,
        'serves': None,
        'time': None,
        'pairsWith': [],
        'notes': row.get('notes', row.get('Notes', '')).strip() or None,
        'ingredients': ingredients,
        'directions': [],  # Pizzas typically use standard pizza-making directions
        'sourceUrl': None,
        'imageUrl': None,
        'tags': ['pizza'],
        'version': 1,
        # Pizza-specific fields
        'pizzaBase': base or None,
        'pizzaCheese': cheese or None,
        'pizzaToppings': toppings or None,
    }


# =============================================================================
# SMOKING PARSER
# =============================================================================

def parse_smoking_recipe(row: dict) -> dict:
    """Parse a smoking recipe with Food, Temp, Time, Wood, Seasoning, Notes format."""
    food = row.get('food', row.get('Food', '')).strip()
    if not food:
        return None
    
    return {
        'uuid': generate_uuid(food, 'smoking'),
        'name': food,
        'course': 'smoking',
        'cuisine': 'BBQ',
        'subcategory': None,
        'serves': None,
        'time': row.get('time', row.get('Time', '')).strip() or None,
        'pairsWith': [],
        'notes': row.get('notes', row.get('Notes', '')).strip() or None,
        'ingredients': [],
        'directions': [],
        'sourceUrl': None,
        'imageUrl': None,
        'tags': ['smoking', 'bbq'],
        'version': 1,
        # Smoking-specific fields
        'smokingTemp': row.get('temp', row.get('Temp', '')).strip() or None,
        'smokingWood': row.get('wood', row.get('Wood', '')).strip() or None,
        'smokingSeasoning': row.get('seasoning', row.get('Seasoning', '')).strip() or None,
    }


# =============================================================================
# CHEESE PARSER
# =============================================================================

def parse_cheese_entry(row: dict) -> dict:
    """Parse a cheese entry with Name, Country, Milk, Texture, Type, Buy, Flavour format."""
    name = row.get('name', row.get('Name', '')).strip()
    if not name:
        return None
    
    return {
        'uuid': generate_uuid(name, 'cheese'),
        'name': name,
        'course': 'cheese',
        'cuisine': row.get('country', row.get('Country', '')).strip() or None,
        'subcategory': row.get('type', row.get('Type', '')).strip() or None,
        'serves': None,
        'time': None,
        'pairsWith': [],
        'notes': row.get('flavour', row.get('Flavour', '')).strip() or None,
        'ingredients': [],
        'directions': [],
        'sourceUrl': None,
        'imageUrl': None,
        'tags': ['cheese', 'reference'],
        'version': 1,
        # Cheese-specific fields
        'cheeseCountry': row.get('country', row.get('Country', '')).strip() or None,
        'cheeseMilk': row.get('milk', row.get('Milk', '')).strip() or None,
        'cheeseTexture': row.get('texture', row.get('Texture', '')).strip() or None,
        'cheeseType': row.get('type', row.get('Type', '')).strip() or None,
        'cheeseBuy': row.get('buy', row.get('Buy', '')).strip() or None,
        'cheeseFlavour': row.get('flavour', row.get('Flavour', '')).strip() or None,
    }


# =============================================================================
# SANDWICH PARSER
# =============================================================================

def parse_sandwich_recipe(row: dict) -> dict:
    """Parse a sandwich with Name, Bread, Toppings, Cheese, Condiments format."""
    name = row.get('name', row.get('Name', '')).strip()
    if not name:
        return None
    
    ingredients = []
    
    bread = row.get('bread', row.get('Bread', '')).strip()
    if bread:
        ingredients.append({
            'name': bread,
            'amount': None,
            'preparation': None,
            'alternative': None,
            'isOptional': False,
            'section': 'Bread',
        })
    
    toppings = row.get('toppings', row.get('Toppings', '')).strip()
    if toppings:
        for t in toppings.split(','):
            t = t.strip()
            if t:
                ingredients.append({
                    'name': t,
                    'amount': None,
                    'preparation': None,
                    'alternative': None,
                    'isOptional': False,
                    'section': 'Toppings',
                })
    
    cheese = row.get('cheese', row.get('Cheese', '')).strip()
    if cheese:
        ingredients.append({
            'name': cheese,
            'amount': None,
            'preparation': None,
            'alternative': None,
            'isOptional': False,
            'section': 'Cheese',
        })
    
    condiments = row.get('condiments', row.get('Condiments', '')).strip()
    if condiments:
        for c in condiments.split(','):
            c = c.strip()
            if c:
                ingredients.append({
                    'name': c,
                    'amount': None,
                    'preparation': None,
                    'alternative': None,
                    'isOptional': False,
                    'section': 'Condiments',
                })
    
    return {
        'uuid': generate_uuid(name, 'sandwiches'),
        'name': name,
        'course': 'sandwiches',
        'cuisine': None,
        'subcategory': None,
        'serves': '1',
        'time': None,
        'pairsWith': [],
        'notes': row.get('notes', row.get('Notes', '')).strip() or None,
        'ingredients': ingredients,
        'directions': [],
        'sourceUrl': None,
        'imageUrl': None,
        'tags': ['sandwich', 'quick'],
        'version': 1,
        # Sandwich-specific fields
        'sandwichBread': bread or None,
        'sandwichCheese': cheese or None,
        'sandwichToppings': toppings or None,
        'sandwichCondiments': condiments or None,
    }


# =============================================================================
# SCRATCH/NOTES PARSER
# =============================================================================

def parse_scratch_entry(row: dict, index: int) -> dict:
    """Parse a scratch/notes entry - flexible format for ideas."""
    # Try to find any content
    content = ''
    name = ''
    
    for key, value in row.items():
        if value and value.strip():
            if not name:
                name = value.strip()[:50]  # First non-empty value as name
            content += f"{key}: {value}\n"
    
    if not name:
        return None
    
    return {
        'uuid': generate_uuid(f"scratch-{index}", 'scratch'),
        'name': name,
        'course': 'scratch',
        'cuisine': None,
        'subcategory': None,
        'serves': None,
        'time': None,
        'pairsWith': [],
        'notes': content.strip(),
        'ingredients': [],
        'directions': [],
        'sourceUrl': None,
        'imageUrl': None,
        'tags': ['idea', 'scratch'],
        'version': 1,
        'isDraft': True,
    }


# =============================================================================
# SPREADSHEET STRUCTURE PARSER
# =============================================================================

def detect_cuisine_sections(rows: list[dict]) -> list[dict]:
    """
    Detect cuisine/subcategory sections in the spreadsheet.
    Your spreadsheet has rows like "Korean" or "European > French" as headers.
    """
    enhanced_rows = []
    current_cuisine = None
    current_subcategory = None
    
    for row in rows:
        name = row.get('name', row.get('Name', '')).strip()
        
        # Check if this is a cuisine header row (only name filled, no other data)
        is_header = name and not any(
            row.get(k, '').strip() 
            for k in row.keys() 
            if k.lower() not in ['name', '']
        )
        
        if is_header:
            # Check for subcategory pattern like "European" followed by "French"
            if name in ['European', 'Asian', 'Latin American', 'Middle Eastern']:
                current_subcategory = name
                current_cuisine = None
            else:
                current_cuisine = name
            continue
        
        # Add cuisine info to regular recipe rows
        if name:
            row['_cuisine'] = current_cuisine
            row['_subcategory'] = current_subcategory
            enhanced_rows.append(row)
    
    return enhanced_rows


def parse_csv_file(filepath: str, sheet_type: str, course: str) -> list[dict]:
    """Parse a CSV file and return list of recipes."""
    recipes = []
    
    with open(filepath, 'r', encoding='utf-8-sig') as f:
        reader = csv.DictReader(f)
        rows = list(reader)
    
    # For standard recipes with multi-row format, use specialized parser
    if sheet_type == 'standard':
        return parse_multirow_csv(filepath, course)
    
    for i, row in enumerate(rows):
        recipe = None
        
        if sheet_type == 'pizza':
            recipe = parse_pizza_recipe(row)
        elif sheet_type == 'smoking':
            recipe = parse_smoking_recipe(row)
        elif sheet_type == 'cheese':
            recipe = parse_cheese_entry(row)
        elif sheet_type == 'sandwich':
            recipe = parse_sandwich_recipe(row)
        elif sheet_type == 'scratch':
            recipe = parse_scratch_entry(row, i)
        
        if recipe:
            recipes.append(recipe)
    
    return recipes


def parse_multirow_csv(filepath: str, course: str) -> list[dict]:
    """
    Parse a CSV where each recipe spans multiple rows.
    Recipe name is in first column, ingredients in subsequent rows.
    
    This matches your spreadsheet format where:
    - Row with Name, Serves, Time, etc. starts a recipe
    - Following rows have ingredient details in columns
    - Empty rows separate recipes
    """
    recipes = []
    current_recipe = None
    current_cuisine = None
    current_subcategory = None
    ingredients = []
    
    with open(filepath, 'r', encoding='utf-8-sig') as f:
        reader = csv.DictReader(f)
        rows = list(reader)
    
    for row in rows:
        name = row.get('Name', '').strip() if row.get('Name') else ''
        
        # Check if this is an empty row (separator between recipes)
        if not any(v.strip() for v in row.values() if v):
            if current_recipe and current_recipe['name']:
                current_recipe['ingredients'] = ingredients
                recipes.append(current_recipe)
            current_recipe = None
            ingredients = []
            continue
        
        # Check if this is a cuisine/section header (only Name filled, nothing else)
        has_other_data = any(
            row.get(k, '').strip() 
            for k in ['Serves', 'Time', 'Pairs With', 'Notes', 'Directions'] 
            if row.get(k)
        )
        
        if name and not has_other_data:
            # This is a section header like "Asian", "Chinese", "French", etc.
            if '>' in name:
                # Subcategory like "European > French"
                parts = name.split('>')
                current_cuisine = parts[0].strip()
                current_subcategory = parts[1].strip()
            else:
                current_cuisine = name
                current_subcategory = None
            continue
        
        # Check if this is a recipe header row (has Name and at least Time or Serves)
        has_recipe_fields = row.get('Time') or row.get('Serves')
        
        if name and has_recipe_fields:
            # Save previous recipe if exists
            if current_recipe and current_recipe['name']:
                current_recipe['ingredients'] = ingredients
                recipes.append(current_recipe)
            
            # Start new recipe
            current_recipe = {
                'uuid': generate_uuid(name, course),
                'name': name,
                'course': course.lower(),
                'cuisine': current_cuisine,
                'subcategory': current_subcategory,
                'serves': row.get('Serves', '').strip() or None,
                'time': row.get('Time', '').strip() or None,
                'pairsWith': parse_pairs_with(row.get('Pairs With', '')),
                'notes': row.get('Notes', '').strip() or None,
                'ingredients': [],
                'directions': parse_directions_column(row.get('Directions', '')),
                'sourceUrl': None,
                'imageUrl': None,
                'tags': [],
                'version': 1,
            }
            ingredients = []
        
        elif current_recipe and name:
            # This is an ingredient row - parse it
            ingredient = parse_ingredient_line(name)
            
            # Add amount from second column if present
            amount_col = row.get(list(row.keys())[1], '').strip() if len(row) > 1 else ''
            if amount_col and not ingredient['amount']:
                ingredient['amount'] = amount_col
            
            ingredients.append(ingredient)
    
    # Don't forget the last recipe
    if current_recipe and current_recipe['name']:
        current_recipe['ingredients'] = ingredients
        recipes.append(current_recipe)
    
    return recipes


# =============================================================================
# MULTI-ROW RECIPE PARSER
# =============================================================================

def parse_multirow_csv(filepath: str, course: str) -> list[dict]:
    """
    Parse a CSV where each recipe spans multiple rows.
    Recipe name is in first column, ingredients in subsequent rows.
    
    This matches your spreadsheet format where:
    - Row with Name, Serves, Time, etc. starts a recipe
    - Following rows have ingredient details in columns
    """
    recipes = []
    current_recipe = None
    current_cuisine = None
    current_subcategory = None
    
    with open(filepath, 'r', encoding='utf-8-sig') as f:
        reader = csv.reader(f)
        headers = next(reader)  # Skip header row
        
        # Normalize headers
        headers = [h.lower().strip() for h in headers]
        
        for row in reader:
            if not row or all(not cell.strip() for cell in row):
                continue
            
            # Create dict from row
            row_dict = {headers[i]: row[i] if i < len(row) else '' for i in range(len(headers))}
            
            name_col = row_dict.get('name', row[0] if row else '').strip()
            
            # Check if this is a cuisine header (name present, but no other main fields)
            serves = row_dict.get('serves', '').strip()
            time = row_dict.get('time', '').strip()
            directions = row_dict.get('directions', '').strip()
            
            # Detect section headers
            if name_col and not serves and not time and not directions:
                # Check if it's a known cuisine or just a single-word header
                if name_col in ['European', 'Asian', 'Latin American', 'Middle Eastern', 'African']:
                    current_subcategory = name_col
                    continue
                elif len(name_col.split()) <= 2 and name_col[0].isupper():
                    # Likely a cuisine header like "Korean", "French", etc.
                    current_cuisine = name_col
                    continue
            
            # Check if this starts a new recipe (has name + some metadata)
            if name_col and (serves or time or row_dict.get('pairs with', row_dict.get('pairs_with', '')).strip()):
                # Save previous recipe if exists
                if current_recipe:
                    recipes.append(current_recipe)
                
                # Start new recipe
                current_recipe = parse_standard_recipe(row_dict, course, current_cuisine, current_subcategory)
                continue
            
            # This row might be an ingredient row for current recipe
            if current_recipe and name_col:
                # Parse as ingredient
                ingredient = {
                    'name': name_col,
                    'amount': row_dict.get('serves', row[1] if len(row) > 1 else '').strip() or None,
                    'preparation': row_dict.get('notes', '').strip() or None,
                    'alternative': None,
                    'isOptional': False,
                    'section': None,
                }
                
                # Check notes column for alternatives
                notes = row_dict.get('notes', '').strip()
                if notes and notes.lower().startswith('alt:'):
                    ingredient['alternative'] = notes
                    ingredient['preparation'] = None
                
                # Check for optional
                if 'optional' in (ingredient.get('preparation') or '').lower():
                    ingredient['isOptional'] = True
                
                current_recipe['ingredients'].append(ingredient)
                
                # Check if directions are in this row
                directions = row_dict.get('directions', '').strip()
                if directions and directions.startswith('-'):
                    current_recipe['directions'].append(directions.lstrip('- ').strip())
    
    # Don't forget the last recipe
    if current_recipe:
        recipes.append(current_recipe)
    
    return recipes


# =============================================================================
# MAIN
# =============================================================================

def main():
    parser = argparse.ArgumentParser(
        description='Convert Google Sheets CSV exports to Memoix JSON format'
    )
    parser.add_argument('input', help='Input CSV file or directory')
    parser.add_argument('--type', '-t', 
                       choices=['mains', 'apps', 'soups', 'brunch', 'sides', 'desserts',
                               'breads', 'rubs', 'sauces', 'pickles', 'molecular', 
                               'not-meat', 'pizzas', 'smoking', 'cheese', 'sandwiches', 'scratch'],
                       help='Type of sheet (determines parser)')
    parser.add_argument('--output', '-o', help='Output JSON file or directory')
    parser.add_argument('--batch', '-b', action='store_true', 
                       help='Process all CSVs in input directory')
    parser.add_argument('--multirow', '-m', action='store_true',
                       help='Use multi-row parser (ingredients on separate rows)')
    parser.add_argument('--pretty', '-p', action='store_true',
                       help='Pretty-print JSON output')
    
    args = parser.parse_args()
    
    if args.batch:
        # Process all CSVs in directory
        input_dir = Path(args.input)
        output_dir = Path(args.output) if args.output else input_dir
        
        for csv_file in input_dir.glob('*.csv'):
            sheet_name = csv_file.stem.lower().replace('_', ' ').replace('-', ' ')
            sheet_type = SHEET_TYPE_MAP.get(sheet_name, 'standard')
            
            print(f"Processing {csv_file.name} as {sheet_type}...")
            
            if args.multirow:
                recipes = parse_multirow_csv(str(csv_file), sheet_name)
            else:
                recipes = parse_csv_file(str(csv_file), sheet_type, sheet_name)
            
            output_file = output_dir / f"{csv_file.stem.lower()}.json"
            with open(output_file, 'w', encoding='utf-8') as f:
                json.dump(recipes, f, indent=2 if args.pretty else None, ensure_ascii=False)
            
            print(f"  → Wrote {len(recipes)} recipes to {output_file}")
    else:
        # Process single file
        if not args.type:
            # Try to infer from filename
            filename = Path(args.input).stem.lower()
            args.type = filename if filename in SHEET_TYPE_MAP else 'mains'
        
        sheet_type = SHEET_TYPE_MAP.get(args.type, 'standard')
        
        if args.multirow:
            recipes = parse_multirow_csv(args.input, args.type)
        else:
            recipes = parse_csv_file(args.input, sheet_type, args.type)
        
        output_file = args.output or f"{args.type}.json"
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(recipes, f, indent=2 if args.pretty else None, ensure_ascii=False)
        
        print(f"Converted {len(recipes)} recipes to {output_file}")


if __name__ == '__main__':
    main()
