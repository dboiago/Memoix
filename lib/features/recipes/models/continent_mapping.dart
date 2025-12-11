/// Helper class to map cuisines to continents and countries
/// Following Figma design's organization: Asian, European, American
class ContinentMapping {
  ContinentMapping._();

  /// Map of cuisine to continent
  static const Map<String, String> cuisineToContinent = {
    // Asian
    'chinese': 'Asian',
    'japanese': 'Asian',
    'korean': 'Asian',
    'thai': 'Asian',
    'vietnamese': 'Asian',
    'indian': 'Asian',
    'malaysian': 'Asian',
    'indonesian': 'Asian',
    'filipino': 'Asian',
    'singaporean': 'Asian',
    
    // European
    'french': 'European',
    'italian': 'European',
    'spanish': 'European',
    'greek': 'European',
    'german': 'European',
    'british': 'European',
    'irish': 'European',
    'portuguese': 'European',
    'dutch': 'European',
    'scandinavian': 'European',
    'russian': 'European',
    'polish': 'European',
    'turkish': 'European',
    
    // American
    'american': 'American',
    'mexican': 'American',
    'brazilian': 'American',
    'peruvian': 'American',
    'argentinian': 'American',
    'cuban': 'American',
    'caribbean': 'American',
    'southern': 'American', // Southern USA
    'cajun': 'American',
    
    // Middle Eastern
    'lebanese': 'Middle Eastern',
    'moroccan': 'Middle Eastern',
    'persian': 'Middle Eastern',
    'israeli': 'Middle Eastern',
    'egyptian': 'Middle Eastern',
    
    // African
    'ethiopian': 'African',
    'south african': 'African',
    
    // Mediterranean (could be European or Middle Eastern)
    'mediterranean': 'Mediterranean',
  };

  /// Map of cuisine to country/region
  static const Map<String, String> cuisineToCountry = {
    'chinese': 'China',
    'japanese': 'Japan',
    'korean': 'Korea',
    'thai': 'Thailand',
    'vietnamese': 'Vietnam',
    'indian': 'India',
    'malaysian': 'Malaysia',
    'indonesian': 'Indonesia',
    'filipino': 'Philippines',
    'singaporean': 'Singapore',
    
    'french': 'France',
    'italian': 'Italy',
    'spanish': 'Spain',
    'greek': 'Greece',
    'german': 'Germany',
    'british': 'United Kingdom',
    'irish': 'Ireland',
    'portuguese': 'Portugal',
    'dutch': 'Netherlands',
    'scandinavian': 'Scandinavia',
    'russian': 'Russia',
    'polish': 'Poland',
    'turkish': 'Turkey',
    
    'american': 'United States',
    'mexican': 'Mexico',
    'brazilian': 'Brazil',
    'peruvian': 'Peru',
    'argentinian': 'Argentina',
    'cuban': 'Cuba',
    'caribbean': 'Caribbean',
    'southern': 'Southern USA',
    'cajun': 'Louisiana',
    
    'lebanese': 'Lebanon',
    'moroccan': 'Morocco',
    'persian': 'Iran',
    'israeli': 'Israel',
    'egyptian': 'Egypt',
    
    'ethiopian': 'Ethiopia',
    'south african': 'South Africa',
    
    'mediterranean': 'Mediterranean',
  };

  /// Get continent from cuisine string
  static String? getContinentFromCuisine(String? cuisine) {
    if (cuisine == null || cuisine.isEmpty) return null;
    return cuisineToContinent[cuisine.toLowerCase()];
  }

  /// Get country from cuisine string
  static String? getCountryFromCuisine(String? cuisine) {
    if (cuisine == null || cuisine.isEmpty) return null;
    return cuisineToCountry[cuisine.toLowerCase()];
  }

  /// Get all continents (for filter tabs)
  static List<String> get allContinents => [
        'All',
        'Asian',
        'European',
        'American',
        'Middle Eastern',
        'African',
        'Mediterranean',
      ];
}
