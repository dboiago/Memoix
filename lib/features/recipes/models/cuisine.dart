import 'package:flutter/material.dart';

/// Represents a cuisine origin with continent grouping
class Cuisine {
  final String code;        // 2-letter code (KR, JP, etc.)
  final String name;        // Full name (Korean, Japanese)
  final String continent;   // Continent grouping
  final String flag;        // Emoji flag
  final Color colour;       // Highlight colour for this cuisine

  const Cuisine({
    required this.code,
    required this.name,
    required this.continent,
    required this.flag,
    required this.colour,
  });

  /// All supported cuisines, grouped by continent
  static const List<Cuisine> all = [
    // African
    Cuisine(code: 'DZ', name: 'Algerian', continent: 'African', flag: '🇩🇿', colour: Color(0xFF006633)),
    Cuisine(code: 'CM', name: 'Cameroonian', continent: 'African', flag: '🇨🇲', colour: Color(0xFF007A5E)),
    Cuisine(code: 'EG', name: 'Egyptian', continent: 'African', flag: '🇪🇬', colour: Color(0xFFCD853F)),
    Cuisine(code: 'ET', name: 'Ethiopian', continent: 'African', flag: '🇪🇹', colour: Color(0xFFCD853F)),
    Cuisine(code: 'GH', name: 'Ghanaian', continent: 'African', flag: '🇬🇭', colour: Color(0xFF228B22)),
    Cuisine(code: 'KE', name: 'Kenyan', continent: 'African', flag: '🇰🇪', colour: Color(0xFF228B22)),
    Cuisine(code: 'MA', name: 'Moroccan', continent: 'African', flag: '🇲🇦', colour: Color(0xFFC1440E)),
    Cuisine(code: 'NG', name: 'Nigerian', continent: 'African', flag: '🇳🇬', colour: Color(0xFF228B22)),
    Cuisine(code: 'SN', name: 'Senegalese', continent: 'African', flag: '🇸🇳', colour: Color(0xFF00853F)),
    Cuisine(code: 'ZA', name: 'South African', continent: 'African', flag: '🇿🇦', colour: Color(0xFF228B22)),
    Cuisine(code: 'TZ', name: 'Tanzanian', continent: 'African', flag: '🇹🇿', colour: Color(0xFF1EB53A)),
    Cuisine(code: 'TN', name: 'Tunisian', continent: 'African', flag: '🇹🇳', colour: Color(0xFFC1440E)),
    Cuisine(code: 'UG', name: 'Ugandan', continent: 'African', flag: '🇺🇬', colour: Color(0xFFD90000)),

    // North American
    Cuisine(code: 'CA', name: 'Canadian', continent: 'North American', flag: '🇨🇦', colour: Color(0xFFFF0000)),
    Cuisine(code: 'MX', name: 'Mexican', continent: 'North American', flag: '🇲🇽', colour: Color(0xFF006847)),
    Cuisine(code: 'US', name: 'American', continent: 'North American', flag: '🇺🇸', colour: Color(0xFF3C3B6E)),

    // Central American
    Cuisine(code: 'CR', name: 'Costa Rican', continent: 'Central American', flag: '🇨🇷', colour: Color(0xFF002B7F)),
    Cuisine(code: 'SV', name: 'Salvadoran', continent: 'Central American', flag: '🇸🇻', colour: Color(0xFF0047AB)),
    Cuisine(code: 'GT', name: 'Guatemalan', continent: 'Central American', flag: '🇬🇹', colour: Color(0xFF4997D0)),
    Cuisine(code: 'HN', name: 'Honduran', continent: 'Central American', flag: '🇭🇳', colour: Color(0xFF0073CF)),
    Cuisine(code: 'NI', name: 'Nicaraguan', continent: 'Central American', flag: '🇳🇮', colour: Color(0xFF0067C6)),
    Cuisine(code: 'PA', name: 'Panamanian', continent: 'Central American', flag: '🇵🇦', colour: Color(0xFFDA121A)),

    // South American
    Cuisine(code: 'AR', name: 'Argentine', continent: 'South American', flag: '🇦🇷', colour: Color(0xFF75AADB)),
    Cuisine(code: 'BO', name: 'Bolivian', continent: 'South American', flag: '🇧🇴', colour: Color(0xFF007934)),
    Cuisine(code: 'BR', name: 'Brazilian', continent: 'South American', flag: '🇧🇷', colour: Color(0xFF009C3B)),
    Cuisine(code: 'CL', name: 'Chilean', continent: 'South American', flag: '🇨🇱', colour: Color(0xFF0039A6)),
    Cuisine(code: 'CO', name: 'Colombian', continent: 'South American', flag: '🇨🇴', colour: Color(0xFFFCD116)),
    Cuisine(code: 'EC', name: 'Ecuadorian', continent: 'South American', flag: '🇪🇨', colour: Color(0xFFFFD100)),
    Cuisine(code: 'PY', name: 'Paraguayan', continent: 'South American', flag: '🇵🇾', colour: Color(0xFFD52B1E)),
    Cuisine(code: 'PE', name: 'Peruvian', continent: 'South American', flag: '🇵🇪', colour: Color(0xFFD91023)),
    Cuisine(code: 'UY', name: 'Uruguayan', continent: 'South American', flag: '🇺🇾', colour: Color(0xFF0038A8)),
    Cuisine(code: 'VE', name: 'Venezuelan', continent: 'South American', flag: '🇻🇪', colour: Color(0xFFFCE300)),

    // Asian
    Cuisine(code: 'BD', name: 'Bangladeshi', continent: 'Asian', flag: '🇧🇩', colour: Color(0xFF006A4E)),
    Cuisine(code: 'MM', name: 'Burmese', continent: 'Asian', flag: '🇲🇲', colour: Color(0xFFFECB00)),
    Cuisine(code: 'KH', name: 'Cambodian', continent: 'Asian', flag: '🇰🇭', colour: Color(0xFF032EA1)),
    Cuisine(code: 'CN', name: 'Chinese', continent: 'Asian', flag: '🇨🇳', colour: Color(0xFFDE2910)),
    Cuisine(code: 'IN', name: 'Indian', continent: 'Asian', flag: '🇮🇳', colour: Color(0xFFFF9933)),
    Cuisine(code: 'ID', name: 'Indonesian', continent: 'Asian', flag: '🇮🇩', colour: Color(0xFFCE1126)),
    Cuisine(code: 'JP', name: 'Japanese', continent: 'Asian', flag: '🇯🇵', colour: Color(0xFFBC002D)),
    Cuisine(code: 'KR', name: 'Korean', continent: 'Asian', flag: '🇰🇷', colour: Color(0xFFCD2E3A)),
    Cuisine(code: 'LA', name: 'Laotian', continent: 'Asian', flag: '🇱🇦', colour: Color(0xFFCE1126)),
    Cuisine(code: 'MY', name: 'Malaysian', continent: 'Asian', flag: '🇲🇾', colour: Color(0xFFCC0001)),
    Cuisine(code: 'MN', name: 'Mongolian', continent: 'Asian', flag: '🇲🇳', colour: Color(0xFFDA2032)),
    Cuisine(code: 'NP', name: 'Nepali', continent: 'Asian', flag: '🇳🇵', colour: Color(0xFFDC143C)),
    Cuisine(code: 'PK', name: 'Pakistani', continent: 'Asian', flag: '🇵🇰', colour: Color(0xFF01411C)),
    Cuisine(code: 'PH', name: 'Filipino', continent: 'Asian', flag: '🇵🇭', colour: Color(0xFF0038A8)),
    Cuisine(code: 'SG', name: 'Singaporean', continent: 'Asian', flag: '🇸🇬', colour: Color(0xFFED2939)),
    Cuisine(code: 'LK', name: 'Sri Lankan', continent: 'Asian', flag: '🇱🇰', colour: Color(0xFF8D153A)),
    Cuisine(code: 'TW', name: 'Taiwanese', continent: 'Asian', flag: '🇹🇼', colour: Color(0xFFDE2910)),
    Cuisine(code: 'TH', name: 'Thai', continent: 'Asian', flag: '🇹🇭', colour: Color(0xFFED1C24)),
    Cuisine(code: 'VN', name: 'Vietnamese', continent: 'Asian', flag: '🇻🇳', colour: Color(0xFFDA251D)),

    // Caribbean
    Cuisine(code: 'BS', name: 'Bahamian', continent: 'Caribbean', flag: '🇧🇸', colour: Color(0xFF00778B)),
    Cuisine(code: 'BB', name: 'Barbadian', continent: 'Caribbean', flag: '🇧🇧', colour: Color(0xFF00267F)),
    Cuisine(code: 'CU', name: 'Cuban', continent: 'Caribbean', flag: '🇨🇺', colour: Color(0xFF002A8F)),
    Cuisine(code: 'DO', name: 'Dominican', continent: 'Caribbean', flag: '🇩🇴', colour: Color(0xFF002D62)),
    Cuisine(code: 'GY', name: 'Guyanese', continent: 'Caribbean', flag: '🇬🇾', colour: Color(0xFF009E49)),
    Cuisine(code: 'HT', name: 'Haitian', continent: 'Caribbean', flag: '🇭🇹', colour: Color(0xFF00209F)),
    Cuisine(code: 'JM', name: 'Jamaican', continent: 'Caribbean', flag: '🇯🇲', colour: Color(0xFF009B3A)),
    Cuisine(code: 'PR', name: 'Puerto Rican', continent: 'Caribbean', flag: '🇵🇷', colour: Color(0xFFED0A3F)),
    Cuisine(code: 'TT', name: 'Trinidadian', continent: 'Caribbean', flag: '🇹🇹', colour: Color(0xFFDA1A35)),

    // European
    Cuisine(code: 'AL', name: 'Albanian', continent: 'European', flag: '🇦🇱', colour: Color(0xFFE41E20)),
    Cuisine(code: 'AT', name: 'Austrian', continent: 'European', flag: '🇦🇹', colour: Color(0xFFED2939)),
    Cuisine(code: 'BY', name: 'Belarusian', continent: 'European', flag: '🇧🇾', colour: Color(0xFFD22730)),
    Cuisine(code: 'BE', name: 'Belgian', continent: 'European', flag: '🇧🇪', colour: Color(0xFFFDDA24)),
    Cuisine(code: 'BA', name: 'Bosnian', continent: 'European', flag: '🇧🇦', colour: Color(0xFF002395)),
    Cuisine(code: 'GB', name: 'British', continent: 'European', flag: '🇬🇧', colour: Color(0xFF012169)),
    Cuisine(code: 'BG', name: 'Bulgarian', continent: 'European', flag: '🇧🇬', colour: Color(0xFF00966E)),
    Cuisine(code: 'HR', name: 'Croatian', continent: 'European', flag: '🇭🇷', colour: Color(0xFF0093DD)),
    Cuisine(code: 'CY', name: 'Cypriot', continent: 'European', flag: '🇨🇾', colour: Color(0xFFD57800)),
    Cuisine(code: 'CZ', name: 'Czech', continent: 'European', flag: '🇨🇿', colour: Color(0xFF11457E)),
    Cuisine(code: 'DK', name: 'Danish', continent: 'European', flag: '🇩🇰', colour: Color(0xFFC60C30)),
    Cuisine(code: 'NL', name: 'Dutch', continent: 'European', flag: '🇳🇱', colour: Color(0xFFFF6600)),
    Cuisine(code: 'EE', name: 'Estonian', continent: 'European', flag: '🇪🇪', colour: Color(0xFF0072CE)),
    Cuisine(code: 'FI', name: 'Finnish', continent: 'European', flag: '🇫🇮', colour: Color(0xFF003580)),
    Cuisine(code: 'FR', name: 'French', continent: 'European', flag: '🇫🇷', colour: Color(0xFF0055A4)),
    Cuisine(code: 'GE', name: 'Georgian', continent: 'European', flag: '🇬🇪', colour: Color(0xFFFF0000)),
    Cuisine(code: 'DE', name: 'German', continent: 'European', flag: '🇩🇪', colour: Color(0xFFDD0000)),
    Cuisine(code: 'GR', name: 'Greek', continent: 'European', flag: '🇬🇷', colour: Color(0xFF0D5EAF)),
    Cuisine(code: 'HU', name: 'Hungarian', continent: 'European', flag: '🇭🇺', colour: Color(0xFF477050)),
    Cuisine(code: 'IS', name: 'Icelandic', continent: 'European', flag: '🇮🇸', colour: Color(0xFF003897)),
    Cuisine(code: 'IE', name: 'Irish', continent: 'European', flag: '🇮🇪', colour: Color(0xFF169B62)),
    Cuisine(code: 'IT', name: 'Italian', continent: 'European', flag: '🇮🇹', colour: Color(0xFF009246)),
    Cuisine(code: 'LV', name: 'Latvian', continent: 'European', flag: '🇱🇻', colour: Color(0xFF9E3039)),
    Cuisine(code: 'LT', name: 'Lithuanian', continent: 'European', flag: '🇱🇹', colour: Color(0xFF006A44)),
    Cuisine(code: 'MT', name: 'Maltese', continent: 'European', flag: '🇲🇹', colour: Color(0xFFCF142B)),
    Cuisine(code: 'MD', name: 'Moldovan', continent: 'European', flag: '🇲🇩', colour: Color(0xFF003DA5)),
    Cuisine(code: 'ME', name: 'Montenegrin', continent: 'European', flag: '🇲🇪', colour: Color(0xFFD4AF37)),
    Cuisine(code: 'NO', name: 'Norwegian', continent: 'European', flag: '🇳🇴', colour: Color(0xFFBA0C2F)),
    Cuisine(code: 'PL', name: 'Polish', continent: 'European', flag: '🇵🇱', colour: Color(0xFFDC143C)),
    Cuisine(code: 'PT', name: 'Portuguese', continent: 'European', flag: '🇵🇹', colour: Color(0xFF006600)),
    Cuisine(code: 'RO', name: 'Romanian', continent: 'European', flag: '🇷🇴', colour: Color(0xFF002B7F)),
    Cuisine(code: 'RU', name: 'Russian', continent: 'European', flag: '🇷🇺', colour: Color(0xFF0039A6)),
    Cuisine(code: 'RS', name: 'Serbian', continent: 'European', flag: '🇷🇸', colour: Color(0xFFC7363D)),
    Cuisine(code: 'SK', name: 'Slovak', continent: 'European', flag: '🇸🇰', colour: Color(0xFF0B4EA2)),
    Cuisine(code: 'SI', name: 'Slovenian', continent: 'European', flag: '🇸🇮', colour: Color(0xFF005DA4)),
    Cuisine(code: 'ES', name: 'Spanish', continent: 'European', flag: '🇪🇸', colour: Color(0xFFAA151B)),
    Cuisine(code: 'SE', name: 'Swedish', continent: 'European', flag: '🇸🇪', colour: Color(0xFF006AA7)),
    Cuisine(code: 'CH', name: 'Swiss', continent: 'European', flag: '🇨🇭', colour: Color(0xFFFF0000)),
    Cuisine(code: 'UA', name: 'Ukrainian', continent: 'European', flag: '🇺🇦', colour: Color(0xFF005BBB)),

    // Middle Eastern
    Cuisine(code: 'AF', name: 'Afghan', continent: 'Middle Eastern', flag: '🇦🇫', colour: Color(0xFF239F40)),
    Cuisine(code: 'BH', name: 'Bahraini', continent: 'Middle Eastern', flag: '🇧🇭', colour: Color(0xFFCE1126)),
    Cuisine(code: 'AE', name: 'Emirati', continent: 'Middle Eastern', flag: '🇦🇪', colour: Color(0xFF00732F)),
    Cuisine(code: 'IR', name: 'Persian', continent: 'Middle Eastern', flag: '🇮🇷', colour: Color(0xFF239F40)),
    Cuisine(code: 'IQ', name: 'Iraqi', continent: 'Middle Eastern', flag: '🇮🇶', colour: Color(0xFF007A3D)),
    Cuisine(code: 'IL', name: 'Israeli', continent: 'Middle Eastern', flag: '🇮🇱', colour: Color(0xFF0038B8)),
    Cuisine(code: 'JO', name: 'Jordanian', continent: 'Middle Eastern', flag: '🇯🇴', colour: Color(0xFF007A3D)),
    Cuisine(code: 'KW', name: 'Kuwaiti', continent: 'Middle Eastern', flag: '🇰🇼', colour: Color(0xFF007A3D)),
    Cuisine(code: 'LB', name: 'Lebanese', continent: 'Middle Eastern', flag: '🇱🇧', colour: Color(0xFFEE161F)),
    Cuisine(code: 'OM', name: 'Omani', continent: 'Middle Eastern', flag: '🇴🇲', colour: Color(0xFFDB161B)),
    Cuisine(code: 'PS', name: 'Palestinian', continent: 'Middle Eastern', flag: '🇵🇸', colour: Color(0xFF007A3D)),
    Cuisine(code: 'QA', name: 'Qatari', continent: 'Middle Eastern', flag: '🇶🇦', colour: Color(0xFF8D1B3D)),
    Cuisine(code: 'SA', name: 'Saudi', continent: 'Middle Eastern', flag: '🇸🇦', colour: Color(0xFF006C35)),
    Cuisine(code: 'SY', name: 'Syrian', continent: 'Middle Eastern', flag: '🇸🇾', colour: Color(0xFFCE1126)),
    Cuisine(code: 'TR', name: 'Turkish', continent: 'Middle Eastern', flag: '🇹🇷', colour: Color(0xFFE30A17)),
    Cuisine(code: 'YE', name: 'Yemeni', continent: 'Middle Eastern', flag: '🇾🇪', colour: Color(0xFFCE1126)),

    // Oceanian
    Cuisine(code: 'AU', name: 'Australian', continent: 'Oceanian', flag: '🇦🇺', colour: Color(0xFF00008B)),
    Cuisine(code: 'FJ', name: 'Fijian', continent: 'Oceanian', flag: '🇫🇯', colour: Color(0xFF68BFE5)),
    Cuisine(code: 'HI', name: 'Hawaiian', continent: 'Oceanian', flag: '�🇸', colour: Color(0xFFE62020)),
    Cuisine(code: 'NZ', name: 'New Zealand', continent: 'Oceanian', flag: '🇳🇿', colour: Color(0xFF00247D)),
    Cuisine(code: 'PG', name: 'Papua New Guinean', continent: 'Oceanian', flag: '🇵🇬', colour: Color(0xFFCE1126)),
    Cuisine(code: 'WS', name: 'Samoan', continent: 'Oceanian', flag: '🇼🇸', colour: Color(0xFF002B7F)),
    Cuisine(code: 'TO', name: 'Tongan', continent: 'Oceanian', flag: '🇹🇴', colour: Color(0xFFC10000)),
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
    
    // Map of regional/provincial terms to their parent national cuisine
    const regionToParent = <String, String>{
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
      'manchurian': 'Chinese',
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
      'basque': 'French',
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
      'creole': 'American',
      'tex-mex': 'American',
      'southwestern': 'American',
      'california': 'American',
      'pacific northwest': 'American',
      'new orleans': 'American',
      'louisiana': 'American',
      'southern american': 'American',
      
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
      'levantine': 'Lebanese',
      'aegean': 'Greek',
      'bavarian': 'German',
      'austrian': 'Austrian',  // Keep as valid
      'viennese': 'Austrian',
      'swiss german': 'Swiss',
    };
    
    // Check if it's a known regional term first
    if (regionToParent.containsKey(lower)) {
      return regionToParent[lower];
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
