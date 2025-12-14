import 'package:flutter/material.dart';

/// Color palette for Memoix app
/// Based on spreadsheet color-coding system for recipe categories
class MemoixColors {
  MemoixColors._();

  // Primary brand colors
  static const Color primary = Color(0xFFE67C23); // Warm orange (like your header)
  static const Color primaryLight = Color(0xFFFFA726);
  static const Color primaryDark = Color(0xFFE65100);

  // Course category colors (matching spreadsheet tabs)
  static const Color mains = Color(0xFFFFB74D);       // Orange/Gold
  static const Color apps = Color(0xFF81C784);        // Green
  static const Color soups = Color(0xFF64B5F6);       // Blue
  static const Color salads = Color(0xFFA5D6A7);      // Light green
  static const Color brunch = Color(0xFFFFD54F);      // Yellow
  static const Color sides = Color(0xFFDCE775);       // Lime
  static const Color desserts = Color(0xFFF48FB1);    // Pink
  static const Color breads = Color(0xFFD7CCC8);      // Tan/Brown
  static const Color rubs = Color(0xFFBCAAA4);        // Brown
  static const Color sauces = Color(0xFFFF8A65);      // Coral
  static const Color pickles = Color(0xFFAED581);     // Lime green
  static const Color modernist = Color(0xFFCE93D8);  // Purple
  static const Color pizzas = Color(0xFFFFCC80);      // Light orange
  static const Color sandwiches = Color(0xFFFFE082);  // Light gold
  static const Color smoking = Color(0xFF90A4AE);     // Gray
  static const Color cheese = Color(0xFFFFF176);      // Light yellow
  static const Color vegn = Color(0xFF80CBC4);        // Teal
  static const Color scratch = Color(0xFFB0BEC5);     // Blue-gray
  static const Color drinks = Color(0xFF81D4FA);      // Light blue

  // Cuisine style colors (for highlighting rows like in spreadsheet)
  static const Color korean = Color(0xFFFFE082);      // Light gold
  static const Color french = Color(0xFFB3E5FC);      // Light blue
  static const Color italian = Color(0xFFC8E6C9);     // Light green
  static const Color mexican = Color(0xFFFFCCBC);     // Light coral
  static const Color japanese = Color(0xFFF8BBD9);    // Light pink
  static const Color indian = Color(0xFFFFE0B2);      // Light orange
  static const Color american = Color(0xFFE1BEE7);    // Light purple
  static const Color chinese = Color(0xFFFFECB3);     // Cream
  static const Color mediterranean = Color(0xFFB2DFDB); // Mint
  static const Color vietnamese = Color(0xFFDCEDC8);  // Light lime
  static const Color thai = Color(0xFFFFCDD2);        // Light red
  static const Color greek = Color(0xFFB2EBF2);       // Light cyan
  static const Color spanish = Color(0xFFF0F4C3);     // Light lime yellow
  static const Color german = Color(0xFFD7CCC8);      // Light brown
  static const Color lebanese = Color(0xFFE0F7FA);    // Pale cyan
  static const Color ethiopian = Color(0xFFD1C4E9);   // Light deep purple
  static const Color cuban = Color(0xFFFFF9C4);       // Light yellow
  static const Color brazilian = Color(0xFFDCEDC8);   // Light green
  static const Color peruvian = Color(0xFFFFE0B2);    // Light amber
  static const Color southern = Color(0xFFFFECB3);    // Light amber
  static const Color cajun = Color(0xFFFFCCBC);       // Light deep orange
  static const Color moroccan = Color(0xFFD7CCC8);    // Light brown
  static const Color turkish = Color(0xFFB3E5FC);     // Light blue

  // Continent-based dot colors (thematic with primary #E8B4A0 / secondary #A88FA8)
  // These are used for cuisine indicator dots, designed to complement the warm palette
  static const Color continentAsian = Color(0xFFE07B6F);       // Warm coral-red
  static const Color continentEuropean = Color(0xFF7B9CC4);    // Muted blue
  static const Color continentAmericas = Color(0xFF7AB89E);    // Sage green  
  static const Color continentCaribbean = Color(0xFFE8A86B);   // Warm orange-gold
  static const Color continentAfrican = Color(0xFFB8906E);     // Terracotta
  static const Color continentMiddleEast = Color(0xFFD4A574);  // Saffron/amber
  static const Color continentOceanian = Color(0xFF6BA3B5);    // Ocean teal
  static const Color fusionCuisine = Color(0xFFA88FA8);        // Purple/mauve - blend of cultures

  // Spirit-based dot colors for drinks/cocktails
  // Thematic colors complementing the warm palette
  static const Color spiritGin = Color(0xFF7EB8C4);            // Clear/juniper blue-green
  static const Color spiritVodka = Color(0xFFB8C4D4);          // Clean/neutral silver-blue
  static const Color spiritWhiskey = Color(0xFFD4A574);        // Amber/oak
  static const Color spiritRum = Color(0xFFD4956E);            // Caramel/molasses
  static const Color spiritTequila = Color(0xFFE8C878);        // Agave gold
  static const Color spiritBrandy = Color(0xFFC4876E);         // Grape/copper
  static const Color spiritWine = Color(0xFF983058);           // Deep wine red
  static const Color spiritSparkling = Color(0xFFF8E8A0);      // Champagne gold
  static const Color spiritLiqueur = Color(0xFFC898B8);        // Sweet lavender
  static const Color spiritBeer = Color(0xFFD8A850);           // Golden ale
  static const Color spiritTea = Color(0xFF8EB878);            // Green tea
  static const Color spiritCoffee = Color(0xFF6F4E37);         // Coffee brown
  static const Color spiritMocktail = Color(0xFF7EB8A8);       // Fresh teal

  // Pizza sauce/base colors for pizza recipes
  // Thematic colors representing each sauce type
  static const Color pizzaMarinara = Color(0xFFD4635A);        // Tomato red
  static const Color pizzaOil = Color(0xFFD4C86E);             // Golden olive oil
  static const Color pizzaPesto = Color(0xFF7AB87A);           // Basil green
  static const Color pizzaCream = Color(0xFFF5F0E8);           // Creamy white
  static const Color pizzaBbq = Color(0xFF8B4513);             // Smoky brown
  static const Color pizzaBuffalo = Color(0xFFE8783A);         // Orange-red buffalo
  static const Color pizzaAlfredo = Color(0xFFE8DCC8);         // Butter cream
  static const Color pizzaGarlic = Color(0xFFE8D87E);          // Garlic butter gold
  static const Color pizzaNoSauce = Color(0xFFB0BEC5);         // Neutral gray

  // Smoked item category colors for smoking recipes
  // Thematic pastel colors matching app palette
  static const Color smokedBeef = Color(0xFFD4847A);           // Soft coral-red for beef
  static const Color smokedPork = Color(0xFFE8A8A8);           // Soft pink for pork
  static const Color smokedPoultry = Color(0xFFE8C878);        // Soft golden for poultry
  static const Color smokedLamb = Color(0xFFBCA898);           // Soft tan for lamb
  static const Color smokedGame = Color(0xFF9C8070);           // Soft brown for game
  static const Color smokedSeafood = Color(0xFF7EBCC4);        // Soft ocean teal for seafood
  static const Color smokedVegetables = Color(0xFF8EC898);     // Soft sage green for vegetables
  static const Color smokedCheese = Color(0xFFE8D87E);         // Soft golden for cheese
  static const Color smokedDesserts = Color(0xFFD8A8C0);       // Soft mauve-pink for desserts
  static const Color smokedFruits = Color(0xFFC4A8D4);         // Soft lavender for fruits
  static const Color smokedDips = Color(0xFFD8A888);           // Soft terracotta for dips
  static const Color smokedOther = Color(0xFFB0BEC5);          // Soft blue-gray for other

  // Modernist type colors (Concept vs Technique)
  // Thematic colors that fit with the warm palette
  static const Color modernistConcept = Color(0xFF7EB8A8);     // Sage teal - creative/flavor concepts
  static const Color modernistTechnique = Color(0xFFB898C4);   // Soft lavender - scientific techniques

  // UI colors
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color error = Color(0xFFE53935);
  static const Color success = Color(0xFF43A047);

  /// Get color for a course category
  static Color forCourse(String course) {
    switch (course.toLowerCase()) {
      case 'mains':
        return mains;
      case 'apps':
      case 'appetizers':
        return apps;
      case 'soup':
      case 'soups':
        return soups;
      case 'salad':
      case 'salads':
        return salads;
      case 'brunch':
        return brunch;
      case 'sides':
        return sides;
      case 'desserts':
        return desserts;
      case 'breads':
        return breads;
      case 'rubs':
        return rubs;
      case 'sauces':
        return sauces;
      case 'pickles':
      case 'pickles/brines':
        return pickles;
      case 'modernist':
        return modernist;
      case 'pizzas':
        return pizzas;
      case 'sandwiches':
        return sandwiches;
      case 'smoking':
        return smoking;
      case 'cheese':
        return cheese;
      case 'vegn':
      case 'veg*n':
      case 'vegetarian':
      case 'not meat':
        return vegn;
      case 'scratch':
        return scratch;
      case 'drinks':
        return drinks;
      default:
        return primary;
    }
  }

  /// Get color for a cuisine style
  static Color forCuisine(String cuisine) {
    switch (cuisine.toLowerCase()) {
      case 'korean':
        return korean;
      case 'french':
        return french;
      case 'italian':
        return italian;
      case 'mexican':
        return mexican;
      case 'japanese':
        return japanese;
      case 'indian':
        return indian;
      case 'american':
        return american;
      case 'chinese':
        return chinese;
      case 'mediterranean':
        return mediterranean;
      case 'vietnamese':
        return vietnamese;
      case 'thai':
        return thai;
      case 'greek':
        return greek;
      case 'spanish':
        return spanish;
      case 'german':
        return german;
      case 'lebanese':
        return lebanese;
      case 'ethiopian':
        return ethiopian;
      case 'cuban':
        return cuban;
      case 'brazilian':
        return brazilian;
      case 'peruvian':
        return peruvian;
      case 'southern':
        return southern;
      case 'cajun':
        return cajun;
      case 'moroccan':
        return moroccan;
      case 'turkish':
        return turkish;
      case 'north american':
        return american;
      case 'south american':
        return brazilian;
      default:
        return Colors.grey.shade100;
    }
  }

  /// Get dot color for a cuisine based on its continent grouping
  /// Uses themed colors that complement the app's primary/secondary palette
  /// Handles both cuisine names ("Japanese") and country codes ("JP")
  static Color forContinentDot(String? cuisine) {
    if (cuisine == null || cuisine.isEmpty) return Colors.grey;
    
    final lower = cuisine.toLowerCase().trim();
    final upper = cuisine.toUpperCase().trim();
    
    // Fusion cuisines get their own distinct color
    if (lower.contains('fusion')) return fusionCuisine;
    
    // Check 2-3 letter country codes first (comprehensive list)
    const asianCodes = ['BD', 'MM', 'KH', 'CN', 'IN', 'ID', 'JP', 'KR', 'LA', 'MY', 'MN', 'NP', 'PK', 'PH', 'SG', 'LK', 'TW', 'TH', 'VN'];
    const europeanCodes = ['AL', 'AT', 'BY', 'BE', 'BA', 'GB', 'BG', 'HR', 'CY', 'CZ', 'DK', 'NL', 'EE', 'FI', 'FR', 'GE', 'DE', 'GR', 'HU', 'IS', 'IE', 'IT', 'LV', 'LT', 'MT', 'MD', 'ME', 'NO', 'PL', 'PT', 'RO', 'RU', 'RS', 'SK', 'SI', 'ES', 'SE', 'CH', 'UA'];
    const americasCodes = ['AR', 'BO', 'BR', 'CA', 'CL', 'CO', 'CR', 'EC', 'SV', 'GT', 'HN', 'MX', 'NI', 'PA', 'PY', 'PE', 'US', 'UY', 'VE'];
    const caribbeanCodes = ['BS', 'BB', 'CU', 'DO', 'GY', 'HT', 'JM', 'PR', 'TT'];
    const africanCodes = ['DZ', 'CM', 'EG', 'ET', 'GH', 'KE', 'MA', 'NG', 'SN', 'ZA', 'TZ', 'TN', 'UG'];
    const middleEastCodes = ['AF', 'BH', 'AE', 'IR', 'IQ', 'IL', 'JO', 'KW', 'LB', 'OM', 'PS', 'QA', 'SA', 'SY', 'TR', 'YE'];
    const oceanianCodes = ['AU', 'FJ', 'HI', 'NZ', 'PG', 'WS', 'TO'];
    
    if (asianCodes.contains(upper)) return continentAsian;
    if (europeanCodes.contains(upper)) return continentEuropean;
    if (americasCodes.contains(upper)) return continentAmericas;
    if (caribbeanCodes.contains(upper)) return continentCaribbean;
    if (africanCodes.contains(upper)) return continentAfrican;
    if (middleEastCodes.contains(upper)) return continentMiddleEast;
    if (oceanianCodes.contains(upper)) return continentOceanian;
    
    // Asian cuisines by name
    if (['korean', 'japanese', 'chinese', 'indian', 'thai', 'vietnamese',
         'filipino', 'indonesian', 'malaysian', 'singaporean', 'taiwanese',
         'pakistani', 'nepali', 'sri lankan', 'bangladeshi', 'burmese',
         'cambodian', 'laotian', 'mongolian', 'korea', 'japan', 'china',
         'india', 'thailand', 'vietnam', 'philippines', 'indonesia', 'malaysia',
         'singapore', 'taiwan', 'pakistan', 'nepal', 'sri lanka', 'bangladesh',
         'myanmar', 'burma', 'cambodia', 'laos', 'mongolia', 'asian',].contains(lower)) {
      return continentAsian;
    }
    
    // European cuisines by name
    if (['french', 'italian', 'spanish', 'german', 'greek', 'british',
         'irish', 'polish', 'portuguese', 'russian', 'swedish', 'hungarian',
         'ukrainian', 'austrian', 'belgian', 'croatian', 'czech', 'danish',
         'dutch', 'finnish', 'norwegian', 'romanian', 'serbian', 'swiss',
         'albanian', 'belarusian', 'bosnian', 'bulgarian', 'cypriot', 'estonian',
         'georgian', 'icelandic', 'latvian', 'lithuanian', 'maltese', 'moldovan',
         'montenegrin', 'slovak', 'slovenian',
         'france', 'italy', 'spain', 'germany', 'greece', 'uk', 'united kingdom',
         'england', 'ireland', 'poland', 'portugal', 'russia', 'sweden',
         'hungary', 'ukraine', 'austria', 'belgium', 'croatia', 'denmark',
         'netherlands', 'finland', 'norway', 'romania', 'serbia', 'switzerland',
         'albania', 'belarus', 'bosnia', 'bulgaria', 'cyprus', 'estonia',
         'georgia', 'iceland', 'latvia', 'lithuania', 'malta', 'moldova',
         'montenegro', 'slovakia', 'slovenia',
         'european', 'mediterranean', 'nordic', 'scandinavian',].contains(lower)) {
      return continentEuropean;
    }
    
    // Americas cuisines by name
    if (['american', 'mexican', 'brazilian', 'argentine', 'peruvian',
         'canadian', 'chilean', 'colombian', 'venezuelan', 'bolivian',
         'costa rican', 'ecuadorian', 'salvadoran', 'guatemalan', 'honduran',
         'nicaraguan', 'panamanian', 'paraguayan', 'uruguayan',
         'usa', 'united states', 'america', 'mexico', 'brazil', 'argentina',
         'peru', 'canada', 'chile', 'colombia', 'venezuela', 'bolivia',
         'costa rica', 'ecuador', 'el salvador', 'guatemala', 'honduras',
         'nicaragua', 'panama', 'paraguay', 'uruguay',
         'north american', 'south american', 'latin american', 'southern',
         'cajun', 'tex-mex', 'creole',].contains(lower)) {
      return continentAmericas;
    }
    
    // Caribbean cuisines by name
    if (['jamaican', 'cuban', 'haitian', 'dominican', 'puerto rican',
         'trinidadian', 'barbadian', 'bahamian', 'guyanese',
         'jamaica', 'cuba', 'haiti', 'dominican republic', 'puerto rico',
         'trinidad', 'barbados', 'bahamas', 'guyana', 'caribbean',].contains(lower)) {
      return continentCaribbean;
    }
    
    // African cuisines by name
    if (['ethiopian', 'moroccan', 'south african', 'egyptian', 'nigerian',
         'ghanaian', 'kenyan', 'tunisian', 'algerian', 'cameroonian',
         'senegalese', 'tanzanian', 'ugandan',
         'ethiopia', 'morocco', 'south africa', 'egypt', 'nigeria', 'ghana',
         'kenya', 'tunisia', 'algeria', 'cameroon', 'senegal', 'tanzania',
         'uganda', 'african',].contains(lower)) {
      return continentAfrican;
    }
    
    // Middle Eastern cuisines by name
    if (['turkish', 'lebanese', 'israeli', 'persian', 'iraqi', 'syrian',
         'jordanian', 'palestinian', 'saudi', 'yemeni', 'afghan', 'bahraini',
         'emirati', 'kuwaiti', 'omani', 'qatari',
         'turkey', 'lebanon', 'israel', 'iran', 'persia', 'iraq', 'syria',
         'jordan', 'palestine', 'saudi arabia', 'yemen', 'afghanistan',
         'bahrain', 'uae', 'united arab emirates', 'kuwait', 'oman', 'qatar',
         'middle east', 'middle eastern',].contains(lower)) {
      return continentMiddleEast;
    }
    
    // Oceanian cuisines by name
    if (['australian', 'new zealand', 'hawaiian', 'fijian', 'samoan',
         'tongan', 'papua new guinean',
         'australia', 'hawaii', 'fiji', 'samoa', 'tonga', 'papua new guinea',
         'oceanian', 'polynesian',].contains(lower)) {
      return continentOceanian;
    }
    
    // Fallback
    return Colors.grey;
  }

  /// Get dot color for a spirit/drink base type
  /// Uses themed colors for visual identification of cocktail base spirits
  static Color forSpiritDot(String? spirit) {
    if (spirit == null || spirit.isEmpty) return Colors.grey;
    
    final lower = spirit.toLowerCase().trim();
    final upper = spirit.toUpperCase().trim();
    
    // Gin family
    if (upper == 'GIN' || lower == 'gin') return spiritGin;
    
    // Vodka
    if (upper == 'VODKA' || lower == 'vodka') return spiritVodka;
    
    // Whiskey family (bourbon, rye, scotch, etc.)
    if (['WHISKEY', 'BOURBON', 'RYE', 'SCOTCH', 'WHISKY'].contains(upper) ||
        ['whiskey', 'bourbon', 'rye', 'scotch', 'whisky', 'irish whiskey'].contains(lower)) {
      return spiritWhiskey;
    }
    
    // Rum family (including cachaça)
    if (['RUM', 'CACHACA'].contains(upper) ||
        ['rum', 'cachaça', 'cachaca', 'rhum'].contains(lower)) {
      return spiritRum;
    }
    
    // Tequila/Mezcal
    if (['TEQUILA', 'MEZCAL'].contains(upper) ||
        ['tequila', 'mezcal', 'agave'].contains(lower)) {
      return spiritTequila;
    }
    
    // Brandy family (cognac, pisco)
    if (['BRANDY', 'COGNAC', 'PISCO'].contains(upper) ||
        ['brandy', 'cognac', 'pisco', 'armagnac', 'calvados'].contains(lower)) {
      return spiritBrandy;
    }
    
    // Wine (still wines)
    if (['RED_WINE', 'WHITE_WINE', 'ROSE_WINE', 'VERMOUTH', 'SHERRY', 'PORT'].contains(upper) ||
        ['red wine', 'white wine', 'rosé', 'rose', 'vermouth', 'sherry', 'port', 'wine'].contains(lower)) {
      return spiritWine;
    }
    
    // Sparkling wine family
    if (['PROSECCO', 'CHAMPAGNE', 'SPARKLING'].contains(upper) ||
        ['prosecco', 'champagne', 'sparkling', 'sparkling wine', 'cava', 'cremant'].contains(lower)) {
      return spiritSparkling;
    }
    
    // Liqueurs and Aperitifs
    if (['LIQUEUR', 'AMARO', 'APERITIF'].contains(upper) ||
        ['liqueur', 'amaro', 'aperitif', 'aperol', 'campari', 'chartreuse', 
         'triple sec', 'cointreau', 'grand marnier', 'kahlua', 'baileys',
         'amaretto', 'frangelico', 'sambuca', 'st germain',].contains(lower)) {
      return spiritLiqueur;
    }
    
    // Beer family
    if (['BEER', 'CIDER'].contains(upper) ||
        ['beer', 'cider', 'lager', 'ale', 'stout', 'ipa', 'porter'].contains(lower)) {
      return spiritBeer;
    }
    
    // Tea
    if (upper == 'TEA' || ['tea', 'barley tea', 'green tea', 'oolong', 'chai', 'matcha'].contains(lower)) {
      return spiritTea;
    }
    
    // Coffee
    if (upper == 'COFFEE' || ['coffee', 'espresso', 'latte', 'cappuccino'].contains(lower)) {
      return spiritCoffee;
    }
    
    // Mocktails and other non-alcoholic
    if (['MOCKTAIL', 'SMOOTHIE', 'JUICE', 'SODA', 'HOT_CHOC'].contains(upper) ||
        ['mocktail', 'smoothie', 'juice', 'soda', 'tonic', 'hot chocolate', 
         'non-alcoholic', 'virgin',].contains(lower)) {
      return spiritMocktail;
    }
    
    // Other Asian spirits
    if (['SAKE', 'SOJU'].contains(upper) || ['sake', 'saké', 'soju'].contains(lower)) {
      return spiritSparkling; // Light/clear color
    }
    
    // Absinthe/Aquavit
    if (['ABSINTHE', 'AQUAVIT'].contains(upper) || ['absinthe', 'aquavit'].contains(lower)) {
      return spiritGin; // Similar botanical profile
    }
    
    // Fallback
    return Colors.grey;
  }

  /// Get dot color for a pizza sauce/base type
  /// Uses themed colors for visual identification of sauce type
  static Color forPizzaBaseDot(String? base) {
    if (base == null || base.isEmpty) return pizzaMarinara;
    
    final lower = base.toLowerCase().trim();
    
    switch (lower) {
      case 'marinara':
      case 'tomato':
      case 'red':
        return pizzaMarinara;
      case 'oil':
      case 'evoo':
      case 'olive':
        return pizzaOil;
      case 'pesto':
        return pizzaPesto;
      case 'cream':
      case 'white':
        return pizzaCream;
      case 'bbq':
      case 'barbeque':
      case 'barbecue':
        return pizzaBbq;
      case 'buffalo':
      case 'hot sauce':
        return pizzaBuffalo;
      case 'alfredo':
        return pizzaAlfredo;
      case 'garlic':
      case 'garlic butter':
        return pizzaGarlic;
      case 'none':
      case 'no sauce':
        return pizzaNoSauce;
      default:
        return pizzaMarinara;
    }
  }

  /// Get dot color for a modernist recipe type (Concept or Technique)
  /// Uses themed colors to distinguish recipe types
  static Color forModernistType(String? type) {
    if (type == null || type.isEmpty) return modernistConcept;
    
    final lower = type.toLowerCase().trim();
    
    switch (lower) {
      case 'concept':
        return modernistConcept;
      case 'technique':
        return modernistTechnique;
      default:
        return modernistConcept;
    }
  }

  /// Get dot color for a smoked item category
  /// Uses themed colors for visual identification of what's being smoked
  static Color forSmokedItemDot(String? category) {
    if (category == null || category.isEmpty) return Colors.grey;
    
    final lower = category.toLowerCase().trim();
    
    switch (lower) {
      case 'beef':
        return smokedBeef;
      case 'pork':
        return smokedPork;
      case 'poultry':
      case 'chicken':
      case 'turkey':
      case 'duck':
        return smokedPoultry;
      case 'lamb':
        return smokedLamb;
      case 'game':
      case 'venison':
      case 'elk':
      case 'wild boar':
        return smokedGame;
      case 'seafood':
      case 'fish':
      case 'salmon':
      case 'shrimp':
        return smokedSeafood;
      case 'vegetables':
      case 'veggie':
      case 'veggies':
        return smokedVegetables;
      case 'cheese':
        return smokedCheese;
      case 'desserts':
      case 'dessert':
      case 'sweet':
        return smokedDesserts;
      case 'fruits':
      case 'fruit':
        return smokedFruits;
      case 'dips':
      case 'dip':
      case 'sides':
        return smokedDips;
      default:
        return smokedOther;
    }
  }
}
