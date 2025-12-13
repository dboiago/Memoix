/// Helper class to map cuisines to cuisine regions and countries
/// Cuisine regions are distinct food style groupings (not strictly continents)
class ContinentMapping {
  ContinentMapping._();

  /// Map of cuisine to cuisine region
  /// Regions are ordered for display: Asian, Southeast Asian, Indian Subcontinent,
  /// European, Mediterranean, Middle Eastern, African, North American, 
  /// Latin American, Caribbean, Oceanian
  static const Map<String, String> cuisineToContinent = {
    // Asian (East Asian)
    'chinese': 'Asian',
    'japanese': 'Asian',
    'korean': 'Asian',
    'taiwanese': 'Asian',
    'cantonese': 'Asian',
    'szechuan': 'Asian',
    'sichuan': 'Asian',
    'hunan': 'Asian',
    'shanghai': 'Asian',
    'beijing': 'Asian',
    'fujian': 'Asian',
    'hakka': 'Asian',
    'dim sum': 'Asian',
    
    // Southeast Asian
    'thai': 'Southeast Asian',
    'vietnamese': 'Southeast Asian',
    'malaysian': 'Southeast Asian',
    'indonesian': 'Southeast Asian',
    'filipino': 'Southeast Asian',
    'singaporean': 'Southeast Asian',
    'burmese': 'Southeast Asian',
    'cambodian': 'Southeast Asian',
    'laotian': 'Southeast Asian',
    
    // Indian Subcontinent
    'indian': 'Indian Subcontinent',
    'pakistani': 'Indian Subcontinent',
    'bangladeshi': 'Indian Subcontinent',
    'sri lankan': 'Indian Subcontinent',
    'nepali': 'Indian Subcontinent',
    'punjabi': 'Indian Subcontinent',
    'gujarati': 'Indian Subcontinent',
    'south indian': 'Indian Subcontinent',
    'north indian': 'Indian Subcontinent',
    'bengali': 'Indian Subcontinent',
    'goan': 'Indian Subcontinent',
    'kashmiri': 'Indian Subcontinent',
    'hyderabadi': 'Indian Subcontinent',
    'kerala': 'Indian Subcontinent',
    'tamil': 'Indian Subcontinent',
    
    // European
    'french': 'European',
    'italian': 'European',
    'spanish': 'European',
    'german': 'European',
    'british': 'European',
    'english': 'European',
    'irish': 'European',
    'scottish': 'European',
    'portuguese': 'European',
    'dutch': 'European',
    'belgian': 'European',
    'swiss': 'European',
    'austrian': 'European',
    'polish': 'European',
    'hungarian': 'European',
    'czech': 'European',
    'russian': 'European',
    'ukrainian': 'European',
    'scandinavian': 'European',
    'swedish': 'European',
    'norwegian': 'European',
    'danish': 'European',
    'finnish': 'European',
    'bavarian': 'European',
    'tuscan': 'European',
    'neapolitan': 'European',
    'roman': 'European',
    'venetian': 'European',
    'lombard': 'European',
    'piedmontese': 'European',
    'emilian': 'European',
    'alsatian': 'European',
    'breton': 'European',
    'burgundian': 'European',
    'norman': 'European',
    'lyonnaise': 'European',
    'andalusian': 'European',
    'galician': 'European',
    'valencian': 'European',
    
    // Mediterranean
    'mediterranean': 'Mediterranean',
    'greek': 'Mediterranean',
    'turkish': 'Mediterranean',
    'cypriot': 'Mediterranean',
    'croatian': 'Mediterranean',
    'sicilian': 'Mediterranean',
    'sardinian': 'Mediterranean',
    'provençal': 'Mediterranean',
    'provencal': 'Mediterranean',
    'catalan': 'Mediterranean',
    'basque': 'Mediterranean',
    'cretan': 'Mediterranean',
    'aegean': 'Mediterranean',
    
    // Middle Eastern
    'lebanese': 'Middle Eastern',
    'syrian': 'Middle Eastern',
    'persian': 'Middle Eastern',
    'iranian': 'Middle Eastern',
    'iraqi': 'Middle Eastern',
    'israeli': 'Middle Eastern',
    'palestinian': 'Middle Eastern',
    'jordanian': 'Middle Eastern',
    'yemeni': 'Middle Eastern',
    'saudi': 'Middle Eastern',
    'emirati': 'Middle Eastern',
    'gulf': 'Middle Eastern',
    'arab': 'Middle Eastern',
    'levantine': 'Middle Eastern',
    
    // African
    'moroccan': 'African',
    'egyptian': 'African',
    'tunisian': 'African',
    'algerian': 'African',
    'ethiopian': 'African',
    'eritrean': 'African',
    'nigerian': 'African',
    'ghanaian': 'African',
    'senegalese': 'African',
    'south african': 'African',
    'kenyan': 'African',
    'north african': 'African',
    'west african': 'African',
    'east african': 'African',
    
    // North American
    'american': 'North American',
    'canadian': 'North American',
    'southern': 'North American',
    'cajun': 'North American',
    'creole': 'North American',
    'tex-mex': 'North American',
    'soul food': 'North American',
    'new england': 'North American',
    'californian': 'North American',
    'hawaiian': 'North American',
    'pacific northwest': 'North American',
    'midwestern': 'North American',
    'southwestern': 'North American',
    'québécois': 'North American',
    'quebecois': 'North American',
    
    // Latin American
    'mexican': 'Latin American',
    'brazilian': 'Latin American',
    'peruvian': 'Latin American',
    'argentinian': 'Latin American',
    'chilean': 'Latin American',
    'colombian': 'Latin American',
    'venezuelan': 'Latin American',
    'ecuadorian': 'Latin American',
    'bolivian': 'Latin American',
    'central american': 'Latin American',
    'salvadoran': 'Latin American',
    'guatemalan': 'Latin American',
    'oaxacan': 'Latin American',
    'yucatecan': 'Latin American',
    'veracruzano': 'Latin American',
    'jalisciense': 'Latin American',
    'norteno': 'Latin American',
    'bahian': 'Latin American',
    'gaucho': 'Latin American',
    'patagonian': 'Latin American',
    
    // Caribbean
    'caribbean': 'Caribbean',
    'cuban': 'Caribbean',
    'jamaican': 'Caribbean',
    'puerto rican': 'Caribbean',
    'dominican': 'Caribbean',
    'haitian': 'Caribbean',
    'trinidadian': 'Caribbean',
    'barbadian': 'Caribbean',
    
    // Oceanian
    'australian': 'Oceanian',
    'new zealand': 'Oceanian',
    'polynesian': 'Oceanian',
    'pacific islander': 'Oceanian',
  };

  /// Map of cuisine to country/region
  static const Map<String, String> cuisineToCountry = {
    // Asian
    'chinese': 'China',
    'japanese': 'Japan',
    'korean': 'Korea',
    'taiwanese': 'Taiwan',
    'cantonese': 'China',
    'szechuan': 'China',
    'sichuan': 'China',
    'hunan': 'China',
    'shanghai': 'China',
    'beijing': 'China',
    'fujian': 'China',
    'hakka': 'China',
    'dim sum': 'China',
    
    // Southeast Asian
    'thai': 'Thailand',
    'vietnamese': 'Vietnam',
    'malaysian': 'Malaysia',
    'indonesian': 'Indonesia',
    'filipino': 'Philippines',
    'singaporean': 'Singapore',
    'burmese': 'Myanmar',
    'cambodian': 'Cambodia',
    'laotian': 'Laos',
    
    // Indian Subcontinent
    'indian': 'India',
    'pakistani': 'Pakistan',
    'bangladeshi': 'Bangladesh',
    'sri lankan': 'Sri Lanka',
    'nepali': 'Nepal',
    'punjabi': 'India',
    'gujarati': 'India',
    'south indian': 'India',
    'north indian': 'India',
    'bengali': 'India',
    'goan': 'India',
    'kashmiri': 'India',
    'hyderabadi': 'India',
    'kerala': 'India',
    'tamil': 'India',
    
    // European
    'french': 'France',
    'italian': 'Italy',
    'spanish': 'Spain',
    'german': 'Germany',
    'british': 'United Kingdom',
    'english': 'United Kingdom',
    'irish': 'Ireland',
    'scottish': 'United Kingdom',
    'portuguese': 'Portugal',
    'dutch': 'Netherlands',
    'belgian': 'Belgium',
    'swiss': 'Switzerland',
    'austrian': 'Austria',
    'polish': 'Poland',
    'hungarian': 'Hungary',
    'czech': 'Czech Republic',
    'russian': 'Russia',
    'ukrainian': 'Ukraine',
    'scandinavian': 'Scandinavia',
    'swedish': 'Sweden',
    'norwegian': 'Norway',
    'danish': 'Denmark',
    'finnish': 'Finland',
    'bavarian': 'Germany',
    'tuscan': 'Italy',
    'neapolitan': 'Italy',
    'roman': 'Italy',
    'venetian': 'Italy',
    'lombard': 'Italy',
    'piedmontese': 'Italy',
    'emilian': 'Italy',
    'alsatian': 'France',
    'breton': 'France',
    'burgundian': 'France',
    'norman': 'France',
    'lyonnaise': 'France',
    'andalusian': 'Spain',
    'galician': 'Spain',
    'valencian': 'Spain',
    
    // Mediterranean
    'mediterranean': 'Mediterranean',
    'greek': 'Greece',
    'turkish': 'Turkey',
    'cypriot': 'Cyprus',
    'croatian': 'Croatia',
    'sicilian': 'Italy',
    'sardinian': 'Italy',
    'provençal': 'France',
    'provencal': 'France',
    'catalan': 'Spain',
    'basque': 'Spain',
    'cretan': 'Greece',
    'aegean': 'Greece',
    
    // Middle Eastern
    'lebanese': 'Lebanon',
    'syrian': 'Syria',
    'persian': 'Iran',
    'iranian': 'Iran',
    'iraqi': 'Iraq',
    'israeli': 'Israel',
    'palestinian': 'Palestine',
    'jordanian': 'Jordan',
    'yemeni': 'Yemen',
    'saudi': 'Saudi Arabia',
    'emirati': 'UAE',
    'gulf': 'Gulf States',
    'arab': 'Arab World',
    'levantine': 'Levant',
    
    // African
    'moroccan': 'Morocco',
    'egyptian': 'Egypt',
    'tunisian': 'Tunisia',
    'algerian': 'Algeria',
    'ethiopian': 'Ethiopia',
    'eritrean': 'Eritrea',
    'nigerian': 'Nigeria',
    'ghanaian': 'Ghana',
    'senegalese': 'Senegal',
    'south african': 'South Africa',
    'kenyan': 'Kenya',
    'north african': 'North Africa',
    'west african': 'West Africa',
    'east african': 'East Africa',
    
    // North American
    'american': 'United States',
    'canadian': 'Canada',
    'southern': 'United States',
    'cajun': 'United States',
    'creole': 'United States',
    'tex-mex': 'United States',
    'soul food': 'United States',
    'new england': 'United States',
    'californian': 'United States',
    'hawaiian': 'United States',
    'pacific northwest': 'United States',
    'midwestern': 'United States',
    'southwestern': 'United States',
    'québécois': 'Canada',
    'quebecois': 'Canada',
    
    // Latin American
    'mexican': 'Mexico',
    'brazilian': 'Brazil',
    'peruvian': 'Peru',
    'argentinian': 'Argentina',
    'chilean': 'Chile',
    'colombian': 'Colombia',
    'venezuelan': 'Venezuela',
    'ecuadorian': 'Ecuador',
    'bolivian': 'Bolivia',
    'central american': 'Central America',
    'salvadoran': 'El Salvador',
    'guatemalan': 'Guatemala',
    'oaxacan': 'Mexico',
    'yucatecan': 'Mexico',
    'veracruzano': 'Mexico',
    'jalisciense': 'Mexico',
    'norteno': 'Mexico',
    'bahian': 'Brazil',
    'gaucho': 'Argentina',
    'patagonian': 'Argentina',
    
    // Caribbean
    'caribbean': 'Caribbean',
    'cuban': 'Cuba',
    'jamaican': 'Jamaica',
    'puerto rican': 'Puerto Rico',
    'dominican': 'Dominican Republic',
    'haitian': 'Haiti',
    'trinidadian': 'Trinidad and Tobago',
    'barbadian': 'Barbados',
    
    // Oceanian
    'australian': 'Australia',
    'new zealand': 'New Zealand',
    'polynesian': 'Polynesia',
    'pacific islander': 'Pacific Islands',
  };

  /// Map of cuisine to province/style (for regional sub-cuisines)
  /// Only populated for cuisines that are sub-regions of a country
  static const Map<String, String> cuisineToProvince = {
    // Chinese provinces/styles
    'cantonese': 'Guangdong',
    'szechuan': 'Sichuan',
    'sichuan': 'Sichuan',
    'hunan': 'Hunan',
    'shanghai': 'Shanghai',
    'beijing': 'Beijing',
    'fujian': 'Fujian',
    'hakka': 'Hakka',
    'dim sum': 'Guangdong',
    
    // Indian provinces/styles
    'punjabi': 'Punjab',
    'gujarati': 'Gujarat',
    'south indian': 'South India',
    'north indian': 'North India',
    'bengali': 'Bengal',
    'goan': 'Goa',
    'kashmiri': 'Kashmir',
    'hyderabadi': 'Hyderabad',
    'kerala': 'Kerala',
    'tamil': 'Tamil Nadu',
    
    // Italian regions
    'tuscan': 'Tuscany',
    'neapolitan': 'Naples',
    'roman': 'Rome',
    'venetian': 'Venice',
    'lombard': 'Lombardy',
    'piedmontese': 'Piedmont',
    'emilian': 'Emilia-Romagna',
    'sicilian': 'Sicily',
    'sardinian': 'Sardinia',
    
    // French regions
    'alsatian': 'Alsace',
    'breton': 'Brittany',
    'burgundian': 'Burgundy',
    'norman': 'Normandy',
    'lyonnaise': 'Lyon',
    'provençal': 'Provence',
    'provencal': 'Provence',
    
    // Spanish regions
    'catalan': 'Catalonia',
    'basque': 'Basque Country',
    'andalusian': 'Andalusia',
    'galician': 'Galicia',
    'valencian': 'Valencia',
    
    // German regions
    'bavarian': 'Bavaria',
    
    // Greek regions
    'cretan': 'Crete',
    'aegean': 'Aegean Islands',
    
    // US regions
    'southern': 'Southern States',
    'cajun': 'Louisiana',
    'creole': 'Louisiana',
    'tex-mex': 'Texas',
    'soul food': 'Southern States',
    'new england': 'New England',
    'californian': 'California',
    'hawaiian': 'Hawaii',
    'pacific northwest': 'Pacific Northwest',
    'midwestern': 'Midwest',
    'southwestern': 'Southwest',
    
    // Canadian regions
    'québécois': 'Quebec',
    'quebecois': 'Quebec',
    
    // Mexican regions
    'oaxacan': 'Oaxaca',
    'yucatecan': 'Yucatan',
    'veracruzano': 'Veracruz',
    'jalisciense': 'Jalisco',
    'norteno': 'Northern Mexico',
    
    // Brazilian regions
    'bahian': 'Bahia',
    
    // Argentinian regions
    'gaucho': 'Pampas',
    'patagonian': 'Patagonia',
  };

  /// Get cuisine region from cuisine string
  static String? getContinentFromCuisine(String? cuisine) {
    if (cuisine == null || cuisine.isEmpty) return null;
    return cuisineToContinent[cuisine.toLowerCase()];
  }

  /// Get country from cuisine string
  static String? getCountryFromCuisine(String? cuisine) {
    if (cuisine == null || cuisine.isEmpty) return null;
    return cuisineToCountry[cuisine.toLowerCase()];
  }

  /// Get province/style from cuisine string (returns null for country-level cuisines)
  static String? getProvinceFromCuisine(String? cuisine) {
    if (cuisine == null || cuisine.isEmpty) return null;
    return cuisineToProvince[cuisine.toLowerCase()];
  }

  /// Get all cuisine regions (for filter tabs), in display order
  static List<String> get allContinents => [
        'All',
        'Asian',
        'Southeast Asian',
        'Indian Subcontinent',
        'European',
        'Mediterranean',
        'Middle Eastern',
        'African',
        'North American',
        'Latin American',
        'Caribbean',
        'Oceanian',
      ];
}
