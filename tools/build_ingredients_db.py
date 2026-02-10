#!/usr/bin/env python3
"""
Memoix Ingredient Database Builder

Builds a compressed ingredient lookup database from OpenFoodFacts data.
Produces two files:
  1. ingredients_json.gz  — {name: category_index} for category classification
  2. ingredients_meta.gz  — {name: {cat, vegan, vegetarian, allergens, kcal, ...}}
     (optional rich metadata for future app features)

Usage:
    # Download the OFF CSV/TSV first from https://world.openfoodfacts.org/data
    python build_ingredients_db.py food.csv
    python build_ingredients_db.py food.csv --meta   # also generate metadata file

The category index maps to the IngredientCategory enum in Dart:
  0=produce, 1=meat, 2=poultry, 3=seafood, 4=egg, 5=cheese, 6=dairy,
  7=grain, 8=pasta, 9=legume, 10=nut, 11=spice, 12=condiment, 13=oil,
  14=vinegar, 15=flour, 16=sugar, 17=leavening, 18=alcohol, 19=pop,
  20=juice, 21=beverage, 22=unknown, 23=pantry
"""

import argparse
import csv
import gzip
import json
import os
import re
import sys

csv.field_size_limit(sys.maxsize)

# =============================================================================
# CATEGORY ENUM (must match Dart IngredientCategory)
# =============================================================================
CATEGORIES = [
    "produce", "meat", "poultry", "seafood", "egg", "cheese", "dairy",
    "grain", "pasta", "legume", "nut", "spice", "condiment", "oil",
    "vinegar", "flour", "sugar", "leavening", "alcohol", "pop", "juice",
    "beverage", "unknown", "pantry"
]
CAT = {cat: i for i, cat in enumerate(CATEGORIES)}
UNKNOWN = CAT["unknown"]

# =============================================================================
# KEYWORD → CATEGORY RULES  (checked in order, first match wins)
#
# Each rule is (keywords_to_check, category_name).
# A rule matches if ALL keywords appear in the combined text
# (product name + OFF categories + OFF tags).
# Multi-word keywords are checked as substrings; single words as \b boundaries.
# =============================================================================
KEYWORD_RULES = [
    # ── Specific multi-word items (must come first: longest match wins) ──
    # Pantry (shelf-stable, canned, jarred, preserved)
    (["stock"],                 "pantry"),
    (["vegetable stock"],       "pantry"),
    (["chicken stock"],         "pantry"),
    (["beef stock"],            "pantry"),    (["]chicken broth"],         "pantry"),
    (["]beef broth"],            "pantry"),
    (["]vegetable broth"],       "pantry"),    (["bouillon"],              "pantry"),
    (["tomato sauce"],          "pantry"),
    (["tomato puree"],          "pantry"),
    (["sun-dried tomato"],      "pantry"),
    (["sundried tomato"],       "pantry"),
    (["sun dried tomato"],      "pantry"),
    (["canned tomato"],         "pantry"),
    (["diced tomato"],          "pantry"),
    (["crushed tomato"],        "pantry"),
    (["whole tomato"],          "pantry"),
    (["roasted pepper"],        "pantry"),
    (["artichoke heart"],       "pantry"),
    (["olive"],                 "pantry"),
    (["caper"],                 "pantry"),
    (["pickle"],                "pantry"),
    (["gherkin"],               "pantry"),
    (["coconut cream"],         "pantry"),
    (["coconut milk"],          "pantry"),
    (["anchovy paste"],         "pantry"),
    (["chipotle"],              "pantry"),
    (["harissa"],               "pantry"),
    (["gochujang"],             "pantry"),
    (["doubanjiang"],            "pantry"),
    (["doenjang"],               "pantry"),
    (["preserved mustard"],      "pantry"),
    (["sesame paste"],           "pantry"),
    (["dashi"],                  "pantry"),
    (["bonito"],                 "pantry"),
    (["kombu"],                  "pantry"),
    (["nori"],                   "pantry"),
    (["seaweed"],                "pantry"),
    (["dried shrimp"],           "pantry"),
    (["shrimp paste"],           "pantry"),
    (["fish paste"],             "pantry"),
    (["curry paste"],            "pantry"),
    (["bean paste"],             "pantry"),
    (["chili paste"],            "pantry"),
    (["miso"],                  "pantry"),    (["]kimchi"],                "pantry"),    (["tahini"],                "pantry"),
    (["pesto"],                 "pantry"),
    (["hoisin"],                "condiment"),
    # True condiments (found in the condiment aisle)
    (["tomato ketchup"],        "condiment"),
    (["soy sauce"],             "condiment"),
    (["fish sauce"],            "condiment"),
    (["hot sauce"],             "condiment"),
    (["barbecue sauce"],        "condiment"),
    (["bbq sauce"],             "condiment"),
    (["teriyaki"],              "condiment"),    
    (["]steak sauce"],          "condiment"),    
    (["hoisin"],                "condiment"),
    (["oyster sauce"],          "condiment"),
    (["worcestershire"],        "condiment"),
    (["sriracha"],              "condiment"),
    (["mustard"],               "condiment"),
    (["mayonnaise"],            "condiment"),
    (["ketchup"],               "condiment"),
    (["salsa"],                 "condiment"),
    (["pesto"],                 "condiment"),
    (["miso"],                  "condiment"),
    (["tahini"],                "condiment"),
    (["sambal"],                "condiment"),
    (["chutney"],               "condiment"),
    (["relish"],                "condiment"),
    (["dressing"],              "condiment"),

    # Nut butters / spreads → pantry (not with whole nuts)
    (["peanut butter"],         "pantry"),
    (["almond butter"],         "pantry"),
    (["cashew butter"],         "pantry"),
    (["nutella"],               "pantry"),
    (["hazelnut spread"],       "pantry"),    
    (["]oyster mushroom sauce"], "pantry"),
    (["]starch water"],          "pantry"),
    (["]stick rice flour"],      "pantry"),
    (["]wakame"],                "pantry"),
    (["cream cheese"],          "cheese"),
    (["goat cheese"],           "cheese"),
    (["blue cheese"],           "cheese"),
    (["cottage cheese"],        "cheese"),

    # Plant milks
    (["almond milk"],           "pantry"),
    (["oat milk"],              "pantry"),
    (["soy milk"],              "pantry"),

    (["olive oil"],             "oil"),
    (["sesame oil"],            "oil"),
    (["coconut oil"],           "oil"),
    (["canola oil"],            "oil"),
    (["vegetable oil"],         "oil"),
    (["sunflower oil"],         "oil"),
    (["avocado oil"],           "oil"),
    (["truffle oil"],           "oil"),

    (["balsamic vinegar"],      "vinegar"),
    (["red wine vinegar"],      "vinegar"),
    (["white wine vinegar"],    "vinegar"),
    (["apple cider vinegar"],   "vinegar"),
    (["rice vinegar"],          "vinegar"),
    (["sherry vinegar"],        "vinegar"),

    (["lemon juice"],           "juice"),
    (["lime juice"],            "juice"),
    (["orange juice"],          "juice"),
    (["apple juice"],           "juice"),
    (["cranberry juice"],       "juice"),
    (["grapefruit juice"],      "juice"),
    (["pomegranate juice"],     "juice"),

    (["maple syrup"],           "sugar"),
    (["corn syrup"],            "sugar"),
    (["agave"],                 "sugar"),
    (["molasses"],              "sugar"),
    (["vanilla extract"],       "sugar"),
    (["cocoa powder"],          "sugar"),

    (["baking powder"],         "leavening"),
    (["baking soda"],           "leavening"),
    (["bicarbonate"],           "leavening"),
    (["yeast"],                 "leavening"),
    (["cream of tartar"],       "leavening"),
    (["gelatin"],               "leavening"),
    (["agar"],                  "leavening"),
    (["pectin"],                "leavening"),

    (["bread flour"],           "flour"),
    (["all-purpose flour"],     "flour"),
    (["all purpose flour"],     "flour"),
    (["cake flour"],            "flour"),
    (["pastry flour"],          "flour"),
    (["self-raising flour"],    "flour"),
    (["self raising flour"],    "flour"),
    (["whole wheat flour"],     "flour"),
    (["vital wheat gluten"],    "flour"),
    (["wheat gluten"],          "flour"),
    (["vital gluten"],          "flour"),
    (["]shortening"],            "flour"),
    (["]cornstarch"],            "flour"),
    (["corn starch"],           "flour"),
    (["cornflour"],             "flour"),
    (["almond flour"],          "flour"),
    (["rice flour"],            "flour"),
    (["tapioca"],               "flour"),
    (["arrowroot"],             "flour"),
    (["semolina"],              "flour"),

    (["brown sugar"],           "sugar"),
    (["powdered sugar"],        "sugar"),
    (["icing sugar"],           "sugar"),
    (["confectioner"],          "sugar"),
    (["demerara"],              "sugar"),
    (["turbinado"],             "sugar"),
    (["muscovado"],             "sugar"),
    (["caster sugar"],          "sugar"),
    (["granulated sugar"],      "sugar"),

    (["dark chocolate"],        "sugar"),
    (["white chocolate"],       "sugar"),
    (["milk chocolate"],        "sugar"),
    (["chocolate chip"],        "sugar"),

    (["ground beef"],           "meat"),
    (["ground pork"],           "meat"),
    (["ground turkey"],         "poultry"),
    (["ground chicken"],        "poultry"),

    (["sweet potato"],          "produce"),
    (["green bean"],            "produce"),
    (["bell pepper"],           "produce"),

    # Fruits
    (["banana"],                "produce"),
    (["strawberry"],            "produce"),
    (["blueberry"],             "produce"),
    (["raspberry"],             "produce"),
    (["blackberry"],            "produce"),
    (["grape"],                 "produce"),
    (["peach"],                 "produce"),
    (["pear"],                  "produce"),
    (["cherry"],                "produce"),
    (["plum"],                  "produce"),
    (["watermelon"],            "produce"),
    (["cantaloupe"],            "produce"),
    (["honeydew"],              "produce"),
    (["mango"],                 "produce"),
    (["pineapple"],             "produce"),
    (["kiwi"],                  "produce"),
    (["papaya"],                "produce"),
    (["ya cai"],                "produce"),

    # Produce (vegetables)
    (["leek"],                  "produce"),
    (["shiitake"],              "produce"),
    (["enoki"],                 "produce"),
    (["portobello"],            "produce"),
    (["bok choy"],              "produce"),
    (["napa cabbage"],          "produce"),
    (["radish"],                "produce"),
    (["turnip"],                "produce"),
    (["beet"],                  "produce"),
    (["watercress"],            "produce"),
    (["arugula"],               "produce"),
    (["endive"],                "produce"),
    (["radicchio"],             "produce"),
    (["rhubarb"],               "produce"),
    (["plantain"],              "produce"),
    (["fig"],                   "produce"),
    (["guava"],                 "produce"),
    (["lemon zest"],            "produce"),
    (["lime zest"],             "produce"),
    (["orange zest"],           "produce"),

    (["black bean"],            "legume"),
    (["kidney bean"],           "legume"),
    (["pinto bean"],            "legume"),
    (["navy bean"],             "legume"),
    (["chickpea"],              "legume"),
    (["lentil"],                "legume"),

    (["pine nut"],              "nut"),
    (["sesame seed"],           "nut"),
    (["sunflower seed"],        "nut"),
    (["pumpkin seed"],          "nut"),
    (["poppy seed"],            "nut"),
    (["flax seed"],             "nut"),
    (["chia seed"],             "nut"),

    (["red wine"],              "alcohol"),
    (["white wine"],            "alcohol"),
    (["rice wine"],             "alcohol"),

    (["kosher salt"],           "spice"),
    (["sea salt"],              "spice"),
    (["maldon salt"],           "spice"),
    (["fine salt"],             "spice"),
    (["table salt"],            "spice"),
    (["fleur de sel"],          "spice"),

    (["black pepper"],          "spice"),
    (["white pepper"],          "spice"),
    (["cayenne pepper"],        "spice"),
    (["chili flake"],           "spice"),
    (["red pepper flake"],      "spice"),
    (["chili powder"],          "spice"),
    (["curry powder"],          "spice"),
    (["garam masala"],          "spice"),
    (["italian seasoning"],     "spice"),
    (["five spice"],            "spice"),
    (["onion powder"],          "spice"),
    (["garlic powder"],         "spice"),

    (["heavy cream"],           "dairy"),
    (["whipping cream"],        "dairy"),
    (["sour cream"],            "dairy"),
    (["half and half"],         "dairy"),
    (["crème fraîche"],         "dairy"),
    (["creme fraiche"],         "dairy"),
    (["evaporated milk"],       "dairy"),
    (["condensed milk"],        "dairy"),
    (["buttermilk"],            "dairy"),

    # ── Single-word categories ──

    # Alcohol (before beverage to prevent "beer" matching "beverage")
    (["wine"],       "alcohol"),
    (["beer"],       "alcohol"),
    (["ale"],        "alcohol"),
    (["lager"],      "alcohol"),
    (["stout"],      "alcohol"),
    (["brandy"],     "alcohol"),
    (["cognac"],     "alcohol"),
    (["rum"],        "alcohol"),
    (["vodka"],      "alcohol"),
    (["whiskey"],    "alcohol"),
    (["whisky"],     "alcohol"),
    (["bourbon"],    "alcohol"),
    (["tequila"],    "alcohol"),
    (["gin"],        "alcohol"),
    (["sake"],       "alcohol"),
    (["mirin"],      "alcohol"),
    (["sherry"],     "alcohol"),
    (["port"],       "alcohol"),
    (["marsala"],    "alcohol"),
    (["kahlua"],     "alcohol"),
    (["amaretto"],   "alcohol"),
    (["grappa"],     "alcohol"),
    (["absinthe"],   "alcohol"),
    (["vermouth"],   "alcohol"),
    (["champagne"],  "alcohol"),
    (["prosecco"],   "alcohol"),
    (["cider"],      "alcohol"),
    (["mead"],       "alcohol"),
    (["liqueur"],    "alcohol"),
    (["campari"],    "alcohol"),
    (["aperol"],     "alcohol"),
    (["cointreau"],  "alcohol"),
    (["grand marnier"], "alcohol"),
    (["triple sec"], "alcohol"),
    (["limoncello"], "alcohol"),
    (["chartreuse"], "alcohol"),

    # Soda/Pop
    (["cola"],       "pop"),
    (["soda"],       "pop"),
    (["tonic"],      "pop"),
    (["sprite"],     "pop"),
    (["ginger ale"], "pop"),

    # Beverage
    (["coffee"],     "beverage"),
    (["tea"],        "beverage"),
    (["broth"],      "beverage"),
    (["stock"],      "beverage"),
    (["water"],      "beverage"),

    # Juice
    (["juice"],      "juice"),

    # Meat
    (["beef"],       "meat"),
    (["steak"],      "meat"),
    (["pork"],       "meat"),
    (["bacon"],      "meat"),
    (["ham"],        "meat"),
    (["prosciutto"], "meat"),
    (["pancetta"],   "meat"),
    (["guanciale"],  "meat"),
    (["chorizo"],    "meat"),
    (["sausage"],    "meat"),
    (["salami"],     "meat"),
    (["pepperoni"],  "meat"),
    (["lamb"],       "meat"),
    (["veal"],       "meat"),
    (["venison"],    "meat"),
    (["bison"],      "meat"),
    (["rabbit"],     "meat"),
    (["lardon"],     "meat"),
    (["bresaola"],   "meat"),
    (["nduja"],      "meat"),
    (["short ribs"],    "meat"),
    (["slab ribs"],     "meat"),
    (["spare ribs"],    "meat"),
    (["beef ribs"],     "meat"),
    (["pork ribs"],     "meat"),
    (["oxtail"],        "meat"),
    (["tongue"],        "meat"),
    (["liver"],         "meat"),
    (["kidney"],        "meat"),
    (["heart"],         "meat"),
    (["offal"],         "meat"),

    # Poultry
    (["chicken"],    "poultry"),
    (["turkey"],     "poultry"),
    (["duck"],       "poultry"),
    (["goose"],      "poultry"),
    (["quail"],      "poultry"),

    # Seafood
    (["salmon"],     "seafood"),
    (["tuna"],       "seafood"),
    (["shrimp"],     "seafood"),
    (["prawn"],      "seafood"),
    (["crab"],       "seafood"),
    (["lobster"],    "seafood"),
    (["scallop"],    "seafood"),
    (["mussel"],     "seafood"),
    (["clam"],       "seafood"),
    (["oyster"],     "seafood"),
    (["anchovy"],    "seafood"),
    (["sardine"],    "seafood"),
    (["cod"],        "seafood"),
    (["halibut"],    "seafood"),
    (["tilapia"],    "seafood"),
    (["trout"],      "seafood"),
    (["bass"],       "seafood"),
    (["mackerel"],   "seafood"),
    (["squid"],      "seafood"),
    (["calamari"],   "seafood"),
    (["octopus"],    "seafood"),
    (["fish"],       "seafood"),
    (["seafood"],    "seafood"),
    (["crustacean"], "seafood"),

    # Egg
    (["egg"],        "egg"),

    # Cheese
    (["cheese"],     "cheese"),
    (["cheddar"],    "cheese"),
    (["parmesan"],   "cheese"),
    (["parmigiano"], "cheese"),
    (["mozzarella"], "cheese"),
    (["gruyere"],    "cheese"),
    (["gruyère"],    "cheese"),
    (["feta"],       "cheese"),
    (["brie"],       "cheese"),
    (["camembert"],  "cheese"),
    (["gouda"],      "cheese"),
    (["ricotta"],    "cheese"),
    (["mascarpone"], "cheese"),
    (["pecorino"],   "cheese"),
    (["emmental"],   "cheese"),
    (["havarti"],    "cheese"),
    (["provolone"],  "cheese"),
    (["halloumi"],   "cheese"),
    (["burrata"],    "cheese"),
    (["paneer"],     "cheese"),
    (["manchego"],   "cheese"),
    (["roquefort"],  "cheese"),
    (["gorgonzola"], "cheese"),
    (["stilton"],    "cheese"),

    # Dairy
    (["milk"],       "dairy"),
    (["butter"],     "dairy"),
    (["cream"],      "dairy"),
    (["yogurt"],     "dairy"),
    (["yoghurt"],    "dairy"),
    (["dairy"],      "dairy"),
    (["ghee"],       "dairy"),

    # Grain
    (["rice"],       "grain"),
    (["bread"],      "grain"),
    (["sourdough"],  "grain"),
    (["brioche"],    "grain"),
    (["ciabatta"],   "grain"),
    (["focaccia"],   "grain"),
    (["pita"],       "grain"),
    (["naan"],       "grain"),
    (["baguette"],   "grain"),
    (["oat"],        "grain"),
    (["quinoa"],     "grain"),
    (["barley"],     "grain"),
    (["couscous"],   "grain"),
    (["bulgur"],     "grain"),
    (["millet"],     "grain"),
    (["polenta"],    "grain"),
    (["grits"],      "grain"),
    (["breadcrumb"], "grain"),
    (["panko"],      "grain"),
    (["tortilla"],   "grain"),
    (["cracker"],    "grain"),
    (["cereal"],     "grain"),
    (["granola"],    "grain"),

    # Pasta
    (["pasta"],      "pasta"),
    (["spaghetti"],  "pasta"),
    (["penne"],      "pasta"),
    (["rigatoni"],   "pasta"),
    (["linguine"],   "pasta"),
    (["fettuccine"], "pasta"),
    (["noodle"],     "pasta"),
    (["lasagna"],    "pasta"),
    (["lasagne"],    "pasta"),
    (["macaroni"],   "pasta"),
    (["orzo"],       "pasta"),
    (["fusilli"],    "pasta"),
    (["farfalle"],   "pasta"),
    (["tagliatelle"],"pasta"),
    (["gnocchi"],    "pasta"),
    (["ramen"],      "pasta"),
    (["udon"],       "pasta"),
    (["soba"],       "pasta"),
    (["vermicelli"], "pasta"),
    (["ravioli"],    "pasta"),
    (["tortellini"], "pasta"),

    # Legume
    (["bean"],       "legume"),
    (["lentil"],     "legume"),
    (["chickpea"],   "legume"),
    # Tofu — in dairy/fridge section in stores
    (["tofu"],       "dairy"),
    (["tempeh"],     "legume"),
    (["edamame"],    "legume"),

    # Nut
    (["almond"],     "nut"),
    (["walnut"],     "nut"),
    (["pecan"],      "nut"),
    (["cashew"],     "nut"),
    (["pistachio"],  "nut"),
    (["peanut"],     "nut"),
    (["hazelnut"],   "nut"),
    (["macadamia"],  "nut"),
    (["chestnut"],   "nut"),
    (["coconut"],    "nut"),

    # Spice / Herb
    (["salt"],       "spice"),
    (["pepper"],     "spice"),
    (["cumin"],      "spice"),
    (["paprika"],    "spice"),
    (["cayenne"],    "spice"),
    (["cinnamon"],   "spice"),
    (["nutmeg"],     "spice"),
    (["oregano"],    "spice"),
    (["turmeric"],   "spice"),
    (["coriander"],  "spice"),
    (["cardamom"],   "spice"),
    (["clove"],      "spice"),
    (["allspice"],   "spice"),
    (["saffron"],    "spice"),
    (["anise"],      "spice"),
    (["fennel"],     "spice"),    (["]tsaoko"],     "spice"),    (["dill"],       "spice"),
    (["thyme"],      "spice"),
    (["rosemary"],   "spice"),
    (["sage"],       "spice"),
    (["basil"],      "spice"),
    (["parsley"],    "spice"),
    (["cilantro"],   "spice"),
    (["mint"],       "spice"),
    (["tarragon"],   "spice"),
    (["chive"],      "spice"),
    (["bay leaf"],   "spice"),
    (["bay leaves"], "spice"),
    (["marjoram"],   "spice"),
    (["five spice"], "spice"),
    (["gochugaru"],  "spice"),
    (["sumac"],      "spice"),
    (["zaatar"],     "spice"),
    (["za'atar"],    "spice"),
    (["lemongrass"], "spice"),
    (["fenugreek"],  "spice"),
    (["msg"],        "spice"),
    (["spice"],      "spice"),
    (["seasoning"],  "spice"),
    (["herb"],       "spice"),

    # Condiment (catch-all)
    (["sauce"],      "condiment"),
    (["paste"],      "condiment"),
    (["marinade"],   "condiment"),
    (["glaze"],      "condiment"),

    # Oil
    (["oil"],        "oil"),

    # Vinegar
    (["vinegar"],    "vinegar"),

    # Flour
    (["flour"],      "flour"),
    (["starch"],     "flour"),

    # Sugar
    (["sugar"],      "sugar"),
    (["honey"],      "sugar"),
    (["syrup"],      "sugar"),
    (["chocolate"],  "sugar"),
    (["candy"],      "sugar"),
    (["caramel"],    "sugar"),
    (["jam"],        "sugar"),
    (["jelly"],      "sugar"),
    (["marmalade"],  "sugar"),
    (["vanilla"],    "sugar"),
]

# =============================================================================
# OFF CATEGORY → Memoix Category heuristic (for main_category_en field)
# =============================================================================
OFF_CATEGORY_MAP = [
    # Multi-word OFF categories (checked first)
    ("plant-based", None),          # Skip — classify by name instead
    ("breakfast cereal", "grain"),
    ("ice cream", "dairy"),
    ("frozen meal", None),          # Too ambiguous
    ("ready meal", None),

    # Single keywords in OFF category
    ("meat", "meat"),
    ("ham", "meat"),
    ("beef", "meat"),
    ("pork", "meat"),
    ("sausage", "meat"),
    ("deli", "meat"),
    ("poultry", "poultry"),
    ("chicken", "poultry"),
    ("turkey", "poultry"),
    ("fish", "seafood"),
    ("seafood", "seafood"),
    ("crustacean", "seafood"),
    ("cheese", "cheese"),
    ("dairy", "dairy"),
    ("milk", "dairy"),
    ("butter", "dairy"),
    ("cream", "dairy"),
    ("yogurt", "dairy"),
    ("egg", "egg"),
    ("bread", "grain"),
    ("cereal", "grain"),
    ("rice", "grain"),
    ("grain", "grain"),
    ("pasta", "pasta"),
    ("noodle", "pasta"),
    ("legume", "legume"),
    ("bean", "legume"),
    ("lentil", "legume"),
    ("nut", "nut"),
    ("seed", "nut"),
    ("spice", "spice"),
    ("herb", "spice"),
    ("seasoning", "spice"),
    ("sauce", "condiment"),
    ("condiment", "condiment"),
    ("dressing", "condiment"),
    ("mustard", "condiment"),
    ("ketchup", "condiment"),
    ("oil", "oil"),
    ("vinegar", "vinegar"),
    ("flour", "flour"),
    ("sugar", "sugar"),
    ("sweetener", "sugar"),
    ("honey", "sugar"),
    ("syrup", "sugar"),
    ("chocolate", "sugar"),
    ("candy", "sugar"),
    ("confectionery", "sugar"),
    ("baking", "leavening"),
    ("alcohol", "alcohol"),
    ("wine", "alcohol"),
    ("beer", "alcohol"),
    ("spirit", "alcohol"),
    ("soda", "pop"),
    ("soft drink", "pop"),
    ("juice", "juice"),
    ("coffee", "beverage"),
    ("tea", "beverage"),
    ("water", "beverage"),
    ("beverage", "beverage"),
    ("drink", "beverage"),
    ("snack", None),               # Too ambiguous
    ("frozen", None),
    ("canned", None),
]


def classify_by_name(name: str) -> str | None:
    """Classify by product name using KEYWORD_RULES. Returns category or None."""
    for keywords, category in KEYWORD_RULES:
        if all(kw in name for kw in keywords):
            return category
    return None


def classify_by_off_category(off_cat: str) -> str | None:
    """Classify by OFF main_category_en field. Returns category or None."""
    if not off_cat:
        return None
    for keyword, category in OFF_CATEGORY_MAP:
        if keyword in off_cat:
            return category
    return None


def is_culinary_ingredient(name: str, off_cat: str, tags: str) -> bool:
    """Filter out non-ingredient products (snacks, ready meals, brands, etc.)."""
    # Skip very long product names (likely branded/packaged items)
    if len(name) > 60:
        return False
    # Skip items with numbers that look like product codes
    if re.search(r'\d{5,}', name):
        return False
    # Skip common non-ingredient indicators
    skip_words = [
        "pizza", "sandwich", "burger", "wrap", "meal kit", "ready to eat",
        "frozen dinner", "tv dinner", "microwave", "instant", "protein bar",
        "energy bar", "snack bar", "chips", "crisps", "cookie", "biscuit",
        "crouton", "popcorn", "pretzel",
    ]
    for w in skip_words:
        if w in name:
            return False
    return True


def build_database(file_path: str, generate_meta: bool = False):
    """Build the ingredient classification database from an OFF TSV export."""
    category_db = {}
    meta_db = {} if generate_meta else None
    skipped = 0
    classified = 0
    unclassified = 0

    if not os.path.exists(file_path):
        print(f"Error: {file_path} not found.")
        print("Download from: https://world.openfoodfacts.org/data")
        return

    print(f"Parsing OpenFoodFacts data from {file_path}...")
    print("(This may take several minutes for large files)")

    with open(file_path, mode='r', encoding='utf-8') as f:
        reader = csv.DictReader(f, delimiter='\t')

        for i, row in enumerate(reader):
            if i % 500_000 == 0 and i > 0:
                print(f"  ...processed {i:,} rows ({classified:,} classified, {skipped:,} skipped)")

            name = (row.get('product_name', '') or '').lower().strip()
            if not name or len(name) < 2:
                skipped += 1
                continue

            off_cat = (row.get('main_category_en', '') or '').lower()
            tags = (row.get('categories_tags', '') or '').lower()

            # Filter out non-ingredient items
            if not is_culinary_ingredient(name, off_cat, tags):
                skipped += 1
                continue

            # Classification priority:
            # 1. Name-based keyword rules (most accurate)
            # 2. OFF category field
            # 3. Skip (do NOT default to produce)
            cat = classify_by_name(name)
            if cat is None:
                cat = classify_by_off_category(off_cat)
            if cat is None:
                # Also try classifying the OFF tags
                cat = classify_by_off_category(tags)

            if cat is None:
                unclassified += 1
                continue  # Skip entirely — better to miss than misclassify

            cat_index = CAT.get(cat, UNKNOWN)
            if cat_index == UNKNOWN:
                unclassified += 1
                continue

            category_db[name] = cat_index
            classified += 1

            # Optional: collect metadata
            if meta_db is not None:
                meta = {"cat": cat_index}

                # Dietary labels
                labels = (row.get('labels_en', '') or '').lower()
                if 'vegan' in labels:
                    meta['vegan'] = True
                elif 'vegetarian' in labels:
                    meta['vegetarian'] = True

                # Allergens
                allergens = (row.get('allergens_en', '') or '').strip()
                if allergens:
                    meta['allergens'] = allergens

                # Basic nutrition (per 100g)
                kcal = row.get('energy-kcal_100g', '')
                if kcal:
                    try:
                        meta['kcal'] = round(float(kcal))
                    except ValueError:
                        pass

                protein = row.get('proteins_100g', '')
                if protein:
                    try:
                        meta['protein'] = round(float(protein), 1)
                    except ValueError:
                        pass

                carbs = row.get('carbohydrates_100g', '')
                if carbs:
                    try:
                        meta['carbs'] = round(float(carbs), 1)
                    except ValueError:
                        pass

                fat = row.get('fat_100g', '')
                if fat:
                    try:
                        meta['fat'] = round(float(fat), 1)
                    except ValueError:
                        pass

                fiber = row.get('fiber_100g', '')
                if fiber:
                    try:
                        meta['fiber'] = round(float(fiber), 1)
                    except ValueError:
                        pass

                sodium = row.get('sodium_100g', '')
                if sodium:
                    try:
                        meta['sodium'] = round(float(sodium), 3)
                    except ValueError:
                        pass

                meta_db[name] = meta

    print(f"\nResults:")
    print(f"  Classified:   {classified:,}")
    print(f"  Unclassified: {unclassified:,}  (skipped — not defaulted to produce)")
    print(f"  Filtered out: {skipped:,}")

    # Category distribution
    dist = {}
    for idx in category_db.values():
        cat_name = CATEGORIES[idx] if idx < len(CATEGORIES) else "unknown"
        dist[cat_name] = dist.get(cat_name, 0) + 1
    print(f"\n  Category distribution:")
    for cat_name in CATEGORIES:
        count = dist.get(cat_name, 0)
        if count > 0:
            print(f"    {cat_name:>12s}: {count:>7,}")

    # Write category-only file (lightweight, used by IngredientService)
    out_path = 'ingredients_json.gz'
    json_str = json.dumps(category_db, separators=(',', ':'))
    with gzip.open(out_path, 'wb') as f:
        f.write(json_str.encode('utf-8'))
    size_kb = os.path.getsize(out_path) / 1024
    print(f"\n  Wrote {out_path} ({size_kb:.0f} KB, {len(category_db):,} entries)")

    # Write metadata file (optional, for future nutrition/dietary features)
    if meta_db is not None:
        meta_path = 'ingredients_meta.gz'
        meta_str = json.dumps(meta_db, separators=(',', ':'))
        with gzip.open(meta_path, 'wb') as f:
            f.write(meta_str.encode('utf-8'))
        meta_kb = os.path.getsize(meta_path) / 1024
        print(f"  Wrote {meta_path} ({meta_kb:.0f} KB, {len(meta_db):,} entries)")

    print("\nDone. Copy ingredients_json.gz to assets/ingredients/")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description='Build Memoix ingredient database from OpenFoodFacts data'
    )
    parser.add_argument('input', help='Path to OFF TSV/CSV export file')
    parser.add_argument('--meta', action='store_true',
                        help='Also generate ingredients_meta.gz with nutrition/dietary data')
    args = parser.parse_args()

    build_database(args.input, generate_meta=args.meta)
