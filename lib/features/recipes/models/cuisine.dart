/// Represents a cuisine origin with continent grouping
class Cuisine {
  final String code;        // 2-letter code (KR, JP, etc.)
  final String name;        // Full name (Korean, Japanese)
  final String continent;   // Continent grouping
  final String flag;        // Emoji flag

  const Cuisine({
    required this.code,
    required this.name,
    required this.continent,
    required this.flag,
  });

  /// All supported cuisines, grouped by continent
  static const List<Cuisine> all = [
    // African
    Cuisine(code: 'DZ', name: 'Algerian', continent: 'African', flag: '🇩🇿'),
    Cuisine(code: 'CM', name: 'Cameroonian', continent: 'African', flag: '🇨🇲'),
    Cuisine(code: 'EG', name: 'Egyptian', continent: 'African', flag: '🇪🇬'),
    Cuisine(code: 'ET', name: 'Ethiopian', continent: 'African', flag: '🇪🇹'),
    Cuisine(code: 'GH', name: 'Ghanaian', continent: 'African', flag: '🇬🇭'),
    Cuisine(code: 'KE', name: 'Kenyan', continent: 'African', flag: '🇰🇪'),
    Cuisine(code: 'MA', name: 'Moroccan', continent: 'African', flag: '🇲🇦'),
    Cuisine(code: 'NG', name: 'Nigerian', continent: 'African', flag: '🇳🇬'),
    Cuisine(code: 'SN', name: 'Senegalese', continent: 'African', flag: '🇸🇳'),
    Cuisine(code: 'ZA', name: 'South African', continent: 'African', flag: '🇿🇦'),
    Cuisine(code: 'TZ', name: 'Tanzanian', continent: 'African', flag: '🇹🇿'),
    Cuisine(code: 'TN', name: 'Tunisian', continent: 'African', flag: '🇹🇳'),
    Cuisine(code: 'UG', name: 'Ugandan', continent: 'African', flag: '🇺🇬'),

    // North American
    Cuisine(code: 'CA', name: 'Canadian', continent: 'North American', flag: '🇨🇦'),
    Cuisine(code: 'MX', name: 'Mexican', continent: 'North American', flag: '🇲🇽'),
    Cuisine(code: 'US', name: 'American', continent: 'North American', flag: '🇺🇸'),

    // Central American
    Cuisine(code: 'CR', name: 'Costa Rican', continent: 'Central American', flag: '🇨🇷'),
    Cuisine(code: 'SV', name: 'Salvadoran', continent: 'Central American', flag: '🇸🇻'),
    Cuisine(code: 'GT', name: 'Guatemalan', continent: 'Central American', flag: '🇬🇹'),
    Cuisine(code: 'HN', name: 'Honduran', continent: 'Central American', flag: '🇭🇳'),
    Cuisine(code: 'NI', name: 'Nicaraguan', continent: 'Central American', flag: '🇳🇮'),
    Cuisine(code: 'PA', name: 'Panamanian', continent: 'Central American', flag: '🇵🇦'),

    // South American
    Cuisine(code: 'AR', name: 'Argentine', continent: 'South American', flag: '🇦🇷'),
    Cuisine(code: 'BO', name: 'Bolivian', continent: 'South American', flag: '🇧🇴'),
    Cuisine(code: 'BR', name: 'Brazilian', continent: 'South American', flag: '🇧🇷'),
    Cuisine(code: 'CL', name: 'Chilean', continent: 'South American', flag: '🇨🇱'),
    Cuisine(code: 'CO', name: 'Colombian', continent: 'South American', flag: '🇨🇴'),
    Cuisine(code: 'EC', name: 'Ecuadorian', continent: 'South American', flag: '🇪🇨'),
    Cuisine(code: 'PY', name: 'Paraguayan', continent: 'South American', flag: '🇵🇾'),
    Cuisine(code: 'PE', name: 'Peruvian', continent: 'South American', flag: '🇵🇪'),
    Cuisine(code: 'UY', name: 'Uruguayan', continent: 'South American', flag: '🇺🇾'),
    Cuisine(code: 'VE', name: 'Venezuelan', continent: 'South American', flag: '🇻🇪'),

    // Asian
    Cuisine(code: 'BD', name: 'Bangladeshi', continent: 'Asian', flag: '🇧🇩'),
    Cuisine(code: 'MM', name: 'Burmese', continent: 'Asian', flag: '🇲🇲'),
    Cuisine(code: 'KH', name: 'Cambodian', continent: 'Asian', flag: '🇰🇭'),
    Cuisine(code: 'CN', name: 'Chinese', continent: 'Asian', flag: '🇨🇳'),
    Cuisine(code: 'IN', name: 'Indian', continent: 'Asian', flag: '🇮🇳'),
    Cuisine(code: 'ID', name: 'Indonesian', continent: 'Asian', flag: '🇮🇩'),
    Cuisine(code: 'JP', name: 'Japanese', continent: 'Asian', flag: '🇯🇵'),
    Cuisine(code: 'KR', name: 'Korean', continent: 'Asian', flag: '🇰🇷'),
    Cuisine(code: 'LA', name: 'Laotian', continent: 'Asian', flag: '🇱🇦'),
    Cuisine(code: 'MY', name: 'Malaysian', continent: 'Asian', flag: '🇲🇾'),
    Cuisine(code: 'MN', name: 'Mongolian', continent: 'Asian', flag: '🇲🇳'),
    Cuisine(code: 'NP', name: 'Nepali', continent: 'Asian', flag: '🇳🇵'),
    Cuisine(code: 'PK', name: 'Pakistani', continent: 'Asian', flag: '🇵🇰'),
    Cuisine(code: 'PH', name: 'Filipino', continent: 'Asian', flag: '🇵🇭'),
    Cuisine(code: 'SG', name: 'Singaporean', continent: 'Asian', flag: '🇸🇬'),
    Cuisine(code: 'LK', name: 'Sri Lankan', continent: 'Asian', flag: '🇱🇰'),
    Cuisine(code: 'TW', name: 'Taiwanese', continent: 'Asian', flag: '🇹🇼'),
    Cuisine(code: 'TH', name: 'Thai', continent: 'Asian', flag: '🇹🇭'),
    Cuisine(code: 'VN', name: 'Vietnamese', continent: 'Asian', flag: '🇻🇳'),

    // Caribbean
    Cuisine(code: 'BS', name: 'Bahamian', continent: 'Caribbean', flag: '🇧🇸'),
    Cuisine(code: 'BB', name: 'Barbadian', continent: 'Caribbean', flag: '🇧🇧'),
    Cuisine(code: 'CU', name: 'Cuban', continent: 'Caribbean', flag: '🇨🇺'),
    Cuisine(code: 'DO', name: 'Dominican', continent: 'Caribbean', flag: '🇩🇴'),
    Cuisine(code: 'GY', name: 'Guyanese', continent: 'Caribbean', flag: '🇬🇾'),
    Cuisine(code: 'HT', name: 'Haitian', continent: 'Caribbean', flag: '🇭🇹'),
    Cuisine(code: 'JM', name: 'Jamaican', continent: 'Caribbean', flag: '🇯🇲'),
    Cuisine(code: 'PR', name: 'Puerto Rican', continent: 'Caribbean', flag: '🇵🇷'),
    Cuisine(code: 'TT', name: 'Trinidadian', continent: 'Caribbean', flag: '🇹🇹'),

    // European
    Cuisine(code: 'AL', name: 'Albanian', continent: 'European', flag: '🇦🇱'),
    Cuisine(code: 'AT', name: 'Austrian', continent: 'European', flag: '🇦🇹'),
    Cuisine(code: 'BY', name: 'Belarusian', continent: 'European', flag: '🇧🇾'),
    Cuisine(code: 'BE', name: 'Belgian', continent: 'European', flag: '🇧🇪'),
    Cuisine(code: 'BA', name: 'Bosnian', continent: 'European', flag: '🇧🇦'),
    Cuisine(code: 'GB', name: 'British', continent: 'European', flag: '🇬🇧'),
    Cuisine(code: 'BG', name: 'Bulgarian', continent: 'European', flag: '🇧🇬'),
    Cuisine(code: 'HR', name: 'Croatian', continent: 'European', flag: '🇭🇷'),
    Cuisine(code: 'CY', name: 'Cypriot', continent: 'European', flag: '🇨🇾'),
    Cuisine(code: 'CZ', name: 'Czech', continent: 'European', flag: '🇨🇿'),
    Cuisine(code: 'DK', name: 'Danish', continent: 'European', flag: '🇩🇰'),
    Cuisine(code: 'NL', name: 'Dutch', continent: 'European', flag: '🇳🇱'),
    Cuisine(code: 'EE', name: 'Estonian', continent: 'European', flag: '🇪🇪'),
    Cuisine(code: 'FI', name: 'Finnish', continent: 'European', flag: '🇫🇮'),
    Cuisine(code: 'FR', name: 'French', continent: 'European', flag: '🇫🇷'),
    Cuisine(code: 'GE', name: 'Georgian', continent: 'European', flag: '🇬🇪'),
    Cuisine(code: 'DE', name: 'German', continent: 'European', flag: '🇩🇪'),
    Cuisine(code: 'GR', name: 'Greek', continent: 'European', flag: '🇬🇷'),
    Cuisine(code: 'HU', name: 'Hungarian', continent: 'European', flag: '🇭🇺'),
    Cuisine(code: 'IS', name: 'Icelandic', continent: 'European', flag: '🇮🇸'),
    Cuisine(code: 'IE', name: 'Irish', continent: 'European', flag: '🇮🇪'),
    Cuisine(code: 'IT', name: 'Italian', continent: 'European', flag: '🇮🇹'),
    Cuisine(code: 'LV', name: 'Latvian', continent: 'European', flag: '🇱🇻'),
    Cuisine(code: 'LT', name: 'Lithuanian', continent: 'European', flag: '🇱🇹'),
    Cuisine(code: 'MT', name: 'Maltese', continent: 'European', flag: '🇲🇹'),
    Cuisine(code: 'MD', name: 'Moldovan', continent: 'European', flag: '🇲🇩'),
    Cuisine(code: 'ME', name: 'Montenegrin', continent: 'European', flag: '🇲🇪'),
    Cuisine(code: 'NO', name: 'Norwegian', continent: 'European', flag: '🇳🇴'),
    Cuisine(code: 'PL', name: 'Polish', continent: 'European', flag: '🇵🇱'),
    Cuisine(code: 'PT', name: 'Portuguese', continent: 'European', flag: '🇵🇹'),
    Cuisine(code: 'RO', name: 'Romanian', continent: 'European', flag: '🇷🇴'),
    Cuisine(code: 'RU', name: 'Russian', continent: 'European', flag: '🇷🇺'),
    Cuisine(code: 'RS', name: 'Serbian', continent: 'European', flag: '🇷🇸'),
    Cuisine(code: 'SK', name: 'Slovak', continent: 'European', flag: '🇸🇰'),
    Cuisine(code: 'SI', name: 'Slovenian', continent: 'European', flag: '🇸🇮'),
    Cuisine(code: 'ES', name: 'Spanish', continent: 'European', flag: '🇪🇸'),
    Cuisine(code: 'SE', name: 'Swedish', continent: 'European', flag: '🇸🇪'),
    Cuisine(code: 'CH', name: 'Swiss', continent: 'European', flag: '🇨🇭'),
    Cuisine(code: 'UA', name: 'Ukrainian', continent: 'European', flag: '🇺🇦'),

    // Middle Eastern
    Cuisine(code: 'AF', name: 'Afghan', continent: 'Middle Eastern', flag: '🇦🇫'),
    Cuisine(code: 'BH', name: 'Bahraini', continent: 'Middle Eastern', flag: '🇧🇭'),
    Cuisine(code: 'AE', name: 'Emirati', continent: 'Middle Eastern', flag: '🇦🇪'),
    Cuisine(code: 'IR', name: 'Persian', continent: 'Middle Eastern', flag: '🇮🇷'),
    Cuisine(code: 'IQ', name: 'Iraqi', continent: 'Middle Eastern', flag: '🇮🇶'),
    Cuisine(code: 'IL', name: 'Israeli', continent: 'Middle Eastern', flag: '🇮🇱'),
    Cuisine(code: 'JO', name: 'Jordanian', continent: 'Middle Eastern', flag: '🇯🇴'),
    Cuisine(code: 'KW', name: 'Kuwaiti', continent: 'Middle Eastern', flag: '🇰🇼'),
    Cuisine(code: 'LB', name: 'Lebanese', continent: 'Middle Eastern', flag: '🇱🇧'),
    Cuisine(code: 'OM', name: 'Omani', continent: 'Middle Eastern', flag: '🇴🇲'),
    Cuisine(code: 'PS', name: 'Palestinian', continent: 'Middle Eastern', flag: '🇵🇸'),
    Cuisine(code: 'QA', name: 'Qatari', continent: 'Middle Eastern', flag: '🇶🇦'),
    Cuisine(code: 'SA', name: 'Saudi', continent: 'Middle Eastern', flag: '🇸🇦'),
    Cuisine(code: 'SY', name: 'Syrian', continent: 'Middle Eastern', flag: '🇸🇾'),
    Cuisine(code: 'TR', name: 'Turkish', continent: 'Middle Eastern', flag: '🇹🇷'),
    Cuisine(code: 'YE', name: 'Yemeni', continent: 'Middle Eastern', flag: '🇾🇪'),

    // Oceanian
    Cuisine(code: 'AU', name: 'Australian', continent: 'Oceanian', flag: '🇦🇺'),
    Cuisine(code: 'FJ', name: 'Fijian', continent: 'Oceanian', flag: '🇫🇯'),
    Cuisine(code: 'NZ', name: 'New Zealand', continent: 'Oceanian', flag: '🇳🇿'),
    Cuisine(code: 'PG', name: 'Papua New Guinean', continent: 'Oceanian', flag: '🇵🇬'),
    Cuisine(code: 'WS', name: 'Samoan', continent: 'Oceanian', flag: '🇼🇸'),
    Cuisine(code: 'TO', name: 'Tongan', continent: 'Oceanian', flag: '🇹🇴'),
  ];

  /// Get all unique continents (sorted alphabetically)
  static List<String> get continents {
    final continents = all.map((c) => c.continent).toSet().toList();
    continents.sort();
    return continents;
  }

  /// Get cuisines for a specific continent (sorted alphabetically by name)
  static List<Cuisine> forContinent(String continent) {
    final cuisines = all.where((c) => c.continent == continent).toList();
    cuisines.sort((a, b) => a.name.compareTo(b.name));
    return cuisines;
  }

  /// Get cuisine by code
  static Cuisine? byCode(String code) {
    try {
      return all.firstWhere((c) => c.code == code);
    } catch (_) {
      return null;
    }
  }

  /// Get cuisine by name (case-insensitive)
  static Cuisine? byName(String name) {
    final lower = name.toLowerCase().trim();
    try {
      return all.firstWhere((c) => c.name.toLowerCase() == lower);
    } catch (_) {
      return null;
    }
  }

  /// Get the continent for a cuisine (by code or name)
  static String? continentFor(String? cuisine) {
    if (cuisine == null || cuisine.isEmpty) return null;
    
    // Try by code first (2-3 letter codes)
    if (cuisine.length <= 3) {
      final byCodeResult = byCode(cuisine.toUpperCase());
      if (byCodeResult != null) return byCodeResult.continent;
    }
    
    // Try by name
    final byNameResult = byName(cuisine);
    if (byNameResult != null) return byNameResult.continent;
    
    // Check adjective forms
    final lower = cuisine.toLowerCase().trim();
    for (final c in all) {
      if (c.name.toLowerCase() == lower) return c.continent;
    }
    
    return null;
  }

  /// Get all cuisines sorted by continent then name
  static List<Cuisine> get sortedAll {
    final sorted = List<Cuisine>.from(all);
    sorted.sort((a, b) {
      final continentCompare = a.continent.compareTo(b.continent);
      if (continentCompare != 0) return continentCompare;
      return a.name.compareTo(b.name);
    });
    return sorted;
  }

  /// Convert a country/region name or code to its cuisine adjective form
  /// e.g., "Japan" -> "Japanese", "Korea" -> "Korean", "JP" -> "Japanese"
  static String toAdjective(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    
    // First check if it's a 2-3 letter country code
    if (raw.length <= 3) {
      final cuisine = byCode(raw.toUpperCase());
      if (cuisine != null) return cuisine.name;
    }
    
    // Map of country/region names to adjective forms
    const countryToAdjective = {
      // Asian
      'japan': 'Japanese',
      'korea': 'Korean',
      'south korea': 'Korean',
      'china': 'Chinese',
      'india': 'Indian',
      'thailand': 'Thai',
      'vietnam': 'Vietnamese',
      'philippines': 'Filipino',
      'indonesia': 'Indonesian',
      'malaysia': 'Malaysian',
      'singapore': 'Singaporean',
      'taiwan': 'Taiwanese',
      'pakistan': 'Pakistani',
      'nepal': 'Nepali',
      'sri lanka': 'Sri Lankan',
      
      // European
      'france': 'French',
      'italy': 'Italian',
      'spain': 'Spanish',
      'germany': 'German',
      'greece': 'Greek',
      'uk': 'British',
      'united kingdom': 'British',
      'great britain': 'British',
      'england': 'British',
      'ireland': 'Irish',
      'poland': 'Polish',
      'portugal': 'Portuguese',
      'russia': 'Russian',
      'sweden': 'Swedish',
      'hungary': 'Hungarian',
      'ukraine': 'Ukrainian',
      'austria': 'Austrian',
      'belgium': 'Belgian',
      'croatia': 'Croatian',
      'czech republic': 'Czech',
      'czechia': 'Czech',
      'denmark': 'Danish',
      'netherlands': 'Dutch',
      'holland': 'Dutch',
      'finland': 'Finnish',
      'norway': 'Norwegian',
      'romania': 'Romanian',
      'serbia': 'Serbian',
      'switzerland': 'Swiss',
      
      // Americas
      'usa': 'American',
      'united states': 'American',
      'america': 'American',
      'mexico': 'Mexican',
      'brazil': 'Brazilian',
      'argentina': 'Argentine',
      'peru': 'Peruvian',
      'canada': 'Canadian',
      'chile': 'Chilean',
      'colombia': 'Colombian',
      'venezuela': 'Venezuelan',
      
      // Caribbean
      'jamaica': 'Jamaican',
      'cuba': 'Cuban',
      'haiti': 'Haitian',
      'dominican republic': 'Dominican',
      'puerto rico': 'Puerto Rican',
      'trinidad': 'Trinidadian',
      'trinidad and tobago': 'Trinidadian',
      'barbados': 'Barbadian',
      
      // Middle Eastern
      'turkey': 'Turkish',
      'lebanon': 'Lebanese',
      'israel': 'Israeli',
      'iran': 'Persian',
      'persia': 'Persian',
      'middle east': 'Middle Eastern',
      'iraq': 'Iraqi',
      'syria': 'Syrian',
      'jordan': 'Jordanian',
      'palestine': 'Palestinian',
      'saudi arabia': 'Saudi',
      'yemen': 'Yemeni',
      'afghanistan': 'Afghan',
      
      // African
      'morocco': 'Moroccan',
      'ethiopia': 'Ethiopian',
      'south africa': 'South African',
      'egypt': 'Egyptian',
      'nigeria': 'Nigerian',
      'ghana': 'Ghanaian',
      'kenya': 'Kenyan',
      'tunisia': 'Tunisian',
      
      // Oceanian
      'australia': 'Australian',
      'new zealand': 'New Zealand',
      'hawaii': 'Hawaiian',
      'fiji': 'Fijian',
      'samoa': 'Samoan',
      
      // Already adjective forms (return as-is)
      'japanese': 'Japanese',
      'korean': 'Korean',
      'chinese': 'Chinese',
      'indian': 'Indian',
      'thai': 'Thai',
      'vietnamese': 'Vietnamese',
      'filipino': 'Filipino',
      'indonesian': 'Indonesian',
      'malaysian': 'Malaysian',
      'singaporean': 'Singaporean',
      'taiwanese': 'Taiwanese',
      'pakistani': 'Pakistani',
      'nepali': 'Nepali',
      'sri lankan': 'Sri Lankan',
      'french': 'French',
      'italian': 'Italian',
      'spanish': 'Spanish',
      'german': 'German',
      'greek': 'Greek',
      'british': 'British',
      'irish': 'Irish',
      'polish': 'Polish',
      'portuguese': 'Portuguese',
      'russian': 'Russian',
      'swedish': 'Swedish',
      'hungarian': 'Hungarian',
      'ukrainian': 'Ukrainian',
      'austrian': 'Austrian',
      'belgian': 'Belgian',
      'croatian': 'Croatian',
      'czech': 'Czech',
      'danish': 'Danish',
      'dutch': 'Dutch',
      'finnish': 'Finnish',
      'norwegian': 'Norwegian',
      'romanian': 'Romanian',
      'serbian': 'Serbian',
      'swiss': 'Swiss',
      'american': 'American',
      'mexican': 'Mexican',
      'brazilian': 'Brazilian',
      'argentine': 'Argentine',
      'peruvian': 'Peruvian',
      'canadian': 'Canadian',
      'chilean': 'Chilean',
      'colombian': 'Colombian',
      'venezuelan': 'Venezuelan',
      'jamaican': 'Jamaican',
      'cuban': 'Cuban',
      'haitian': 'Haitian',
      'dominican': 'Dominican',
      'puerto rican': 'Puerto Rican',
      'trinidadian': 'Trinidadian',
      'barbadian': 'Barbadian',
      'turkish': 'Turkish',
      'lebanese': 'Lebanese',
      'israeli': 'Israeli',
      'persian': 'Persian',
      'middle eastern': 'Middle Eastern',
      'iraqi': 'Iraqi',
      'syrian': 'Syrian',
      'jordanian': 'Jordanian',
      'palestinian': 'Palestinian',
      'saudi': 'Saudi',
      'yemeni': 'Yemeni',
      'afghan': 'Afghan',
      'moroccan': 'Moroccan',
      'ethiopian': 'Ethiopian',
      'south african': 'South African',
      'egyptian': 'Egyptian',
      'nigerian': 'Nigerian',
      'ghanaian': 'Ghanaian',
      'kenyan': 'Kenyan',
      'tunisian': 'Tunisian',
      'australian': 'Australian',
      'hawaiian': 'Hawaiian',
      'fijian': 'Fijian',
      'samoan': 'Samoan',
      
      // Generic regions
      'asian': 'Asian',
      'european': 'European',
      'african': 'African',
      'mediterranean': 'Mediterranean',
      'caribbean': 'Caribbean',
      'latin america': 'Latin American',
      'latin american': 'Latin American',
      'nordic': 'Nordic',
      'scandinavian': 'Scandinavian',
      'southern': 'Southern',
      'cajun': 'Cajun',
      'creole': 'Creole',
      'tex-mex': 'Tex-Mex',
    };
    
    final key = raw.toLowerCase().trim();
    return countryToAdjective[key] ?? raw;
  }
  
  /// Regional or provincial terms mapped to their parent national cuisine.
  static const _regionToParent = <String, String>{
      // Chinese regions
      'sichuan': 'Chinese',
      'szechuan': 'Chinese',
      'szechwan': 'Chinese',
      'cantonese': 'Chinese',
      'hunan': 'Chinese',
      'hunanese': 'Chinese',
      'shanghai': 'Chinese',
      'shanghainese': 'Chinese',
      'beijing': 'Chinese',
      'peking': 'Chinese',
      'fujian': 'Chinese',
      'hokkien': 'Chinese',
      'teochew': 'Chinese',
      'hakka': 'Chinese',
      'dongbei': 'Chinese',
      'manchurian': 'Indian',
      'xinjiang': 'Chinese',
      'uyghur': 'Chinese',
      'yunnan': 'Chinese',
      'guangdong': 'Chinese',
      'zhejiang': 'Chinese',
      'jiangsu': 'Chinese',
      'anhui': 'Chinese',
      'shandong': 'Chinese',
      
      // Indian regions
      'punjabi': 'Indian',
      'gujarati': 'Indian',
      'rajasthani': 'Indian',
      'goan': 'Indian',
      'kerala': 'Indian',
      'south indian': 'Indian',
      'north indian': 'Indian',
      'bengali': 'Indian',
      'kashmiri': 'Indian',
      'hyderabadi': 'Indian',
      'chettinad': 'Indian',
      'mughlai': 'Indian',
      'maharashtrian': 'Indian',
      'tamil': 'Indian',
      'andhra': 'Indian',
      'telugu': 'Indian',
      'konkani': 'Indian',
      
      // Japanese regions
      'osaka': 'Japanese',
      'kansai': 'Japanese',
      'kanto': 'Japanese',
      'tokyo': 'Japanese',
      'hokkaido': 'Japanese',
      'okinawan': 'Japanese',
      'kyoto': 'Japanese',
      
      // Italian regions
      'tuscan': 'Italian',
      'tuscany': 'Italian',
      'sicilian': 'Italian',
      'sicily': 'Italian',
      'neapolitan': 'Italian',
      'naples': 'Italian',
      'roman': 'Italian',
      'rome': 'Italian',
      'venetian': 'Italian',
      'lombardy': 'Italian',
      'milanese': 'Italian',
      'piedmont': 'Italian',
      'piedmontese': 'Italian',
      'emilia-romagna': 'Italian',
      'bolognese': 'Italian',
      'ligurian': 'Italian',
      'sardinian': 'Italian',
      'calabrian': 'Italian',
      'puglia': 'Italian',
      'amalfi': 'Italian',
      
      // French regions
      'provençal': 'French',
      'provencal': 'French',
      'provence': 'French',
      'normandy': 'French',
      'norman': 'French',
      'breton': 'French',
      'brittany': 'French',
      'alsatian': 'French',
      'alsace': 'French',
      'burgundy': 'French',
      'burgundian': 'French',
      'lyonnaise': 'French',
      'lyon': 'French',
      'basque': 'Spanish',
      'parisian': 'French',
      'bordeaux': 'French',
      
      // Spanish regions
      'catalan': 'Spanish',
      'catalonia': 'Spanish',
      'andalusian': 'Spanish',
      'andalusia': 'Spanish',
      'galician': 'Spanish',
      'valencian': 'Spanish',
      'barcelona': 'Spanish',
      'madrid': 'Spanish',
      'castilian': 'Spanish',
      
      // American regions
      'southern': 'American',
      'new england': 'American',
      'cajun': 'American',
      'tex-mex': 'American',
      'southwestern': 'American',
      'california': 'American',
      'pacific northwest': 'American',
      'new orleans': 'American',
      'louisiana': 'American',
      'southern american': 'American',
      'hawaii': 'American',
      'hawaiian': 'American',
      
      // Thai regions
      'isaan': 'Thai',
      'isan': 'Thai',
      'northern thai': 'Thai',
      'southern thai': 'Thai',
      'bangkok': 'Thai',
      
      // Mexican regions
      'oaxacan': 'Mexican',
      'oaxaca': 'Mexican',
      'yucatan': 'Mexican',
      'yucatecan': 'Mexican',
      'veracruz': 'Mexican',
      'baja': 'Mexican',
      'jalisco': 'Mexican',
      'michoacan': 'Mexican',
      'puebla': 'Mexican',
      
      // Other regional terms
      'aegean': 'Greek',
      'bavarian': 'German',
      'austrian': 'Austrian',  // Keep as valid
      'viennese': 'Austrian',
      'swiss german': 'Swiss',
      
      // British nations
      'scottish': 'British',
      'scotland': 'British',
      'welsh': 'British',
      'wales': 'British',
      
    };
    
  /// Country names and alternate forms mapped to their cuisine demonym.
  static const _countryToCuisine = <String, String>{
      'algeria': 'Algerian',
      'cameroon': 'Cameroonian',
      'senegal': 'Senegalese',
      'tanzania': 'Tanzanian',
      'uganda': 'Ugandan',
      'costa rica': 'Costa Rican',
      'el salvador': 'Salvadoran',
      'guatemala': 'Guatemalan',
      'honduras': 'Honduran',
      'nicaragua': 'Nicaraguan',
      'panama': 'Panamanian',
      'bolivia': 'Bolivian',
      'ecuador': 'Ecuadorian',
      'paraguay': 'Paraguayan',
      'uruguay': 'Uruguayan',
      'bangladesh': 'Bangladeshi',
      'myanmar': 'Burmese',
      'burma': 'Burmese',
      'cambodia': 'Cambodian',
      'laos': 'Laotian',
      'mongolia': 'Mongolian',
      'bahamas': 'Bahamian',
      'guyana': 'Guyanese',
      'albania': 'Albanian',
      'belarus': 'Belarusian',
      'bosnia': 'Bosnian',
      'bosnia and herzegovina': 'Bosnian',
      'bulgaria': 'Bulgarian',
      'cyprus': 'Cypriot',
      'estonia': 'Estonian',
      'latvia': 'Latvian',
      'lithuania': 'Lithuanian',
      'iceland': 'Icelandic',
      'malta': 'Maltese',
      'moldova': 'Moldovan',
      'montenegro': 'Montenegrin',
      'slovakia': 'Slovak',
      'slovenia': 'Slovenian',
      'bahrain': 'Bahraini',
      'uae': 'Emirati',
      'emirates': 'Emirati',
      'united arab emirates': 'Emirati',
      'kuwait': 'Kuwaiti',
      'oman': 'Omani',
      'qatar': 'Qatari',
      'papua new guinea': 'Papua New Guinean',
      'tonga': 'Tongan',
      'argentinian': 'Argentine',
      'czechia': 'Czech',
      'holland': 'Dutch',
      'english': 'British',
      'england': 'British',
      'iranian': 'Persian',
    };

  /// Multi-country style terms that are kept as a region and are not a cuisine.
  static const _multiCountryTerms = <String>{
    'latin',
    'latin american',
    'mediterranean',
    'middle eastern',
    'asian',
    'southeast asian',
    'east asian',
    'south asian',
    'african',
    'caribbean',
    'nordic',
    'scandinavian',
    'european',
    'levantine',
    'creole',
  };

  /// Validate and normalize a cuisine string for import.
  ///
  /// This method:
  /// 1. Maps regional/provincial terms to their parent national cuisine
  ///    (e.g., "Sichuan" -> "Chinese", "Cantonese" -> "Chinese")
  /// 2. Returns null if the input doesn't match any known cuisine
  /// 3. Returns the standardized cuisine name if valid
  ///
  /// Use this during import to ensure only valid cuisines are assigned.
  static String? validateForImport(String? raw) {
    if (raw == null || raw.isEmpty) return null;

    final lower = raw.toLowerCase().trim();

    // Check if it's a known regional term first
    if (_regionToParent.containsKey(lower)) {
      return _regionToParent[lower];
    }

    if (_countryToCuisine.containsKey(lower)) {
      return _countryToCuisine[lower];
    }
    
    // Try to find a matching cuisine in our standard list
    // First try exact match by name
    final byNameMatch = byName(raw);
    if (byNameMatch != null) {
      return byNameMatch.name;
    }
    
    // Try adjective conversion (handles country names -> adjective)
    final adjective = toAdjective(raw);
    final byAdjectiveMatch = byName(adjective);
    if (byAdjectiveMatch != null) {
      return byAdjectiveMatch.name;
    }
    
    // Not a recognized cuisine - return null to indicate validation failure
    return null;
  }
  
  static String? codeFor(String? raw) {
    final name = validateForImport(raw);
    return name == null ? null : byName(name)?.code;
  }

  /// The original term, capitalised, when it is a sub-region of a cuisine or a
  /// multi-country style; otherwise null.
  static String? regionFor(String? raw) {
    if (raw == null) return null;
    final lower = raw.trim().toLowerCase();
    if (lower.isEmpty) return null;
    final parent = _regionToParent[lower];
    final isSubRegion = parent != null && parent.toLowerCase() != lower;
    if (!isSubRegion && !_multiCountryTerms.contains(lower)) return null;
    return lower.replaceAllMapped(
      RegExp(r'(^|[\s-])(\S)'),
      (m) => '${m[1]}${m[2]!.toUpperCase()}',
    );
  }

  /// Cuisine adjective with the region in parentheses, e.g. "Chinese (Sichuan)".
  static String displayWithRegion(String? cuisine, String? region) {
    final adjective = toAdjective(cuisine);
    if (region != null && region.isNotEmpty) return '$adjective ($region)';
    return adjective;
  }

  /// Label and colour key for a cuisine and optional region; null when nothing should show.
  static ({String label, String colourKey})? displayFor(
    String? cuisine,
    String? region,
  ) {
    final cuisineText = cuisine?.trim();
    final regionText = region?.trim();
    final hasCuisine = cuisineText != null && cuisineText.isNotEmpty;
    final hasRegion = regionText != null && regionText.isNotEmpty;

    if (hasCuisine) {
      return (
        label: displayWithRegion(cuisineText, hasRegion ? regionText : null),
        colourKey: cuisineText,
      );
    }
    if (!hasRegion) return null;

    final code = codeFor(regionText);
    if (code == null && !_multiCountryTerms.contains(regionText.toLowerCase())) {
      return null;
    }
    return (label: regionText, colourKey: code ?? regionText);
  }

  /// Get a list of all valid cuisine names (for autocomplete/validation UI)
  static List<String> get allNames {
    return all.map((c) => c.name).toList()..sort();
  }
}

/// Grouped cuisine data for display
class CuisineGroup {
  final String continent;
  final List<Cuisine> cuisines;

  const CuisineGroup({required this.continent, required this.cuisines});

  static List<CuisineGroup> get all {
    return Cuisine.continents.map((continent) {
      return CuisineGroup(
        continent: continent,
        cuisines: Cuisine.forContinent(continent),
      );
    }).toList();
  }
}
