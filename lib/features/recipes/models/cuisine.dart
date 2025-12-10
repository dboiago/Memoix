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
    Cuisine(code: 'ET', name: 'Ethiopian', continent: 'African', flag: '🇪🇹', colour: Color(0xFFCD853F)),
    Cuisine(code: 'MA', name: 'Moroccan', continent: 'African', flag: '🇲🇦', colour: Color(0xFFC1440E)),
    Cuisine(code: 'ZA', name: 'South African', continent: 'African', flag: '🇿🇦', colour: Color(0xFF228B22)),

    // Americas
    Cuisine(code: 'AR', name: 'Argentine', continent: 'Americas', flag: '🇦🇷', colour: Color(0xFF75AADB)),
    Cuisine(code: 'BR', name: 'Brazilian', continent: 'Americas', flag: '🇧🇷', colour: Color(0xFF009C3B)),
    Cuisine(code: 'CA', name: 'Canadian', continent: 'Americas', flag: '🇨🇦', colour: Color(0xFFFF0000)),
    Cuisine(code: 'CU', name: 'Cuban', continent: 'Americas', flag: '🇨🇺', colour: Color(0xFF002A8F)),
    Cuisine(code: 'JM', name: 'Jamaican', continent: 'Americas', flag: '🇯🇲', colour: Color(0xFF009B3A)),
    Cuisine(code: 'MX', name: 'Mexican', continent: 'Americas', flag: '🇲🇽', colour: Color(0xFF006847)),
    Cuisine(code: 'PE', name: 'Peruvian', continent: 'Americas', flag: '🇵🇪', colour: Color(0xFFD91023)),
    Cuisine(code: 'US', name: 'American', continent: 'Americas', flag: '🇺🇸', colour: Color(0xFF3C3B6E)),

    // Asian
    Cuisine(code: 'CN', name: 'Chinese', continent: 'Asian', flag: '🇨🇳', colour: Color(0xFFDE2910)),
    Cuisine(code: 'IN', name: 'Indian', continent: 'Asian', flag: '🇮🇳', colour: Color(0xFFFF9933)),
    Cuisine(code: 'ID', name: 'Indonesian', continent: 'Asian', flag: '🇮🇩', colour: Color(0xFFCE1126)),
    Cuisine(code: 'JP', name: 'Japanese', continent: 'Asian', flag: '🇯🇵', colour: Color(0xFFBC002D)),
    Cuisine(code: 'KR', name: 'Korean', continent: 'Asian', flag: '🇰🇷', colour: Color(0xFFCD2E3A)),
    Cuisine(code: 'MY', name: 'Malaysian', continent: 'Asian', flag: '🇲🇾', colour: Color(0xFFCC0001)),
    Cuisine(code: 'PH', name: 'Filipino', continent: 'Asian', flag: '🇵🇭', colour: Color(0xFF0038A8)),
    Cuisine(code: 'TH', name: 'Thai', continent: 'Asian', flag: '🇹🇭', colour: Color(0xFFED1C24)),
    Cuisine(code: 'VN', name: 'Vietnamese', continent: 'Asian', flag: '🇻🇳', colour: Color(0xFFDA251D)),

    // European
    Cuisine(code: 'GB', name: 'British', continent: 'European', flag: '🇬🇧', colour: Color(0xFF012169)),
    Cuisine(code: 'FR', name: 'French', continent: 'European', flag: '🇫🇷', colour: Color(0xFF0055A4)),
    Cuisine(code: 'DE', name: 'German', continent: 'European', flag: '🇩🇪', colour: Color(0xFFDD0000)),
    Cuisine(code: 'GR', name: 'Greek', continent: 'European', flag: '🇬🇷', colour: Color(0xFF0D5EAF)),
    Cuisine(code: 'HU', name: 'Hungarian', continent: 'European', flag: '🇭🇺', colour: Color(0xFF477050)),
    Cuisine(code: 'IE', name: 'Irish', continent: 'European', flag: '🇮🇪', colour: Color(0xFF169B62)),
    Cuisine(code: 'IT', name: 'Italian', continent: 'European', flag: '🇮🇹', colour: Color(0xFF009246)),
    Cuisine(code: 'PL', name: 'Polish', continent: 'European', flag: '🇵🇱', colour: Color(0xFFDC143C)),
    Cuisine(code: 'PT', name: 'Portuguese', continent: 'European', flag: '🇵🇹', colour: Color(0xFF006600)),
    Cuisine(code: 'RU', name: 'Russian', continent: 'European', flag: '🇷🇺', colour: Color(0xFF0039A6)),
    Cuisine(code: 'ES', name: 'Spanish', continent: 'European', flag: '🇪🇸', colour: Color(0xFFAA151B)),
    Cuisine(code: 'SE', name: 'Swedish', continent: 'European', flag: '🇸🇪', colour: Color(0xFF006AA7)),
    Cuisine(code: 'UA', name: 'Ukrainian', continent: 'European', flag: '🇺🇦', colour: Color(0xFF005BBB)),

    // Middle Eastern
    Cuisine(code: 'LB', name: 'Lebanese', continent: 'Middle Eastern', flag: '🇱🇧', colour: Color(0xFFEE161F)),
    Cuisine(code: 'IL', name: 'Israeli', continent: 'Middle Eastern', flag: '🇮🇱', colour: Color(0xFF0038B8)),
    Cuisine(code: 'TR', name: 'Turkish', continent: 'Middle Eastern', flag: '🇹🇷', colour: Color(0xFFE30A17)),
    Cuisine(code: 'IR', name: 'Persian', continent: 'Middle Eastern', flag: '🇮🇷', colour: Color(0xFF239F40)),

    // Oceanian
    Cuisine(code: 'AU', name: 'Australian', continent: 'Oceanian', flag: '🇦🇺', colour: Color(0xFF00008B)),
    Cuisine(code: 'NZ', name: 'New Zealand', continent: 'Oceanian', flag: '🇳🇿', colour: Color(0xFF00247D)),
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
