import 'dart:convert';
import 'dart:io' show gzip, HttpClient;
import 'package:flutter/material.dart' show BuildContext;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/recipes/models/recipe.dart';
import '../../features/recipes/models/cuisine.dart';
import 'webview_fetcher.dart';
import '../../features/recipes/models/spirit.dart';
import '../../features/import/models/recipe_import_result.dart';
import '../utils/text_normalizer.dart';
import '../utils/unit_normalizer.dart';

/// Helper class for YouTube chapters
class YouTubeChapter {
  final String title;
  final int startSeconds;
  
  YouTubeChapter({required this.title, required this.startSeconds});
}

/// Helper class for transcript segments with timestamps
class TranscriptSegment {
  final String text;
  final double startSeconds;
  
  TranscriptSegment({required this.text, required this.startSeconds});
}

/// Extraction mode for site configs
enum ExtractionMode {
  /// Container has sections as children, each with header + ingredient list
  containerWithSections,
  /// Headers are siblings followed by ingredient lists
  siblingHeaderList,
  /// Single list with mixed category and ingredient items
  mixedList,
}

/// Configuration for extracting ingredients from a specific site pattern
class SiteConfig {
  /// Selector for the main container (optional - uses document if null)
  final String? containerSelector;
  
  /// Selector for section/group elements (for containerWithSections mode)
  final String? sectionSelector;
  
  /// Selector for section header within a section or document
  final String? headerSelector;
  
  /// Selector for ingredient items
  final String ingredientSelector;
  
  /// How to extract ingredients from this site
  final ExtractionMode mode;
  
  /// Whether header is a direct child element (vs querySelector)
  final bool headerIsDirectChild;
  
  /// Tag name for direct child header (e.g., 'p', 'h3')
  final String? headerChildTag;

  const SiteConfig({
    this.containerSelector,
    this.sectionSelector,
    this.headerSelector,
    required this.ingredientSelector,
    required this.mode,
    this.headerIsDirectChild = false,
    this.headerChildTag,
  });
}

/// ========================================================================
/// SITE CONFIGURATIONS - HTML STRUCTURE PATTERNS
/// ========================================================================
/// 
/// WHY SITE CONFIGS: Recipe sites use vastly different HTML structures for
/// the same semantic content (ingredient lists with section headers).
/// These configs teach the parser how to find ingredients on each site.
///
/// EXTRACTION MODES:
/// - containerWithSections: Container div holds multiple section divs, each with header + list
///   Use for: King Arthur, Tasty.co, WPRM plugin
///   
/// - siblingHeaderList: Headers (h3/h4) followed by sibling <ul> elements
///   Use for: Serious Eats, NYT Cooking
///   
/// - mixedList: Single list with header items inline (li.category) mixed with ingredients
///   Use for: AmazingFoodMadeEasy, Saveur
///
/// WHEN TO ADD A NEW CONFIG:
/// 1. Test URL import fails to extract ingredient sections
/// 2. Inspect HTML to find the section/header/ingredient pattern
/// 3. Add config with appropriate mode and selectors
/// 4. Test with multiple recipes from that site
/// ========================================================================
const _siteConfigs = <String, SiteConfig>{
  /// King Arthur Baking: Professional baking site with complex multi-part recipes
  /// Structure: .ingredient-section contains a direct <p> child as header, then ul.list--bullets
  /// WHY: Their recipes often have "For the Dough", "For the Filling" sections critical for baking
  'kingarthur': SiteConfig(
    sectionSelector: '.ingredient-section',
    headerIsDirectChild: true,
    headerChildTag: 'p',
    ingredientSelector: 'ul li',
    mode: ExtractionMode.containerWithSections,
  ),
  
  /// Tasty.co (BuzzFeed): Popular video recipe site
  /// Structure: .ingredients__section with .ingredient-section-name header
  /// WHY: Their JSON-LD often lacks sections but HTML has them properly structured
  'tasty': SiteConfig(
    sectionSelector: '.ingredients__section',
    headerSelector: '.ingredient-section-name',
    ingredientSelector: 'li.ingredient',
    mode: ExtractionMode.containerWithSections,
  ),
  
  /// Serious Eats: Kenji López-Alt's site, rigorous recipe testing
  /// Structure: Heading elements followed by sibling ingredient lists
  /// WHY: They use CSS class naming that includes "heading" in structured ingredients
  'seriouseats': SiteConfig(
    headerSelector: '.structured-ingredients__list-heading',
    ingredientSelector: 'li',
    mode: ExtractionMode.siblingHeaderList,
  ),
  
  /// AmazingFoodMadeEasy: Sous vide and modernist cooking site
  /// Structure: Single ul.ingredient_list with li.category (headers) and li.ingredient (items)
  /// WHY: Modernist recipes have many components (e.g., "For the gel", "For the foam")
  /// that are embedded as list items rather than separate containers
  'amazingfood': SiteConfig(
    containerSelector: 'ul.ingredient_list, .ingredient_list',
    headerSelector: 'li.category h3',
    ingredientSelector: 'li.ingredient',
    mode: ExtractionMode.mixedList,
  ),
  
  /// NYT Cooking: New York Times recipe section (paywall site)
  /// Structure: Uses dynamic class names containing "ingredientgroup_name"
  /// WHY: React-based site with obfuscated classes, need partial matching
  'nyt': SiteConfig(
    headerSelector: '[class*="ingredientgroup_name"]',
    ingredientSelector: 'li',
    mode: ExtractionMode.siblingHeaderList,
  ),
  
  /// WordPress Recipe Maker (WPRM): Most popular WordPress recipe plugin
  /// Structure: .wprm-recipe-ingredient-group with .wprm-recipe-group-name
  /// WHY: ~40% of food blogs use WPRM, so this config handles a huge number of sites
  'wprm': SiteConfig(
    sectionSelector: '.wprm-recipe-ingredient-group',
    headerSelector: '.wprm-recipe-group-name',
    ingredientSelector: '.wprm-recipe-ingredient',
    mode: ExtractionMode.containerWithSections,
  ),
  
  /// Generic headers pattern: Works for many smaller sites
  /// Structure: .ingredients container with h3/h4 headers followed by li items
  /// WHY: Fallback for sites that use semantic HTML without recipe plugins
  'generic-headers': SiteConfig(
    containerSelector: '.ingredients',
    headerSelector: 'h3, h4',
    ingredientSelector: 'li',
    mode: ExtractionMode.siblingHeaderList,
  ),
  
  /// Generic container pattern: Broad fallback for common ingredient containers
  /// Structure: Various common IDs/classes, with category headers inline
  /// WHY: Last resort for sites like Saveur that don't use recipe plugins
  'generic-container': SiteConfig(
    containerSelector: '#recipe-ingredients, ul.ingredients, .ingredients ul, .recipe-ingredients, [data-recipe-ingredients]',
    headerSelector: 'li.category h3',
    ingredientSelector: 'li:not(.category)',
    mode: ExtractionMode.mixedList,
  ),
};

/// ========================================================================
/// URL RECIPE IMPORTER - ARCHITECTURE OVERVIEW
/// ========================================================================
/// 
/// This service imports recipes from URLs using a multi-stage approach:
/// 
/// STAGE 1: JSON-LD parsing (schema.org/Recipe format)
///   - Most reliable when available
///   - Provides structured data: name, ingredients, directions, times, yield
/// 
/// STAGE 2: HTML section supplementation (ALWAYS runs after Stage 1)
///   - WHY: JSON-LD often lacks ingredient sections (e.g., "For the crust", "For the filling")
///   - Sites like Punch, GBC, Tasty.co have sections in HTML but flat lists in JSON-LD
///   - This stage merges HTML sections INTO the JSON-LD data
/// 
/// STAGE 3: Embedded data enhancement (Next.js, Nuxt, Vite __NEXT_DATA__, etc.)
///   - WHY: Some sites (especially React/Vue) have more data in hydration state
///   - Can provide equipment, techniques, notes not in JSON-LD
/// 
/// STAGE 4: Pure HTML fallback (only if no JSON-LD found)
///   - Uses site-specific configs and heuristic parsing
///   - Lowest confidence, highest extraction effort
/// 
/// CRITICAL: NEVER short-circuit after Stage 1. The merge logic in stages 2-4
/// is what makes sites like Punch Drink, Great British Chefs, and Modernist
/// Pantry work correctly.
/// 
/// SITE-SPECIFIC HANDLING:
/// - YouTube: Fetches video description, transcripts, chapter timestamps
/// - Shopify/Lyres: Non-alcoholic spirit sites with custom recipe format
/// - Great British Chefs (GBC): Complex ingredient sections with sub-recipes
/// - AmazingFoodMadeEasy: Uses li.category for section headers
/// - Difford's Guide: Professional cocktail database with specific selectors
/// - Punch Drink: High-quality cocktail journalism, needs section merging
/// ========================================================================
class UrlRecipeImporter {
  static final _uuid = Uuid();

  /// Known cocktail recipe sites - used to detect course="Drinks" automatically
  /// 
  /// WHY a static list: These sites are dedicated cocktail/drink resources.
  /// When a URL matches, we can:
  /// 1. Set course to "Drinks" with high confidence (0.95)
  /// 2. Apply drink-specific parsing (detect base spirit, extract garnish)
  /// 3. Skip food-specific heuristics (serves/yield interpretation)
  /// 
  /// Sites in this list are maintained based on:
  /// - Professional cocktail databases (diffordsguide, liquor.com)
  /// - Magazine/journalism (imbibemagazine, punchdrink)
  /// - Non-alcoholic alternatives (seedlipdrinks, lyres)
  static const _cocktailSites = [
    'diffordsguide.com',     // Professional bartender database
    'liquor.com',            // Spirits industry magazine
    'thecocktailproject.com',// Cocktail tutorial site
    'imbibemagazine.com',    // Drinks journalism
    'cocktailsandshots.com', // Recipe aggregator
    'cocktails.lovetoknow.com', // General drinks reference
    'thespruceats.com/cocktails', // Spruce Eats drinks section
    'punchdrink.com',        // High-end drinks journalism - excellent sections
    'makedrinks.com',        // Recipe site
    'drinksmixer.com',       // Classic cocktail database
    'cocktail.uk',           // UK cocktail reference
    'absolutdrinks.com',     // Absolut vodka recipes
    'drinkflow.com',         // Modern cocktail app
    'drinkify.co',           // Pairing suggestions
    'seedlipdrinks.com',     // Non-alcoholic spirit recipes
    'lyres.com',             // Non-alcoholic spirit brand - Shopify site
  ];

  /// Known BBQ/Smoking recipe sites
  /// URLs containing these domains should default to 'Smoking' course
  /// Similar pattern to _cocktailSites for drinks
  static const _bbqSites = [
    'amazingribs.com',       // Premier BBQ science and recipes
    'smokingmeatforums.com', // BBQ community forum
    'virtualweberbullet.com',// Weber smoker community
    'bbqu.net',              // BBQ University
    'thermoworks.com',       // Thermometer company with BBQ recipes
    'traeger.com',           // Pellet grill manufacturer
    'weber.com',             // Grill manufacturer
    'charbroil.com',         // Grill manufacturer
    'bbqguys.com',           // BBQ equipment and recipes
    'heygrillhey.com',       // BBQ blog
    'smokedbbqsource.com',   // BBQ recipes and guides
    'meatchurch.com',        // BBQ rubs and recipes
    'malcomsbbq.com',        // BBQ competition champion
    'bradleysmoker.com',     // Smoker manufacturer
    'pitboss-grills.com',    // Pellet grill manufacturer
    'masterbuilt.com',       // Smoker manufacturer
    'kamadojoe.com',         // Kamado grill manufacturer
    'biggreenegg.com',       // Kamado grill manufacturer
    'recteq.com',            // Pellet grill manufacturer
    'oklahomajoes.com',      // Smoker manufacturer
  ];

  /// Known sites that embed recipes as images (infographics, recipe cards)
  /// These sites cannot be parsed via URL import - users should use OCR instead
  /// Returns a user-friendly message explaining the limitation
  static const _imageOnlyRecipeSites = <String, String>{
    'modernistcuisine.com': 'Modernist Cuisine displays recipes as high-resolution images. '
        'To import this recipe, save/screenshot the recipe image and use OCR Import from your gallery.',
  };

  /// Consolidated course detection keywords
  /// Each course maps to a list of keywords that indicate that course type
  /// Keywords are matched as word boundaries (\b) in lowercase text
  static const _courseKeywords = <String, List<String>>{
    'Smoking': [
      'smoked', 'smoking', 'smoker', 'bbq', 'barbecue', 'barbeque', 
      'low and slow', 'pellet grill', 'hickory', 'mesquite', 'applewood',
      'cherrywood', 'pecan', 'wood chips', 'wood chunks',
    ],
    'Drinks': [
      'cocktail', 'smoothie', 'juice', 'lemonade', 'drink', 'beverage', 
      'mocktail', 'sangria', 'punch', 'milkshake', 'frappe', 'martini', 
      'margarita', 'mojito', 'daiquiri', 'manhattan', 'negroni', 
      'old fashioned', 'highball', 'sour', 'fizz', 'collins', 'spritz', 
      'mimosa', 'bellini', 'cosmopolitan', 'mai tai', 'pina colada', 
      'bloody mary', 'paloma', 'vodka', 'gin', 'rum', 'tequila', 
      'whiskey', 'whisky', 'bourbon', 'scotch', 'brandy', 'cognac', 
      'mezcal', 'liqueur', 'vermouth', 'amaro', 'aperol', 'campari',
      'cordial', 'elixir', 'tonic', 'shrub', 'bitters',
    ],
    'Modernist': [
      'modernist', 'molecular', 'spherification', 'gelification', 
      'sous vide', 'foam', 'caviar', 'agar', 'xanthan', 'sodium alginate',
      'calcium chloride', 'lecithin', 'maltodextrin', 'methylcellulose',
      'gellan', 'transglutaminase', 'immersion circulator',
    ],
    'Breads': [
      'bread', 'focaccia', 'ciabatta', 'baguette', 'brioche', 'sourdough', 
      'rolls', 'buns', 'loaf', 'loaves', 'naan', 'pita', 'flatbread', 
      'bagel', 'croissant', 'pretzel', 'challah', 'dough',
    ],
    'Desserts': [
      'cake', 'cookie', 'brownie', 'pie', 'tart', 'dessert', 'sweet', 
      'chocolate', 'cheesecake', 'cupcake', 'muffin', 'donut', 'doughnut', 
      'pastry', 'pudding', 'ice cream', 'sorbet', 'flan', 'custard', 
      'macaron', 'tiramisu', 'mousse', 'creme brulee', 'pavlova', 'baklava',
      'gelato', 'truffle', 'fudge', 'candy', 'meringue', 'souffle',
      'gateau', 'petit four', 'entremets', 'mille-feuille', 'millefeuille',
      'eclair', 'choux', 'profiterole', 'opera cake', 'dacquoise',
      'genoise', 'sponge cake', 'layer cake', 'torte', 'trifle',
      'cremeux', 'glaze', 'ganache', 'tuile', 'praline', 'bonbon',
    ],
    'Soup': [
      'soup', 'stew', 'chowder', 'bisque', 'broth', 'consomme', 
      'gazpacho', 'minestrone', 'pho', 'ramen', 'chili', 'goulash',
      'tom yum', 'laksa',
    ],
    'Sides': [
      'salad', 'slaw', 'coleslaw', 'side dish', 'mashed', 
      'roasted vegetables', 'french fries', 'fries', 'wedges', 
      'gratin', 'pilaf', 'rice dish', 'risotto',
    ],
    'Sauces': [
      'sauce', 'gravy', 'dressing', 'dip', 'aioli', 'mayo', 'mayonnaise', 
      'ketchup', 'mustard', 'vinaigrette', 'pesto', 'salsa', 'guacamole', 
      'hummus', 'relish', 'chutney', 'coulis', 'marinade', 'glaze', 
      'reduction', 'chimichurri', 'gremolata',
    ],
    'Brunch': [
      'brunch', 'breakfast', 'pancake', 'waffle', 'french toast', 
      'eggs benedict', 'omelette', 'omelet', 'frittata', 'quiche', 
      'hash', 'scrambled', 'poached eggs',
    ],
    'Apps': [
      'appetizer', 'starter', 'tapas', 'antipasto', 'bruschetta', 
      'crostini', 'canape', 'spring roll', 'egg roll', 'dumpling', 
      'wonton', 'samosa', 'empanada', 'arancini', 'croquette', 'ceviche',
      'tartare', 'carpaccio',
    ],
    'Pickles': [
      'pickle', 'pickled', 'ferment', 'kimchi', 'sauerkraut', 
      'preserve', 'preserves', 'canning', 'jam', 'jelly', 'marmalade',
    ],
    'Rubs': [
      'rub', 'seasoning', 'spice mix', 'spice blend',
    ],
  };

  /// URL patterns that strongly indicate a specific course
  static const _courseUrlPatterns = <String, List<String>>{
    'Modernist': ['modernist', 'molecular', 'chefsteps', 'technique'],
  };

  /// HTML entity decode map for common entities
  static final _htmlEntities = {
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&#34;': '"',
    '&apos;': "'",
    '&#39;': "'",
    '&nbsp;': ' ',
    '&#160;': ' ',
    '&ndash;': '–',
    '&#8211;': '–',
    '&mdash;': '—',
    '&#8212;': '—',
    '&frac12;': '½',
    '&#189;': '½',
    '&frac14;': '¼',
    '&#188;': '¼',
    '&frac34;': '¾',
    '&#190;': '¾',
    '&frac13;': '⅓',
    '&frac23;': '⅔',
    '&deg;': '°',
    '&#176;': '°',
  };

  /// Fraction conversion map (decimal strings to unicode)
  static final _fractionMap = {
    '1/2': '½',
    '1/4': '¼',
    '3/4': '¾',
    '1/3': '⅓',
    '2/3': '⅔',
    '1/8': '⅛',
    '3/8': '⅜',
    '5/8': '⅝',
    '7/8': '⅞',
    '1/5': '⅕',
    '2/5': '⅖',
    '3/5': '⅗',
    '4/5': '⅘',
    '1/6': '⅙',
    '5/6': '⅚',
  };

  /// Measurement abbreviation normalisation
  static final _measurementNormalisation = {
    RegExp(r'\btbsp\b', caseSensitive: false): 'Tbsp',
    RegExp(r'\btbs\b', caseSensitive: false): 'Tbsp',
    RegExp(r'\btbl\b', caseSensitive: false): 'Tbsp',
    RegExp(r'\btb\b', caseSensitive: false): 'Tbsp',
    RegExp(r'\btablespoon[s]?\b', caseSensitive: false): 'Tbsp',
    RegExp(r'\btsp\b', caseSensitive: false): 'tsp',
    RegExp(r'\bteaspoon[s]?\b', caseSensitive: false): 'tsp',
    RegExp(r'\bcup[s]?\b', caseSensitive: false): 'cup',
    RegExp(r'\boz\b', caseSensitive: false): 'oz',
    RegExp(r'\bounce[s]?\b', caseSensitive: false): 'oz',
    RegExp(r'\blb[s]?\b', caseSensitive: false): 'lb',
    RegExp(r'\bpound[s]?\b', caseSensitive: false): 'lb',
    RegExp(r'\bkg\b', caseSensitive: false): 'kg',
    RegExp(r'\bkilogram[s]?\b', caseSensitive: false): 'kg',
    RegExp(r'\bg\b', caseSensitive: false): 'g',
    RegExp(r'\bgram[s]?\b', caseSensitive: false): 'g',
    RegExp(r'\bml\b', caseSensitive: false): 'ml',
    RegExp(r'\bmillilitre[s]?\b', caseSensitive: false): 'ml',
    RegExp(r'\bl\b', caseSensitive: false): 'L',
    RegExp(r'\blitre[s]?\b', caseSensitive: false): 'L',
  };

  /// ========================================================================
  /// SHARED CONSTANTS - Reduces duplication and improves maintainability
  /// ========================================================================
  
  /// Unicode fraction characters for ingredient parsing
  static const _unicodeFractions = r'[½¼¾⅓⅔⅛⅜⅝⅞⅕⅖⅗⅘⅙⅚]';
  
  /// Time unit patterns for duration parsing
  static const _timeUnitPattern = r'(?:minutes?|mins?|hours?|hrs?|h|days?|d)';
  
  /// Max recursion depth for embedded data extraction
  static const _maxRecursionDepth = 10;
  
  /// Retry configuration
  static const _maxRetryAttempts = 3;
  static const _retryDelayMs = 500;
  
  /// Content length limits
  static const _maxIngredientLineLength = 200;
  static const _minIngredientCount = 2;
  static const _maxSectionHeaderLength = 60;
  
  /// SECURITY: Maximum HTTP response size (10 MB)
  /// Prevents downloading massive files (e.g., ISOs, videos) that could crash the app
  static const _maxResponseBytes = 10 * 1024 * 1024; // 10 MB
  
  /// JSON search limits for embedded data
  static const _jsonSearchBackward = 5000;
  static const _jsonSearchForward = 10000;

  /// Regex for "For the X" prefix in section headers
  static final _forThePrefixRegex = RegExp(r'^For\s+(?:the\s+)?(.+)$', caseSensitive: false);
  
  /// Strip "For the" prefix from section headers (e.g., "For the sauce" -> "sauce")
  /// Returns cleaned string with the prefix removed, or original if no match
  static String _stripForThePrefix(String text) {
    final match = _forThePrefixRegex.firstMatch(text);
    return match?.group(1)?.trim() ?? text;
  }

  /// ========================================================================
  /// MAIN IMPORT ENTRY POINT - MULTI-STAGE EXTRACTION
  /// ========================================================================
  /// 
  /// Import a recipe from a URL using the multi-stage approach:
  /// 
  /// STAGE 1: JSON-LD parsing (schema.org/Recipe format)
  /// STAGE 2: HTML section supplementation (ALWAYS after Stage 1)
  /// STAGE 3: Embedded data enhancement (Next.js, Nuxt, Vite hydration)
  /// STAGE 4: Pure HTML fallback (only if no JSON-LD)
  /// 
  /// CRITICAL: NEVER short-circuit after Stage 1. The merge logic is what
  /// makes sites like Punch Drink, Great British Chefs, and Modernist Pantry
  /// work correctly. JSON-LD often has flat ingredient lists but HTML has
  /// section headers ("For the Crust", "For the Filling") that are essential.
  /// 
  /// Returns RecipeImportResult with confidence scores for user review.
  /// 
  /// If [context] is provided, will attempt to use WebView fallback when
  /// the site returns 403 (bot detection). This requires a valid BuildContext.
  Future<RecipeImportResult> importFromUrl(String url, {BuildContext? context}) async {
    try {
      // SECURITY: Validate URL scheme before any processing
      // Only allow http:// and https:// to prevent local file access or XSS
      final uri = Uri.tryParse(url);
      if (uri == null) {
        throw ArgumentError('Invalid URL format: unable to parse URL');
      }
      if (!uri.isScheme('http') && !uri.isScheme('https')) {
        throw ArgumentError(
          'Invalid URL scheme: "${uri.scheme}". Only HTTP and HTTPS URLs are allowed. '
          'Schemes like file://, javascript://, and content:// are blocked for security.'
        );
      }
      
      // Check if this is a YouTube video
      final videoId = _extractYouTubeVideoId(url);
      if (videoId != null) {
        return await _importFromYouTube(videoId, url);
      }
      
      // Parse the URL to get the host for Referer header
      final origin = '${uri.scheme}://${uri.host}';
      
      // Try print version first for sites that support it
      // Print versions are cleaner (less JS) and often bypass bot detection
      final printUrl = _getPrintUrl(url, uri);
      
      // Helper function to attempt fetch with given headers
      // Uses IOClient with custom HttpClient for better HTTP/1.1 compatibility
      // SECURITY: Implements streaming with size limits to prevent OOM attacks
      Future<http.Response> tryFetch(String fetchUrl, Map<String, String> headers) async {
        // Create a custom HttpClient that mimics a real browser
        // This helps avoid bot detection on sites like allrecipes.com
        final httpClient = HttpClient()
          ..connectionTimeout = const Duration(seconds: 30)
          ..idleTimeout = const Duration(seconds: 10)
          ..userAgent = headers['User-Agent'] ?? 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36'
          ..autoUncompress = true // Let the client handle decompression like a browser
          ..maxConnectionsPerHost = 6; // Chrome uses 6 connections per host
        
        try {
          final client = IOClient(httpClient);
          
          // Use streamed request to check Content-Length before downloading body
          final request = http.Request('GET', Uri.parse(fetchUrl));
          headers.forEach((key, value) => request.headers[key] = value);
          
          final streamedResponse = await client.send(request);
          
          // SECURITY: Fast-fail if Content-Length header indicates response is too large
          final contentLength = streamedResponse.contentLength;
          if (contentLength != null && contentLength > _maxResponseBytes) {
            // Cancel the stream before throwing
            await streamedResponse.stream.drain<void>();
            throw Exception(
              'Response too large: ${(contentLength / 1024 / 1024).toStringAsFixed(1)} MB. '
              'Maximum allowed: ${(_maxResponseBytes / 1024 / 1024).toStringAsFixed(0)} MB.'
            );
          }
          
          // SECURITY: Fast-fail on non-HTML content types (PDF, images, videos, archives)
          // This prevents downloading useless binary files
          final contentType = streamedResponse.headers['content-type']?.toLowerCase();
          if (contentType != null) {
            // Reject known binary/non-recipe content types
            final blockedTypes = [
              'application/pdf',
              'application/zip',
              'application/x-rar',
              'application/x-7z',
              'application/octet-stream',
              'image/',
              'video/',
              'audio/',
            ];
            
            for (final blocked in blockedTypes) {
              if (contentType.contains(blocked)) {
                await streamedResponse.stream.drain<void>();
                throw Exception('Invalid content type: $contentType. Expected HTML or JSON.');
              }
            }
            
            // Verify it's an acceptable content type (if specified)
            // Accept: text/html, application/json, application/ld+json, text/plain, application/xhtml+xml
            final allowedTypes = [
              'text/html',
              'application/json',
              'application/ld+json',
              'text/plain',
              'application/xhtml+xml',
            ];
            
            final isAllowed = allowedTypes.any((allowed) => contentType.contains(allowed));
            if (!isAllowed && !contentType.startsWith('text/')) {
              await streamedResponse.stream.drain<void>();
              throw Exception('Invalid content type: $contentType. Expected HTML or JSON.');
            }
          }
          // Note: If Content-Type header is missing, we allow it through
          // (some old servers don't send it) and let the HTML parser handle it
          
          // SECURITY: Stream the body with running byte count (safety net for chunked encoding)
          // This handles servers that don't send Content-Length header
          final chunks = <List<int>>[];
          int bytesRead = 0;
          
          await for (final chunk in streamedResponse.stream) {
            bytesRead += chunk.length;
            
            // Check if we've exceeded the limit
            if (bytesRead > _maxResponseBytes) {
              throw Exception(
                'Response too large: exceeded ${(_maxResponseBytes / 1024 / 1024).toStringAsFixed(0)} MB limit '
                'while streaming (no Content-Length header). Download cancelled.'
              );
            }
            
            chunks.add(chunk);
          }
          
          // Combine chunks into final body bytes
          final bodyBytes = chunks.expand((chunk) => chunk).toList();
          
          // Create a standard Response from the streamed response
          return http.Response.bytes(
            bodyBytes,
            streamedResponse.statusCode,
            headers: streamedResponse.headers,
            request: request,
            reasonPhrase: streamedResponse.reasonPhrase,
          );
        } catch (e) {
          httpClient.close();
          rethrow;
        }
      }
      
      // List of header configurations to try in order
      // Site-specific configurations for known problematic sites
      final isDotdashSite = uri.host.contains('thespruceeats.com') ||
          uri.host.contains('thespruce.com') ||
          uri.host.contains('simplyrecipes.com') ||
          uri.host.contains('seriouseats.com') ||
          uri.host.contains('allrecipes.com') ||
          uri.host.contains('foodandwine.com') ||
          uri.host.contains('bhg.com') ||
          uri.host.contains('marthastewart.com') ||
          uri.host.contains('eatingwell.com') ||
          uri.host.contains('delish.com') ||
          uri.host.contains('bonappetit.com');
      
      final headerConfigs = [
        // Config 0: Googlebot FIRST for Dotdash sites - they reliably allow crawlers for SEO
        if (isDotdashSite) {
          'User-Agent': 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
          'Accept-Encoding': 'identity',
          'Connection': 'close',
        },
        // Config 1: Dotdash Meredith sites - full Chrome headers as fallback
        if (isDotdashSite) {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
          'Accept-Encoding': 'identity', // Avoid compression - http package has issues with some encodings
          'Connection': 'close', // Disable keep-alive to avoid chunked encoding parsing issues
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
          'Sec-Ch-Ua': '"Google Chrome";v="137", "Chromium";v="137", "Not_A Brand";v="24"',
          'Sec-Ch-Ua-Mobile': '?0',
          'Sec-Ch-Ua-Platform': '"Windows"',
          'Sec-Fetch-Dest': 'document',
          'Sec-Fetch-Mode': 'navigate',
          'Sec-Fetch-Site': 'none',
          'Sec-Fetch-User': '?1',
          'Upgrade-Insecure-Requests': '1',
        },
        // Config 2: Standard Chrome browser headers
        {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
          'Accept-Encoding': 'identity', // No compression - safest option
          'Connection': 'close', // Disable keep-alive to avoid chunked encoding parsing issues
          'Referer': origin,
          'Origin': origin,
          'Sec-Ch-Ua': '"Google Chrome";v="137", "Chromium";v="137", "Not_A Brand";v="24"',
          'Sec-Ch-Ua-Mobile': '?0',
          'Sec-Ch-Ua-Platform': '"Windows"',
          'Sec-Fetch-Dest': 'document',
          'Sec-Fetch-Mode': 'navigate',
          'Sec-Fetch-Site': 'same-origin',
          'Sec-Fetch-User': '?1',
          'Upgrade-Insecure-Requests': '1',
          'Cache-Control': 'max-age=0',
        },
        // Config 3: Googlebot (for non-Dotdash sites that allow crawlers)
        {
          'User-Agent': 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
          'Accept-Encoding': 'identity',
          'Connection': 'close',
        },
        // Config 4: Mobile Safari
        {
          'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
          'Accept-Encoding': 'identity',
          'Connection': 'close',
        },
        // Config 5: Firefox with minimal headers
        {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:122.0) Gecko/20100101 Firefox/122.0',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.5',
          'Accept-Encoding': 'identity',
          'Connection': 'close',
        },
        // Config 6: Bare minimum headers
        {
          'User-Agent': 'Mozilla/5.0',
          'Accept': '*/*',
          'Connection': 'close',
        },
      ];
      
      http.Response? response;
      String? lastError;
      String actualUrl = url; // Track which URL succeeded (print or original)
      
      // Strategy: Try print URL first (if available), then fall back to original URL
      // Print versions are cleaner and often bypass bot detection
      final urlsToTry = [
        if (printUrl != null) printUrl,
        url,
      ];
      
      // Try each URL with each header configuration until one works
      urlLoop:
      for (final urlToTry in urlsToTry) {
        for (int i = 0; i < headerConfigs.length; i++) {
          final headers = headerConfigs[i];
          try {
            response = await tryFetch(urlToTry, headers);
            if (response.statusCode == 200) {
              actualUrl = urlToTry;
              break urlLoop; // Success!
            }
            lastError = 'HTTP ${response.statusCode}';
          } catch (e) {
            // ClientException or other HTTP errors - try next config
            lastError = e.toString();
            response = null;
            
            // If this is an HTTP parsing error (like "115 does not match 13"), 
            // wait a moment before retrying with next config
            if (lastError.contains('does not match') || 
                lastError.contains('Failed to parse HTTP')) {
              await Future.delayed(const Duration(milliseconds: 500));
            }
            continue;
          }
        }
      }
      
      String body;
      var document;
      bool usedWaybackMachine = false; // Track if we used archive (images won't work)
      
      if (response == null || response.statusCode != 200) {
        // Check if we got a 403 (bot detection)
        final is403 = lastError?.contains('403') == true || response?.statusCode == 403;
        
        // Try Wayback Machine (Internet Archive) as a fallback for blocked sites
        // The Wayback Machine caches most popular recipe sites
        if (is403) {
          try {
            // First, check if the URL is archived and get the latest snapshot
            final availabilityUrl = 'https://archive.org/wayback/available?url=${Uri.encodeComponent(url)}';
            final availabilityResponse = await http.get(
              Uri.parse(availabilityUrl),
              headers: {'Accept': 'application/json'},
            );
            
            if (availabilityResponse.statusCode == 200) {
              final availabilityData = jsonDecode(availabilityResponse.body);
              final snapshot = availabilityData['archived_snapshots']?['closest'];
              
              if (snapshot != null && snapshot['available'] == true) {
                final archiveUrl = snapshot['url'] as String;
                
                // Fetch the archived version
                final archiveResponse = await http.get(
                  Uri.parse(archiveUrl),
                  headers: {
                    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                  },
                );
                
                if (archiveResponse.statusCode == 200) {
                  body = _decodeResponseBody(archiveResponse);
                  // Clean up Wayback Machine's injected toolbar HTML
                  body = body.replaceAll(RegExp(r'<!-- BEGIN WAYBACK TOOLBAR INSERT -->.*?<!-- END WAYBACK TOOLBAR INSERT -->', dotAll: true), '');
                  document = html_parser.parse(body);
                  usedWaybackMachine = true; // Images from archive are often broken
                  // Archive succeeded, continue with normal parsing below
                } else {
                  throw Exception('Archive returned ${archiveResponse.statusCode}');
                }
              } else {
                throw Exception('No archived version available');
              }
            } else {
              throw Exception('Wayback API returned ${availabilityResponse.statusCode}');
            }
          } catch (archiveError) {
            // Wayback Machine also failed, try WebView on mobile
            if (context != null && WebViewFetcher.isSupported) {
              try {
                body = await WebViewFetcher.fetchHtml(context, url);
                document = html_parser.parse(body);
                // WebView succeeded, continue with normal parsing below
              } catch (webViewError) {
                throw Exception('Failed to fetch URL: This site blocks automated access. Try copying the recipe text manually.');
              }
            } else {
              throw Exception('Failed to fetch URL: This site blocks automated access. Try copying the recipe text manually.');
            }
          }
        } else {
          // Non-403 error
          String errorMessage = lastError ?? 'unknown error';
          if (errorMessage.contains('does not match') || 
              errorMessage.contains('Failed to parse HTTP')) {
            errorMessage = 'This site may have connection issues. Please try again later or copy the recipe manually.';
          }
          throw Exception('Failed to fetch URL: $errorMessage');
        }
      } else {
        // Decode response body - handle encoding errors gracefully
        body = _decodeResponseBody(response);
        document = html_parser.parse(body);
      }
      
      // Check if we got a JavaScript shell (no real content)
      final hasRealContent = document.querySelector('title')?.text?.isNotEmpty == true ||
          document.querySelectorAll('h1, h2, h3').isNotEmpty ||
          document.querySelector('[itemtype*="Recipe"]') != null ||
          document.querySelectorAll('script[type="application/ld+json"]').isNotEmpty;
      
      // If no real content, retry with Googlebot user-agent (many sites serve pre-rendered HTML for SEO)
      if (!hasRealContent) {
        response = await http.get(
          Uri.parse(url),
          headers: {
            'User-Agent': 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.9',
          },
        );
        
        if (response.statusCode == 200) {
          body = _decodeResponseBody(response);
          document = html_parser.parse(body);
        }
      }

      // Try to find JSON-LD structured data first (most reliable)
      final jsonLdScripts = document.querySelectorAll('script[type="application/ld+json"]');
      RecipeImportResult? jsonLdResult;
      
      for (final script in jsonLdScripts) {
        try {
          // Handle potential encoding issues in JSON-LD script content
          final String scriptText = script.text;
          // If decoding fails, try to fix common encoding issues
          try {
            final data = jsonDecode(scriptText);
            jsonLdResult = _parseJsonLdWithConfidence(data, url);
            if (jsonLdResult != null) break;
          } on FormatException {
            // If JSON decode fails due to encoding, try to re-encode
            try {
              // Re-encode as UTF-8 bytes and decode again
              final bytes = utf8.encode(scriptText);
              final fixed = utf8.decode(bytes, allowMalformed: true);
              final data = jsonDecode(fixed);
              jsonLdResult = _parseJsonLdWithConfidence(data, url);
              if (jsonLdResult != null) break;
            } catch (_) {
              // Skip this script if we can't fix it
              continue;
            }
          }
        } catch (_) {
          continue;
        }
      }
      
      // If JSON-LD found a result, check if we need to supplement with equipment or sections from HTML
      if (jsonLdResult != null) {
        // Check if HTML has ingredient sections that JSON-LD is missing
        // This handles sites like AmazingFoodMadeEasy where JSON-LD has flat ingredient list
        // but HTML has section headers (ingredient_dish_header, li.category, etc.)
        final hasHtmlSections = document.querySelector('.ingredient_dish_header') != null ||
                                document.querySelector('li.category') != null ||
                                document.querySelector('.ingredient-group-header') != null ||
                                document.querySelector('.wprm-recipe-group-name') != null ||
                                document.querySelector('.ingredients__section .ingredient-section-name') != null || // Tasty.co
                                document.querySelector('[class*="ingredientgroup_name"]') != null || // NYT Cooking
                                document.querySelector('.structured-ingredients__list-heading') != null || // Serious Eats
                                document.querySelector('.ingredient-section') != null || // King Arthur Baking
                                document.querySelector('.tasty-recipes-ingredients h4') != null || // Tasty Recipes plugin
                                document.querySelector('.tasty-recipes-ingredients-body h4') != null || // Tasty Recipes (alt)
                                document.querySelector('.content-info h3.wp-block-heading') != null || // sogoodmagazine.com
                                document.querySelector('h3.wp-block-heading + ul') != null; // pastryartsmag.com (WP block headings)
        
        if (hasHtmlSections) {
          // Re-parse with HTML to get section headers
          // Fall through to HTML parsing below instead of returning JSON-LD result
          // We'll use JSON-LD for other metadata but get ingredients from HTML
          var htmlIngredients = _extractIngredientsWithSections(document);
          // Filter out garbage (UI elements, ads, social media prompts) and deduplicate
          htmlIngredients = _filterIngredientStrings(htmlIngredients);
          if (htmlIngredients.isNotEmpty) {
            // Parse the raw ingredient strings to Ingredient objects with sections
            final ingredients = _parseIngredients(htmlIngredients);
            
            // Return combined result: ingredients from HTML (with sections), rest from JSON-LD
            // Also get equipment from HTML
            final sectionResult = _parseHtmlBySections(document);
            final htmlEquipment = sectionResult['equipment'] as List<String>? ?? [];
            return RecipeImportResult(
              name: jsonLdResult.name,
              course: jsonLdResult.course,
              cuisine: jsonLdResult.cuisine,
              subcategory: jsonLdResult.subcategory,
              serves: jsonLdResult.serves,
              time: jsonLdResult.time,
              ingredients: _filterParsedIngredients(ingredients),
              directions: jsonLdResult.directions,
              comments: jsonLdResult.comments,
              imageUrl: jsonLdResult.imageUrl,
              nutrition: jsonLdResult.nutrition,
              equipment: htmlEquipment.isNotEmpty ? htmlEquipment : jsonLdResult.equipment,
              rawIngredients: _buildRawIngredients(htmlIngredients),
              rawDirections: jsonLdResult.rawDirections,
              detectedCourses: jsonLdResult.detectedCourses,
              detectedCuisines: jsonLdResult.detectedCuisines,
              nameConfidence: jsonLdResult.nameConfidence,
              courseConfidence: jsonLdResult.courseConfidence,
              cuisineConfidence: jsonLdResult.cuisineConfidence,
              ingredientsConfidence: jsonLdResult.ingredientsConfidence,
              directionsConfidence: jsonLdResult.directionsConfidence,
              servesConfidence: jsonLdResult.servesConfidence,
              timeConfidence: jsonLdResult.timeConfidence,
              sourceUrl: jsonLdResult.sourceUrl,
              source: jsonLdResult.source,
              imagePaths: jsonLdResult.imagePaths,
            );
          }
        }
        
        // Try to enhance JSON-LD with richer ingredient data from embedded JavaScript
        // (Vite SSR, Next.js, Nuxt, etc.) - these often have section groupings and better serves data
        final enhancedResult = _tryEnhanceWithEmbeddedData(body, jsonLdResult);
        if (enhancedResult != null) {
          return enhancedResult;
        }
        
        // Always try to supplement JSON-LD with glass/garnish from HTML (for drink recipes)
        // and equipment/directions/ingredients if missing. These aren't standard Schema.org Recipe properties.
        final sectionResult = _parseHtmlBySections(document);
        final htmlEquipment = sectionResult['equipment'] as List<String>? ?? [];
        final htmlGlass = sectionResult['glass'] as String?;
        final htmlGarnish = sectionResult['garnish'] as List<String>? ?? [];
        final htmlNotes = sectionResult['notes'] as String?;
        
        // Also try to extract directions from HTML (handles Lyres/Shopify embedded JSON)
        final htmlDirections = _extractDirectionsFromRawHtml(document, body);
        
        // Try to extract ingredients from HTML if JSON-LD is missing them
        // First try the <br>-separated approach (Bradley Smoker style)
        var htmlIngredientStrings = <String>[];
        if (jsonLdResult.ingredients.isEmpty) {
          // Try heading-based <br> separated ingredients
          for (final heading in document.querySelectorAll('h1, h2, h3')) {
            final headingText = (heading.text ?? '').toLowerCase().trim();
            if (headingText.contains('ingredient')) {
              var nextElement = heading.nextElementSibling;
              if (nextElement?.localName == 'div') {
                final innerP = nextElement!.querySelector('p');
                if (innerP != null) {
                  nextElement = innerP;
                }
              }
              if (nextElement != null && (nextElement.localName == 'p' || nextElement.localName == 'div')) {
                final innerHtml = nextElement.innerHtml;
                if (innerHtml.contains('<br')) {
                  final parts = innerHtml.split(RegExp(r'<br\s*/?>', caseSensitive: false));
                  for (final part in parts) {
                    final text = _decodeHtml(part.replaceAll(RegExp(r'<[^>]+>'), '').trim());
                    if (text.isNotEmpty) {
                      htmlIngredientStrings.add(text);
                    }
                  }
                }
              }
              if (htmlIngredientStrings.isNotEmpty) break;
            }
          }
          
          // If still empty, try standard selectors
          if (htmlIngredientStrings.isEmpty) {
            final ingredientElements = document.querySelectorAll(
              '.ingredients li, .ingredient-list li, [itemprop="recipeIngredient"], .wprm-recipe-ingredient, '
              '.recipe-ingredients li, .recipe__ingredients li, article ul li',
            );
            for (final e in ingredientElements) {
              final text = _decodeHtml((e.text ?? '').trim());
              if (text.isNotEmpty) {
                htmlIngredientStrings.add(text);
              }
            }
          }
        }
        final htmlIngredients = _parseIngredients(htmlIngredientStrings);
        
        // Try to extract directions from HTML if JSON-LD is missing them
        var htmlDirectionStrings = <String>[];
        if (jsonLdResult.directions.isEmpty && htmlDirections.isEmpty) {
          // Try heading-based paragraph directions (Bradley Smoker style)
          for (final heading in document.querySelectorAll('h1, h2, h3')) {
            final headingText = (heading.text ?? '').toLowerCase().trim();
            if (headingText.contains('preparation') || 
                headingText.contains('instruction') || 
                headingText.contains('direction') ||
                headingText.contains('method')) {
              var sibling = heading.nextElementSibling;
              while (sibling != null && 
                     sibling.localName != 'h1' && 
                     sibling.localName != 'h2' && 
                     sibling.localName != 'h3') {
                if (sibling.localName == 'p') {
                  final text = _decodeHtml((sibling.text ?? '').trim());
                  if (text.isNotEmpty && text.length > 20) {
                    htmlDirectionStrings.add(text);
                  }
                } else if (sibling.localName == 'div') {
                  for (final p in sibling.querySelectorAll('p')) {
                    final text = _decodeHtml((p.text ?? '').trim());
                    if (text.isNotEmpty && text.length > 20) {
                      htmlDirectionStrings.add(text);
                    }
                  }
                }
                sibling = sibling.nextElementSibling;
              }
              if (htmlDirectionStrings.isNotEmpty) break;
            }
          }
        }
        
        // Check if we need to supplement anything
        final needsEquipment = jsonLdResult.equipment.isEmpty && htmlEquipment.isNotEmpty;
        final needsGlass = (jsonLdResult.glass == null || jsonLdResult.glass!.isEmpty) && htmlGlass != null;
        final needsGarnish = jsonLdResult.garnish.isEmpty && htmlGarnish.isNotEmpty;
        final needsNotes = (jsonLdResult.comments == null || jsonLdResult.comments!.isEmpty) && htmlNotes != null;
        final needsDirections = jsonLdResult.directions.isEmpty && (htmlDirections.isNotEmpty || htmlDirectionStrings.isNotEmpty);
        final needsIngredients = jsonLdResult.ingredients.isEmpty && htmlIngredients.isNotEmpty;
        
        if (needsEquipment || needsGlass || needsGarnish || needsNotes || needsDirections || needsIngredients) {
          // Combine notes if both exist
          String? combinedNotes = jsonLdResult.comments;
          if (needsNotes) {
            combinedNotes = htmlNotes;
          } else if (combinedNotes != null && htmlNotes != null && !combinedNotes.contains(htmlNotes)) {
            // Append HTML notes to existing notes if they differ
            combinedNotes = '$combinedNotes\n\n$htmlNotes';
          }
          
          return RecipeImportResult(
            name: jsonLdResult.name,
            course: jsonLdResult.course,
            cuisine: jsonLdResult.cuisine,
            subcategory: jsonLdResult.subcategory,
            serves: jsonLdResult.serves,
            time: jsonLdResult.time,
            ingredients: _filterParsedIngredients(needsIngredients ? htmlIngredients : jsonLdResult.ingredients),
            directions: needsDirections 
                ? (htmlDirections.isNotEmpty ? List<String>.from(htmlDirections) : htmlDirectionStrings)
                : jsonLdResult.directions,
            comments: combinedNotes,
            imageUrl: jsonLdResult.imageUrl,
            nutrition: jsonLdResult.nutrition,
            equipment: needsEquipment ? htmlEquipment : jsonLdResult.equipment,
            glass: needsGlass ? htmlGlass : jsonLdResult.glass,
            garnish: needsGarnish ? htmlGarnish : jsonLdResult.garnish,
            rawIngredients: jsonLdResult.rawIngredients, // Keep original raw data
            rawDirections: needsDirections 
                ? (htmlDirections.isNotEmpty ? htmlDirections : htmlDirectionStrings)
                : jsonLdResult.rawDirections,
            detectedCourses: jsonLdResult.detectedCourses,
            detectedCuisines: jsonLdResult.detectedCuisines,
            nameConfidence: jsonLdResult.nameConfidence,
            courseConfidence: jsonLdResult.courseConfidence,
            cuisineConfidence: jsonLdResult.cuisineConfidence,
            ingredientsConfidence: needsIngredients ? 0.7 : jsonLdResult.ingredientsConfidence, // Lower confidence for HTML-extracted ingredients
            directionsConfidence: needsDirections ? 0.7 : jsonLdResult.directionsConfidence, // Lower confidence for HTML-extracted directions
            servesConfidence: jsonLdResult.servesConfidence,
            timeConfidence: jsonLdResult.timeConfidence,
            sourceUrl: jsonLdResult.sourceUrl,
            source: jsonLdResult.source,
            imagePaths: jsonLdResult.imagePaths,
          );
        }
        
        return jsonLdResult;
      }
      
      // Try to extract recipe data from embedded JavaScript (React/Next.js/Vue hydration state)
      final embeddedResult = _tryExtractFromEmbeddedJson(body, url);
      if (embeddedResult != null) {
        return embeddedResult;
      }

      // Fallback: try to parse from HTML structure
      final result = _parseFromHtmlWithConfidence(document, url, body);
      if (result != null) {
        return result;
      }
      
      // Provide more helpful error message with diagnostic info
      final jsonLdCount = jsonLdScripts.length;
      final hasMicrodata = document.querySelector('[itemtype*="Recipe"]') != null;
      final hasIngredientById = document.querySelector('#ingredients, [id="ingredients"]') != null;
      final hasRecipeClass = document.querySelector('.recipe, .recipe-card, .recipe-content') != null;
      final hasAnyLists = document.querySelectorAll('ul li, ol li').length > 0;
      final bodyText = document.body?.text ?? '';
      final bodyLength = bodyText.length;
      final hasBullets = bodyText.contains('•') || bodyText.contains('\u2022') || bodyText.contains('\u2023') || bodyText.contains('\u25E6');
      final hasH2 = document.querySelectorAll('h2').length;
      final hasH3 = document.querySelectorAll('h3').length;
      final hasIngredientWord = bodyText.toLowerCase().contains('ingredient');
      
      // Get page title to help diagnose what was returned
      final pageTitle = document.querySelector('title')?.text?.trim() ?? '';
      final titlePreview = pageTitle.length > 50 ? '${pageTitle.substring(0, 50)}...' : pageTitle;
      
      // Check for common text patterns
      final hasMeasurements = RegExp(r'\d+\s*[gG](?:\s|$|\))|\d+\s*(?:cup|tbsp|tsp)', caseSensitive: false).hasMatch(bodyText);
      
      // Check raw HTML for bullets and measurements (in case DOM parsing strips them)
      final rawHasBullets = body.contains('•') || body.contains('&bull;') || body.contains('&#8226;');
      final rawHasMeasurements = RegExp(r'\d+\s*g\s*\(', caseSensitive: false).hasMatch(body);
      
      // Check raw HTML for key markers the page should have
      final rawHasH2 = body.contains('<h2');
      final rawHasItemtype = body.toLowerCase().contains('itemtype');
      final rawHasSchema = body.toLowerCase().contains('schema.org');
      
      // Sample of body text for debugging (first 200 chars after title-like content)
      String bodySample = '';
      final ingredientIdx = bodyText.toLowerCase().indexOf('ingredient');
      if (ingredientIdx >= 0) {
        final endIdx = (ingredientIdx + 300).clamp(0, bodyText.length);
        bodySample = bodyText.substring(ingredientIdx, endIdx).replaceAll(RegExp(r'\s+'), ' ').trim();
        if (bodySample.length > 100) bodySample = '${bodySample.substring(0, 100)}...';
      }
      
      // Also sample raw HTML near ingredient patterns
      String rawSample = '';
      final rawIngIdx = body.toLowerCase().indexOf('ingredient');
      if (rawIngIdx >= 0) {
        final rawEnd = (rawIngIdx + 200).clamp(0, body.length);
        rawSample = body.substring(rawIngIdx, rawEnd).replaceAll(RegExp(r'\s+'), ' ').trim();
        if (rawSample.length > 80) rawSample = '${rawSample.substring(0, 80)}...';
      }
      
      String diagnostics = 'title:"$titlePreview", JSON-LD:$jsonLdCount, microdata:${hasMicrodata ? "yes" : "no"}, #ingredients:${hasIngredientById ? "yes" : "no"}, h2:$hasH2, h3:$hasH3, lists:${hasAnyLists ? "yes" : "no"}';
      diagnostics += ', rawH2:${rawHasH2 ? "yes" : "no"}, rawSchema:${rawHasSchema ? "yes" : "no"}';
      diagnostics += ', bullets:${hasBullets ? "yes" : "no"}, measurements:${hasMeasurements ? "yes" : "no"}';
      diagnostics += ', rawBullets:${rawHasBullets ? "yes" : "no"}, rawMeas:${rawHasMeasurements ? "yes" : "no"}';
      diagnostics += ', body=$bodyLength chars';
      if (rawSample.isNotEmpty) diagnostics += '. Raw: "$rawSample"';
      
      throw Exception(
        'Could not find recipe data on this page. '
        '$diagnostics. '
        'The page may use JavaScript to load content dynamically or use an unsupported format.'
      );
    } catch (e) {
      throw Exception('Failed to import recipe from URL: $e');
    }
  }
  
  /// Decode HTTP response body handling encoding errors and compression gracefully
  String _decodeResponseBody(http.Response response) {
    List<int> bytes = response.bodyBytes.toList();
    
    // Check if response is gzip compressed (either by header or by magic bytes)
    final contentEncoding = response.headers['content-encoding']?.toLowerCase() ?? '';
    final isGzipHeader = contentEncoding.contains('gzip');
    // Gzip magic bytes: 0x1f 0x8b
    final isGzipMagic = bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;
    
    if (isGzipHeader || isGzipMagic) {
      try {
        bytes = gzip.decode(bytes);
      } catch (_) {
        // If decompression fails, try with original bytes
      }
    }
    
    // Check for brotli (we can't decode it, but detect it for better error messages)
    final isBrotli = contentEncoding.contains('br');
    if (isBrotli && bytes.length >= 2 && !(bytes[0] == 0x3c || bytes[0] == 0x0a || bytes[0] == 0x20)) {
      // Brotli compressed - try to request without compression
      // For now, just try to decode what we have
    }
    
    try {
      // Try UTF-8 decoding
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      try {
        // Try automatic decoding (handles Content-Type charset)
        return response.body;
      } catch (_) {
        // Last resort: use Latin-1 (never fails, but may produce wrong characters)
        return latin1.decode(bytes);
      }
    }
  }
  
  /// Try to enhance JSON-LD result with richer data from embedded JavaScript
  /// Many modern sites (Vite SSR, Next.js, Nuxt) have embedded JSON with section groupings,
  /// better serves data, and other details not in their JSON-LD
  RecipeImportResult? _tryEnhanceWithEmbeddedData(String body, RecipeImportResult jsonLdResult) {
    try {
      // Patterns for embedded JSON data in various frameworks
      final patterns = <String, RegExp>{
        'vite': RegExp(r'<script[^>]*id="vite-plugin-ssr_pageContext"[^>]*>(.*?)</script>', dotAll: true),
        'next': RegExp(r'<script[^>]*id="__NEXT_DATA__"[^>]*>(.*?)</script>', dotAll: true),
        'nuxt': RegExp(r'window\.__NUXT__\s*=\s*(\{.*?\});?\s*</script>', dotAll: true),
      };
      
      Map<String, dynamic>? recipeData;
      
      for (final entry in patterns.entries) {
        final match = entry.value.firstMatch(body);
        if (match == null) continue;
        
        final jsonStr = match.group(1);
        if (jsonStr == null || jsonStr.isEmpty) continue;
        
        try {
          final data = jsonDecode(jsonStr);
          if (data is! Map<String, dynamic>) continue;
          
          // Find recipe data within the embedded JSON (different paths for different frameworks)
          recipeData = _findRecipeDataInEmbedded(data);
          if (recipeData != null) break;
        } catch (_) {
          continue;
        }
      }
      
      if (recipeData == null) return null;
      
      // Extract enhanced serves (yieldTextOverride is common in Vite/Next sites)
      String? serves = jsonLdResult.serves;
      final yieldOverride = recipeData['yieldTextOverride'] ?? recipeData['servings'] ?? recipeData['yield'];
      if (yieldOverride is String && yieldOverride.isNotEmpty) {
        serves = yieldOverride;
      } else if (yieldOverride is int) {
        serves = yieldOverride.toString();
      }
      
      // Extract ingredients using existing function (handles all formats including groupName sections)
      final ingredientsData = recipeData['ingredients'] ?? recipeData['recipeIngredient'];
      if (ingredientsData == null) {
        // No ingredients in embedded data - just return with updated serves if changed
        if (serves != jsonLdResult.serves) {
          return _copyResultWithUpdates(jsonLdResult, serves: serves, servesConfidence: 0.9);
        }
        return null;
      }
      
      // Use existing _extractRawIngredients which handles all formats including:
      // - GBC format: {groupName, unstructuredTextMetric}
      // - WordPress ACF: {ingredient, quantity, measurement}
      // - Sections: {title, items}
      // - Standard: strings or {text/name}
      var rawIngredientStrings = _extractRawIngredients(ingredientsData);
      // Filter out garbage (UI elements, ads, social media prompts) and deduplicate
      rawIngredientStrings = _filterIngredientStrings(rawIngredientStrings);
      if (rawIngredientStrings.isEmpty) {
        if (serves != jsonLdResult.serves) {
          return _copyResultWithUpdates(jsonLdResult, serves: serves, servesConfidence: 0.9);
        }
        return null;
      }
      
      // Check if embedded data has sections that JSON-LD is missing
      final hasSections = rawIngredientStrings.any((s) => s.startsWith('[') && s.endsWith(']'));
      final jsonLdHasSections = jsonLdResult.rawIngredients.any((r) => r.sectionName != null);
      
      // Only use embedded ingredients if they have sections that JSON-LD is missing
      // This avoids replacing good JSON-LD data with potentially worse embedded data
      if (!hasSections && jsonLdResult.ingredients.isNotEmpty) {
        if (serves != jsonLdResult.serves) {
          return _copyResultWithUpdates(jsonLdResult, serves: serves, servesConfidence: 0.9);
        }
        return null;
      }
      
      // Parse ingredients using existing function (handles [Section] headers)
      var ingredients = _parseIngredients(rawIngredientStrings);
      ingredients = _sortIngredientsByQuantity(ingredients);
      
      if (ingredients.isEmpty) {
        if (serves != jsonLdResult.serves) {
          return _copyResultWithUpdates(jsonLdResult, serves: serves, servesConfidence: 0.9);
        }
        return null;
      }
      
      // Build raw ingredients list
      final rawIngredients = _buildRawIngredients(rawIngredientStrings);
      
      return RecipeImportResult(
        name: jsonLdResult.name,
        course: jsonLdResult.course,
        cuisine: jsonLdResult.cuisine,
        subcategory: jsonLdResult.subcategory,
        serves: serves,
        time: jsonLdResult.time,
        ingredients: _filterParsedIngredients(ingredients),
        directions: jsonLdResult.directions,
        comments: jsonLdResult.comments,
        imageUrl: jsonLdResult.imageUrl,
        nutrition: jsonLdResult.nutrition,
        equipment: jsonLdResult.equipment,
        rawIngredients: rawIngredients,
        rawDirections: jsonLdResult.rawDirections,
        detectedCourses: jsonLdResult.detectedCourses,
        detectedCuisines: jsonLdResult.detectedCuisines,
        nameConfidence: jsonLdResult.nameConfidence,
        courseConfidence: jsonLdResult.courseConfidence,
        cuisineConfidence: jsonLdResult.cuisineConfidence,
        ingredientsConfidence: hasSections ? 0.95 : 0.85, // Higher confidence with sections
        directionsConfidence: jsonLdResult.directionsConfidence,
        servesConfidence: serves != null ? 0.9 : 0.0,
        timeConfidence: jsonLdResult.timeConfidence,
        sourceUrl: jsonLdResult.sourceUrl,
        source: jsonLdResult.source,
        imagePaths: jsonLdResult.imagePaths,
      );
    } catch (_) {
      return null;
    }
  }
  
  /// Find recipe data within embedded JSON structures (Vite, Next.js, Nuxt)
  /// Returns the innermost object that looks like recipe data
  Map<String, dynamic>? _findRecipeDataInEmbedded(Map<String, dynamic> data, [int depth = 0]) {
    if (depth > _maxRecursionDepth) return null;
    
    // Common paths for recipe data in different frameworks
    final commonPaths = [
      ['pageContext', 'pageProps', 'config'],  // Vite SSR (Great British Chefs)
      ['pageContext', 'pageProps'],             // Vite SSR alternate
      ['props', 'pageProps'],                   // Next.js
      ['props', 'pageProps', 'recipe'],         // Next.js with recipe key
      ['data'],                                 // Nuxt
      ['state', 'recipe'],                      // Generic state
    ];
    
    // Try common paths first
    for (final path in commonPaths) {
      dynamic current = data;
      for (final key in path) {
        if (current is Map<String, dynamic> && current.containsKey(key)) {
          current = current[key];
        } else {
          current = null;
          break;
        }
      }
      if (current is Map<String, dynamic> && _hasRecipeIngredients(current)) {
        return current;
      }
    }
    
    // Fallback: recursively search for recipe-like data
    for (final value in data.values) {
      if (value is Map<String, dynamic>) {
        if (_hasRecipeIngredients(value)) {
          return value;
        }
        final nested = _findRecipeDataInEmbedded(value, depth + 1);
        if (nested != null) return nested;
      } else if (value is List) {
        for (final item in value) {
          if (item is Map<String, dynamic>) {
            if (_hasRecipeIngredients(item)) {
              return item;
            }
            final nested = _findRecipeDataInEmbedded(item, depth + 1);
            if (nested != null) return nested;
          }
        }
      }
    }
    
    return null;
  }
  
  /// Check if a map has recipe ingredients (with potential section data)
  bool _hasRecipeIngredients(Map<String, dynamic> data) {
    final ingredients = data['ingredients'] ?? data['recipeIngredient'];
    if (ingredients is! List || ingredients.isEmpty) return false;
    
    // Check if ingredients have section/group data (which makes this worth extracting)
    for (final item in ingredients) {
      if (item is Map) {
        // Look for section indicators
        if (item.containsKey('groupName') ||
            item.containsKey('section') ||
            item.containsKey('unstructuredTextMetric')) {
          return true;
        }
      }
    }
    
    // Also check for yieldTextOverride (indicates rich data)
    if (data.containsKey('yieldTextOverride')) return true;
    
    return false;
  }
  
  /// Create a copy of RecipeImportResult with specific updates
  RecipeImportResult _copyResultWithUpdates(
    RecipeImportResult original, {
    String? serves,
    double? servesConfidence,
  }) {
    return RecipeImportResult(
      name: original.name,
      course: original.course,
      cuisine: original.cuisine,
      subcategory: original.subcategory,
      serves: serves ?? original.serves,
      time: original.time,
      ingredients: original.ingredients,
      directions: original.directions,
      comments: original.comments,
      imageUrl: original.imageUrl,
      nutrition: original.nutrition,
      equipment: original.equipment,
      rawIngredients: original.rawIngredients,
      rawDirections: original.rawDirections,
      detectedCourses: original.detectedCourses,
      detectedCuisines: original.detectedCuisines,
      nameConfidence: original.nameConfidence,
      courseConfidence: original.courseConfidence,
      cuisineConfidence: original.cuisineConfidence,
      ingredientsConfidence: original.ingredientsConfidence,
      directionsConfidence: original.directionsConfidence,
      servesConfidence: servesConfidence ?? original.servesConfidence,
      timeConfidence: original.timeConfidence,
      sourceUrl: original.sourceUrl,
      source: original.source,
      imagePaths: original.imagePaths,
    );
  }
  
  /// Try to extract recipe data from embedded JavaScript (React/Next.js/Vue hydration state)
  /// Many modern sites embed recipe data in script tags for client-side rendering
  RecipeImportResult? _tryExtractFromEmbeddedJson(String body, String sourceUrl) {
    // Common patterns for embedded JSON data in JavaScript-heavy sites
    final patterns = [
      // Next.js __NEXT_DATA__
      RegExp(r'<script[^>]*id="__NEXT_DATA__"[^>]*>(.*?)</script>', dotAll: true),
      // Nuxt.js __NUXT__
      RegExp(r'window\.__NUXT__\s*=\s*(\{.*?\});?\s*</script>', dotAll: true),
      // Generic window.__INITIAL_STATE__ or similar
      RegExp(r'window\.__INITIAL_STATE__\s*=\s*(\{.*?\});?\s*</script>', dotAll: true),
      // WordPress REST API embedded data
      RegExp(r'<script[^>]*type="application/json"[^>]*>(.*?)</script>', dotAll: true),
      // Generic JSON object containing recipe-like data
      RegExp(r'"recipeIngredient"\s*:\s*\[(.*?)\]', dotAll: true),
      RegExp(r'"ingredients"\s*:\s*\[(.*?)\]', dotAll: true),
    ];
    
    for (final pattern in patterns) {
      final matches = pattern.allMatches(body);
      for (final match in matches) {
        try {
          String jsonStr = match.group(1) ?? '';
          if (jsonStr.isEmpty) continue;
          
          // For the ingredient array patterns, wrap them back into valid JSON
          if (pattern.pattern.contains('recipeIngredient') || pattern.pattern.contains('"ingredients"')) {
            // Try to find the full recipe object around this
            final ingredientIdx = body.indexOf(match.group(0)!);
            if (ingredientIdx >= 0) {
              // Search backward for opening brace of recipe object
              int braceCount = 0;
              int startIdx = ingredientIdx;
              for (int i = ingredientIdx; i >= 0 && i > ingredientIdx - _jsonSearchBackward; i--) {
                if (body[i] == '}') braceCount++;
                if (body[i] == '{') {
                  braceCount--;
                  if (braceCount < 0) {
                    startIdx = i;
                    break;
                  }
                }
              }
              // Search forward for closing brace
              braceCount = 0;
              int endIdx = ingredientIdx + match.group(0)!.length;
              for (int i = startIdx; i < body.length && i < startIdx + _jsonSearchForward; i++) {
                if (body[i] == '{') braceCount++;
                if (body[i] == '}') {
                  braceCount--;
                  if (braceCount == 0) {
                    endIdx = i + 1;
                    break;
                  }
                }
              }
              jsonStr = body.substring(startIdx, endIdx);
            }
          }
          
          // Try to parse as JSON
          final data = jsonDecode(jsonStr);
          
          // Look for recipe data within the parsed JSON
          final result = _findRecipeInNestedJson(data, sourceUrl);
          if (result != null) return result;
        } catch (_) {
          continue;
        }
      }
    }
    
    return null;
  }
  
  /// Recursively search for recipe data in nested JSON structures
  RecipeImportResult? _findRecipeInNestedJson(dynamic data, String sourceUrl, [int depth = 0]) {
    if (depth > _maxRecursionDepth) return null; // Prevent infinite recursion
    
    if (data is Map<String, dynamic>) {
      // Check for @type: Recipe (standard JSON-LD)
      if (data['@type'] == 'Recipe' || data['type'] == 'Recipe') {
        final result = _parseJsonLdWithConfidence(data, sourceUrl);
        if (result != null) return result;
      }
      
      // Check if this looks like a recipe object but without @type (Next.js, WordPress ACF, etc.)
      if (_looksLikeRecipe(data)) {
        // First try JSON-LD parser (handles standard format)
        final result = _parseJsonLdWithConfidence(data, sourceUrl);
        if (result != null) return result;
        
        // If JSON-LD parser returned null (no @type), try parsing as non-standard format
        final nonStandardResult = _parseNonStandardRecipeJson(data, sourceUrl);
        if (nonStandardResult != null) return nonStandardResult;
      }
      
      // Recurse into nested objects
      for (final value in data.values) {
        final result = _findRecipeInNestedJson(value, sourceUrl, depth + 1);
        if (result != null) return result;
      }
    } else if (data is List) {
      for (final item in data) {
        final result = _findRecipeInNestedJson(item, sourceUrl, depth + 1);
        if (result != null) return result;
      }
    }
    
    return null;
  }
  
  /// Parse non-standard recipe JSON (Next.js __NEXT_DATA__, WordPress ACF, etc.)
  /// These have recipe data but no @type: Recipe
  RecipeImportResult? _parseNonStandardRecipeJson(Map<String, dynamic> data, String sourceUrl) {
    // Must have name
    final name = _cleanRecipeName(
      _parseString(data['name']) ?? 
      _parseString(data['title']) ?? 
      _parseString(data['recipeName']) ?? ''
    );
    if (name.isEmpty) return null;
    
    // Extract ingredients - support various formats
    var rawIngredientStrings = <String>[];
    final ingredientsData = data['ingredients'] ?? data['recipeIngredient'];
    if (ingredientsData != null) {
      rawIngredientStrings = _extractRawIngredients(ingredientsData);
      // Filter out garbage (UI elements, ads, social media prompts) and deduplicate
      rawIngredientStrings = _filterIngredientStrings(rawIngredientStrings);
    }
    
    // Extract directions - support various formats  
    var directions = <String>[];
    var rawDirections = <String>[];
    final instructionsData = data['instructions'] ?? data['recipeInstructions'] ?? data['directions'] ?? data['steps'];
    if (instructionsData != null) {
      directions = _parseInstructions(instructionsData);
      rawDirections = _extractRawDirections(instructionsData);
      // Filter out junk direction lines (ads, subscribe prompts, social media, etc.)
      directions = directions.where((d) => !_isJunkDirectionLine(d)).toList();
      rawDirections = rawDirections.where((d) => !_isJunkDirectionLine(d)).toList();
    }
    
    // Must have at least ingredients OR directions to be a valid recipe
    if (rawIngredientStrings.isEmpty && directions.isEmpty) return null;
    
    // Parse ingredients
    var ingredients = _parseIngredients(rawIngredientStrings);
    ingredients = _sortIngredientsByQuantity(ingredients);
    
    // Build raw ingredients list
    final rawIngredients = _buildRawIngredients(rawIngredientStrings);
    
    // Extract other fields
    final serves = _parseString(data['serves']) ?? 
                   _parseString(data['yield']) ?? 
                   _parseString(data['recipeYield']) ??
                   _parseString(data['yieldTextOverride']); // Great British Chefs
    final time = _parseString(data['time']) ?? 
                 _parseString(data['cookTimeCustom']) ??
                 _parseString(data['cookTime']);
    final description = _parseString(data['description']);
    final imageUrl = _parseImage(data['image']);
    
    // Detect course
    final course = _guessCourse(data, sourceUrl: sourceUrl);
    
    // Detect cuisine
    final cuisine = _parseCuisine(data['cuisine'] ?? data['recipeCuisine']);
    
    return RecipeImportResult(
      name: name,
      course: course,
      cuisine: cuisine,
      serves: serves,
      time: time,
      ingredients: _filterParsedIngredients(ingredients),
      directions: directions,
      comments: description,
      imageUrl: imageUrl,
      rawIngredients: rawIngredients,
      rawDirections: rawDirections,
      detectedCourses: _detectAllCourses(data),
      detectedCuisines: _detectAllCuisines(data),
      nameConfidence: 0.9,
      courseConfidence: 0.6,
      cuisineConfidence: cuisine != null ? 0.7 : 0.3,
      ingredientsConfidence: rawIngredientStrings.isNotEmpty ? 0.8 : 0.0,
      directionsConfidence: directions.isNotEmpty ? 0.8 : 0.0,
      servesConfidence: serves != null ? 0.7 : 0.0,
      timeConfidence: time != null ? 0.7 : 0.0,
      sourceUrl: sourceUrl,
      source: RecipeSource.url,
    );
  }
  
  /// Check if a map looks like it might be recipe data
  bool _looksLikeRecipe(Map<String, dynamic> data) {
    // Must have some kind of name/title
    final hasName = data.containsKey('name') || data.containsKey('title') || data.containsKey('recipeName');
    if (!hasName) return false;
    
    // Must have ingredients
    final hasIngredients = data.containsKey('recipeIngredient') || 
        data.containsKey('ingredients') || 
        data.containsKey('extendedIngredients');
    
    // Or must have instructions/directions
    final hasInstructions = data.containsKey('recipeInstructions') || 
        data.containsKey('instructions') || 
        data.containsKey('directions') ||
        data.containsKey('steps');
    
    return hasIngredients || hasInstructions;
  }
  
  /// Extract YouTube video ID from various URL formats
  String? _extractYouTubeVideoId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    
    final host = uri.host.toLowerCase();
    
    // youtube.com/watch?v=VIDEO_ID
    if (host.contains('youtube.com')) {
      return uri.queryParameters['v'];
    }
    
    // youtu.be/VIDEO_ID
    if (host == 'youtu.be') {
      final path = uri.pathSegments;
      return path.isNotEmpty ? path.first : null;
    }
    
    // youtube.com/embed/VIDEO_ID
    if (host.contains('youtube.com') && uri.path.startsWith('/embed/')) {
      final segments = uri.pathSegments;
      if (segments.length >= 2) {
        return segments[1];
      }
    }
    
    return null;
  }
  
  /// Generate print-friendly URL for sites that support it
  /// 
  /// Print versions are often:
  /// - Cleaner (less JavaScript, ads, tracking)
  /// - Less likely to trigger bot detection
  /// - Contain all recipe content in static HTML
  /// 
  /// Returns null if the URL already has a print parameter or site doesn't support it
  String? _getPrintUrl(String url, Uri uri) {
    // Skip if already a print URL
    if (uri.queryParameters.containsKey('print') ||
        uri.queryParameters.containsKey('printable') ||
        uri.path.contains('/print')) {
      return null;
    }
    
    final host = uri.host.toLowerCase();
    
    // Dotdash Meredith sites (allrecipes, thespruceeats, simplyrecipes, etc.)
    // Use ?print parameter
    if (host.contains('allrecipes.com') ||
        host.contains('thespruceeats.com') ||
        host.contains('thespruce.com') ||
        host.contains('simplyrecipes.com') ||
        host.contains('seriouseats.com') ||
        host.contains('foodandwine.com') ||
        host.contains('bhg.com') ||
        host.contains('marthastewart.com') ||
        host.contains('eatingwell.com')) {
      // Add ?print or &print depending on existing query
      if (uri.query.isEmpty) {
        return '$url?print';
      } else {
        return '$url&print';
      }
    }
    
    // Food Network uses /print suffix
    if (host.contains('foodnetwork.com')) {
      // Remove trailing slash if present, then add /print
      final cleanUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
      return '$cleanUrl/print';
    }
    
    // BBC Good Food uses /print suffix
    if (host.contains('bbcgoodfood.com')) {
      final cleanUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
      return '$cleanUrl/print';
    }
    
    // Epicurious uses ?printable=true
    if (host.contains('epicurious.com')) {
      if (uri.query.isEmpty) {
        return '$url?printable=true';
      } else {
        return '$url&printable=true';
      }
    }
    
    // Bon Appetit (also Conde Nast) uses /print
    if (host.contains('bonappetit.com')) {
      final cleanUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
      return '$cleanUrl/print';
    }
    
    // Taste of Home uses ?print=1
    if (host.contains('tasteofhome.com')) {
      if (uri.query.isEmpty) {
        return '$url?print=1';
      } else {
        return '$url&print=1';
      }
    }
    
    // Delish uses /print suffix
    if (host.contains('delish.com')) {
      final cleanUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
      return '$cleanUrl/print';
    }
    
    return null;
  }
  
  /// ========================================================================
  /// YOUTUBE IMPORT - VIDEO RECIPE EXTRACTION
  /// ========================================================================
  /// 
  /// WHY YOUTUBE SUPPORT: Many professional chefs post recipes on YouTube.
  /// Video descriptions often contain full ingredient lists and directions.
  /// 
  /// EXTRACTION STRATEGY:
  /// 1. Fetch video page HTML (not API - no auth required)
  /// 2. Extract title from JSON embedded in page ("title" field)
  /// 3. Parse description for ingredients/directions (section headers like "INGREDIENTS:")
  /// 4. Extract chapter timestamps as potential direction steps
  /// 5. Attempt to fetch closed captions/transcripts for additional context
  /// 
  /// CONFIDENCE SCORING:
  /// - Higher confidence if description has clear "INGREDIENTS:" section
  /// - Lower confidence if we only have transcript (needs user review)
  /// - Medium confidence for chapter-based directions
  /// 
  /// LIMITATIONS:
  /// - Requires video to have text description (some don't)
  /// - Transcript parsing is heuristic (audio-to-text artifacts)
  /// - No image extraction (would require API access)
  /// ========================================================================
  Future<RecipeImportResult> _importFromYouTube(String videoId, String sourceUrl) async {
    try {
      // Fetch the video page to get description and metadata
      final videoPageUrl = 'https://www.youtube.com/watch?v=$videoId';
      final response = await http.get(
        Uri.parse(videoPageUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch YouTube video: ${response.statusCode}');
      }
      
      // Decode response body - handle encoding errors gracefully
      String body;
      try {
        // Try automatic decoding (handles Content-Type charset)
        body = response.body;
      } on FormatException {
        // If automatic decoding fails due to encoding, try UTF-8 with error tolerance
        try {
          body = utf8.decode(response.bodyBytes, allowMalformed: true);
        } catch (_) {
          // Last resort: use Latin-1 (never fails, but may produce wrong characters)
          body = latin1.decode(response.bodyBytes);
        }
      }
      
      // Extract video title from page
      String? title;
      final titleMatch = RegExp(r'"title":\s*"([^"]+)"').firstMatch(body);
      if (titleMatch != null) {
        title = _decodeUnicodeEscapes(titleMatch.group(1) ?? '');
      }
      
      // Try to get title from og:title as fallback
      if (title == null || title.isEmpty) {
        final ogTitleMatch = RegExp(r'<meta\s+property="og:title"\s+content="([^"]+)"').firstMatch(body);
        title = ogTitleMatch?.group(1);
      }
      
      // Extract channel name
      String? channelName;
      final channelMatch = RegExp(r'"ownerChannelName":\s*"([^"]+)"').firstMatch(body);
      if (channelMatch != null) {
        channelName = _decodeUnicodeEscapes(channelMatch.group(1) ?? '');
      }
      
      // Extract video description
      String? description;
      // Try to find description in the initial player response JSON
      final descMatch = RegExp(r'"shortDescription":\s*"((?:[^"\\]|\\.)*)"').firstMatch(body);
      if (descMatch != null) {
        description = _decodeUnicodeEscapes(descMatch.group(1) ?? '');
      }
      
      // Extract thumbnail
      String? thumbnail;
      final thumbMatch = RegExp(r'"thumbnails":\s*\[\s*\{\s*"url":\s*"([^"]+)"').firstMatch(body);
      if (thumbMatch != null) {
        thumbnail = thumbMatch.group(1);
      }
      // Fallback to standard thumbnail URL
      thumbnail ??= 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';
      
      // Extract chapters from description (timestamp lines)
      final chapters = _extractYouTubeChapters(description ?? '');
      
      // Try to fetch and parse transcript/captions with timestamps
      List<TranscriptSegment> transcriptSegments = [];
      try {
        final (segments, _) = await _fetchYouTubeTranscriptWithTimestamps(videoId, body);
        transcriptSegments = segments;
      } catch (e) {
        // Transcript fetch failed, will fall back to description parsing
      }
      
      // Parse the description for ingredients
      final parsedDescription = _parseYouTubeDescription(description ?? '');
      
      // Build directions from chapters + transcript
      List<String> directions = [];
      
      if (chapters.isNotEmpty && transcriptSegments.isNotEmpty) {
        // Use chapters to slice transcript into steps
        directions = _buildDirectionsFromChapters(chapters, transcriptSegments);
      } else if (chapters.isNotEmpty) {
        // Just use chapter titles if no transcript
        directions = chapters.map((c) => c.title).toList();
      } else {
        // Fall back to description parsing
        directions = parsedDescription['directions'] ?? [];
      }
      
      // Build ingredients list
      var rawIngredientStrings = (parsedDescription['ingredients'] as List<String>?) ?? [];
      // Filter out garbage (UI elements, ads, social media prompts) and deduplicate
      rawIngredientStrings = _filterIngredientStrings(rawIngredientStrings);
      final ingredients = rawIngredientStrings
          .map((s) => _parseIngredientString(s))
          .where((i) => i.name.isNotEmpty)
          .toList();
      
      // Clean recipe name - remove common YouTube suffixes
      final String recipeName = _cleanYouTubeTitle(title ?? 'YouTube Recipe');
      
      // Detect course from title
      final detectedCourse = _detectCourseFromTitle(recipeName);
      
      // Build time string from parsed times - extract numeric values and sum
      String? recipeTime;
      final prepTime = parsedDescription['prepTime'] as String?;
      final cookTime = parsedDescription['cookTime'] as String?;
      final totalTime = parsedDescription['totalTime'] as String?;
      
      if (totalTime != null) {
        recipeTime = _normalizeTimeString(totalTime);
      } else if (prepTime != null || cookTime != null) {
        final prepMinutes = _extractMinutes(prepTime);
        final cookMinutes = _extractMinutes(cookTime);
        final totalMinutes = prepMinutes + cookMinutes;
        if (totalMinutes > 0) {
          if (totalMinutes >= 60) {
            final hours = totalMinutes ~/ 60;
            final mins = totalMinutes % 60;
            recipeTime = mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
          } else {
            recipeTime = '$totalMinutes min';
          }
        }
      }
      
      // Build notes with channel attribution
      String notes = 'Source: YouTube video by ${channelName ?? "Unknown"}';
      if (parsedDescription['notes'] != null) {
        notes += '\n\n${parsedDescription["notes"]}';
      }
      
      // Determine if we have enough data
      final hasIngredients = ingredients.isNotEmpty;
      final hasDirections = directions.isNotEmpty;
      
      // Create raw ingredient data for review
      final rawIngredients = _buildRawIngredients(rawIngredientStrings);
      
      // Calculate confidence based on what was successfully parsed
      // Higher confidence when we found structured data
      final nameConf = title != null && title.isNotEmpty ? 0.85 : 0.3;
      final courseConf = detectedCourse != null ? 0.8 : 0.5;
      final ingredientsConf = hasIngredients 
          ? (ingredients.length >= 3 ? 0.85 : 0.7) // More ingredients = more confidence
          : 0.0;
      final directionsConf = hasDirections 
          ? (transcriptSegments.isNotEmpty ? 0.85 : 0.7) 
          : 0.0;
      final timeConf = recipeTime != null ? 0.9 : 0.0;
      
      return RecipeImportResult(
        name: recipeName,
        course: detectedCourse ?? 'Mains',
        time: recipeTime,
        ingredients: _filterParsedIngredients(ingredients),
        directions: directions,
        comments: notes,
        imageUrl: thumbnail,
        rawIngredients: rawIngredients,
        rawDirections: directions,
        detectedCourses: [detectedCourse ?? 'Mains'],
        nameConfidence: nameConf,
        courseConfidence: courseConf,
        ingredientsConfidence: ingredientsConf,
        directionsConfidence: directionsConf,
        timeConfidence: timeConf,
        sourceUrl: sourceUrl,
        source: RecipeSource.url,
      );
    } catch (e) {
      throw Exception('Failed to import YouTube video: $e');
    }
  }
  
  /// Decode unicode escape sequences like \u0026 in YouTube JSON
  String _decodeUnicodeEscapes(String text) {
    return text.replaceAllMapped(
      RegExp(r'\\u([0-9a-fA-F]{4})'),
      (match) {
        final code = int.tryParse(match.group(1)!, radix: 16);
        return code != null ? String.fromCharCode(code) : match.group(0)!;
      },
    ).replaceAll(r'\n', '\n').replaceAll(r'\"', '"').replaceAll(r'\\', '\\');
  }
  
  /// Clean YouTube video title to extract recipe name
  String _cleanYouTubeTitle(String title) {
    var cleaned = title;
    
    // Remove common patterns
    final patterns = [
      RegExp(r'\s*[|\-–—]\s*YouTube\s*$', caseSensitive: false),
      RegExp(r'\s*\|\s*[^|]+$'), // Remove "| Channel Name" suffix
      RegExp(r'\s*[-–—]\s*(?:Full\s+)?Recipe\s*$', caseSensitive: false),
      RegExp(r'^\s*(?:How\s+to\s+(?:Make|Cook|Prepare)\s+)', caseSensitive: false),
      RegExp(r'\s*\((?:Easy|Simple|Quick|Best|Homemade|The\s+Best)(?:\s+Recipe)?\)\s*', caseSensitive: false),
      RegExp(r'\s*(?:Recipe|Tutorial|Video)\s*$', caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      cleaned = cleaned.replaceAll(pattern, '');
    }
    
    return cleaned.trim();
  }
  
  /// Detect recipe course from text using the consolidated _courseKeywords map
  /// Returns the course name if any keywords match, null otherwise
  /// Priority order is defined by the order of entries in _courseKeywords
  String? _detectCourseFromText(String text) {
    final lowerText = text.toLowerCase();
    
    // Check each course's keywords in priority order
    for (final entry in _courseKeywords.entries) {
      final course = entry.key;
      final keywords = entry.value;
      
      for (final keyword in keywords) {
        // Build regex with word boundaries, handling multi-word keywords
        final pattern = RegExp(
          r'\b' + keyword.replaceAll(' ', r'\s+') + r's?\b',
          caseSensitive: false,
        );
        if (pattern.hasMatch(lowerText)) {
          return course;
        }
      }
    }
    
    return null; // Let caller default to Mains
  }
  
  /// Detect recipe course from title keywords
  /// Uses the consolidated _courseKeywords map
  String? _detectCourseFromTitle(String title) {
    return _detectCourseFromText(title);
  }
  
  /// Unified course detection with confidence scoring
  /// Combines text-based matching with ingredient/content analysis for specialized courses
  /// 
  /// Why a unified approach: 
  /// - Simple courses (Soup, Sides, Sauces, Apps) only need title/URL keyword matching
  /// - Complex courses (Drinks, Smoking, Modernist, Breads) need ingredient/content analysis
  /// - This function handles both patterns and provides consistent confidence scoring
  /// 
  /// Returns: (course: String, confidence: double)
  ({String course, double confidence}) _detectCourseWithConfidence({
    required String titleLower,
    required String urlLower,
    required List<String> ingredientStrings,
    required bool isCocktailSite,
    bool isBBQSite = false,
    dynamic document, // Optional for modernist detection
  }) {
    // Priority 1: Known cocktail site (highest confidence)
    if (isCocktailSite) {
      return (course: 'Drinks', confidence: 0.95);
    }
    
    // Priority 1b: Known BBQ/smoking site (highest confidence)
    if (isBBQSite) {
      return (course: 'Smoking', confidence: 0.95);
    }
    
    // Priority 2: Drinks detection (ingredient-aware) - check before generic text matching
    // because spirit names in titles are strong indicators
    if (_matchesCourseKeywords('Drinks', titleLower) || 
        _matchesCourseKeywords('Drinks', urlLower) ||
        _hasSpiritsInIngredients(ingredientStrings)) {
      return (course: 'Drinks', confidence: 0.75);
    }
    
    // Priority 3: Smoking (ingredient-aware for wood types)
    if (_matchesCourseKeywords('Smoking', titleLower) ||
        _matchesCourseKeywords('Smoking', urlLower) ||
        _hasSmokingIndicators(ingredientStrings)) {
      return (course: 'Smoking', confidence: 0.8);
    }
    
    // Priority 3.5: Pickles/Fermentation (check BEFORE modernist - calcium chloride is used in both)
    if (_matchesCourseKeywords('Pickles', titleLower) ||
        _matchesCourseKeywords('Pickles', urlLower) ||
        _hasPickleIndicators(titleLower, urlLower)) {
      return (course: 'Pickles', confidence: 0.8);
    }
    
    // Priority 4: Modernist (needs document + ingredients for technique detection)
    // Skip if already detected as Pickles context
    if (document != null && _isModernistRecipe(document, urlLower, ingredientStrings)) {
      return (course: 'Modernist', confidence: 0.75);
    }
    
    // Priority 5: Breads (ingredient-aware for flour+yeast)
    if (_matchesCourseKeywords('Breads', titleLower) ||
        _matchesCourseKeywords('Breads', urlLower) ||
        _hasBreadIndicators(ingredientStrings)) {
      return (course: 'Breads', confidence: 0.75);
    }
    
    // Priority 6: Simple text-based courses in order of confidence
    final combinedText = '$titleLower $urlLower';
    
    if (_matchesCourseKeywords('Desserts', combinedText)) {
      return (course: 'Desserts', confidence: 0.7);
    }
    if (_matchesCourseKeywords('Soup', combinedText)) {
      return (course: 'Soup', confidence: 0.75);
    }
    if (_matchesCourseKeywords('Sauces', combinedText)) {
      return (course: 'Sauces', confidence: 0.7);
    }
    if (_matchesCourseKeywords('Apps', combinedText)) {
      return (course: 'Apps', confidence: 0.65);
    }
    if (_matchesCourseKeywords('Sides', combinedText)) {
      return (course: 'Sides', confidence: 0.6);
    }
    if (_matchesCourseKeywords('Brunch', combinedText)) {
      return (course: 'Brunch', confidence: 0.65);
    }
    if (_matchesCourseKeywords('Pickles', combinedText)) {
      return (course: 'Pickles', confidence: 0.7);
    }
    if (_matchesCourseKeywords('Rubs', combinedText)) {
      return (course: 'Rubs', confidence: 0.7);
    }
    
    // Priority 7: Vegan/Vegetarian detection from URL or title
    // Check if URL contains "vegan" or "vegetarian" - suggests dedicated veg'n recipe
    if (_isVeganRecipe(titleLower, urlLower)) {
      return (course: "Veg'n", confidence: 0.7);
    }
    
    // Default: Mains (medium confidence as it's a reasonable fallback)
    return (course: 'Mains', confidence: 0.5);
  }
  
  /// Check if recipe is vegan/vegetarian based on URL and title
  bool _isVeganRecipe(String titleLower, String urlLower) {
    final veganPattern = RegExp(r'\bvegan\b', caseSensitive: false);
    final vegetarianPattern = RegExp(r'\bvegetarian\b', caseSensitive: false);
    final vegPattern = RegExp(r'\bveg\b', caseSensitive: false);
    final plantBasedPattern = RegExp(r'\bplant[\s-]?based\b', caseSensitive: false);
    
    return veganPattern.hasMatch(urlLower) ||
           veganPattern.hasMatch(titleLower) ||
           vegetarianPattern.hasMatch(urlLower) ||
           vegetarianPattern.hasMatch(titleLower) ||
           vegPattern.hasMatch(urlLower) ||
           plantBasedPattern.hasMatch(titleLower);
  }
  
  /// Check if text matches any keyword for a specific course
  bool _matchesCourseKeywords(String course, String text) {
    final keywords = _courseKeywords[course];
    if (keywords == null) return false;
    
    final lowerText = text.toLowerCase();
    for (final keyword in keywords) {
      final pattern = RegExp(
        r'\b' + keyword.replaceAll(' ', r'\s+') + r's?\b',
        caseSensitive: false,
      );
      if (pattern.hasMatch(lowerText)) return true;
    }
    return false;
  }
  
  /// Check for spirit-related ingredients (helper for Drinks detection)
  bool _hasSpiritsInIngredients(List<String> ingredients) {
    // Use word boundaries to avoid false positives like 'ginger' matching 'gin'
    final spiritPatterns = [
      RegExp(r'\bvodka\b', caseSensitive: false),
      RegExp(r'\bgin\b', caseSensitive: false),
      RegExp(r'\brum\b', caseSensitive: false),
      RegExp(r'\btequila\b', caseSensitive: false),
      RegExp(r'\bwhiske?y\b', caseSensitive: false),
      RegExp(r'\bbourbon\b', caseSensitive: false),
      RegExp(r'\bscotch\b', caseSensitive: false),
      RegExp(r'\bbrandy\b', caseSensitive: false),
      RegExp(r'\bcognac\b', caseSensitive: false),
      RegExp(r'\bmezcal\b', caseSensitive: false),
    ];
    final allText = ingredients.join(' ').toLowerCase();
    return spiritPatterns.any((p) => p.hasMatch(allText));
  }
  
  /// Check for smoking/BBQ indicators in ingredients (wood types)
  bool _hasSmokingIndicators(List<String> ingredients) {
    const woodTypes = ['hickory', 'mesquite', 'applewood', 'apple wood',
                       'cherrywood', 'cherry wood', 'pecan', 'oak',
                       'maple wood', 'alder', 'wood chips', 'wood chunks'];
    final allText = ingredients.join(' ').toLowerCase();
    return woodTypes.any((w) => allText.contains(w));
  }
  
  /// Check for bread-making indicators (flour + yeast OR flour + starter for sourdough)
  bool _hasBreadIndicators(List<String> ingredients) {
    final allText = ingredients.join(' ').toLowerCase();
    // Traditional breads use yeast, sourdough uses starter
    return allText.contains('flour') && 
           (allText.contains('yeast') || allText.contains('starter') || allText.contains('levain'));
  }

  /// Check for pickle/fermentation indicators in title or URL
  bool _hasPickleIndicators(String titleLower, String urlLower) {
    const pickleIndicators = [
      'pickle', 'pickled', 'brine', 'brined', 'brining',
      'ferment', 'fermented', 'lacto', 'kimchi', 'sauerkraut',
      'canning', 'preserve', 'preserved',
    ];
    final combined = '$titleLower $urlLower';
    return pickleIndicators.any((indicator) => combined.contains(indicator));
  }

  /// Parse YouTube video description to extract ingredients and directions
  Map<String, dynamic> _parseYouTubeDescription(String description) {
    final result = <String, dynamic>{
      'ingredients': <String>[],
      'directions': <String>[],
      'notes': null,
      'prepTime': null,
      'cookTime': null,
      'totalTime': null,
    };
    
    if (description.isEmpty) return result;
    
    // Split into lines
    final lines = description.split('\n');
    
    // State machine to track which section we're in
    String? currentSection;
    final ingredients = <String>[];
    final directions = <String>[];
    final notes = <String>[];
    String? prepTime;
    String? cookTime;
    String? totalTime;
    
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;
      
      // Extract time information before other processing
      final timeMatch = RegExp(
        r'^(prep|cook|total|bake|rise|rest|chill)\s*(?:time)?\s*:\s*(.+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (timeMatch != null) {
        final timeType = timeMatch.group(1)!.toLowerCase();
        final timeValue = timeMatch.group(2)!.trim();
        if (timeType == 'prep') {
          prepTime = timeValue;
        } else if (timeType == 'cook' || timeType == 'bake') {
          cookTime = timeValue;
        } else if (timeType == 'total') {
          totalTime = timeValue;
        }
        // Don't add to notes - we'll use the structured time field
        continue;
      }
      
      // Strip common decorative characters for section header detection
      final strippedLine = line.replaceAll(RegExp(r'^[•\-*#▶►▸→]+\s*|\s*[•\-*#◀◄◂←]+$'), '').trim();
      final lowerLine = strippedLine.toLowerCase();
      
      // Check for section headers
      if (_isIngredientSectionHeader(lowerLine)) {
        currentSection = 'ingredients';
        continue;
      } else if (_isDirectionSectionHeader(lowerLine)) {
        currentSection = 'directions';
        continue;
      } else if (_isNotesSectionHeader(lowerLine)) {
        currentSection = 'notes';
        continue;
      } else if (_isIgnorableSection(lowerLine)) {
        currentSection = 'ignore';
        continue;
      } else if (_isTimestampSectionHeader(lowerLine)) {
        // Timestamps/Chapters section typically contains step-by-step directions
        currentSection = 'directions';
        continue;
      }
      
      // Skip links, timestamps, and other non-content lines
      if (_isIgnorableLine(line)) continue;
      
      // Handle yield info separately (add to notes)
      if (_isYieldInfo(line)) {
        notes.add(line);
        continue;
      }
      
      // If we haven't hit a section header yet, try to auto-detect
      if (currentSection == null) {
        if (_looksLikeIngredient(line)) {
          currentSection = 'ingredients';
        } else if (_looksLikeDirection(line)) {
          currentSection = 'directions';
        } else {
          // Could be intro text - add to notes
          notes.add(line);
          continue;
        }
      }
      
      // Smart section assignment - check what the line actually looks like
      final looksLikeIng = _looksLikeIngredient(line);
      final looksLikeDir = _looksLikeDirection(line);
      
      // Add to appropriate section with smart switching
      switch (currentSection) {
        case 'ingredients':
          if (looksLikeIng) {
            ingredients.add(line);
          } else if (looksLikeDir && !looksLikeIng) {
            // Switched to directions without a header
            currentSection = 'directions';
            directions.add(_cleanDirectionLine(line));
          }
          break;
        case 'directions':
          // Check if this line is actually an ingredient (switch back)
          if (looksLikeIng && !_isTimestampedStep(line)) {
            // This looks like an ingredient, not a direction
            currentSection = 'ingredients';
            ingredients.add(line);
          } else if (looksLikeDir) {
            directions.add(_cleanDirectionLine(line));
          } else if (_isTimestampedStep(line)) {
            // Timestamped step - extract the title
            directions.add(_cleanDirectionLine(line));
          } else if (line.length > 30 && !looksLikeIng) {
            // Once in directions section, longer lines are likely directions
            // Skip obvious non-direction lines
            if (!line.contains('...') && !line.startsWith('http') && 
                !RegExp(r'^[A-Z][A-Z\s]+$').hasMatch(line)) {
              directions.add(_cleanDirectionLine(line));
            }
          }
          break;
        case 'notes':
          notes.add(line);
          break;
        case 'ignore':
          // Skip this section
          break;
        case null:
          // No section yet - this shouldn't happen but handle it
          if (looksLikeIng) {
            currentSection = 'ingredients';
            ingredients.add(line);
          } else if (looksLikeDir) {
            currentSection = 'directions';
            directions.add(_cleanDirectionLine(line));
          } else {
            notes.add(line);
          }
          break;
      }
    }
    
    result['ingredients'] = ingredients;
    result['directions'] = directions;
    if (notes.isNotEmpty) {
      result['notes'] = notes.join('\n');
    }
    result['prepTime'] = prepTime;
    result['cookTime'] = cookTime;
    result['totalTime'] = totalTime;
    
    return result;
  }
  
  bool _isIngredientSectionHeader(String line) {
    return RegExp(r'^(ingredients?|what you.?ll need|you.?ll need|shopping list)[:\s]*$', caseSensitive: false).hasMatch(line) ||
           line == 'ingredients' || line == 'ingredient';
  }
  
  bool _isDirectionSectionHeader(String line) {
    return RegExp(r'^(directions?|instructions?|method|steps?|how to (?:make|cook|prepare)|procedure)[:\s]*$', caseSensitive: false).hasMatch(line);
  }
  
  bool _isNotesSectionHeader(String line) {
    return RegExp(r'^(notes?|tips?|variations?)[:\s]*$', caseSensitive: false).hasMatch(line);
  }
  
  bool _isIgnorableSection(String line) {
    return RegExp(r'^(follow me|subscribe|social|links?|connect|my (?:gear|equipment|kitchen|tools|setup|camera)|affiliate|music|credits?|shop|merch|merchandise|sponsors?|business|contact|about me|faq|disclaimer)[:\s]*$', caseSensitive: false).hasMatch(line);
  }
  
  /// Check if line is a timestamps/chapters section header (contains directions)
  bool _isTimestampSectionHeader(String line) {
    return RegExp(r'^(chapters?|timestamps?)[:\s]*$', caseSensitive: false).hasMatch(line);
  }
  
  bool _isIgnorableLine(String line) {
    // Separator lines (dashes, equals, underscores, box drawing chars)
    if (RegExp(r'^[─━═—–\-_=]{3,}\s*$').hasMatch(line)) {
      return true;
    }
    // ALL CAPS lines that look like section headers (e.g., "OTHER VIDEOS YOU'LL ENJOY")
    if (line.length > 10 && line.length < 60) {
      final upperCount = line.replaceAll(RegExp(r'[^A-Z]'), '').length;
      final letterCount = line.replaceAll(RegExp(r'[^A-Za-z]'), '').length;
      if (letterCount > 5 && upperCount / letterCount > 0.8) {
        return true;
      }
    }
    // Lines starting with emoji hearts/symbols followed by ALL CAPS
    if (RegExp(r'^[♥♡★☆●○◆◇▶►▸❤️💕🔥👇👆📺🎥🎬📹🍳🍴🍽️\s]+[A-Z]{2,}').hasMatch(line)) {
      return true;
    }
    // URLs anywhere in the line
    if (line.contains('http://') || line.contains('https://') || line.startsWith('www.') || line.contains('.com/') || line.contains('.co/')) {
      return true;
    }
    // Social media handles
    if (RegExp(r'^[@#]').hasMatch(line)) {
      return true;
    }
    // Amazon affiliate patterns
    if (RegExp(r'amzn\.to|amazon\.com|a]inks|affiliate|commission', caseSensitive: false).hasMatch(line)) {
      return true;
    }
    // Social media and promo boilerplate
    if (RegExp(r'subscribe|follow me|check out my|filmed with|music by|instagram|facebook|twitter|tiktok|patreon|merch|merchandise|shop my|use code|discount|sponsored|#ad\b', caseSensitive: false).hasMatch(line)) {
      return true;
    }
    // Equipment/gear list sections
    if (RegExp(r'^my\s+(?:gear|equipment|kitchen|tools|camera|setup)|i\s+use\s+(?:this|these)|what i\s+(?:film|shoot|use)', caseSensitive: false).hasMatch(line)) {
      return true;
    }
    // Business inquiries / contact info
    if (RegExp(r'business\s*(?:inquir|email)|contact\s*me|for\s*(?:inquir|collaborat)', caseSensitive: false).hasMatch(line)) {
      return true;
    }
    // Section header "chapters" or "timestamps" alone
    if (RegExp(r'^chapters?\s*$|^timestamps?\s*$', caseSensitive: false).hasMatch(line)) {
      return true;
    }
    // NOTE: We do NOT filter "timestamp lines" like "Mixing dough – 00:55" 
    // because we want to extract those as directions
    return false;
  }
  
  bool _looksLikeIngredient(String line) {
    // First, exclude timestamp lines like "Mixing dough – 00:55"
    if (_isTimestampedStep(line)) {
      return false;
    }
    // Exclude numbered direction steps like "1. Stir the flour" or "1) Mix ingredients"
    if (RegExp(r'^\d+[.):]\s+[A-Za-z]').hasMatch(line)) {
      return false;
    }
    // Contains measurement units
    if (RegExp(r'\d+\s*(?:g|kg|oz|lb|cup|tbsp|tsp|ml|l|pound|gram|ounce|teaspoon|tablespoon)s?\b', caseSensitive: false).hasMatch(line)) {
      return true;
    }
    // Starts with a number followed by a unit (not just a bare number which could be a step)
    if (RegExp(r'^[\d½¼¾⅓⅔⅛⅜⅝⅞]+(?:\s*/\s*\d+)?\s*(?:cup|tbsp|tsp|oz|lb|g|kg|ml|l)s?\b', caseSensitive: false).hasMatch(line)) {
      return true;
    }
    // Starts with a fraction like 1/4 or unicode fractions
    if (RegExp(r'^(?:\d+\s+)?(?:\d+/\d+|[½¼¾⅓⅔⅛⅜⅝⅞])\s').hasMatch(line)) {
      return true;
    }
    // Baker's percentage format: "Flour, 100% – 600g" or "Water, 75%"
    if (RegExp(r'\d+%\s*[–-]?\s*\d*', caseSensitive: false).hasMatch(line) && line.length < 80) {
      return true;
    }
    // Format like "Ingredient Name – amount" (with en-dash) but NOT timestamp format
    // Must have a measurement-like value after the dash, not just digits (which could be time)
    if (RegExp(r'^[A-Za-z][^–-]*[–-]\s*\d+\s*(?:g|kg|oz|lb|cup|tbsp|tsp|ml|%)', caseSensitive: false).hasMatch(line) && line.length < 80) {
      return true;
    }
    // Short line with common ingredient words
    if (line.length < 60 && RegExp(r'\b(?:salt|pepper|butter|oil|garlic|onion|flour|sugar|water|milk|cream|egg|chicken|beef|pork|yeast|olive|rosemary|herbs?)\b', caseSensitive: false).hasMatch(line)) {
      return true;
    }
    // "as needed" or "to taste" patterns
    if (RegExp(r'\b(?:as needed|to taste|optional|for topping|for garnish)\b', caseSensitive: false).hasMatch(line) && line.length < 60) {
      return true;
    }
    return false;
  }
  
  bool _looksLikeDirection(String line) {
    // Numbered step
    if (RegExp(r'^(?:step\s*)?\d+[.:\)]\s*', caseSensitive: false).hasMatch(line)) {
      return true;
    }
    // Timestamped step like "Mixing the dough – 00:55" or "Step name - 1:23"
    if (_isTimestampedStep(line)) {
      return true;
    }
    // Starts with cooking action verb (expanded list)
    if (RegExp(r'^(?:preheat|heat|mix|combine|add|stir|whisk|fold|pour|place|put|cook|bake|roast|fry|sauté|boil|simmer|reduce|let|allow|serve|garnish|season|taste|check|remove|transfer|set|cover|wrap|chill|refrigerate|freeze|blend|process|pulse|slice|dice|chop|mince|grate|shred|knead|proof|rise|ferment|dimple|top|cut|use|form|make|prepare|work|bring|turn|roll|shape|flatten|stretch|pull|push|press|spread|brush|drizzle|sprinkle|dust|coat|dip|toss|flip|rotate|rest|cool|warm|melt|dissolve|cream|beat|whip|pipe|layer|assemble|arrange|portion|divide|measure|weigh|sift|strain|drain|rinse|wash|dry|pat|trim|peel|core|seed|pit|zest|juice|squeeze|crack|separate|break|tear|crumble|crush|grind|puree|mash|smash|score|slit)\b', caseSensitive: false).hasMatch(line)) {
      return true;
    }
    // Long sentence that sounds instructional (contains action verbs anywhere)
    if (line.length > 40 && RegExp(r'\b(?:until|minutes?|hours?|degrees?|°|constantly|occasionally|gently|carefully|slowly|thoroughly|completely|well|evenly)\b', caseSensitive: false).hasMatch(line)) {
      return true;
    }
    // Don't use length alone - too many false positives with intro paragraphs
    return false;
  }
  
  /// Check if line is yield/serving info like "(makes one 9x13 bread)"
  bool _isYieldInfo(String line) {
    return RegExp(r'^\(?\s*(?:makes?|yields?|serves?|for)\s+', caseSensitive: false).hasMatch(line);
  }
  
  /// Check if line is a timestamped step like "Mixing dough – 00:55"
  bool _isTimestampedStep(String line) {
    // Format: "Step description – MM:SS" or "Step description - M:SS"
    return RegExp(r'^[A-Za-z].+\s*[–-]\s*\d{1,2}:\d{2}(?::\d{2})?\s*$').hasMatch(line);
  }
  
  /// Extract step title from timestamped line
  String? _extractStepFromTimestamp(String line) {
    final match = RegExp(r'^(.+?)\s*[–-]\s*\d{1,2}:\d{2}(?::\d{2})?\s*$').firstMatch(line);
    if (match != null) {
      return match.group(1)?.trim();
    }
    return null;
  }
  
  /// Extract minutes from a time string like "15 minutes", "1 hour 30 minutes", or ISO 8601 "PT30M"
  /// This is a convenience wrapper around _parseDurationMinutes for String? parameters
  int _extractMinutes(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return 0;
    return _parseDurationMinutes(timeStr);
  }
  
  /// Normalize a time string to a clean display format (e.g., "1h 30m")
  /// Uses _formatMinutes for consistent output
  String _normalizeTimeString(String timeStr) {
    final minutes = _parseDurationMinutes(timeStr);
    if (minutes <= 0) return timeStr; // Can't parse, return as-is
    return _formatMinutes(minutes);
  }
  
  String _cleanDirectionLine(String line) {
    // First, try to extract step title from timestamp format
    final timestampStep = _extractStepFromTimestamp(line);
    if (timestampStep != null) {
      return timestampStep;
    }
    // Remove step numbers at the beginning
    var cleaned = line.replaceFirst(RegExp(r'^(?:step\s*)?\d+[.:\)]\s*', caseSensitive: false), '');
    return cleaned.trim();
  }
  
  /// Check if a direction line should be skipped (junk content)
  bool _isJunkDirectionLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return true;
    
    // Skip markdown-style titles like **Title** (these are often recipe titles, not directions)
    if (RegExp(r'^\*\*[^*]+\*\*$').hasMatch(trimmed)) return true;
    
    // Skip "By AUTHOR NAME" lines (author bylines)
    if (RegExp(r'^By\s+[A-Z][A-Z\s]+$', caseSensitive: true).hasMatch(trimmed)) return true;
    if (RegExp(r'^By\s+[A-Z][a-z]+(\s+[A-Z][a-z]+)*$').hasMatch(trimmed)) return true;
    
    // Skip standalone "Step X" headers (the content follows in another element)
    if (RegExp(r'^Step\s*\d+\.?$', caseSensitive: false).hasMatch(trimmed)) return true;
    
    // Skip navigation/UI elements
    if (trimmed.toLowerCase() == 'directions' ||
        trimmed.toLowerCase() == 'instructions' ||
        trimmed.toLowerCase() == 'method' ||
        trimmed.toLowerCase() == 'steps' ||
        trimmed.toLowerCase() == 'preparation') return true;
    
    // Skip very short lines that are likely headers
    if (trimmed.length < 5) return true;
    
    // Skip lines that are just numbers or punctuation
    if (RegExp(r'^[\d\s.,;:!?-]+$').hasMatch(trimmed)) return true;
    
    // Skip ad scripts and JavaScript garbage
    if (RegExp(r'adsbygoogle', caseSensitive: false).hasMatch(trimmed)) return true;
    if (RegExp(r'googlesyndication', caseSensitive: false).hasMatch(trimmed)) return true;
    if (RegExp(r'window\._wca', caseSensitive: false).hasMatch(trimmed)) return true;
    if (RegExp(r'\.push\s*\(\s*\{\s*\}\s*\)', caseSensitive: false).hasMatch(trimmed)) return true;
    if (RegExp(r'\|\|\s*\[\]', caseSensitive: false).hasMatch(trimmed)) return true;
    
    // Skip subscribe/newsletter prompts
    if (RegExp(r'Subscribe\s+to\s+get', caseSensitive: false).hasMatch(trimmed)) return true;
    if (RegExp(r'sent\s+to\s+your\s+email', caseSensitive: false).hasMatch(trimmed)) return true;
    if (RegExp(r'sign\s+up\s+for\s+(?:our|the)?\s*newsletter', caseSensitive: false).hasMatch(trimmed)) return true;
    if (RegExp(r'get\s+the\s+latest\s+(?:posts|recipes)', caseSensitive: false).hasMatch(trimmed)) return true;
    if (RegExp(r'Type\s+your\s+email', caseSensitive: false).hasMatch(trimmed)) return true;
    if (RegExp(r'Subscribe$', caseSensitive: false).hasMatch(trimmed)) return true;
    
    // Skip social media share prompts
    if (RegExp(r'Click\s+to\s+Share', caseSensitive: false).hasMatch(trimmed)) return true;
    if (RegExp(r'Share\s+(?:this|on)\s+(?:Facebook|Twitter|Pinterest|Instagram)', caseSensitive: false).hasMatch(trimmed)) return true;
    if (RegExp(r'^(?:Like|Tweet|Pin)\s+(?:this|it)?$', caseSensitive: false).hasMatch(trimmed)) return true;
    
    // Skip print/save buttons captured as text
    if (RegExp(r'^(?:Print|Save|Share)\s+(?:Recipe|This)?$', caseSensitive: false).hasMatch(trimmed)) return true;
    
    // Skip navigation menu text that got captured
    if (RegExp(r'\b(?:shop|gifts|products|cart|checkout|account|login|sign in|menu|home|about|contact|search|blog|news)\b.*\b(?:shop|gifts|products|cart|checkout|account|login|sign in|menu|home|about|contact|search|blog|news)\b', caseSensitive: false).hasMatch(trimmed)) return true;
    
    return false;
  }
  
  /// Patterns to identify equipment items (not ingredients)
  static final _equipmentPatterns = [
    RegExp(r'^(?:half-?gallon|quart|pint|gallon)\s+(?:jar|mason\s+jar|container)', caseSensitive: false),
    RegExp(r'^(?:measuring|mixing)\s+(?:cup|spoon|bowl)s?', caseSensitive: false),
    RegExp(r'^(?:knife|knives)\s*(?:&|and)?\s*(?:cutting\s+board)?', caseSensitive: false),
    RegExp(r'^cutting\s+board', caseSensitive: false),
    RegExp(r'^(?:medium|large|small|heavy)?\s*(?:sauce)?pan', caseSensitive: false),
    RegExp(r'^(?:medium|large|small)?\s*(?:pot|skillet|wok|dutch\s+oven)', caseSensitive: false),
    RegExp(r'^(?:baking|sheet|cookie)\s+(?:sheet|pan|tray)', caseSensitive: false),
    RegExp(r'^(?:food\s+)?processor', caseSensitive: false),
    RegExp(r'^(?:stand|hand)\s+mixer', caseSensitive: false),
    RegExp(r'^blender', caseSensitive: false),
    RegExp(r'^(?:kitchen\s+)?scale', caseSensitive: false),
    RegExp(r'^thermometer', caseSensitive: false),
    RegExp(r'^(?:slotted|wooden|metal)\s+spoon', caseSensitive: false),
    RegExp(r'^(?:rubber|silicone)\s+spatula', caseSensitive: false),
    RegExp(r'^whisk', caseSensitive: false),
    RegExp(r'^tongs', caseSensitive: false),
    RegExp(r'^colander', caseSensitive: false),
    RegExp(r'^strainer', caseSensitive: false),
    RegExp(r'^(?:fine\s+)?mesh\s+(?:strainer|sieve)', caseSensitive: false),
    RegExp(r'^(?:plastic|saran|cling)\s+wrap', caseSensitive: false),
    RegExp(r'^(?:aluminum|tin|aluminium)\s+foil', caseSensitive: false),
    RegExp(r'^parchment\s+(?:paper)?', caseSensitive: false),
  ];
  
  /// Check if a string looks like equipment rather than an ingredient
  bool _isEquipmentItem(String item) {
    final trimmed = item.trim().toLowerCase();
    return _equipmentPatterns.any((p) => p.hasMatch(trimmed));
  }
  
  /// Patterns to identify direction-like lines (instructions, not ingredients)
  static final _directionLikePatterns = [
    // Lines that start with action verbs followed by articles
    RegExp(r'^(?:Slice|Cut|Chop|Dice|Mince|Add|Mix|Stir|Combine|Pour|Heat|Bake|Cook|Place|Allow|Let|Store|Preheat|Prepare|Remove|Transfer|Cover|Drain|Rinse|Wash|Peel|Core|Grate|Shred|Massage|Pack|Press|Weight|Weigh|Sprinkle|Toss|Season|Taste|Serve|Set|Leave|Keep|Check|Wait|Refrigerate|Ferment|Cure|Marinate|Soak|Dissolve|Whisk|Blend|Process|Puree|Strain|Filter|Skim|Ladle|Spoon)\s+(?:the|a|an|your|each|all)\b', caseSensitive: false),
    // Lines that start with action verbs followed by common prepositions or adverbs
    RegExp(r'^(?:Slice|Cut|Chop|Dice|Mince|Add|Mix|Stir|Combine|Pour|Heat|Bake|Cook|Place|Allow|Let|Store|Preheat|Prepare|Remove|Transfer|Cover|Drain|Rinse|Wash|Bring|Reduce|Simmer|Boil|Season|Taste|Serve|Peel|Core|Grate|Shred|Massage|Pack|Press|Weight|Weigh|Sprinkle|Toss|Set|Leave|Keep|Check|Wait|Refrigerate|Ferment|Cure|Marinate|Soak|Dissolve|Whisk|Blend|Process|Puree|Strain|Filter|Using|Once|After|When|Before|While|If|Make|Start|Begin|Continue|Repeat|Turn|Flip|Rotate)\s+(?:until|over|for|to|into|in|on|at|with|all|your|this|it|them|each|every|together|well|thoroughly|gently|carefully|slowly|quickly|immediately|aside)\b', caseSensitive: false),
    // Lines that start with action verbs followed by any word(s) and contain action verbs later (compound instructions)
    RegExp(r'^(?:Slice|Cut|Chop|Dice|Peel|Core|Grate|Shred|Massage|Pack|Place|Remove|Transfer|Cover)\s+.+\b(?:add|and\s+add|then\s+add|;|and\s+wait|and\s+let)\b', caseSensitive: false),
    // Lines that start with "Once" followed by descriptive text (conditional instructions)
    RegExp(r'^Once\s+(?:you|the|it|they|everything)\b', caseSensitive: false),
    // Lines that contain multiple direction verbs (likely instructions)
    RegExp(r'\b(?:and\s+)?(?:then\s+)?(?:stir|mix|add|cook|bake|heat|let|allow|place|cover|remove|transfer|serve|refrigerate|store)\b.*\b(?:until|for|about|approximately)\b', caseSensitive: false),
  ];
  
  /// Strong action verb pattern - if line starts with these AND is long enough, it's likely a direction
  static final _strongActionVerbPattern = RegExp(
    r'^(?:Slice|Cut|Chop|Dice|Mince|Peel|Core|Grate|Shred|Massage|Pack|Place|Remove|Transfer|Cover|Drain|Rinse|Wash|Add|Mix|Stir|Combine|Pour|Heat|Bake|Cook|Allow|Let|Store|Prepare|Season|Serve|Wait|Refrigerate|Ferment|Cure|Marinate|Soak|Whisk|Blend|Process|Puree|Strain|Filter|Once|After|When|Before|While)\b',
    caseSensitive: false,
  );
  
  /// Check if a string looks like a direction/instruction
  bool _isDirectionLikeLine(String line) {
    final trimmed = line.trim();
    // Must be longer than a typical ingredient (instructions are usually verbose)
    if (trimmed.length < 40) return false;
    
    // Check if starts with a strong action verb - if so, relaxed punctuation requirements
    final startsWithActionVerb = _strongActionVerbPattern.hasMatch(trimmed);
    
    // For lines starting with action verbs, accept semicolons or just being long enough
    if (startsWithActionVerb) {
      // If it's long enough (>50 chars) and starts with action verb, it's likely a direction
      if (trimmed.length > 50) return true;
      // Or if it contains semicolon (often used as step separator)
      if (trimmed.contains(';')) return true;
    }
    
    // For other lines, require more structure
    // Must contain a period, semicolon, or be very long with commas
    if (!trimmed.contains('.') && !trimmed.contains(';') && !(trimmed.length > 80 && trimmed.contains(','))) return false;
    
    // Check against explicit patterns
    if (_directionLikePatterns.any((p) => p.hasMatch(trimmed))) return true;
    
    // Heuristic: If it's a very long line (>100 chars) with multiple sentences, likely a direction
    if (trimmed.length > 100 && RegExp(r'\.\s+[A-Z]').hasMatch(trimmed)) return true;
    
    // Heuristic: Contains time indicators common in directions
    if (RegExp(r'\b(?:minutes?|hours?|days?|weeks?)\b.*\b(?:until|or\s+until|before|after)\b', caseSensitive: false).hasMatch(trimmed)) return true;
    
    return false;
  }
  
  /// Shared garbage patterns for ingredient filtering
  /// Used by both JSON-LD and HTML parsing paths
  static final _ingredientGarbagePatterns = [
    RegExp(r'Completed\s+step', caseSensitive: false),  // Weber checkbox labels
    RegExp(r'^step\s+\d+$', caseSensitive: false),       // Standalone "Step 1", "Step 2"
    RegExp(r'^save\s+recipe', caseSensitive: false),     // Save buttons
    RegExp(r'^print\s+recipe', caseSensitive: false),    // Print buttons
    RegExp(r'^share\s+recipe', caseSensitive: false),    // Share buttons
    RegExp(r'^\d+\s*(?:min(?:ute)?s?|hrs?|hours?)$', caseSensitive: false), // Standalone time labels
    // Social media garbage - broad patterns
    RegExp(r'Click\s*to\s*Share', caseSensitive: false),   // "Click to Share"
    RegExp(r'^Click\s*to\s', caseSensitive: false),        // Any "Click to ..." at start
    RegExp(r'Share\s+on\s+(?:Facebook|Twitter|Pinterest|Instagram|Linkedin|Whatsapp|Reddit|X\b)', caseSensitive: false),
    RegExp(r'(?:Facebook|Twitter|Pinterest|Instagram|Linkedin|Whatsapp|Reddit)\s+(?:Facebook|Twitter|Pinterest|Instagram|Linkedin|Whatsapp|Reddit)?$', caseSensitive: false),
    RegExp(r'^(?:Like|Tweet|Pin|Share)\s+(?:this|it)?$', caseSensitive: false),
    RegExp(r'Facebook\s+Facebook', caseSensitive: false), // Doubled social media names
    RegExp(r'Twitter\s+Twitter', caseSensitive: false),
    RegExp(r'Pinterest\s+Pinterest', caseSensitive: false),
    RegExp(r'Linkedin\s+Linkedin', caseSensitive: false),
    RegExp(r'Whatsapp\s+Whatsapp', caseSensitive: false),
    RegExp(r'Reddit\s+Reddit', caseSensitive: false),
    RegExp(r'\bX\s+X\b', caseSensitive: false),           // X X (Twitter rebrand)
    RegExp(r'Opens\s+in\s+new\s+window', caseSensitive: false), // Accessibility text
    RegExp(r'Email\s+a\s+Link', caseSensitive: false),    // Email share
    RegExp(r'Click\s+to\s+Print', caseSensitive: false),  // Print button
    RegExp(r'Click\s+to\s+Email', caseSensitive: false),  // Email button
    // Subscribe/newsletter garbage
    RegExp(r'Subscribe\s+to', caseSensitive: false),
    RegExp(r'sent\s+to\s+your\s+email', caseSensitive: false),
    RegExp(r'newsletter', caseSensitive: false),
    RegExp(r'get\s+the\s+latest', caseSensitive: false),
    RegExp(r'sign\s+up', caseSensitive: false),
    RegExp(r'Type\s+your\s+email', caseSensitive: false), // Email input placeholder
    // Ad script garbage
    RegExp(r'adsbygoogle', caseSensitive: false),
    RegExp(r'window\._wca', caseSensitive: false),
    RegExp(r'window\.adsbygoogle', caseSensitive: false),
    RegExp(r'googlesyndication', caseSensitive: false),
    RegExp(r'^\s*\|\|\s*\[\]', caseSensitive: false),  // JavaScript array patterns
    RegExp(r'\.push\s*\(', caseSensitive: false),       // JavaScript push calls
  ];
  
  /// Check if an ingredient string is garbage (UI element, ad script, etc.)
  bool _isGarbageIngredient(String ingredient) {
    final trimmed = ingredient.trim();
    if (trimmed.isEmpty || !RegExp(r'[a-zA-Z0-9]').hasMatch(trimmed)) return true;
    return _ingredientGarbagePatterns.any((p) => p.hasMatch(trimmed));
  }
  
  /// Filter and deduplicate ingredient strings, removing garbage
  /// Also extracts direction-like lines and equipment items for separate use
  /// Returns a map with keys: 'ingredients', 'directions', 'equipment'
  Map<String, List<String>> _filterIngredientStringsWithExtraction(List<String> rawStrings) {
    final seenIngredients = <String>{};
    final filteredIngredients = <String>[];
    final extractedDirections = <String>[];
    final extractedEquipment = <String>[];
    
    for (final s in rawStrings) {
      final trimmed = s.trim();
      if (trimmed.isEmpty) continue;
      
      // Check for direction-like lines FIRST - move to directions list
      // This must come before garbage check because directions look like garbage to some patterns
      if (_isDirectionLikeLine(trimmed)) {
        extractedDirections.add(trimmed);
        continue;
      }
      
      // Check for pure garbage (social media, ads, etc.) - discard completely
      if (_isGarbageIngredient(trimmed)) {
        continue;
      }
      
      // Check for equipment items - move to equipment list
      if (_isEquipmentItem(trimmed)) {
        extractedEquipment.add(trimmed);
        continue;
      }
      
      // Deduplicate ingredients
      final normalizedKey = trimmed.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      if (seenIngredients.contains(normalizedKey)) continue;
      seenIngredients.add(normalizedKey);
      filteredIngredients.add(trimmed);
    }
    
    return {
      'ingredients': filteredIngredients,
      'directions': extractedDirections,
      'equipment': extractedEquipment,
    };
  }
  
  /// Filter and deduplicate ingredient strings, removing garbage
  List<String> _filterIngredientStrings(List<String> rawStrings) {
    final seenIngredients = <String>{};
    final filtered = <String>[];
    
    for (final s in rawStrings) {
      final trimmed = s.trim();
      // Check for garbage OR equipment OR direction-like (all filtered from ingredients)
      final isGarbage = _isGarbageIngredient(trimmed);
      final isEquipment = _isEquipmentItem(trimmed);
      final isDirection = _isDirectionLikeLine(trimmed);
      
      if (isGarbage || isEquipment || isDirection) continue;
      
      // Normalize for comparison (lowercase, collapse whitespace)
      final normalizedKey = trimmed.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      if (seenIngredients.contains(normalizedKey)) continue;
      seenIngredients.add(normalizedKey);
      filtered.add(trimmed);
    }
    
    return filtered;
  }
  
  /// Filter parsed Ingredient objects, removing garbage entries
  /// This is a safety net for cases where raw strings weren't filtered before parsing
  List<Ingredient> _filterParsedIngredients(List<Ingredient> ingredients) {
    final filtered = <Ingredient>[];
    final seenNames = <String>{};
    
    for (final ing in ingredients) {
      // Check if the ingredient name or the original name looks like garbage
      final nameToCheck = ing.name;
      if (_isGarbageIngredient(nameToCheck)) {
        continue;
      }
      
      // Check for equipment items
      if (_isEquipmentItem(nameToCheck)) {
        continue;
      }
      
      // Check for direction-like lines
      if (_isDirectionLikeLine(nameToCheck)) {
        continue;
      }
      
      // Deduplicate by name
      final normalizedName = nameToCheck.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
      if (seenNames.contains(normalizedName)) continue;
      seenNames.add(normalizedName);
      
      filtered.add(ing);
    }
    
    return filtered;
  }
  
  /// Extract chapters from YouTube description
  /// Format: "Chapter Title – MM:SS" or "MM:SS Chapter Title"
  List<YouTubeChapter> _extractYouTubeChapters(String description) {
    final chapters = <YouTubeChapter>[];
    final lines = description.split('\n');
    
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;
      
      // Format 1: "Title – MM:SS" or "Title - M:SS"
      var match = RegExp(r'^(.+?)\s*[–-]\s*(\d{1,2}):(\d{2})(?::(\d{2}))?\s*$').firstMatch(line);
      if (match != null) {
        final title = match.group(1)?.trim() ?? '';
        final minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
        final seconds = int.tryParse(match.group(3) ?? '0') ?? 0;
        final hours = int.tryParse(match.group(4) ?? '0') ?? 0;
        
        if (title.isNotEmpty && !_isIgnorableLine(title)) {
          chapters.add(YouTubeChapter(
            title: title,
            startSeconds: hours * 3600 + minutes * 60 + seconds,
          ),);
        }
        continue;
      }
      
      // Format 2: "MM:SS Title" or "M:SS Title"
      match = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?\s+(.+)$').firstMatch(line);
      if (match != null) {
        final minutes = int.tryParse(match.group(1) ?? '0') ?? 0;
        final seconds = int.tryParse(match.group(2) ?? '0') ?? 0;
        final hours = int.tryParse(match.group(3) ?? '0') ?? 0;
        final title = match.group(4)?.trim() ?? '';
        
        if (title.isNotEmpty && !_isIgnorableLine(title)) {
          chapters.add(YouTubeChapter(
            title: title,
            startSeconds: hours * 3600 + minutes * 60 + seconds,
          ),);
        }
      }
    }
    
    return chapters;
  }
  
  /// Fetch YouTube transcript with timestamps
  /// Returns tuple of (segments, debugInfo)
  Future<(List<TranscriptSegment>, String)> _fetchYouTubeTranscriptWithTimestamps(String videoId, String pageBody) async {
    try {
      final captionTrackMatch = RegExp(
        r'"captionTracks":\s*\[(.*?)\]',
        dotAll: true,
      ).firstMatch(pageBody);
      
      if (captionTrackMatch == null) {
        return (<TranscriptSegment>[], 'no captionTracks in page');
      }
      
      final captionTracksJson = captionTrackMatch.group(1) ?? '';
      
      String? captionUrl;
      String? langCode;
      String matchedType = '';
      
      // Simple approach: find baseUrl and languageCode separately
      // First, try to find English captions by looking for languageCode":"en" near a baseUrl
      
      // Check if there's an English caption track
      if (captionTracksJson.contains('"languageCode":"en"') || 
          captionTracksJson.contains('"vssId":".en"') ||
          captionTracksJson.contains('"vssId":"a.en"')) {
        langCode = 'en';
        matchedType = 'en';
      }
      
      // Extract the first baseUrl we can find
      final baseUrlMatch = RegExp(r'"baseUrl"\s*:\s*"([^"]+)"').firstMatch(captionTracksJson);
      if (baseUrlMatch != null) {
        captionUrl = _decodeUnicodeEscapes(baseUrlMatch.group(1)!);
        if (matchedType.isEmpty) matchedType = 'first';
      }
      
      // If no English found, try to extract any language code
      if (langCode == null) {
        final langMatch = RegExp(r'"languageCode"\s*:\s*"([^"]+)"').firstMatch(captionTracksJson);
        if (langMatch != null) {
          langCode = langMatch.group(1);
          matchedType = 'lang-$langCode';
        }
      }
      
      if (captionUrl == null) {
        // Include a sample of what we found for debugging
        final sample = captionTracksJson.length > 100 
            ? captionTracksJson.substring(0, 100) 
            : captionTracksJson;
        return (<TranscriptSegment>[], 'no baseUrl found. Sample: $sample');
      }
      
      // Debug: check what's in the URL before we modify it
      final hasLangInUrl = captionUrl.contains('lang=');
      final langInUrlMatch = RegExp(r'lang=([a-zA-Z\-]+)').firstMatch(captionUrl);
      final langInUrl = langInUrlMatch?.group(1) ?? 'none';
      
      // Ensure the URL has the lang parameter
      if (langCode != null && !hasLangInUrl) {
        captionUrl = captionUrl.contains('?') 
            ? '$captionUrl&lang=$langCode' 
            : '$captionUrl?lang=$langCode';
      }
      
      // Debug info about URL
      final urlDebug = 'url_lang=$langInUrl, matchType=$matchedType';
      
      String? successBody;
      String usedMethod = '';
      String lastError = '';
      
      // Method 1: Try to find transcript engagement panel params
      // Look for engagement panel with transcript - try multiple patterns
      String? transcriptParams;
      String foundPattern = '';
      
      // Pattern 1: Look for transcript panel targetId and nearby params
      final panelMatch1 = RegExp(
        r'"targetId"\s*:\s*"engagement-panel-searchable-transcript"[^}]*?"params"\s*:\s*"([^"]+)"',
        dotAll: true,
      ).firstMatch(pageBody);
      
      if (panelMatch1 != null) {
        transcriptParams = panelMatch1.group(1);
        foundPattern = 'p1';
      }
      
      // Pattern 2: Look for transcriptEndpoint params
      if (transcriptParams == null) {
        final panelMatch2 = RegExp(
          r'"transcriptEndpoint"\s*:\s*\{[^}]*"params"\s*:\s*"([^"]+)"',
          dotAll: true,
        ).firstMatch(pageBody);
        if (panelMatch2 != null) {
          transcriptParams = panelMatch2.group(1);
          foundPattern = 'p2';
        }
      }
      
      // Pattern 3: Look for showTranscriptCommand or openTranscript patterns
      if (transcriptParams == null) {
        final panelMatch3 = RegExp(
          r'"(?:showTranscript|openTranscript)[^"]*"[^}]*?"params"\s*:\s*"([^"]+)"',
          dotAll: true,
        ).firstMatch(pageBody);
        if (panelMatch3 != null) {
          transcriptParams = panelMatch3.group(1);
          foundPattern = 'p3';
        }
      }
      
      // Pattern 4: Broader search - any params near "transcript" keyword
      if (transcriptParams == null) {
        // Search for transcript-related params in a 500 char window
        final transcriptSection = RegExp(
          r'transcript[^{]*\{[^}]{0,300}"params"\s*:\s*"([^"]+)"',
          caseSensitive: false,
        ).firstMatch(pageBody);
        if (transcriptSection != null) {
          transcriptParams = transcriptSection.group(1);
          foundPattern = 'p4';
        }
      }
      
      if (transcriptParams != null) {
        // Retry up to 3 times - YouTube API can be flaky
        for (int attempt = 1; attempt <= 3; attempt++) {
          try {
            final transcriptResponse = await http.post(
              Uri.parse('https://www.youtube.com/youtubei/v1/get_transcript?prettyPrint=false'),
              headers: {
                'Content-Type': 'application/json',
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                'Origin': 'https://www.youtube.com',
                'Referer': 'https://www.youtube.com/watch?v=$videoId',
              },
              body: '{"context":{"client":{"clientName":"WEB","clientVersion":"2.20231219.04.00","hl":"en"}},"params":"$transcriptParams"}',
            );
            
            if (transcriptResponse.statusCode == 200 && transcriptResponse.body.isNotEmpty) {
              final segments = _parseYouTubeiTranscript(transcriptResponse.body);
              if (segments.isNotEmpty) {
                return (segments, 'youtubei($foundPattern): ${segments.length} segments');
              }
              lastError = 'youtubei($foundPattern): 0 segs';
            } else {
              lastError = 'youtubei($foundPattern): ${transcriptResponse.statusCode}';
            }
            
            // If failed, wait a bit before retry
            if (attempt < 3) {
              await Future.delayed(Duration(milliseconds: 500 * attempt));
            }
          } catch (e) {
            lastError = 'youtubei err: $e';
          }
        }
      } else {
        lastError = 'no panel params';
      }
      
      // Method 1b: If extracted params failed, try player API to get fresh caption URL
      if (lastError.isNotEmpty && !lastError.contains('segments')) {
        try {
          // Use innertube player API to get fresh caption tracks
          final playerResponse = await http.post(
            Uri.parse('https://www.youtube.com/youtubei/v1/player?prettyPrint=false'),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
              'Origin': 'https://www.youtube.com',
            },
            body: '{"context":{"client":{"clientName":"WEB","clientVersion":"2.20231219.04.00","hl":"en"}},"videoId":"$videoId"}',
          );
          
          if (playerResponse.statusCode == 200) {
            // Extract caption URL from player response
            final captionMatch = RegExp(
              r'"captionTracks":\s*\[\s*\{[^}]*"baseUrl"\s*:\s*"([^"]+)"',
            ).firstMatch(playerResponse.body);
            
            if (captionMatch != null) {
              final freshCaptionUrl = _decodeUnicodeEscapes(captionMatch.group(1)!);
              // Add format parameter
              // Try without format first (default XML), then with json3
              for (final fmt in ['', '&fmt=json3']) {
                var urlToTry = freshCaptionUrl;
                if (fmt.isNotEmpty && !urlToTry.contains('fmt=')) {
                  urlToTry = '$urlToTry$fmt';
                }
                
                final captionResponse = await http.get(
                  Uri.parse(urlToTry),
                  headers: {
                    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                  },
                );
                
                if (captionResponse.statusCode == 200 && captionResponse.body.isNotEmpty) {
                  // Try XML parsing first
                  final xmlSegments = _parseTranscriptXmlWithTimestamps(captionResponse.body);
                  if (xmlSegments.isNotEmpty) {
                    return (xmlSegments, 'player-xml: ${xmlSegments.length} segments');
                  }
                  // Try JSON parsing
                  final segments = _parseTranscriptJson(captionResponse.body);
                  if (segments.isNotEmpty) {
                    return (segments, 'player-json: ${segments.length} segments');
                  }
                }
              }
              // Debug: show sample of what we got
              final debugResponse = await http.get(Uri.parse(freshCaptionUrl));
              final sample = debugResponse.body.length > 80 
                  ? debugResponse.body.substring(0, 80) 
                  : debugResponse.body;
              lastError = '$lastError | player:0segs($sample)';
            } else {
              lastError = '$lastError | player:no-cap';
            }
          } else {
            lastError = '$lastError | player:${playerResponse.statusCode}';
          }
        } catch (e) {
          lastError = '$lastError | player:err';
        }
      }
      
      // Store youtubei result before trying timedtext
      final youtubeiResult = lastError;
      
      // Method 2: Try timedtext URLs as fallback
      final urlsToTry = <String>[
        captionUrl,  // Original extracted URL
        'https://www.youtube.com/api/timedtext?v=$videoId&lang=en&fmt=srv3',
      ];
      
      for (final baseUrl in urlsToTry) {
        try {
          final response = await http.get(
            Uri.parse(baseUrl),
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
              'Accept': '*/*',
              'Referer': 'https://www.youtube.com/watch?v=$videoId',
            },
          );
          
          if (response.statusCode == 200 && response.body.isNotEmpty) {
            successBody = response.body;
            usedMethod = 'timedtext';
            break;
          } else {
            lastError = '$youtubeiResult | tt:${response.body.length}';
          }
        } catch (e) {
          lastError = 'timedtext err';
          continue;
        }
      }
      
      if (successBody == null || successBody.isEmpty) {
        // Show URL debug info to help diagnose
        return (<TranscriptSegment>[], 'all methods failed ($lastError)');
      }
      
      // Parse transcript - try XML first, then JSON
      var segments = _parseTranscriptXmlWithTimestamps(successBody);
      
      // If XML parsing failed, try JSON parsing
      if (segments.isEmpty && successBody.startsWith('{')) {
        segments = _parseTranscriptJson(successBody);
      }
      
      if (segments.isEmpty) {
        final bodyLen = successBody.length;
        final sample = bodyLen > 100 ? successBody.substring(0, 100) : successBody;
        return (<TranscriptSegment>[], 'no segments (len=$bodyLen). Sample: $sample');
      }
      
      return (segments, '$usedMethod: ${segments.length} segments');
    } catch (e) {
      return (<TranscriptSegment>[], 'exception: ${e.toString().substring(0, 50.clamp(0, e.toString().length))}');
    }
  }
  
  /// Parse YouTube transcript XML keeping timestamps
  List<TranscriptSegment> _parseTranscriptXmlWithTimestamps(String xml) {
    final segments = <TranscriptSegment>[];
    
    // Try multiple regex patterns to handle different YouTube XML formats
    
    // Pattern 1: Standard format <text start="123.45" dur="1.23">content</text>
    var textMatches = RegExp(
      r'<text\s+start="([^"]+)"[^>]*>(.*?)</text>',
      dotAll: true,
    ).allMatches(xml);
    
    // Pattern 2: If attributes are in different order or format
    if (textMatches.isEmpty) {
      textMatches = RegExp(
        r'<text[^>]*\sstart="([^"]+)"[^>]*>(.*?)</text>',
        dotAll: true,
      ).allMatches(xml);
    }
    
    // Pattern 3: More permissive - any text element with start attribute
    if (textMatches.isEmpty) {
      textMatches = RegExp(
        r'<text[^>]*start="(\d+\.?\d*)"[^>]*>(.*?)</text>',
        dotAll: true,
      ).allMatches(xml);
    }
    
    for (final match in textMatches) {
      final startStr = match.group(1) ?? '0';
      final startSeconds = double.tryParse(startStr) ?? 0;
      var text = match.group(2) ?? '';
      text = _decodeHtml(text);
      text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
      
      if (text.isNotEmpty) {
        segments.add(TranscriptSegment(text: text, startSeconds: startSeconds));
      }
    }
    
    return segments;
  }
  
  /// Parse YouTube transcript JSON format (json3)
  List<TranscriptSegment> _parseTranscriptJson(String json) {
    final segments = <TranscriptSegment>[];
    
    try {
      // YouTube json3 format has events with segs containing utf8 text
      // Look for patterns like "tOffsetMs":123,"segs":[{"utf8":"text"}]
      final eventMatches = RegExp(
        r'"tOffsetMs"\s*:\s*(\d+).*?"segs"\s*:\s*\[(.*?)\]',
        dotAll: true,
      ).allMatches(json);
      
      for (final match in eventMatches) {
        final offsetMs = int.tryParse(match.group(1) ?? '0') ?? 0;
        final startSeconds = offsetMs / 1000.0;
        final segsJson = match.group(2) ?? '';
        
        // Extract utf8 text from segs
        final textParts = <String>[];
        final utf8Matches = RegExp(r'"utf8"\s*:\s*"([^"]*)"').allMatches(segsJson);
        for (final tm in utf8Matches) {
          var text = tm.group(1) ?? '';
          text = _decodeUnicodeEscapes(text);
          text = _decodeHtml(text);
          if (text.isNotEmpty && text != '\n') {
            textParts.add(text);
          }
        }
        
        if (textParts.isNotEmpty) {
          final combinedText = textParts.join('').replaceAll(RegExp(r'\s+'), ' ').trim();
          if (combinedText.isNotEmpty) {
            segments.add(TranscriptSegment(text: combinedText, startSeconds: startSeconds));
          }
        }
      }
    } catch (_) {
      // JSON parsing failed
    }
    
    return segments;
  }
  
  /// Build base64 params for YouTube transcript API
  /// Build transcript params for YouTube API
  /// Based on youtube-transcript library approach
  String _buildTranscriptParams(String videoId, {String lang = 'en'}) {
    // The params are a base64-encoded protobuf structure
    // Structure: \n + length + videoId + \x12 + length + "asr" + \x1a + length + lang
    // This requests auto-generated captions in the specified language
    
    final videoIdBytes = videoId.codeUnits;
    final langBytes = lang.codeUnits;
    const asr = 'asr'; // Auto-generated subtitles
    
    // Build the protobuf-like structure
    final buffer = <int>[
      0x0a, // Field 1 (video ID)
      videoIdBytes.length,
      ...videoIdBytes,
      0x12, // Field 2 (track kind)
      asr.length,
      ...asr.codeUnits,
      0x1a, // Field 3 (language)
      langBytes.length,
      ...langBytes,
    ];
    
    // Wrap in outer container
    final outer = <int>[
      0x0a, // Field 1
      buffer.length,
      ...buffer,
    ];
    
    // Base64 encode
    return base64Encode(outer);
  }
  
  /// Parse YouTube's internal transcript API response
  List<TranscriptSegment> _parseYouTubeiTranscript(String json) {
    final segments = <TranscriptSegment>[];
    
    try {
      // YouTubei transcript response has structure like:
      // actions[].updateEngagementPanelAction.content.transcriptRenderer
      //   .content.transcriptSearchPanelRenderer.body.transcriptSegmentListRenderer
      //   .initialSegments[].transcriptSegmentRenderer
      
      // Look for transcriptSegmentRenderer entries with timestamps
      final segmentMatches = RegExp(
        r'"transcriptSegmentRenderer"\s*:\s*\{[^}]*"startMs"\s*:\s*"?(\d+)"?[^}]*"snippet"\s*:\s*\{[^}]*"text"\s*:\s*"([^"]+)"',
        dotAll: true,
      ).allMatches(json);
      
      for (final match in segmentMatches) {
        final startMs = int.tryParse(match.group(1) ?? '0') ?? 0;
        final text = _decodeUnicodeEscapes(match.group(2) ?? '');
        if (text.isNotEmpty) {
          segments.add(TranscriptSegment(
            text: _decodeHtml(text),
            startSeconds: startMs / 1000.0,
          ),);
        }
      }
      
      // Alternative pattern - sometimes the structure is different
      if (segments.isEmpty) {
        final altMatches = RegExp(
          r'"cueGroupRenderer".*?"simpleText"\s*:\s*"([^"]+)".*?"startOffset"\s*:\s*"?(\d+)"?',
          dotAll: true,
        ).allMatches(json);
        
        for (final match in altMatches) {
          final text = _decodeUnicodeEscapes(match.group(1) ?? '');
          final startMs = int.tryParse(match.group(2) ?? '0') ?? 0;
          if (text.isNotEmpty) {
            segments.add(TranscriptSegment(
              text: _decodeHtml(text),
              startSeconds: startMs / 1000.0,
            ),);
          }
        }
      }
    } catch (_) {
      // Parsing failed
    }
    
    return segments;
  }
  
  /// Build directions by slicing transcript based on chapter timestamps
  List<String> _buildDirectionsFromChapters(
    List<YouTubeChapter> chapters,
    List<TranscriptSegment> segments,
  ) {
    final directions = <String>[];
    
    for (var i = 0; i < chapters.length; i++) {
      final chapter = chapters[i];
      final nextChapterStart = i + 1 < chapters.length 
          ? chapters[i + 1].startSeconds 
          : double.infinity;
      
      // Get transcript segments for this chapter
      final chapterSegments = segments.where((s) =>
          s.startSeconds >= chapter.startSeconds &&
          s.startSeconds < nextChapterStart,
      ).toList();
      
      if (chapterSegments.isEmpty) {
        // No transcript for this chapter, just use title
        directions.add(chapter.title);
        continue;
      }
      
      // Combine segment text
      var text = chapterSegments.map((s) => s.text).join(' ');
      
      // Clean up the text
      text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
      
      // Capitalize first letter
      if (text.isNotEmpty) {
        text = text[0].toUpperCase() + text.substring(1);
      }
      
      // Add period if missing
      if (text.isNotEmpty && !text.endsWith('.') && !text.endsWith('!') && !text.endsWith('?')) {
        text = '$text.';
      }
      
      directions.add(text);
    }
    
    return directions;
  }

  /// Fetch YouTube transcript/captions (legacy - keeping for compatibility)
  Future<List<String>> _fetchYouTubeTranscript(String videoId, String pageBody) async {
    try {
      // Find the captions track URL in the page response
      // YouTube embeds caption data in the initial page load
      final captionTrackMatch = RegExp(
        r'"captionTracks":\s*\[(.*?)\]',
        dotAll: true,
      ).firstMatch(pageBody);
      
      if (captionTrackMatch == null) {
        return [];
      }
      
      final captionTracksJson = '[${captionTrackMatch.group(1)}]';
      
      // Find English captions (prefer manual over auto-generated)
      String? captionUrl;
      try {
        // Extract baseUrl for English captions
        // Look for English manual captions first
        var urlMatch = RegExp(r'"baseUrl":\s*"([^"]+)"[^}]*"vssId":\s*"\.en"').firstMatch(captionTracksJson);
        // Fall back to auto-generated English
        urlMatch ??= RegExp(r'"baseUrl":\s*"([^"]+)"[^}]*"vssId":\s*"a\.en"').firstMatch(captionTracksJson);
        // Fall back to any English variant
        urlMatch ??= RegExp(r'"baseUrl":\s*"([^"]+)"[^}]*"languageCode":\s*"en"').firstMatch(captionTracksJson);
        // Fall back to first available track
        urlMatch ??= RegExp(r'"baseUrl":\s*"([^"]+)"').firstMatch(captionTracksJson);
        
        if (urlMatch != null) {
          captionUrl = _decodeUnicodeEscapes(urlMatch.group(1)!);
        }
      } catch (_) {
        return [];
      }
      
      if (captionUrl == null) return [];
      
      // Fetch the caption track
      final captionResponse = await http.get(
        Uri.parse(captionUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      );
      
      if (captionResponse.statusCode != 200) return [];
      
      // Parse the XML transcript
      final transcript = _parseYouTubeTranscriptXml(captionResponse.body);
      
      // Convert transcript to recipe directions
      return _extractDirectionsFromTranscript(transcript);
    } catch (_) {
      return [];
    }
  }
  
  /// Parse YouTube transcript XML format
  List<String> _parseYouTubeTranscriptXml(String xml) {
    final segments = <String>[];
    
    // Extract text from <text> elements
    final textMatches = RegExp(r'<text[^>]*>([^<]*)</text>').allMatches(xml);
    
    for (final match in textMatches) {
      var text = match.group(1) ?? '';
      // Decode HTML entities
      text = _decodeHtml(text);
      text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (text.isNotEmpty) {
        segments.add(text);
      }
    }
    
    return segments;
  }
  
  /// Extract recipe directions from transcript segments
  List<String> _extractDirectionsFromTranscript(List<String> segments) {
    if (segments.isEmpty) return [];
    
    // Combine segments into larger chunks (captions are often fragmented)
    final combinedText = segments.join(' ');
    
    // Split into sentences
    final sentences = combinedText
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    
    // Filter to keep only sentences that look like cooking instructions
    final directions = <String>[];
    
    for (final sentence in sentences) {
      // Skip very short sentences (likely fragments)
      if (sentence.length < 15) continue;
      
      // Skip sentences that are clearly not instructions
      if (RegExp(r'\b(subscribe|comment|like|share|video|channel|patreon|sponsor)\b', caseSensitive: false).hasMatch(sentence)) {
        continue;
      }
      
      // Keep sentences with cooking-related content
      if (_looksLikeCookingInstruction(sentence)) {
        // Clean up the sentence
        var cleaned = sentence;
        // Capitalize first letter
        if (cleaned.isNotEmpty) {
          cleaned = cleaned[0].toUpperCase() + cleaned.substring(1);
        }
        // Ensure it ends with punctuation
        if (!RegExp(r'[.!?]$').hasMatch(cleaned)) {
          cleaned += '.';
        }
        directions.add(cleaned);
      }
    }
    
    // Limit to reasonable number of steps
    if (directions.length > 20) {
      // Try to consolidate into larger steps
      return _consolidateDirections(directions);
    }
    
    return directions;
  }
  
  bool _looksLikeCookingInstruction(String text) {
    final lower = text.toLowerCase();
    
    // Contains cooking verbs
    if (RegExp(r'\b(add|mix|stir|cook|heat|bake|roast|fry|boil|simmer|chop|dice|slice|cut|pour|combine|whisk|fold|season|taste|serve|place|put|remove|transfer|let|allow|wait|set|cover|preheat|refrigerate|chill|freeze)\b').hasMatch(lower)) {
      return true;
    }
    
    // Contains cooking equipment
    if (RegExp(r'\b(pan|pot|oven|bowl|skillet|baking|sheet|tray|blender|processor|mixer|whisk|spatula|knife|cutting board|thermometer)\b').hasMatch(lower)) {
      return true;
    }
    
    // Contains temperature or time references
    if (RegExp(r'\b(\d+\s*(?:degrees|°|minutes|mins|hours|hrs|seconds|secs))\b').hasMatch(lower)) {
      return true;
    }
    
    return false;
  }
  
  List<String> _consolidateDirections(List<String> directions) {
    // Group related directions into larger steps
    final consolidated = <String>[];
    var current = <String>[];
    
    for (final dir in directions) {
      current.add(dir);
      // Start a new step after ~3 sentences or when hitting a natural break
      if (current.length >= 3 || 
          RegExp(r'\b(then|next|now|after|finally|lastly)\b', caseSensitive: false).hasMatch(dir)) {
        consolidated.add(current.join(' '));
        current = [];
      }
    }
    
    if (current.isNotEmpty) {
      consolidated.add(current.join(' '));
    }
    
    return consolidated;
  }

  /// Legacy method for backwards compatibility - returns Recipe directly
  Future<Recipe?> importRecipeFromUrl(String url) async {
    final result = await importFromUrl(url);
    return result.toRecipe(_uuid.v4());
  }

  /// Check if text looks like binary, base64, or other encoded data
  /// This helps filter out garbage content from images, SVGs, or encoded scripts
  bool _looksLikeBinaryOrEncoded(String text) {
    // Check for high concentration of non-printable or unusual characters
    // (characters outside normal text range)
    int unusualCharCount = 0;
    for (final rune in text.runes) {
      // Characters outside printable ASCII range (excluding common Unicode letters)
      if ((rune < 32 && rune != 10 && rune != 13) || // control chars
          (rune > 126 && rune < 160) || // extended ASCII control
          (rune > 65535)) { // very high unicode
        unusualCharCount++;
      }
    }
    // If more than 5% unusual characters, it's likely binary
    if (unusualCharCount > text.length * 0.05) return true;
    
    // Check for base64 patterns (long strings without spaces)
    final wordsWithoutSpaces = text.split(RegExp(r'\s+'));
    for (final word in wordsWithoutSpaces) {
      // Very long "words" without spaces are likely encoded data
      if (word.length > 50 && !word.contains('http')) return true;
    }
    
    // Check for common encoded data markers
    if (text.contains('data:') ||
        text.contains('base64') ||
        text.contains('svg+xml') ||
        RegExp(r'[A-Za-z0-9+/]{60,}={1,2}$').hasMatch(text)) { // base64 pattern with trailing =
      return true;
    }
    
    return false;
  }

  /// Check if a string is a valid ingredient candidate
  bool _isValidIngredientCandidate(String text) {
    if (text.isEmpty || text.length < 5 || text.length > 150) return false;
    if (_looksLikeBinaryOrEncoded(text)) return false;
    
    final lower = text.toLowerCase();
    // Skip navigation/UI elements
    if (lower.contains('subscribe') ||
        lower.contains('http') ||
        lower.contains('click') ||
        lower.contains('menu') ||
        lower.contains('instagram') ||
        lower.contains('facebook') ||
        lower.contains('newsletter') ||
        lower.contains('function') ||
        lower.contains('script') ||
        lower.contains('copyright') ||
        lower.contains('privacy') ||
        lower.contains('cookie')) {
      return false;
    }
    
    return true;
  }

  /// Decode HTML entities and normalise text
  String _decodeHtml(String text) {
    var result = text;
    
    // Strip HTML tags first (e.g., <span style="...">text</span> -> text)
    result = result.replaceAll(RegExp(r'<[^>]+>'), '');
    
    // Decode HTML entities
    _htmlEntities.forEach((entity, char) {
      result = result.replaceAll(entity, char);
    });
    
    // Handle numeric entities
    result = result.replaceAllMapped(
      RegExp(r'&#(\d+);'),
      (match) {
        final code = int.tryParse(match.group(1) ?? '');
        return code != null ? String.fromCharCode(code) : match.group(0)!;
      },
    );
    
    // Handle hex entities
    result = result.replaceAllMapped(
      RegExp(r'&#x([0-9a-fA-F]+);'),
      (match) {
        final code = int.tryParse(match.group(1) ?? '', radix: 16);
        return code != null ? String.fromCharCode(code) : match.group(0)!;
      },
    );
    
    // Convert fractions
    _fractionMap.forEach((fraction, unicode) {
      result = result.replaceAll(fraction, unicode);
    });
    
    // Normalise measurements
    _measurementNormalisation.forEach((pattern, replacement) {
      result = result.replaceAllMapped(pattern, (_) => replacement);
    });
    
    // Clean up extra whitespace
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return result;
  }

  /// Clean recipe name - remove "Recipe" suffix, clean up, and apply Title Case
  String _cleanRecipeName(String name) {
    var cleaned = _decodeHtml(name);
    
    // Remove common suffixes
    cleaned = cleaned.replaceAll(RegExp(r'\s*[-–—]\s*Recipe\s*$', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+Recipe\s*$', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'^Recipe\s*[-–—:]\s*', caseSensitive: false), '');
    
    cleaned = cleaned.trim();
    
    if (cleaned.isEmpty) return cleaned;
    
    // Words that should stay lowercase (unless first word)
    const lowercaseWords = {'a', 'an', 'the', 'and', 'or', 'of', 'for', 'to', 'in', 'on', 'at', 'by', 'with'};
    
    // Apply Title Case to all words
    final words = cleaned.split(' ');
    final titleCased = words.asMap().entries.map((entry) {
      final i = entry.key;
      final word = entry.value;
      if (word.isEmpty) return word;
      
      // First word always capitalized
      if (i == 0) {
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      }
      
      // Keep short common words lowercase
      if (lowercaseWords.contains(word.toLowerCase())) {
        return word.toLowerCase();
      }
      
      // Capitalize first letter of other words
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
    
    return titleCased;
  }

  // NOTE: Legacy _parseJsonLd removed - only _parseJsonLdWithConfidence is used
  
  /// Parse JSON-LD with confidence scoring for review flow
  RecipeImportResult? _parseJsonLdWithConfidence(dynamic data, String sourceUrl) {
    // Handle @graph structure
    if (data is Map && data['@graph'] != null) {
      final graph = data['@graph'] as List;
      for (final item in graph) {
        final result = _parseJsonLdWithConfidence(item, sourceUrl);
        if (result != null) return result;
      }
      return null;
    }

    // Handle array of items
    if (data is List) {
      for (final item in data) {
        final result = _parseJsonLdWithConfidence(item, sourceUrl);
        if (result != null) return result;
      }
      return null;
    }

    // Check if this is a Recipe type
    if (data is! Map) {
      return null;
    }
    
    final type = data['@type'];
    final isRecipe = type == 'Recipe' || 
                     (type is List && type.contains('Recipe'));
    
    if (!isRecipe) {
      return null;
    }

    // Parse with confidence scoring
    final name = _cleanRecipeName(_parseString(data['name']) ?? '');
    final nameConfidence = name.isNotEmpty ? 0.9 : 0.0;

    // Parse ingredients and collect raw data
    // Use _extractRawIngredients first to rejoin incorrectly split ingredients (e.g., Diffords comma splits)
    // Support both JSON-LD format (recipeIngredient) and non-standard format (ingredients)
    var rawIngredientStrings = _extractRawIngredients(data['recipeIngredient']);
    // Fallback to non-standard keys if JSON-LD key not found
    if (rawIngredientStrings.isEmpty) {
      rawIngredientStrings = _extractRawIngredients(data['ingredients']);
    }
    // Filter out garbage (UI elements, ads, social media prompts) and deduplicate
    rawIngredientStrings = _filterIngredientStrings(rawIngredientStrings);
    // Parse from the already-rejoined raw strings, not the original JSON-LD
    var ingredients = _parseIngredients(rawIngredientStrings);
    ingredients = _sortIngredientsByQuantity(ingredients);
    
    // Calculate ingredients confidence based on how many we successfully parsed
    double ingredientsConfidence = 0.0;
    if (rawIngredientStrings.isNotEmpty) {
      ingredientsConfidence = ingredients.length / rawIngredientStrings.length;
      // Boost if ingredients have amounts
      final withAmounts = ingredients.where((i) => i.amount != null && i.amount!.isNotEmpty).length;
      if (ingredients.isNotEmpty) {
        ingredientsConfidence = (ingredientsConfidence + (withAmounts / ingredients.length)) / 2;
      }
    }

    // Parse directions with confidence
    // Support both JSON-LD format (recipeInstructions) and non-standard format (instructions)
    var directions = _parseInstructions(data['recipeInstructions']);
    var rawDirections = _extractRawDirections(data['recipeInstructions']);
    // Fallback to non-standard keys if JSON-LD key not found
    if (directions.isEmpty) {
      directions = _parseInstructions(data['instructions']);
      rawDirections = _extractRawDirections(data['instructions']);
    }
    // Filter out junk direction lines (ads, subscribe prompts, social media, etc.)
    directions = directions.where((d) => !_isJunkDirectionLine(d)).toList();
    rawDirections = rawDirections.where((d) => !_isJunkDirectionLine(d)).toList();
    
    double directionsConfidence = directions.isNotEmpty ? 0.8 : 0.0;
    // Boost if directions are detailed (more than a few words each)
    if (directions.isNotEmpty) {
      final avgWords = directions.map((d) => d.split(' ').length).reduce((a, b) => a + b) / directions.length;
      if (avgWords > 10) directionsConfidence = 0.9;
    }

    // Parse nutrition
    final nutrition = _parseNutrition(data['nutrition']);

    // Detect course with confidence
    final course = _guessCourse(data, sourceUrl: sourceUrl);
    final courseConfidence = _getCourseConfidence(data, sourceUrl);
    
    // Parse cuisine
    final cuisine = _parseCuisine(data['recipeCuisine']);
    final cuisineConfidence = cuisine != null ? 0.8 : 0.3;
    
    // Detect all possible courses and cuisines
    final detectedCourses = _detectAllCourses(data);
    final detectedCuisines = _detectAllCuisines(data);

    // Parse other fields
    final serves = _parseYield(data['recipeYield']);
    final servesConfidence = serves != null ? 0.9 : 0.0;
    
    final time = _parseTime(data);
    final timeConfidence = time != null ? 0.9 : 0.0;
    
    // Extract equipment from JSON-LD 'tool' field or look for equipment in description/keywords
    final equipmentList = _extractEquipmentFromJsonLd(data);

    // For drinks, detect the base spirit
    String? subcategory;
    if (course == 'Drinks') {
      subcategory = _detectSpirit(ingredients);
      if (subcategory != null) {
        subcategory = Spirit.toDisplayName(subcategory);
      }
    }

    // Create raw ingredient data
    final rawIngredients = _buildRawIngredients(rawIngredientStrings);

    // Build notes - combine description with editor's note if present
    String notes = _decodeHtml(_parseString(data['description']) ?? '');
    // Check for editor's note in meta (Punch style)
    final meta = data['meta'];
    if (meta is Map) {
      final editorsNote = _parseString(meta['editors_note'] ?? meta['editorsNote']);
      if (editorsNote != null && editorsNote.isNotEmpty) {
        final editorNoteText = "Editor's Note: ${_decodeHtml(editorsNote)}";
        notes = notes.isNotEmpty ? '$notes\n\n$editorNoteText' : editorNoteText;
      }
    }
    
    return RecipeImportResult(
      name: name.isNotEmpty ? name : null,
      course: course,
      cuisine: cuisine,
      subcategory: subcategory,
      serves: serves,
      time: time,
      ingredients: _filterParsedIngredients(ingredients),
      directions: directions,
      equipment: equipmentList,
      comments: notes,
      imageUrl: _parseImage(data['image']),
      nutrition: nutrition,
      rawIngredients: rawIngredients,
      rawDirections: rawDirections,
      detectedCourses: detectedCourses,
      detectedCuisines: detectedCuisines,
      nameConfidence: nameConfidence,
      courseConfidence: courseConfidence,
      cuisineConfidence: cuisineConfidence,
      ingredientsConfidence: ingredientsConfidence,
      directionsConfidence: directionsConfidence,
      servesConfidence: servesConfidence,
      timeConfidence: timeConfidence,
      sourceUrl: sourceUrl,
      source: RecipeSource.url,
    );
  }

  /// Extract raw ingredient strings without parsing
  List<String> _extractRawIngredients(dynamic value) {
    if (value == null) return [];
    if (value is String) return [_decodeHtml(value)];
    if (value is List) {
      final result = <String>[];
      for (final item in value) {
        if (item is String) {
          final decoded = _decodeHtml(item.trim());
          if (decoded.isNotEmpty) result.add(decoded);
        } else if (item is Map) {
          // Handle nested ingredient objects
          // Great British Chefs format: {groupName: "Section", unstructuredTextMetric: "1.5kg lamb shoulder"}
          // Check this FIRST because GBC items also have an 'ingredient' key (nested object with metadata)
          if (item.containsKey('unstructuredTextMetric') || item.containsKey('linkTextMetric')) {
            final groupName = _parseString(item['groupName']) ?? '';
            final ingredientText = _parseString(item['unstructuredTextMetric']) ??
                                   _parseString(item['linkTextMetric']) ?? '';
            
            // Add section header if we haven't seen this group yet
            if (groupName.isNotEmpty && (result.isEmpty || !result.last.contains('[$groupName]'))) {
              // Check if we already have this section
              final sectionHeader = '[$groupName]';
              if (!result.contains(sectionHeader)) {
                result.add(sectionHeader);
              }
            }
            
            if (ingredientText.isNotEmpty) {
              result.add(_decodeHtml(ingredientText.trim()));
            }
          }
          // Saveur/WordPress ACF format: {ingredient: "name", quantity: "2", measurement: "cups"}
          // Note: 'ingredient' must be a string, not an object (GBC has ingredient as object)
          else if (item.containsKey('ingredient') && item['ingredient'] is String) {
            final quantity = _parseString(item['quantity']) ?? '';
            final measurement = _parseString(item['measurement']) ?? '';
            final ingredientName = _parseString(item['ingredient']) ?? '';
            if (ingredientName.isNotEmpty) {
              final parts = <String>[];
              if (quantity.isNotEmpty) parts.add(quantity);
              if (measurement.isNotEmpty) parts.add(measurement);
              parts.add(ingredientName);
              result.add(_decodeHtml(parts.join(' ').trim()));
            }
          }
          // Saveur/WordPress ACF format with sections: {title: "Section", items: [...]} 
          // Items can contain {ingredient, quantity, measurement} objects
          else if (item.containsKey('items')) {
            final sectionTitle = _parseString(item['title'] ?? item['section_title']) ?? '';
            if (sectionTitle.isNotEmpty) {
              result.add('[$sectionTitle]'); // Add section header
            }
            final items = item['items'] ?? item['section_items'];
            if (items is List) {
              for (final subItem in items) {
                if (subItem is Map) {
                  // Handle {ingredient, quantity, measurement} format within items
                  if (subItem.containsKey('ingredient')) {
                    final quantity = _parseString(subItem['quantity']) ?? '';
                    final measurement = _parseString(subItem['measurement']) ?? '';
                    final ingredientName = _parseString(subItem['ingredient']) ?? '';
                    if (ingredientName.isNotEmpty) {
                      final parts = <String>[];
                      if (quantity.isNotEmpty) parts.add(quantity);
                      if (measurement.isNotEmpty) parts.add(measurement);
                      parts.add(ingredientName);
                      result.add(_decodeHtml(parts.join(' ').trim()));
                    }
                  } else {
                    // Fallback: try text/name field
                    final text = _parseString(subItem['text'] ?? subItem['name']) ?? '';
                    if (text.isNotEmpty) result.add(_decodeHtml(text));
                  }
                } else if (subItem is String) {
                  final decoded = _decodeHtml(subItem.trim());
                  if (decoded.isNotEmpty) result.add(decoded);
                }
              }
            }
          }
          // Standard JSON-LD or generic format with text field
          else {
            final text = _parseString(item['text'] ?? item['name']) ?? '';
            if (text.isNotEmpty) {
              result.add(_decodeHtml(text.trim()));
            }
          }
        } else {
          final decoded = _decodeHtml(item.toString().trim());
          if (decoded.isNotEmpty) result.add(decoded);
        }
      }
      
      // Post-process to rejoin incorrectly split ingredients
      // Some sites (like Diffords) incorrectly split ingredients on commas in their JSON-LD,
      // resulting in fragments like "(2", "1", ")" instead of "(2 sugar to 1 water, 65.0°Brix)"
      var items = _rejoinSplitIngredients(result);
      
      // Deduplicate ingredients (some sites like Saveur have same ingredient in HTML multiple times)
      items = _deduplicateIngredients(items);
      
      return items;
    }
    return [];
  }
  
  /// Deduplicate a list of ingredient strings while preserving order
  /// Some sites (like Saveur with MUI components) have the same ingredient in HTML multiple times
  /// This is section-aware: resets the "seen" set at each section header so legitimately
  /// repeated ingredients in different sections (e.g., "2 eggs" for cake and for creme anglaise)
  /// are preserved
  List<String> _deduplicateIngredients(List<String> items) {
    var seen = <String>{};
    final result = <String>[];
    for (final item in items) {
      // Check if this is a section header - if so, reset the seen set
      // Section headers are formatted as [Section Name] or end with ":"
      final trimmed = item.trim();
      if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
        seen = <String>{}; // Reset for new section
        result.add(item);
        continue;
      }
      if (trimmed.endsWith(':') && trimmed.length < 50 && !RegExp(r'\d').hasMatch(trimmed)) {
        // Looks like a section header (e.g., "For the filling:")
        seen = <String>{}; // Reset for new section
        result.add(item);
        continue;
      }
      
      // Normalize for comparison: lowercase, collapse whitespace
      final normalized = trimmed.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      if (normalized.isEmpty) continue;
      if (seen.contains(normalized)) continue;
      seen.add(normalized);
      result.add(item);
    }
    return result;
  }
  
  /// Rejoin ingredient items that were incorrectly split (usually on commas)
  /// Detects fragments like "(2", "1", ")" and rejoins them with the previous complete ingredient
  List<String> _rejoinSplitIngredients(List<String> items) {
    if (items.length <= 1) return items;
    
    final result = <String>[];
    var buffer = '';
    int openParens = 0;
    
    for (final item in items) {
      // Count parentheses
      final openCount = item.split('(').length - 1;
      final closeCount = item.split(')').length - 1;
      
      // Check if this looks like a fragment that should be rejoined:
      // 1. Very short (like "1", ")", "(2")
      // 2. Just numbers, punctuation, degree symbols
      // 3. Just a parenthesis
      // 4. Starts with a number but no unit (like "65.0°Brix)" - partial measurement)
      // 5. We're currently inside unbalanced parentheses
      final looksLikeFragment = 
          item.length <= 3 ||
          RegExp(r'^[\d.,°\s]+$').hasMatch(item) ||
          RegExp(r'^[()]$').hasMatch(item) ||
          RegExp(r'^\d+\.?\d*°').hasMatch(item) ||  // Starts with degree measurement like "65.0°Brix"
          (item.startsWith(')') && buffer.isNotEmpty) ||  // Starts with closing paren
          (buffer.isNotEmpty && openParens > 0);
      
      // Also check if this item lacks typical ingredient structure
      // A valid ingredient usually starts with a number+unit or an ingredient name (letters)
      final lacksIngredientStructure = buffer.isNotEmpty && (
          !RegExp(r'^[\d½¼¾⅓⅔⅛⅜⅝⅞]+\s*(?:ml|g|oz|tsp|tbsp|cup|dash|drop|cl|l|kg|lb|pound|ounce|teaspoon|tablespoon)s?\b', caseSensitive: false).hasMatch(item) &&
          !RegExp(r'^[A-Za-z][A-Za-z\s]{2,}').hasMatch(item) &&
          item.length < 15
      );
      
      if (buffer.isEmpty) {
        buffer = item;
        openParens = openCount - closeCount;
      } else if (looksLikeFragment || openParens > 0 || lacksIngredientStructure) {
        // This is a continuation - rejoin with comma (since that's likely how it was split)
        buffer = '$buffer, $item';
        openParens += openCount - closeCount;
      } else {
        // This is a new complete ingredient
        result.add(buffer);
        buffer = item;
        openParens = openCount - closeCount;
      }
    }
    
    // Don't forget the last item
    if (buffer.isNotEmpty) {
      result.add(buffer);
    }
    
    return result;
  }

  /// Extract equipment from JSON-LD data
  /// Schema.org Recipe can have 'tool' field for equipment
  List<String> _extractEquipmentFromJsonLd(Map data) {
    final equipment = <String>[];
    
    // Check 'tool' field (schema.org standard)
    final tool = data['tool'];
    if (tool != null) {
      if (tool is String && tool.isNotEmpty) {
        equipment.add(_decodeHtml(tool));
      } else if (tool is List) {
        for (final item in tool) {
          if (item is String && item.isNotEmpty) {
            equipment.add(_decodeHtml(item));
          } else if (item is Map) {
            final name = _parseString(item['name']) ?? _parseString(item['text']);
            if (name != null && name.isNotEmpty) {
              equipment.add(_decodeHtml(name));
            }
          }
        }
      }
    }
    
    // Check 'recipeEquipment' (non-standard but used by some sites)
    final recipeEquipment = data['recipeEquipment'];
    if (recipeEquipment != null) {
      if (recipeEquipment is String && recipeEquipment.isNotEmpty) {
        equipment.add(_decodeHtml(recipeEquipment));
      } else if (recipeEquipment is List) {
        for (final item in recipeEquipment) {
          if (item is String && item.isNotEmpty) {
            equipment.add(_decodeHtml(item));
          } else if (item is Map) {
            final name = _parseString(item['name']) ?? _parseString(item['text']);
            if (name != null && name.isNotEmpty) {
              equipment.add(_decodeHtml(name));
            }
          }
        }
      }
    }
    
    return equipment;
  }

  /// Extract raw direction strings
  List<String> _extractRawDirections(dynamic value) {
    if (value == null) return [];
    if (value is String) return [_decodeHtml(value)];
    if (value is List) {
      return value.map((item) {
        if (item is String) return _decodeHtml(item.trim());
        if (item is Map) {
          return _decodeHtml(_parseString(item['text']) ?? _parseString(item['name']) ?? item.toString());
        }
        return _decodeHtml(item.toString().trim());
      }).where((s) => s.isNotEmpty).toList();
    }
    return [];
  }

  /// Get confidence score for course detection
  double _getCourseConfidence(Map data, String? sourceUrl) {
    final category = _parseString(data['recipeCategory'])?.toLowerCase();
    
    // High confidence if category is explicitly set
    if (category != null && category.isNotEmpty) {
      if (_isCocktailSite(sourceUrl ?? '')) return 0.95;
      if (category.contains('dessert') || category.contains('soup') || 
          category.contains('salad') || category.contains('main')) {
        return 0.85;
      }
      return 0.7;
    }
    
    // Medium confidence if we can infer from keywords
    final keywords = _parseString(data['keywords'])?.toLowerCase() ?? '';
    if (keywords.contains('dessert') || keywords.contains('main') || 
        keywords.contains('appetizer')) {
      return 0.6;
    }
    
    // Low confidence - just guessing
    return 0.4;
  }

  /// Detect all possible course categories from recipe data
  List<String> _detectAllCourses(Map data) {
    final courses = <String>{};
    final category = _parseString(data['recipeCategory'])?.toLowerCase() ?? '';
    final keywords = _parseString(data['keywords'])?.toLowerCase() ?? '';
    final allText = '$category $keywords';
    
    if (allText.contains('dessert') || allText.contains('sweet')) courses.add('Desserts');
    if (allText.contains('appetizer') || allText.contains('starter')) courses.add('Apps');
    if (allText.contains('soup')) courses.add('Soups');
    if (allText.contains('salad') || allText.contains('side')) courses.add('Sides');
    if (allText.contains('bread')) courses.add('Breads');
    if (allText.contains('breakfast') || allText.contains('brunch')) courses.add('Brunch');
    if (allText.contains('main') || allText.contains('dinner') || allText.contains('entrée')) courses.add('Mains');
    if (allText.contains('sauce') || allText.contains('dressing')) courses.add('Sauces');
    if (allText.contains('drink') || allText.contains('cocktail') || allText.contains('beverage')) courses.add('Drinks');
    
    // Only add Veg'n if category explicitly mentions it (not just keywords like "Vegan" which are often dietary info)
    if (category.contains('vegetarian') || category.contains('vegan')) courses.add("Veg'n");
    
    // Always include Mains as default option
    if (courses.isEmpty) courses.add('Mains');
    
    return courses.toList()..sort();
  }

  /// Detect all possible cuisines from recipe data
  /// Only uses the recipeCuisine field - doesn't infer from keywords/name to avoid false positives
  List<String> _detectAllCuisines(Map data) {
    final cuisines = <String>{};
    final cuisine = _parseString(data['recipeCuisine'])?.toLowerCase() ?? '';
    if (cuisine.isEmpty) return [];
    
    // Check for cuisine indicators
    final cuisineIndicators = {
      'french': 'France', 'italian': 'Italy', 'spanish': 'Spain',
      'mexican': 'Mexico', 'chinese': 'China', 'japanese': 'Japan',
      'korean': 'Korea', 'thai': 'Thailand', 'vietnamese': 'Vietnam',
      'indian': 'India', 'greek': 'Greece', 'mediterranean': 'Mediterranean',
      'middle eastern': 'Middle East', 'moroccan': 'Morocco',
      'caribbean': 'Caribbean', 'brazilian': 'Brazil',
    };
    
    cuisineIndicators.forEach((indicator, cuisineName) {
      if (cuisine.contains(indicator)) {
        cuisines.add(cuisineName);
      }
    });
    
    return cuisines.toList()..sort();
  }

  String? _parseString(dynamic value) {
    if (value == null) return null;
    if (value is String) return _decodeHtml(value.trim());
    if (value is List && value.isNotEmpty) return _decodeHtml(value.first.toString().trim());
    return _decodeHtml(value.toString().trim());
  }

  String? _parseYield(dynamic value) {
    if (value == null) return null;
    
    String? raw;
    if (value is String) {
      raw = _decodeHtml(value);
    } else if (value is num) {
      return value.toString();
    } else if (value is List && value.isNotEmpty) {
      raw = _decodeHtml(value.first.toString());
    }
    
    if (raw == null) return null;
    
    // Check for "(X servings)" pattern first - common in King Arthur, etc.
    // e.g., "one 9" x 4" loaf (16 servings)" -> "16"
    final parenServingsMatch = RegExp(r'\((\d+)\s*(?:servings?|portions?)\)', caseSensitive: false).firstMatch(raw);
    if (parenServingsMatch != null) {
      return parenServingsMatch.group(1);
    }
    
    // Check for "X servings" pattern anywhere in string
    final servingsMatch = RegExp(r'(\d+)\s*(?:servings?|portions?)', caseSensitive: false).firstMatch(raw);
    if (servingsMatch != null) {
      return servingsMatch.group(1);
    }
    
    // Strip common prefixes like "Servings:", "Serves:", "Yield:", "Makes:"
    raw = raw.replaceFirst(RegExp(r'^(?:Servings?|Serves?|Yield|Makes?)\s*:?\s*', caseSensitive: false), '').trim();
    
    // Extract just the number from strings like "16 per loaf", "4 servings", "makes 12"
    // First try to find a number at the start
    final leadingNumber = RegExp(r'^(\d+(?:\.\d+)?)').firstMatch(raw.trim());
    if (leadingNumber != null) {
      return leadingNumber.group(1);
    }
    
    // Try "makes X" pattern
    final makesMatch = RegExp(r'makes\s+(\d+)', caseSensitive: false).firstMatch(raw);
    if (makesMatch != null) {
      return makesMatch.group(1);
    }
    
    // Strip trailing "servings" or "portions"
    raw = raw.replaceFirst(RegExp(r'\s+(?:servings?|portions?)$', caseSensitive: false), '').trim();
    
    return raw;
  }

  /// Parse cuisine - validate against standardized list and map regional terms
  /// 
  /// Uses Cuisine.validateForImport() to:
  /// 1. Map regional terms to parent cuisines (e.g., "Sichuan" -> "Chinese")
  /// 2. Validate against the standardized cuisine list
  /// 3. Return null for unrecognized values (will show as empty in review screen)
  String? _parseCuisine(dynamic value) {
    if (value == null) return null;
    
    final cuisine = _parseString(value);
    if (cuisine == null || cuisine.isEmpty) return null;
    
    // Use the centralized cuisine validation which:
    // - Maps regions to parent cuisines (Sichuan -> Chinese)
    // - Validates against known cuisines
    // - Returns null for invalid values
    return Cuisine.validateForImport(cuisine);
  }

  String _capitalise(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  /// Convert text to Title Case (capitalize first letter of each word)
  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      // Keep short words lowercase unless they're the first word
      final lower = word.toLowerCase();
      if (lower == 'a' || lower == 'an' || lower == 'the' || lower == 'of' || 
          lower == 'in' || lower == 'on' || lower == 'at' || lower == 'to' ||
          lower == 'for' || lower == 'and' || lower == 'or' || lower == 'with') {
        return lower;
      }
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).toList().asMap().entries.map((e) {
      // Always capitalize first word
      if (e.key == 0 && e.value.isNotEmpty) {
        return e.value[0].toUpperCase() + e.value.substring(1);
      }
      return e.value;
    }).join(' ');
  }

  /// Normalize serves/yield string - extract just the serving count number
  String _normalizeServes(String text) {
    var cleaned = text.trim();
    
    // Check for "(X servings)" pattern first - common in King Arthur, etc.
    // e.g., "one 9" x 4" loaf (16 servings)" -> "16"
    final parenServingsMatch = RegExp(r'\((\d+)\s*(?:servings?|portions?)\)', caseSensitive: false).firstMatch(cleaned);
    if (parenServingsMatch != null) {
      return parenServingsMatch.group(1) ?? cleaned;
    }
    
    // Check for "X servings" or "serves X" pattern
    final servingsMatch = RegExp(r'(\d+)\s*(?:servings?|portions?)', caseSensitive: false).firstMatch(cleaned);
    if (servingsMatch != null) {
      return servingsMatch.group(1) ?? cleaned;
    }
    
    final servesMatch = RegExp(r'(?:serves?|yields?|makes?)\s*:?\s*(\d+)', caseSensitive: false).firstMatch(cleaned);
    if (servesMatch != null) {
      return servesMatch.group(1) ?? cleaned;
    }
    
    // Strip common prefixes
    cleaned = cleaned.replaceFirst(RegExp(r'^(?:Servings?|Serves?|Yield|Makes?)\s*:?\s*', caseSensitive: false), '');
    // Strip trailing labels like "servings" from "4 servings"
    cleaned = cleaned.replaceFirst(RegExp(r'\s+(?:servings?|portions?)$', caseSensitive: false), '');
    
    // If what remains is a simple number, return it
    final simpleNumber = RegExp(r'^(\d+)$').firstMatch(cleaned.trim());
    if (simpleNumber != null) {
      return simpleNumber.group(1) ?? cleaned;
    }
    
    // If there's a number at the start, extract it (e.g., "4-6" -> "4-6", "4 people" -> "4")
    final leadingNumber = RegExp(r'^(\d+(?:\s*-\s*\d+)?)').firstMatch(cleaned.trim());
    if (leadingNumber != null) {
      return leadingNumber.group(1) ?? cleaned;
    }
    
    return cleaned.trim();
  }

  /// Split garnish text intelligently - handles "X or Y" as separate items
  /// e.g., "orange or lemon peel" becomes ["Orange Peel", "Lemon Peel"]
  List<String> _splitGarnishText(String text) {
    if (text.isEmpty) return [];
    
    // First split by comma
    final commaSplit = text.split(RegExp(r',\s*'));
    final result = <String>[];
    
    for (final part in commaSplit) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      
      // Check for "X or Y" pattern where they share a common suffix
      // e.g., "orange or lemon peel" -> "orange peel", "lemon peel"
      final orMatch = RegExp(r'^(.+?)\s+or\s+(.+)$', caseSensitive: false).firstMatch(trimmed);
      if (orMatch != null) {
        final firstPart = orMatch.group(1)?.trim() ?? '';
        final secondPart = orMatch.group(2)?.trim() ?? '';
        
        // Check if second part has a suffix that should apply to first
        // e.g., "orange or lemon peel" - "peel" is the shared suffix
        final words = secondPart.split(' ');
        if (words.length > 1) {
          // Assume last word(s) are shared suffix
          final lastWord = words.last;
          // Check if first part is missing the suffix type word
          if (!firstPart.toLowerCase().contains(lastWord.toLowerCase())) {
            // Add the suffix to the first option
            result.add('$firstPart $lastWord');
            result.add(secondPart);
          } else {
            // Both are complete, add separately
            result.add(firstPart);
            result.add(secondPart);
          }
        } else {
          // Simple "X or Y" - both are complete items
          result.add(firstPart);
          result.add(secondPart);
        }
      } else {
        result.add(trimmed);
      }
    }
    
    return result.where((s) => s.isNotEmpty).map((s) => normalizeGarnish(s)).toList();
  }

  /// Parse nutrition information from schema.org NutritionInformation
  NutritionInfo? _parseNutrition(dynamic data) {
    if (data == null) return null;
    if (data is! Map) return null;
    
    // Parse nutrition values - they may be strings like "150 calories" or numbers
    final nutrition = NutritionInfo.create(
      servingSize: _parseString(data['servingSize']),
      calories: _parseNutritionValue(data['calories'])?.round(),
      fatContent: _parseNutritionValue(data['fatContent']),
      saturatedFatContent: _parseNutritionValue(data['saturatedFatContent']),
      transFatContent: _parseNutritionValue(data['transFatContent']),
      cholesterolContent: _parseNutritionValue(data['cholesterolContent']),
      sodiumContent: _parseNutritionValue(data['sodiumContent']),
      carbohydrateContent: _parseNutritionValue(data['carbohydrateContent']),
      fiberContent: _parseNutritionValue(data['fiberContent']),
      sugarContent: _parseNutritionValue(data['sugarContent']),
      proteinContent: _parseNutritionValue(data['proteinContent']),
    );
    
    return nutrition.hasData ? nutrition : null;
  }

  /// Parse a nutrition value that might be a number or string like "20 g"
  double? _parseNutritionValue(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      // Extract number from strings like "20 g", "150 kcal", etc.
      final match = RegExp(r'([\d.]+)').firstMatch(value);
      if (match != null) {
        return double.tryParse(match.group(1)!);
      }
    }
    return null;
  }

  String? _parseTime(Map data) {
    // Prefer totalTime if available
    if (data['totalTime'] != null) {
      final total = _parseDuration(data['totalTime']);
      if (total != null) return total;
    }
    
    // Otherwise calculate from prep + cook
    int totalMinutes = 0;
    
    if (data['prepTime'] != null) {
      totalMinutes += _parseDurationMinutes(data['prepTime']);
    }
    
    if (data['cookTime'] != null) {
      totalMinutes += _parseDurationMinutes(data['cookTime']);
    }
    
    if (totalMinutes > 0) {
      return _formatMinutes(totalMinutes);
    }
    
    return null;
  }

  int _parseDurationMinutes(dynamic value) {
    if (value == null) return 0;
    var str = value.toString().toLowerCase().trim();
    
    // Normalize malformed ISO 8601 durations
    // Some sites use "PT1hour5M" instead of "PT1H5M"
    str = str.replaceAll(RegExp(r'hours?'), 'h');
    str = str.replaceAll(RegExp(r'minutes?|mins?'), 'm');
    str = str.replaceAll(RegExp(r'seconds?|secs?'), 's');
    
    // Parse full ISO 8601 duration format (e.g., P0Y0M0DT0H35M0.000S, PT30M, PT1H30M)
    final fullIsoRegex = RegExp(
      r'p(?:(\d+)y)?(?:(\d+)m)?(?:(\d+)d)?(?:t(?:(\d+)h)?(?:(\d+)m)?(?:[\d.]+s)?)?',
      caseSensitive: false,
    );
    final isoMatch = fullIsoRegex.firstMatch(str);
    
    if (isoMatch != null) {
      final years = int.tryParse(isoMatch.group(1) ?? '') ?? 0;
      final months = int.tryParse(isoMatch.group(2) ?? '') ?? 0;
      final days = int.tryParse(isoMatch.group(3) ?? '') ?? 0;
      final hours = int.tryParse(isoMatch.group(4) ?? '') ?? 0;
      final minutes = int.tryParse(isoMatch.group(5) ?? '') ?? 0;
      
      // Convert to total minutes
      final totalMinutes = (years * 365 * 24 * 60) + (months * 30 * 24 * 60) + 
                           (days * 24 * 60) + (hours * 60) + minutes;
      if (totalMinutes > 0) {
        return totalMinutes;
      }
    }

    // Pure number => treat as minutes
    final pureNumber = int.tryParse(str);
    if (pureNumber != null) {
      return pureNumber;
    }

    // Extract days/hours/minutes from textual formats (e.g., "6 hours 20 minutes", "380 min")
    final daysMatch = RegExp(r'(\d+)\s*days?').firstMatch(str);
    final hoursMatch = RegExp(r'(\d+)\s*(hours?|hrs?|h)').firstMatch(str);
    final minsMatch = RegExp(r'(\d+)\s*(minutes?|mins?|min|m)').firstMatch(str);
    int days = 0, hours = 0, minutes = 0;
    if (daysMatch != null) {
      days = int.tryParse(daysMatch.group(1) ?? '') ?? 0;
    }
    if (hoursMatch != null) {
      hours = int.tryParse(hoursMatch.group(1) ?? '') ?? 0;
    }
    if (minsMatch != null) {
      minutes = int.tryParse(minsMatch.group(1) ?? '') ?? 0;
    }
    
    if (days > 0 || hours > 0 || minutes > 0) {
      return days * 1440 + hours * 60 + minutes;
    }

    return 0;
  }

  String? _parseDuration(dynamic value) {
    if (value == null) return null;
    var str = value.toString();
    
    // Normalize malformed ISO 8601 durations
    // Some sites use "PT1hour5M" instead of "PT1H5M"
    // Also handle "PT1hours30minutes" variants
    str = str.replaceAll(RegExp(r'hours?', caseSensitive: false), 'H');
    str = str.replaceAll(RegExp(r'minutes?|mins?', caseSensitive: false), 'M');
    str = str.replaceAll(RegExp(r'seconds?|secs?', caseSensitive: false), 'S');
    
    // Parse full ISO 8601 duration format (e.g., P0Y0M0DT0H35M0.000S, PT30M, PT1H30M)
    // Format: P[n]Y[n]M[n]DT[n]H[n]M[n]S where each component is optional
    // FoodNetwork uses: P0Y0M0DT0H35M0.000S
    final fullIsoRegex = RegExp(
      r'P(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:[\d.]+S)?)?',
      caseSensitive: false,
    );
    final fullMatch = fullIsoRegex.firstMatch(str);
    
    if (fullMatch != null) {
      final years = int.tryParse(fullMatch.group(1) ?? '') ?? 0;
      final months = int.tryParse(fullMatch.group(2) ?? '') ?? 0;
      final days = int.tryParse(fullMatch.group(3) ?? '') ?? 0;
      final hours = int.tryParse(fullMatch.group(4) ?? '') ?? 0;
      final minutes = int.tryParse(fullMatch.group(5) ?? '') ?? 0;
      
      // Convert to total minutes (approximate: 1 month = 30 days, 1 year = 365 days)
      final totalMinutes = (years * 365 * 24 * 60) + (months * 30 * 24 * 60) + 
                           (days * 24 * 60) + (hours * 60) + minutes;
      if (totalMinutes > 0) {
        return _formatMinutes(totalMinutes);
      }
    }
    
    // Fallback: parse non-ISO strings like "380 minutes", "6 hours 20 minutes"
    final lowered = str.toLowerCase().trim();
    // Pure number => treat as minutes
    final pureNumber = int.tryParse(lowered);
    if (pureNumber != null) {
      return _formatMinutes(pureNumber);
    }

    // Extract hours and minutes from text
    final hoursMatch = RegExp(r'(\d+)\s*(hours?|hrs?|h)').firstMatch(lowered);
    final minsMatch = RegExp(r'(\d+)\s*(minutes?|mins?|min|m)').firstMatch(lowered);
    int hours = 0;
    int minutes = 0;
    if (hoursMatch != null) {
      hours = int.tryParse(hoursMatch.group(1) ?? '') ?? 0;
    }
    if (minsMatch != null) {
      minutes = int.tryParse(minsMatch.group(1) ?? '') ?? 0;
    }
    if (hours > 0 || minutes > 0) {
      final totalMinutes = hours * 60 + minutes;
      return _formatMinutes(totalMinutes);
    }

    // Days support: "1 day 2 hours"
    final daysMatch = RegExp(r'(\d+)\s*days?').firstMatch(lowered);
    if (daysMatch != null) {
      final days = int.tryParse(daysMatch.group(1) ?? '') ?? 0;
      // try also to capture any hours/mins if present
      final hrs = hoursMatch != null ? (int.tryParse(hoursMatch.group(1)!) ?? 0) : 0;
      final mins = minsMatch != null ? (int.tryParse(minsMatch.group(1)!) ?? 0) : 0;
      return _formatMinutes(days * 1440 + hrs * 60 + mins);
    }

    // If nothing matched, return cleaned original
    return lowered;
  }

  /// Format minutes as compact days/hours/minutes (e.g., 380 -> 6 hr 20 min)
  String _formatMinutes(int totalMinutes) {
    if (totalMinutes <= 0) return '0 min';
    final days = totalMinutes ~/ 1440;
    final remAfterDays = totalMinutes % 1440;
    final hours = remAfterDays ~/ 60;
    final mins = remAfterDays % 60;
    final parts = <String>[];
    if (days > 0) parts.add('$days day${days > 1 ? 's' : ''}');
    if (hours > 0) parts.add('$hours hr');
    if (mins > 0) parts.add('$mins min');
    return parts.join(' ');
  }

  List<Ingredient> _parseIngredients(dynamic value) {
    if (value == null) return [];
    
    List<String> items;
    if (value is String) {
      items = [value];
    } else if (value is List) {
      items = value.map((e) => e.toString()).toList();
    } else {
      return [];
    }

    // Detect sections - some sites prefix ingredients with section headers
    // Common patterns: "For the sauce:", "Sauce:", "Main Ingredients:", "[Section]", etc.
    String? currentSection;
    final result = <Ingredient>[];
    
    for (final item in items) {
      final decoded = _decodeHtml(item.trim());
      if (decoded.isEmpty) continue;
      
      // First check for bracketed section format [Section Name] from _processIngredientListItems
      final bracketMatch = RegExp(r'^\[(.+)\]$').firstMatch(decoded);
      if (bracketMatch != null) {
        currentSection = bracketMatch.group(1)?.trim();
        continue;  // Skip to next item - this was just a section header
      }
      
      // Check if this is a section header (no amount, ends with colon, or "For the X" pattern)
      // Also check for short standalone items that look like headers
      final sectionPatterns = [
        RegExp(r'^For\s+(?:the\s+)?(.+?)[:.]?\s*$', caseSensitive: false),  // "For the sauce:"
        RegExp(r'^(.+?)\s+[Ii]ngredients?[:.]?\s*$'),  // "Main ingredients:"
        RegExp(r'^(.+?)\s+[Ss]auce[:.]?\s*$'),  // "Spicy ketchup sauce:"
        RegExp(r'^(.+?)\s+[Mm]arinade[:.]?\s*$'),  // "Tofu marinade:"
        RegExp(r'^(.+?)\s+[Gg]laze[:.]?\s*$'),  // "Honey glaze:"
        RegExp(r'^(.+?)\s+[Ss]easoning[:.]?\s*$'),  // "Spice seasoning:"
        RegExp(r'^(.+?)\s+[Rr]ub[:.]?\s*$'),  // "Spice rub:"
        RegExp(r'^(.+?)\s+[Tt]opping[s]?[:.]?\s*$'),  // "Toppings:"
        RegExp(r'^(.+?)\s+[Gg]arnish[:.]?\s*$'),  // "Garnish:"
        RegExp(r'^(.+?)\s+[Ff]illing[:.]?\s*$'),  // "Filling:"
        RegExp(r'^(.+?)[:–—]\s*$'),  // General "Something:" (must end with colon/dash)
      ];
      
      bool isSection = false;
      for (final pattern in sectionPatterns) {
        final match = pattern.firstMatch(decoded);
        if (match != null) {
          // Verify it's not an ingredient (no numbers at start)
          if (!RegExp(r'^[\d½¼¾⅓⅔⅛⅜⅝⅞⅕⅖⅗⅘⅙⅚]').hasMatch(decoded)) {
            currentSection = match.group(1)?.trim();
            isSection = true;
            break;
          }
        }
      }
      
      if (!isSection) {
        final ingredient = _parseIngredientString(decoded);
        // Skip empty ingredient names (pure section markers should not add blank lines)
        if (ingredient.name.isEmpty) {
          // But if it had a section, update the current section
          if (ingredient.section != null) {
            currentSection = ingredient.section;
          }
          continue;
        }
        if (ingredient.name.isNotEmpty) {
          // Update currentSection if ingredient has inline section
          if (ingredient.section != null) {
            currentSection = ingredient.section;
          }
          
          // Apply current section to this ingredient (inline or header-based)
          final effectiveSection = ingredient.section ?? currentSection;
          if (effectiveSection != null && effectiveSection != ingredient.section) {
            result.add(Ingredient.create(
              name: ingredient.name,
              amount: ingredient.amount,
              unit: ingredient.unit,
              preparation: ingredient.preparation,
              alternative: ingredient.alternative,
              isOptional: ingredient.isOptional,
              section: effectiveSection,
            ),);
          } else {
            result.add(ingredient);
          }
        }
      }
    }
    
    return result;
  }

  /// Extract baker's percentage from ingredient string if present
  /// Returns the percentage value (e.g., "100", "75", "3.3") or null
  String? _extractBakerPercent(String text) {
    final match = RegExp(
      r'^[^,]+,\s*([\d.]+)%\s*[–—-]',  // en-dash, em-dash, or hyphen
      caseSensitive: false,
    ).firstMatch(text);
    return match?.group(1);
  }

  /// Detect if a string is a section header (not an ingredient)
  /// Returns the section name if it's a header, null otherwise
  String? _detectSectionHeader(String text) {
    final decoded = _decodeHtml(text.trim());
    if (decoded.isEmpty) return null;
    
    // If it starts with a number/fraction, it's likely an ingredient
    if (RegExp(r'^[\d½¼¾⅓⅔⅛⅜⅝⅞⅕⅖⅗⅘⅙⅚]').hasMatch(decoded)) {
      return null;
    }
    
    // Bracketed section format [Section Name]
    final bracketMatch = RegExp(r'^\[(.+)\]$').firstMatch(decoded);
    if (bracketMatch != null) {
      return bracketMatch.group(1)?.trim();
    }
    
    // Common section patterns with explicit suffixes
    final sectionPatterns = [
      RegExp(r'^For\s+(?:the\s+)?(.+?)[:.]?\s*$', caseSensitive: false),  // "For the sauce:"
      RegExp(r'^(.+?)\s+[Ii]ngredients?[:.]?\s*$'),  // "Main ingredients:"
      RegExp(r'^(.+?)\s+[Ss]auce[:.]?\s*$'),  // "Spicy ketchup sauce:"
      RegExp(r'^(.+?)\s+[Mm]arinade[:.]?\s*$'),  // "Tofu marinade:"
      RegExp(r'^(.+?)\s+[Gg]laze[:.]?\s*$'),  // "Honey glaze:"
      RegExp(r'^(.+?)\s+[Ss]easoning[:.]?\s*$'),  // "Spice seasoning:"
      RegExp(r'^(.+?)\s+[Rr]ub[:.]?\s*$'),  // "Spice rub:"
      RegExp(r'^(.+?)\s+[Tt]opping[s]?[:.]?\s*$'),  // "Toppings:"
      RegExp(r'^(.+?)\s+[Gg]arnish[:.]?\s*$'),  // "Garnish:"
      RegExp(r'^(.+?)\s+[Ff]illing[:.]?\s*$'),  // "Filling:"
      RegExp(r'^(.+?)[:–—]\s*$'),  // General "Something:" (must end with colon/dash)
    ];
    
    for (final pattern in sectionPatterns) {
      final match = pattern.firstMatch(decoded);
      if (match != null) {
        return match.group(1)?.trim() ?? decoded;
      }
    }
    
    // Short standalone words that are likely section headers (King Arthur style)
    // Must be short (< 40 chars), no commas (ingredients often have commas),
    // and match common section names
    if (decoded.length < 40 && !decoded.contains(',')) {
      final lower = decoded.toLowerCase();
      const sectionKeywords = [
        'dough', 'batter', 'filling', 'topping', 'frosting', 'icing', 'glaze',
        'crust', 'base', 'sauce', 'marinade', 'rub', 'seasoning', 'garnish',
        'assembly', 'finish', 'decoration', 'streusel', 'crumb', 'coating',
        'syrup', 'caramel', 'ganache', 'cream', 'custard', 'curd', 'compote',
      ];
      // Check if any section keyword is in the text
      for (final keyword in sectionKeywords) {
        if (lower.contains(keyword)) {
          // Return the original text (cleaned) as the section name
          return decoded;
        }
      }
    }
    
    return null;
  }

  /// Build a list of RawIngredientData from raw ingredient strings
  /// This is the single source of truth for creating raw ingredient data
  /// across all import sources (JSON-LD, HTML, YouTube, etc.)
  List<RawIngredientData> _buildRawIngredients(List<String> rawStrings) {
    final result = <RawIngredientData>[];
    
    for (final raw in rawStrings) {
      // Skip completely empty strings
      if (raw.trim().isEmpty) {
        continue;
      }
      
      final parsed = _parseIngredientString(raw);
      final bakerPct = _extractBakerPercent(raw);
      
      // Check if this raw string is a section header
      final detectedSection = _detectSectionHeader(raw);
      final effectiveSection = parsed.section ?? detectedSection;
      
      // Determine if this is a section-only entry (no actual ingredient)
      final isSectionOnly = (parsed.name.isEmpty && effectiveSection != null) ||
                            (detectedSection != null && parsed.amount == null && parsed.unit == null);
      
      // Clean the fallback raw string by removing footnote markers (*, †, [1], etc.)
      final cleanedRaw = raw.replaceAll(RegExp(r'^[\*†]+|[\*†]+$|\[\d+\]'), '').trim();
      
      // Determine the name to use
      String name;
      if (isSectionOnly) {
        name = '';  // Section-only entries have empty name
      } else if (parsed.name.isNotEmpty) {
        name = parsed.name;
      } else {
        name = cleanedRaw;
      }
      
      // Skip entries that have no meaningful name and no section
      // This is the key filter that prevents blank rows
      if (name.trim().isEmpty && effectiveSection == null) {
        continue;
      }
      if (name.trim().isNotEmpty && !RegExp(r'[a-zA-Z0-9]').hasMatch(name)) {
        continue;
      }
      
      result.add(RawIngredientData(
        original: raw,
        amount: isSectionOnly ? null : parsed.amount,
        unit: isSectionOnly ? null : parsed.unit,
        preparation: isSectionOnly ? null : parsed.preparation,
        bakerPercent: isSectionOnly ? null : (bakerPct != null ? '$bakerPct%' : null),
        name: name,
        looksLikeIngredient: parsed.name.isNotEmpty && !isSectionOnly,
        isSection: effectiveSection != null,
        sectionName: effectiveSection,
      ));
    }
    
    return result;
  }

  /// Parse a single ingredient string into structured data
  Ingredient _parseIngredientString(String text) {
    var remaining = text;
    bool isOptional = false;
    final List<String> notesParts = [];
    String? amount;
    String? inlineSection;
    
    // Handle "Optional:" prefix at the start of ingredient line
    // e.g., "Optional: 1/4 tsp calcium chloride (aka Pickle Crisp granules)"
    // -> amount: "1/4 tsp", name: "Calcium Chloride", preparation: "optional, aka Pickle Crisp granules"
    final optionalPrefixMatch = RegExp(
      r'^Optional\s*:\s*',
      caseSensitive: false,
    ).firstMatch(remaining);
    if (optionalPrefixMatch != null) {
      isOptional = true;
      remaining = remaining.substring(optionalPrefixMatch.end).trim();
      notesParts.add('optional');
    }
    
    // Handle "Top up with [Ingredient]" format (Difford's style)
    // e.g., "Top up with Thomas Henry Soda Water" -> name: "Thomas Henry Soda Water", amount: "Top"
    final topUpWithMatch = RegExp(
      r'^Top\s+(?:up\s+)?with\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(remaining);
    if (topUpWithMatch != null) {
      final name = topUpWithMatch.group(1)?.trim() ?? '';
      return Ingredient.create(
        name: _cleanIngredientName(name),
        amount: 'Top',
      );
    }
    
    // Handle Seedlip/cocktail format: "Name: amount / metric" 
    // e.g., "Seedlip Grove 42: 1.75 oz / 53ml" or "Marmalade Cordial*: 1 oz / 30 ml"
    // Also handles "Cold Sparkling Water: Top" where "Top" means "top up"
    // Also handles unicode fractions like "Fresh lime juice: ½ oz"
    final colonAmountMatch = RegExp(
      r'^([^:]+):\s*([\d.½¼¾⅓⅔⅛⅜⅝⅞]+\s*(?:oz|ml|cl|dash|dashes|drops?|barspoons?|tsp|tbsp)\.?|Top(?:\s+up)?|to\s+taste|as\s+needed)\s*(?:/\s*([\d.½¼¾⅓⅔⅛⅜⅝⅞]+\s*(?:ml|cl|oz)\.?))?(.*)$',
      caseSensitive: false,
    ).firstMatch(remaining);
    if (colonAmountMatch != null) {
      var name = colonAmountMatch.group(1)?.trim() ?? '';
      var primaryAmount = colonAmountMatch.group(2)?.trim() ?? '';
      final metricAmount = colonAmountMatch.group(3)?.trim();
      final extra = colonAmountMatch.group(4)?.trim() ?? '';
      
      // Remove leading and trailing * or other footnote markers from name
      name = name.replaceAll(RegExp(r'^[\*†]+|[\*†]+$'), '').trim();
      
      // Normalize "Top" to "Top" (capitalize)
      if (primaryAmount.toLowerCase() == 'top' || primaryAmount.toLowerCase() == 'top up') {
        primaryAmount = 'Top';
      }
      
      // Use the primary amount (typically oz for US sites)
      // Add metric as a note if present
      String? preparation;
      if (metricAmount != null && metricAmount.isNotEmpty) {
        preparation = metricAmount;
      }
      if (extra.isNotEmpty) {
        preparation = preparation != null ? '$preparation $extra' : extra;
      }
      
      return Ingredient.create(
        name: _cleanIngredientName(name),
        amount: primaryAmount,
        preparation: preparation,
      );
    }
    
    // Handle baker's percentage format: "All-Purpose Flour, 100% – 600g (4 1/2 Cups)"
    // or "Warm Water, 75% – 450g (2 Cups)" or "Extra Virgin Olive Oil, 3.3% – 20g (2 tbsp.)"
    // or "Active Dry Yeast, 0.15% – 1/4 tsp. (Instant is good too)"
    final bakerPercentMatch = RegExp(
      r'^([^,]+),\s*([\d.]+)%\s*[–—-]\s*([\d./½¼¾⅓⅔⅛⅜⅝⅞]+\s*(?:g|kg|ml|l|tsp|tbsp|cup|oz|lb)s?\.?)\s*(?:\(([^)]+)\))?',  // en-dash, em-dash, or hyphen
      caseSensitive: false,
    ).firstMatch(remaining);
    if (bakerPercentMatch != null) {
      final name = bakerPercentMatch.group(1)?.trim() ?? '';
      final bakerPercent = bakerPercentMatch.group(2)?.trim();
      final amount = bakerPercentMatch.group(3)?.trim() ?? '';
      final notes = bakerPercentMatch.group(4)?.trim();
      
      // Use the amount as-is, notes go to preparation
      // Store bakerPercent in the bakerPercent field
      return Ingredient.create(
        name: _cleanIngredientName(name),
        amount: amount,
        preparation: notes,
        bakerPercent: bakerPercent != null ? '$bakerPercent%' : null,
      );
    }
    
    // Handle leading baker's percentage format: "15% warm water" or "2% of salt"
    // These are common in artisan bread recipes (baker's math)
    // Also handles alternatives: "2% dry yeast, or 6% fresh yeast, or 20% sourdough starter"
    final leadingBakerPercentMatch = RegExp(
      r'^([\d.]+)%\s+(?:of\s+)?(.+?)(?:,\s*(.+))?$',
      caseSensitive: false,
    ).firstMatch(remaining);
    if (leadingBakerPercentMatch != null) {
      final bakerPercent = leadingBakerPercentMatch.group(1)?.trim();
      var name = leadingBakerPercentMatch.group(2)?.trim() ?? '';
      final alternatives = leadingBakerPercentMatch.group(3)?.trim();
      
      // Clean up the name - remove leading "of" if still present
      name = name.replaceFirst(RegExp(r'^of\s+', caseSensitive: false), '').trim();
      
      return Ingredient.create(
        name: _cleanIngredientName(name),
        bakerPercent: bakerPercent != null ? '$bakerPercent%' : null,
        preparation: alternatives,
      );
    }
    
    // Handle ratio-based ingredients: "1 egg per 250 grams of flour"
    // Also handles: "1 egg per 250g flour", "2 eggs per pound of flour"
    final perRatioMatch = RegExp(
      r'^(\d+)\s+([a-zA-Z]+(?:\s+[a-zA-Z]+)?)\s+per\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(remaining);
    if (perRatioMatch != null) {
      final amountNum = perRatioMatch.group(1)?.trim() ?? '';
      final name = perRatioMatch.group(2)?.trim() ?? '';
      var ratioNote = perRatioMatch.group(3)?.trim() ?? '';
      
      // Normalize common unit patterns in the ratio note
      ratioNote = ratioNote
          .replaceAll(RegExp(r'grams?\s+of\s+', caseSensitive: false), 'g ')
          .replaceAll(RegExp(r'grams?', caseSensitive: false), 'g')
          .replaceAll(RegExp(r'kilograms?\s+of\s+', caseSensitive: false), 'kg ')
          .replaceAll(RegExp(r'kilograms?', caseSensitive: false), 'kg')
          .replaceAll(RegExp(r'pounds?\s+of\s+', caseSensitive: false), 'lb ')
          .replaceAll(RegExp(r'pounds?', caseSensitive: false), 'lb')
          .replaceAll(RegExp(r'ounces?\s+of\s+', caseSensitive: false), 'oz ')
          .replaceAll(RegExp(r'ounces?', caseSensitive: false), 'oz')
          .trim();
      
      return Ingredient.create(
        name: _cleanIngredientName(name),
        amount: amountNum,
        preparation: 'per $ratioNote',
      );
    }
    
    // Handle "Name, amount unit (notes)" format
    // e.g., "00 Flour, 300g (10.5 oz. or about 2 Cups)"
    // e.g., "Egg Yolks, 5 each"
    // e.g., "Fine Sea Salt, 1/4 tsp. (or 1g)"
    // e.g., "EVOO, 1 tsp. (about 3g or 0.125 oz.)"
    final nameAmountMatch = RegExp(
      r'^([^,]+),\s*(\d+(?:/\d+|[½¼¾⅓⅔⅛⅜⅝⅞])?(?:\s*\d+(?:/\d+|[½¼¾⅓⅔⅛⅜⅝⅞])?)?)\s*(g|kg|ml|l|oz|lb|cup|cups|tbsp|tsp|each|whole|large|medium|small)?\.?\s*(?:\(([^)]+)\))?$',
      caseSensitive: false,
    ).firstMatch(remaining);
    if (nameAmountMatch != null) {
      final name = nameAmountMatch.group(1)?.trim() ?? '';
      var amountNum = nameAmountMatch.group(2)?.trim() ?? '';
      final unit = nameAmountMatch.group(3)?.trim() ?? '';
      final notes = nameAmountMatch.group(4)?.trim();
      
      // Convert text fractions to unicode
      amountNum = amountNum.replaceAllMapped(RegExp(r'(\d+)/(\d+)'), (m) {
        final frac = '${m.group(1)}/${m.group(2)}';
        return _fractionMap[frac] ?? frac;
      });
      
      final amount = unit.isNotEmpty ? '$amountNum $unit' : amountNum;
      
      return Ingredient.create(
        name: _cleanIngredientName(name),
        amount: amount,
        preparation: notes,
      );
    }
    
    // Handle simple "Ingredient, as needed" or "Ingredient Name – amount" formats
    final simpleAsNeededMatch = RegExp(
      r'^([^,–-]+),\s*(as needed|to taste)$',
      caseSensitive: false,
    ).firstMatch(remaining);
    if (simpleAsNeededMatch != null) {
      final name = simpleAsNeededMatch.group(1)?.trim() ?? '';
      final note = simpleAsNeededMatch.group(2)?.trim() ?? '';
      return Ingredient.create(
        name: _cleanIngredientName(name),
        amount: note,
      );
    }
    
    // Check for inline section markers like "[Sauce]" or "(For the sauce)" at the start
    final inlineSectionMatch = RegExp(
      r'^\[([^\]]+)\]\s*|^\((?:For\s+(?:the\s+)?)?([^)]+)\)\s*',
      caseSensitive: false,
    ).firstMatch(remaining);
    if (inlineSectionMatch != null) {
      inlineSection = (inlineSectionMatch.group(1) ?? inlineSectionMatch.group(2))?.trim();
      remaining = remaining.substring(inlineSectionMatch.end).trim();
      
      // If the entire line was just a section marker (no ingredient after it), 
      // return an ingredient with only section set (acts as section header)
      if (remaining.isEmpty) {
        return Ingredient.create(
          name: '', // Empty name marks this as a pure section header
          section: inlineSection,
        );
      }
    }
    
    // Remove footnote markers like [1], *, †, etc. from both start and end
    remaining = remaining.replaceAll(RegExp(r'^[\*†]+|[\*†]+$|\[\d+\]'), '').trim();
    
    // Convert word numbers to digits at the start of ingredient
    // e.g., "One 6-in. sage sprig" -> "1 6-in. sage sprig"
    // e.g., "Two large eggs" -> "2 large eggs"
    const wordNumbers = {
      'one': '1', 'two': '2', 'three': '3', 'four': '4', 'five': '5',
      'six': '6', 'seven': '7', 'eight': '8', 'nine': '9', 'ten': '10',
      'eleven': '11', 'twelve': '12', 'a': '1', 'an': '1',
      'half': '½', 'quarter': '¼',
    };
    final wordNumberMatch = RegExp(r'^(one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|a|an|half|quarter)\b\s*', caseSensitive: false).firstMatch(remaining);
    if (wordNumberMatch != null) {
      final word = wordNumberMatch.group(1)!.toLowerCase();
      final digit = wordNumbers[word] ?? word;
      remaining = digit + remaining.substring(wordNumberMatch.end);
    }
    
    // Handle King Arthur Baking complex format:
    // "2 cups plus 2 tablespoons (255g) King Arthur Unbleached Cake Flour or King Arthur Gluten-Free Flour*"
    // Pattern: amount unit "plus" amount unit (weight) Name or Alternative
    final kingArthurMatch = RegExp(
      r'^([\d\s½¼¾⅓⅔⅛⅜⅝⅞/]+)\s*(cups?|tablespoons?|teaspoons?|tbsp|tsp|oz|lb)\.?\s+plus\s+([\d\s½¼¾⅓⅔⅛⅜⅝⅞/]+)\s*(cups?|tablespoons?|teaspoons?|tbsp|tsp|oz|lb)\.?\s*(?:\((\d+g?)\))?\s*(.+)$',
      caseSensitive: false,
    ).firstMatch(remaining);
    if (kingArthurMatch != null) {
      final primaryAmt = kingArthurMatch.group(1)?.trim() ?? '';
      final primaryUnit = _normalizeUnit(kingArthurMatch.group(2)?.trim() ?? '');
      final secondaryAmt = kingArthurMatch.group(3)?.trim() ?? '';
      final secondaryUnit = _normalizeUnit(kingArthurMatch.group(4)?.trim() ?? '');
      final weight = kingArthurMatch.group(5)?.trim();
      var nameAndAlt = kingArthurMatch.group(6)?.trim() ?? '';
      
      // Remove trailing asterisk/footnote markers
      nameAndAlt = nameAndAlt.replaceAll(RegExp(r'\*+$'), '').trim();
      
      // Check for "or" alternatives
      String name;
      String? alternative;
      final orMatch = RegExp(r'^(.+?)\s+or\s+(.+)$', caseSensitive: false).firstMatch(nameAndAlt);
      if (orMatch != null) {
        name = orMatch.group(1)?.trim() ?? nameAndAlt;
        alternative = orMatch.group(2)?.trim();
      } else {
        name = nameAndAlt;
      }
      
      // Build preparation string with additional info
      final prepParts = <String>[];
      prepParts.add('plus $secondaryAmt $secondaryUnit');
      if (weight != null && weight.isNotEmpty) {
        // Ensure weight has 'g' suffix
        final weightStr = weight.endsWith('g') ? weight : '${weight}g';
        prepParts.add(weightStr);
      }
      if (alternative != null) {
        prepParts.add('alt: $alternative');
      }
      
      return Ingredient.create(
        name: _cleanIngredientName(name),
        amount: '$primaryAmt $primaryUnit',
        preparation: prepParts.join(', '),
      );
    }
    
    // Handle simpler "X plus Y" format without the complex alternative
    // e.g., "3/4 cup plus 2 tablespoons (173g) granulated sugar"
    final simplePlusMatch = RegExp(
      r'^([\d\s½¼¾⅓⅔⅛⅜⅝⅞/]+)\s*(cups?|tablespoons?|teaspoons?|tbsp|tsp|oz|lb)\.?\s+plus\s+([\d\s½¼¾⅓⅔⅛⅜⅝⅞/]+)\s*(cups?|tablespoons?|teaspoons?|tbsp|tsp|oz|lb)\.?\s*(?:\((\d+g?)\))?\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(remaining);
    if (simplePlusMatch != null) {
      final primaryAmt = simplePlusMatch.group(1)?.trim() ?? '';
      final primaryUnit = _normalizeUnit(simplePlusMatch.group(2)?.trim() ?? '');
      final secondaryAmt = simplePlusMatch.group(3)?.trim() ?? '';
      final secondaryUnit = _normalizeUnit(simplePlusMatch.group(4)?.trim() ?? '');
      final weight = simplePlusMatch.group(5)?.trim();
      final name = simplePlusMatch.group(6)?.trim() ?? '';
      
      // Build preparation string
      final prepParts = <String>[];
      prepParts.add('plus $secondaryAmt $secondaryUnit');
      if (weight != null && weight.isNotEmpty) {
        final weightStr = weight.endsWith('g') ? weight : '${weight}g';
        prepParts.add(weightStr);
      }
      
      return Ingredient.create(
        name: _cleanIngredientName(name.replaceAll(RegExp(r'\*+$'), '').trim()),
        amount: '$primaryAmt $primaryUnit',
        preparation: prepParts.join(', '),
      );
    }
    
    // Handle Bon Appétit style: "1 28-oz./794-g can crushed tomatoes"
    // Pattern: quantity + size-unit./size-metric + container + name
    // e.g., "1 28-oz./794-g can crushed tomatoes" -> amount: "1 can (28-oz./794-g)", name: "crushed tomatoes"
    // e.g., "1 12-oz./355-ml jar banana peppers" -> amount: "1 jar (12-oz./355-ml)", name: "banana peppers"
    final quantitySizeContainerMatch = RegExp(
      r'^(\d+)\s+([\d.]+)\s*[-–—−]?\s*(oz|ounces?)\.?\s*/\s*([\d.]+)\s*[-–—−]?\s*(g|grams?|ml|l)\s+(can|jar|bottle|package|pkg|box|bag|container|carton)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(remaining);
    if (quantitySizeContainerMatch != null) {
      final quantity = quantitySizeContainerMatch.group(1)?.trim() ?? '';
      final sizeAmt = quantitySizeContainerMatch.group(2)?.trim() ?? '';
      final sizeUnit = quantitySizeContainerMatch.group(3)?.trim() ?? '';
      final metricAmt = quantitySizeContainerMatch.group(4)?.trim() ?? '';
      final metricUnit = quantitySizeContainerMatch.group(5)?.trim() ?? '';
      final container = quantitySizeContainerMatch.group(6)?.trim() ?? '';
      final ingredientName = quantitySizeContainerMatch.group(7)?.trim() ?? '';
      
      // Normalize units
      String normalizedSizeUnit = sizeUnit.toLowerCase();
      if (normalizedSizeUnit.startsWith('ounce')) normalizedSizeUnit = 'oz';
      
      String normalizedMetricUnit = metricUnit.toLowerCase();
      if (normalizedMetricUnit.startsWith('gram')) normalizedMetricUnit = 'g';
      
      // Format: amount = "1 can", preparation = "(28-oz./794-g)" or just the metric info
      final sizeInfo = '$sizeAmt $normalizedSizeUnit / $metricAmt$normalizedMetricUnit';
      
      return Ingredient.create(
        name: _cleanIngredientName(ingredientName),
        amount: '$quantity $container',
        preparation: sizeInfo,
      );
    }
    
    // Handle dual unit amounts EARLY - before other patterns can partially match
    // Pattern: "28-oz./794-g can" or "14.5-oz./411-g can" or "One 28-oz./794-g can"
    // These have number-unit./number-unit followed by descriptor/name
    // Handle various dash types (hyphen, en-dash, em-dash) and Unicode minus
    // Also handle ounces as 'ounce' or 'ounces' not just 'oz'
    final dualUnitMatch = RegExp(
      r'^([\d.]+)\s*[-–—−]?\s*(oz|ounces?|lb|pounds?|cups?|tbsp|tsp)\.?\s*/\s*([\d.]+)\s*[-–—−]?\s*(g|kg|ml|l|grams?)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(remaining);
    if (dualUnitMatch != null) {
      final primaryAmt = dualUnitMatch.group(1)?.trim() ?? '';
      final primaryUnit = dualUnitMatch.group(2)?.trim() ?? '';
      final metricAmt = dualUnitMatch.group(3)?.trim() ?? '';
      final metricUnit = dualUnitMatch.group(4)?.trim() ?? '';
      var nameWithDescriptor = dualUnitMatch.group(5)?.trim() ?? '';
      
      // Normalize units (ounces -> oz, pounds -> lb, grams -> g)
      String normalizedPrimaryUnit = primaryUnit.toLowerCase();
      if (normalizedPrimaryUnit.startsWith('ounce')) normalizedPrimaryUnit = 'oz';
      if (normalizedPrimaryUnit.startsWith('pound')) normalizedPrimaryUnit = 'lb';
      
      String normalizedMetricUnit = metricUnit.toLowerCase();
      if (normalizedMetricUnit.startsWith('gram')) normalizedMetricUnit = 'g';
      
      // Check for "can", "jar", "bottle" etc. as part of the ingredient description
      // e.g., "can crushed tomatoes" -> name: "can crushed tomatoes" or just "crushed tomatoes"
      return Ingredient.create(
        name: _cleanIngredientName(nameWithDescriptor),
        amount: '$primaryAmt $normalizedPrimaryUnit',
        preparation: '$metricAmt$normalizedMetricUnit',
      );
    }
    
    // Check for optional markers anywhere and extract to notes
    final optionalPatterns = [
      RegExp(r'\(\s*optional\s*\)', caseSensitive: false),
      RegExp(r',\s*optional\s*$', caseSensitive: false),
      RegExp(r'\s+optional\s*$', caseSensitive: false),
    ];
    
    for (final pattern in optionalPatterns) {
      if (pattern.hasMatch(remaining)) {
        isOptional = true;
        remaining = remaining.replaceAll(pattern, '').trim();
        notesParts.add('optional');
        break;
      }
    }
    
    // Extract ALL parenthetical content as notes (preparation info, alternatives, etc.)
    // Handle double parentheses like ((0.6 pounds)) and leading commas like (, regular)
    // First normalize double parentheses to single
    remaining = remaining.replaceAll('((', '(').replaceAll('))', ')');
    
    final parenMatches = RegExp(r'\(([^)]+)\)').allMatches(remaining).toList();
    for (final match in parenMatches.reversed) {
      var content = match.group(1)?.trim() ?? '';
      
      // Remove leading commas/spaces from inside parentheses (site-specific quirk)
      content = content.replaceAll(RegExp(r'^[,\s]+'), '').trim();
      
      if (content.isNotEmpty && content.toLowerCase() != 'optional') {
        // Check if this looks like a ratio/recipe description that should stay with the name
        // e.g., "(2 sugar to 1 water, 65.0°Brix)" or "(3:1 simple syrup)"
        // These describe the ingredient itself, not preparation
        final looksLikeRatio = RegExp(
          r'\d+\s*(to|:|parts?)\s*\d+|brix|syrup|ratio|simple|rich',
          caseSensitive: false,
        ).hasMatch(content);
        
        if (looksLikeRatio) {
          // Keep this as part of the ingredient name, don't extract to notes
          continue;
        }
        
        // Check if it's a weight conversion (e.g., "0.6 pounds", "1 lb", "500g")
        final isWeightConversion = RegExp(
          r'^[\d.]+\s*(?:pounds?|lbs?|oz|ounces?|kg|g|grams?)$',
          caseSensitive: false,
        ).hasMatch(content);
        
        if (isWeightConversion) {
          // Add weight conversion to notes
          notesParts.insert(0, content);
        } else {
          // Add other parenthetical content to notes
          notesParts.insert(0, content);
        }
      }
      remaining = remaining.substring(0, match.start) + remaining.substring(match.end);
    }
    remaining = remaining.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    // Try to extract amount (number at start, possibly with range and unit)
    // Handle compound fractions like "1 1/2" or "1 ½" (whole number + fraction)
    // Handle ranges like "1-1.5 Tbsp" or "1 -1.5 Tbsp" (space before dash)
    final compoundFractionMatch = RegExp(
      r'^(\d+)\s+([½¼¾⅓⅔⅛⅜⅝⅞⅕⅖⅗⅘⅙⅚]|1/2|1/4|3/4|1/3|2/3|1/8|3/8|5/8|7/8)'
      r'(\s*(?:teaspoons?|tablespoons?|cups?|Tbsp|tbsp|tsp|oz|lb|kg|g|ml|L|pounds?|ounces?|inch(?:es)?|in|cm|slices?|cloves?|sprigs?|cans?|stalks?|heads?|bunche?s?|pieces?|pinch(?:es)?|dash(?:es)?|drops?|large|medium|small)\.?)?\s+',
      caseSensitive: false,
    ).firstMatch(remaining);
    
    if (compoundFractionMatch != null) {
      // Handle compound fraction like "1 1/2 tsp" or "1 ½ tsp"
      final whole = compoundFractionMatch.group(1) ?? '';
      var fraction = compoundFractionMatch.group(2) ?? '';
      final unit = compoundFractionMatch.group(3)?.trim() ?? '';
      // Convert text fractions to unicode
      fraction = _fractionMap[fraction] ?? fraction;
      amount = '$whole$fraction';
      if (unit.isNotEmpty) {
        amount = '$amount ${_normalizeUnit(unit)}';
      }
      remaining = remaining.substring(compoundFractionMatch.end).trim();
    }
    
    // Try standalone text fraction like "1/4 tsp" (without whole number)
    if (amount == null) {
      final textFractionMatch = RegExp(
        r'^(\d+/\d+)'
        r'(\s*(?:teaspoons?|tablespoons?|cups?|Tbsp|tbsp|tsp|oz|lb|kg|g|ml|L|pounds?|ounces?|inch(?:es)?|in|cm|slices?|cloves?|sprigs?|cans?|stalks?|heads?|bunche?s?|pieces?|pinch(?:es)?|dash(?:es)?|drops?|large|medium|small)\.?)?\s+',
        caseSensitive: false,
      ).firstMatch(remaining);
      
      if (textFractionMatch != null) {
        var fraction = textFractionMatch.group(1) ?? '';
        final unit = textFractionMatch.group(2)?.trim() ?? '';
        // Convert text fractions to unicode
        fraction = _fractionMap[fraction] ?? fraction;
        amount = fraction;
        if (unit.isNotEmpty) {
          amount = '$amount ${_normalizeUnit(unit)}';
        }
        remaining = remaining.substring(textFractionMatch.end).trim();
      }
    }
    
    if (amount == null) {
      // Handle "X to Y unit" range format (e.g., "1 to 2 teaspoons")
      final toRangeMatch = RegExp(
        r'^([\d½¼¾⅓⅔⅛⅜⅝⅞⅕⅖⅗⅘⅙⅚.]+)\s+to\s+([\d½¼¾⅓⅔⅛⅜⅝⅞⅕⅖⅗⅘⅙⅚.]+)'
        r'(\s*(?:teaspoons?|tablespoons?|cups?|Tbsp|tbsp|tsp|oz|lb|kg|g|ml|L|pounds?|ounces?|inch(?:es)?|in|cm|slices?|cloves?|sprigs?|cans?|stalks?|heads?|bunche?s?|pieces?|pinch(?:es)?|dash(?:es)?|drops?|large|medium|small)\.?)?\s+',
        caseSensitive: false,
      ).firstMatch(remaining);
      
      if (toRangeMatch != null) {
        final start = toRangeMatch.group(1)?.trim() ?? '';
        final end = toRangeMatch.group(2)?.trim() ?? '';
        final unit = toRangeMatch.group(3)?.trim() ?? '';
        amount = '$start-$end';
        if (unit.isNotEmpty) {
          amount = '$amount ${_normalizeUnit(unit)}';
        }
        remaining = remaining.substring(toRangeMatch.end).trim();
      }
    }
    
    if (amount == null) {
      // Original pattern for simple amounts and ranges with dash/en-dash
      final amountMatch = RegExp(
        r'^([\d½¼¾⅓⅔⅛⅜⅝⅞⅕⅖⅗⅘⅙⅚.]+\s*[-–]\s*[\d½¼¾⅓⅔⅛⅜⅝⅞⅕⅖⅗⅘⅙⅚.]+|[\d½¼¾⅓⅔⅛⅜⅝⅞⅕⅖⅗⅘⅙⅚.]+)'
        r'(\s*(?:teaspoons?|tablespoons?|cups?|Tbsp|tbsp|tsp|oz|lb|kg|g|ml|L|pounds?|ounces?|inch(?:es)?|in|cm|slices?|cloves?|sprigs?|cans?|stalks?|heads?|bunche?s?|pieces?|pinch(?:es)?|dash(?:es)?|drops?|large|medium|small)\.?)?\s+',
        caseSensitive: false,
      ).firstMatch(remaining);
      
      if (amountMatch != null) {
        final number = amountMatch.group(1)?.trim() ?? '';
        final unit = amountMatch.group(2)?.trim() ?? '';
        // Normalize the range format (remove extra spaces around dash)
        amount = number.replaceAll(RegExp(r'\s*[-–]\s*'), '-');
        if (unit.isNotEmpty) {
          amount = '$amount ${_normalizeUnit(unit)}';
        }
        remaining = remaining.substring(amountMatch.end).trim();
      }
    }
    
    // Strip leading "of" that some sites include after the amount
    // e.g., "2 tbsp of sunflower oil" -> remaining is "of sunflower oil" after amount extraction
    remaining = remaining.replaceFirst(RegExp(r'^of\s+', caseSensitive: false), '');
    
    // Extract leading adjectives/modifiers AFTER amount extraction
    // e.g., "boneless, skinless chicken thighs" -> extract "boneless, skinless"
    // Handles both space-separated and comma-separated modifiers
    final leadingModifierRegex = RegExp(
      r'^(boneless|skinless|skin-?on|bone-?in|frozen|fresh|dried|organic|chopped|minced|diced|sliced|grated|shredded|crushed|crumbled|smashed|cubed|melted|softened|beaten|sifted|peeled|cored|seeded|pitted|trimmed|finely|coarsely)(?:,?\s+)',
      caseSensitive: false,
    );
    
    final extractedMods = <String>[];
    while (remaining.isNotEmpty) {
      final match = leadingModifierRegex.firstMatch(remaining);
      if (match == null) break;
      
      final mod = match.group(1)?.trim().toLowerCase();
      if (mod != null && mod.isNotEmpty) {
        extractedMods.add(mod);
      }
      // Strip the matched modifier AND any following comma+space or just space
      remaining = remaining.substring(match.end).trim();
      // Also strip any leading comma that might remain
      remaining = remaining.replaceFirst(RegExp(r'^,\s*'), '');
    }
    
    // Add extracted modifiers to notesParts in correct order
    if (extractedMods.isNotEmpty) {
      notesParts.addAll(extractedMods);
    }
    
    // Extract preparation instructions after comma (e.g., "oil, I used rice bran oil")
    // But don't split on commas that are inside parentheses
    int commaIndex = -1;
    int parenDepth = 0;
    for (int i = 0; i < remaining.length; i++) {
      final char = remaining[i];
      if (char == '(') parenDepth++;
      else if (char == ')') parenDepth--;
      else if (char == ',' && parenDepth == 0) {
        commaIndex = i;
        break;
      }
    }
    if (commaIndex > 0) {
      var afterComma = remaining.substring(commaIndex + 1).trim();
      remaining = remaining.substring(0, commaIndex).trim();
      
      // Clean up common patterns like "I used X" -> just note the alternative
      afterComma = afterComma.replaceAllMapped(
        RegExp(r'^I\s+used\s+', caseSensitive: false),
        (m) => '',
      );
      
      // Remove any leading commas or spaces
      afterComma = afterComma.replaceAll(RegExp(r'^[,\s]+'), '').trim();
      
      if (afterComma.isNotEmpty) {
        notesParts.add(afterComma);
      }
    }
    
    // Handle "or" alternatives - e.g., "confectioners' sugar or King Arthur Snow White Sugar"
    // BUT: Don't split on "or" when it's between adjectives describing the same ingredient
    // e.g., "red or yellow onion" should stay as "red or yellow onion", not split to "red" + "alt: yellow onion"
    // Match " or " but not at very start, and not "for" or other words ending in "or"
    final orMatch = RegExp(r'\s+or\s+', caseSensitive: false).firstMatch(remaining);
    if (orMatch != null && orMatch.start > 0) {
      final beforeOr = remaining.substring(0, orMatch.start).trim();
      final afterOr = remaining.substring(orMatch.end).trim();
      
      // Check if beforeOr is just a simple adjective (color, size, etc.)
      // If so, keep the entire phrase together as the ingredient name
      final adjectivePattern = RegExp(
        r'^(red|yellow|green|white|black|brown|orange|purple|pink|blue|'
        r'large|medium|small|big|tiny|fresh|dried|frozen|canned|raw|cooked|'
        r'hot|cold|warm|sweet|sour|spicy|mild)$',
        caseSensitive: false,
      );
      
      final isSimpleAdjective = adjectivePattern.hasMatch(beforeOr);
      
      // Only treat as alternative if:
      // 1. beforeOr is NOT just a simple adjective
      // 2. afterOr looks like an ingredient name, not a phrase
      // (avoid splitting on "or until golden brown" type phrases in directions that leaked in)
      if (!isSimpleAdjective && 
          afterOr.isNotEmpty && 
          !RegExp(r'^(until|if|when|as)\s', caseSensitive: false).hasMatch(afterOr)) {
        remaining = beforeOr;
        // Clean up the alternative - remove trailing punctuation and footnotes
        var alternative = afterOr
            .replaceAll(RegExp(r'\*+$'), '')
            .replaceAll(RegExp(r'^[,\s]+|[,\s]+$'), '')
            .trim();
        if (alternative.isNotEmpty) {
          notesParts.insert(0, 'alt: $alternative');
        }
      }
      // If isSimpleAdjective, keep the entire "red or yellow onion" as the name (don't split)
    }
    
    // Skip empty ingredients (like just "cooking oil" with nothing useful after extraction)
    // But allow simple ingredients like "oil", "salt", etc.
    if (remaining.isEmpty && notesParts.isEmpty && amount == null) {
      return Ingredient.create(name: '', amount: null);
    }
    
    // If the remaining ingredient name is empty but we have notes, try to salvage it
    if (remaining.isEmpty && notesParts.isNotEmpty) {
      // Use the first meaningful note as the name
      for (var i = 0; i < notesParts.length; i++) {
        final note = notesParts[i].toLowerCase();
        if (!note.contains('optional') && 
            !RegExp(r'^[\d.]+\s*(?:pounds?|lbs?|oz|ounces?|kg|g|grams?)$', caseSensitive: false).hasMatch(notesParts[i])) {
          remaining = notesParts.removeAt(i);
          break;
        }
      }
    }
    
    // Clean the ingredient name - remove trailing/leading punctuation
    remaining = remaining.replaceAll(RegExp(r'^[,\s]+|[,\s]+$'), '');
    
    // Build final notes string, cleaning up any remaining stray parentheses, commas, and footnotes
    String? finalNotes;
    if (notesParts.isNotEmpty) {
      finalNotes = notesParts
          .map((n) => n
              .replaceAll(RegExp(r'^\(+|\)+$'), '')  // Remove stray parentheses
              .replaceAll(RegExp(r'^[,\s]+|[,\s]+$'), '')  // Remove leading/trailing commas and spaces
              .trim(),)
          .where((n) => n.isNotEmpty)
          // Filter out footnote references like "Footnote 1", "Footnote 2", etc.
          .where((n) => !RegExp(r'^Footnote\s*\d*$', caseSensitive: false).hasMatch(n))
          .join(', ');
      if (finalNotes.isEmpty) finalNotes = null;
    }
    
    return Ingredient.create(
      name: _cleanIngredientName(remaining),
      amount: _normalizeFractions(amount),
      preparation: finalNotes,
      isOptional: isOptional,
      section: inlineSection,
    );
  }

  /// Clean an ingredient name - capitalize first letter, remove trailing punctuation.
  /// Clean an ingredient name - apply Title Case to all words.
  /// Words like 'of', 'the', 'and', 'or' stay lowercase unless first word.
  String _cleanIngredientName(String name) {
    if (name.isEmpty) return name;
    
    var cleaned = name.trim();
    
    // Remove trailing punctuation
    cleaned = cleaned.replaceAll(RegExp(r'[,;:.]+$'), '').trim();
    
    // Words that should stay lowercase (unless first word)
    const lowercaseWords = {'a', 'an', 'the', 'and', 'or', 'of', 'for', 'to', 'in', 'on', 'at', 'by', 'with'};
    
    // Apply Title Case to all words
    final words = cleaned.split(' ');
    final titleCased = words.asMap().entries.map((entry) {
      final i = entry.key;
      final word = entry.value;
      if (word.isEmpty) return word;
      
      // First word always capitalized
      if (i == 0) {
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      }
      
      // Keep short common words lowercase
      if (lowercaseWords.contains(word.toLowerCase())) {
        return word.toLowerCase();
      }
      
      // Capitalize first letter of other words
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
    
    return titleCased;
  }

  /// Normalize unit names to standard abbreviations
  /// e.g., "tablespoons" -> "Tbsp", "cups" -> "C", "teaspoons" -> "tsp"
  /// Uses shared UnitNormalizer for consistent behavior across importers
  String _normalizeUnit(String unit) {
    return UnitNormalizer.normalize(unit);
  }

  /// Normalize fractions to unicode characters (1/2 → ½, 0.5 → ½, 0.333333 → ⅓)
  /// 
  /// Uses shared TextNormalizer for consistent behavior across importers.
  String? _normalizeFractions(String? text) {
    if (text == null || text.isEmpty) return text;
    return TextNormalizer.normalizeFractions(text);
  }

  /// Sort ingredients by quantity (largest first), keeping sections together
  List<Ingredient> _sortIngredientsByQuantity(List<Ingredient> ingredients) {
    if (ingredients.isEmpty) return ingredients;
    
    // Don't sort if there are section headers - preserve original order
    // Section headers are ingredients with empty name but non-null section
    final hasSectionHeaders = ingredients.any((i) => i.name.isEmpty && i.section != null);
    if (hasSectionHeaders) {
      return ingredients; // Preserve original order when sections are present
    }
    
    // Group by section
    final Map<String?, List<Ingredient>> sections = {};
    for (final ing in ingredients) {
      sections.putIfAbsent(ing.section, () => []).add(ing);
    }
    
    // Sort each section by unit priority then quantity
    final result = <Ingredient>[];
    for (final section in sections.keys) {
      final sectionItems = sections[section]!;
      sectionItems.sort((a, b) {
        final aScore = _getIngredientSortScore(a.amount);
        final bScore = _getIngredientSortScore(b.amount);
        return bScore.compareTo(aScore); // Descending (largest first)
      });
      result.addAll(sectionItems);
    }
    
    return result;
  }

  /// Get a sort score for an ingredient amount (higher = larger/more important)
  /// Priority order: weight (kg, g, lb, oz) > whole items > volume (cups, ml) > Tbsp > tsp
  double _getIngredientSortScore(String? amount) {
    if (amount == null || amount.isEmpty) return 0;
    
    final text = amount.toLowerCase();
    
    // Unit priority multipliers - weight first, then volume, then small measures
    double unitMultiplier = 1.0;
    
    // Weight units - highest priority
    if (text.contains('kg') || text.contains('kilogram')) {
      unitMultiplier = 10000.0; // kg - largest weight
    } else if (text.contains('lb') || text.contains('pound')) {
      unitMultiplier = 8000.0;
    } else if (RegExp(r'\bg\b').hasMatch(text) || text.contains('gram')) {
      unitMultiplier = 5000.0; // grams
    } else if (text.contains('oz') || text.contains('ounce')) {
      unitMultiplier = 4000.0;
    }
    // Whole items (pure numbers like "1 onion") - high priority
    else if (!RegExp(r'[a-zA-Z]').hasMatch(text)) {
      unitMultiplier = 3000.0;
    }
    // Volume units - medium priority
    else if (text.contains('l') && (text.contains(' l') || text.endsWith('l') || text.contains('liter') || text.contains('litre'))) {
      unitMultiplier = 2000.0; // liters
    } else if (text.contains('ml') || text.contains('milliliter')) {
      unitMultiplier = 1500.0;
    } else if (text.contains('cup') || RegExp(r'\bc\b').hasMatch(text)) {
      unitMultiplier = 1000.0; // cups
    }
    // Small measurements - lower priority
    else if (text.contains('tbsp') || text.contains('tablespoon')) {
      unitMultiplier = 100.0;
    } else if (text.contains('tsp') || text.contains('teaspoon')) {
      unitMultiplier = 10.0;
    } else if (text.contains('in') || text.contains('inch') || text.contains('"')) {
      unitMultiplier = 5.0; // length measurements
    }
    
    // Extract numeric quantity
    final quantity = _extractNumericQuantity(amount);
    
    return quantity * unitMultiplier;
  }

  /// Extract numeric value from amount string for sorting
  double _extractNumericQuantity(String? amount) {
    if (amount == null || amount.isEmpty) return 0;
    
    // Unicode fractions to decimal
    final fractionValues = {
      '½': 0.5, '¼': 0.25, '¾': 0.75,
      '⅓': 0.33, '⅔': 0.67,
      '⅛': 0.125, '⅜': 0.375, '⅝': 0.625, '⅞': 0.875,
      '⅕': 0.2, '⅖': 0.4, '⅗': 0.6, '⅘': 0.8,
      '⅙': 0.167, '⅚': 0.833,
    };
    
    var text = amount;
    double total = 0;
    
    // Replace unicode fractions with values
    for (final entry in fractionValues.entries) {
      if (text.contains(entry.key)) {
        total += entry.value;
        text = text.replaceAll(entry.key, '');
      }
    }
    
    // Try to find integer or range
    final numMatch = RegExp(r'(\d+)(?:\s*[-–]\s*(\d+))?').firstMatch(text);
    if (numMatch != null) {
      final first = double.tryParse(numMatch.group(1) ?? '') ?? 0;
      final second = double.tryParse(numMatch.group(2) ?? '');
      // Use the higher number in a range
      total += second ?? first;
    }
    
    return total;
  }

  List<String> _parseInstructions(dynamic value) {
    if (value == null) return [];
    
    if (value is String) {
      return _decodeHtml(value)
          .split(RegExp(r'\n+|\. (?=[A-Z])'))
          .where((s) => s.trim().isNotEmpty)
          .toList();
    }
    
    if (value is List) {
      return value.map((item) {
        if (item is String) return _decodeHtml(item.trim());
        if (item is Map) {
          return _decodeHtml(_parseString(item['text']) ?? _parseString(item['name']) ?? '');
        }
        return _decodeHtml(item.toString().trim());
      }).where((s) => s.isNotEmpty).toList();
    }
    
    return [];
  }

  String? _parseImage(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      // Skip Wayback Machine archived images - they often don't work correctly
      if (value.contains('web.archive.org') || value.contains('archive.org/web/')) {
        return null;
      }
      return value;
    }
    if (value is List && value.isNotEmpty) {
      return _parseImage(value.first);
    }
    if (value is Map) {
      return _parseImage(_parseString(value['url']) ?? _parseString(value['contentUrl']));
    }
    return null;
  }

  /// Check if a URL is from a known cocktail/drinks site
  bool _isCocktailSite(String url) {
    final lower = url.toLowerCase();
    return _cocktailSites.any((site) => lower.contains(site));
  }

  /// Check if a URL is from a known BBQ/smoking site
  bool _isBBQSite(String url) {
    final lower = url.toLowerCase();
    return _bbqSites.any((site) => lower.contains(site));
  }

  /// Check if a URL is from a known image-only recipe site
  /// Returns the user-friendly message if it is, null otherwise
  String? _getImageOnlySiteMessage(String url) {
    final lower = url.toLowerCase();
    for (final entry in _imageOnlyRecipeSites.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Check if a URL indicates a pickle/fermentation site
  bool _isPickleSite(String url) {
    final lower = url.toLowerCase();
    const pickleIndicators = [
      'pickle', 'brine', 'ferment', 'kimchi', 'sauerkraut',
      'canning', 'preserve', 'lacto',
    ];
    return pickleIndicators.any((indicator) => lower.contains(indicator));
  }

  /// Check if content indicates a pickle/fermentation recipe
  bool _isPickleRecipe(String? category, String keywords, String name, String description) {
    final allText = '${category ?? ''} $keywords $name $description'.toLowerCase();
    
    const pickleIndicators = [
      'pickle', 'pickled', 'pickles', 'pickling',
      'brine', 'brined', 'brining',
      'ferment', 'fermented', 'fermentation', 'lacto-ferment',
      'kimchi', 'sauerkraut', 'kraut',
      'canning', 'canned', 'preserve', 'preserved', 'preserves',
      'quick pickle', 'refrigerator pickle',
    ];
    
    return pickleIndicators.any((indicator) => allText.contains(indicator));
  }

  /// Detect the course, with special handling for drinks/cocktails
  String _guessCourse(Map data, {String? sourceUrl}) {
    var category = _parseString(data['recipeCategory'])?.toLowerCase();
    
    // Also check WordPress/Next.js nested category format: categories.nodes[].name
    final categoriesData = data['categories'];
    if (categoriesData is Map && categoriesData['nodes'] is List) {
      final categoryNames = (categoriesData['nodes'] as List)
          .whereType<Map>()
          .map((node) => _parseString(node['name'])?.toLowerCase() ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
      // Check for drink/cocktail category directly in nested categories
      if (categoryNames.any((c) => c.contains('drink') || c.contains('cocktail') || c.contains('beverage') || c == 'spirits' || c.contains('amaro'))) {
        return 'Drinks';
      }
      // If no standard category, use the nested categories for detection
      if (category == null || category.isEmpty) {
        category = categoryNames.join(' ');
      }
    }
    
    final keywords = _parseString(data['keywords'])?.toLowerCase() ?? '';
    final name = _parseString(data['name'])?.toLowerCase() ?? '';
    final description = _parseString(data['description'])?.toLowerCase() ?? '';
    final allText = '$category $keywords $name $description';
    
    // Check if this is from a cocktail site (highest priority)
    if (sourceUrl != null && _isCocktailSite(sourceUrl)) {
      return 'Drinks';
    }
    
    // Check if this is from a BBQ/smoking site (highest priority)
    // BBQ sites should return 'Smoking' even if the recipe name contains 'soup', 'salad', etc.
    // because the smoking technique is what makes it unique
    if (sourceUrl != null && _isBBQSite(sourceUrl)) {
      return 'Smoking';
    }
    
    // Priority: Check name for definitive recipe types BEFORE generic indicator checks
    // A recipe named "Sourdough Bread" should be Breads, not Drinks just because
    // some drink-related word appears elsewhere in the metadata
    if (name.contains('bread') || name.contains('sourdough') || name.contains('focaccia') || 
        name.contains('baguette') || name.contains('ciabatta') || name.contains('brioche') ||
        name.contains('loaf') || name.contains('rolls') || name.contains('buns')) {
      return 'Breads';
    }
    
    // Check for drink/cocktail indicators in the data
    if (_isDrinkRecipe(category, keywords, name, description)) {
      return 'Drinks';
    }
    
    // Check for pickle/fermentation indicators BEFORE modernist
    // (calcium chloride is used in both, but pickle context takes precedence)
    if (sourceUrl != null && _isPickleSite(sourceUrl)) {
      return 'Pickles';
    }
    if (_isPickleRecipe(category, keywords, name, description)) {
      return 'Pickles';
    }
    
    // Check for modernist/molecular gastronomy indicators
    if (sourceUrl != null && _isModernistUrl(sourceUrl)) {
      return 'Modernist';
    }
    if (_isModernistContent(allText)) {
      return 'Modernist';
    }
    
    // Check category first (most reliable)
    if (category != null) {
      if (category.contains('dessert') || category.contains('sweet')) return 'Desserts';
      if (category.contains('appetizer') || category.contains('starter')) return 'Apps';
      if (category.contains('soup')) return 'Soups';
      if (category.contains('salad') || category.contains('side')) return 'Sides';
      if (category.contains('bread')) return 'Breads';
      if (category.contains('breakfast') || category.contains('brunch')) return 'Brunch';
      if (category.contains('main') || category.contains('dinner') || category.contains('entrée')) return 'Mains';
      if (category.contains('sauce') || category.contains('dressing')) return 'Sauces';
      if (category.contains('pizza')) return 'Pizzas';
    }
    
    // Check name and keywords for specific recipe types (before dietary indicators)
    // Note: Bread check is done earlier in the function for priority over drink detection
    if (name.contains('soup') || name.contains('stew') || name.contains('chowder')) {
      return 'Soups';
    }
    if (name.contains('cake') || name.contains('cookie') || name.contains('brownie') || 
        name.contains('pie') || name.contains('dessert')) {
      return 'Desserts';
    }
    if (name.contains('sauce') || name.contains('dressing')) {
      return 'Sauces';
    }
    if (name.contains('pizza')) {
      return 'Pizzas';
    }
    
    // Vegan/vegetarian is a dietary restriction, not a course type
    // Only use it as a fallback if no specific course was detected
    // and only if it's explicitly a vegetarian/vegan dish (in category, not just keywords)
    if (category != null && (category.contains('vegetarian') || category.contains('vegan'))) {
      return "Veg'n";
    }
    
    return 'Mains'; // Default
  }
  
  /// Check if URL indicates a modernist/molecular gastronomy site
  /// Uses the consolidated _courseUrlPatterns map
  bool _isModernistUrl(String url) {
    final patterns = _courseUrlPatterns['Modernist'];
    if (patterns == null) return false;
    final lowerUrl = url.toLowerCase();
    return patterns.any((p) => lowerUrl.contains(p));
  }
  
  /// Check if content indicates modernist/molecular gastronomy
  /// Uses a subset of the _courseKeywords map plus additional technique keywords
  bool _isModernistContent(String text) {
    // First check _courseKeywords for Modernist
    if (_matchesCourseKeywords('Modernist', text)) return true;
    
    // Additional modernist technique/ingredient keywords not in title matching
    final lower = text.toLowerCase();
    const additionalKeywords = [
      'spherification', 'gelification', 'immersion circulator',
      'agar', 'xanthan', 'sodium alginate', 'calcium chloride',
      'molecular gastronomy', 'modernist cuisine', 'hydrocolloid',
      'methylcellulose', 'lecithin', 'maltodextrin', 'transglutaminase',
    ];
    return additionalKeywords.any((k) => lower.contains(k));
  }

  /// Check if this is a drink/cocktail recipe based on content
  bool _isDrinkRecipe(String? category, String keywords, String name, String description) {
    final allText = '${category ?? ''} $keywords $name $description'.toLowerCase();
    
    // Cocktail/drink category indicators - use word boundaries to avoid false positives
    // e.g., "sour" should not match "sourdough"
    const drinkIndicators = [
      'cocktail', 'cocktails', 'drink', 'drinks', 'beverage', 'beverages',
      'martini', 'margarita', 'mojito', 'negroni', 'manhattan', 'daiquiri',
      'old fashioned', 'old-fashioned', 'highball', 'lowball',
      'fizz', 'collins', 'spritz', 'punch', 'shooter', 'shot',
      'mocktail', 'smoothie', 'shake', 'milkshake',
    ];
    
    // Indicators that need word boundary matching (avoid false positives)
    const wordBoundaryIndicators = [
      'sour',  // Don't match "sourdough"
    ];
    
    // Spirit indicators
    const spiritIndicators = [
      'gin', 'vodka', 'rum', 'whiskey', 'whisky', 'bourbon', 'scotch',
      'tequila', 'mezcal', 'brandy', 'cognac', 'liqueur',
      'champagne', 'prosecco', 'wine', 'vermouth', 'amaro', 'aperol',
      'campari', 'bitters',
    ];
    
    for (final indicator in drinkIndicators) {
      if (allText.contains(indicator)) return true;
    }
    
    // Check word-boundary indicators with regex
    for (final indicator in wordBoundaryIndicators) {
      if (RegExp(r'\b' + indicator + r'\b').hasMatch(allText)) return true;
    }
    
    // Check spirit indicators in name/description (not just category)
    // These indicate the recipe IS a spirit/liqueur, not just uses one as ingredient
    for (final spirit in spiritIndicators) {
      if (name.contains(spirit) || (category != null && category.contains(spirit))) return true;
    }
    
    return false;
  }

  /// Detect the base spirit for a cocktail from ingredients
  String? _detectSpirit(List<Ingredient> ingredients) {
    final ingredientNames = ingredients.map((i) => i.name).toList();
    return Spirit.detectFromIngredients(ingredientNames);
  }

  // NOTE: Legacy _parseFromHtml removed - only _parseFromHtmlWithConfidence is used
  
  /// Fallback HTML parsing with confidence scoring
  RecipeImportResult? _parseFromHtmlWithConfidence(dynamic document, String sourceUrl, [String? rawHtmlBody]) {
    // Try common selectors for recipe sites
    final title = document.querySelector('h1')?.text?.trim() ?? 
                  document.querySelector('.recipe-title')?.text?.trim() ??
                  document.querySelector('[itemprop="name"]')?.text?.trim();

    var rawIngredientStrings = <String>[];
    var rawDirections = <String>[];
    List<String> equipmentItems = [];
    List<String> stepImages = []; // Images found in direction steps
    String? glassType;
    List<String> garnishItems = [];
    String? yield;
    String? timing;
    String? htmlNotes;
    bool usedStructuredFormat = false; // Flag for higher confidence when using structured recipe plugins
    
    // Squarespace pattern: h4 headers (INGREDIENTS:, METHOD:) with <p> + <br> content
    // Detection: sqs-html-content class, squarespace.com in scripts, or known Squarespace sites
    // Must run early to prevent generic selectors from mismatching content
    final bodyHtmlCheck = document.outerHtml ?? '';
    final isSquarespace = bodyHtmlCheck.contains('sqs-html-content') ||
        bodyHtmlCheck.contains('squarespace.com') ||
        bodyHtmlCheck.contains('static1.squarespace.com') ||
        sourceUrl.contains('starchefs.com'); // Known Squarespace site
    
    if (isSquarespace) {
      final h4Elements = document.querySelectorAll('h4');
      
      for (final h4 in h4Elements) {
        final h4Text = (h4.text ?? '').trim().toUpperCase();
        
        if (h4Text.contains('INGREDIENTS')) {
          // Get next sibling - usually a <p> tag with content
          var sibling = h4.nextElementSibling;
          while (sibling != null) {
            final tagName = sibling.localName?.toLowerCase() ?? '';
            
            // Stop at next h4 (METHOD section) or h3/h2
            if (tagName == 'h4' || tagName == 'h3' || tagName == 'h2') {
              break;
            }
            
            if (tagName == 'p') {
              // Get the inner HTML to preserve <strong> and <br> tags
              final innerHtml = sibling.innerHtml ?? '';
              
              // Split by <br> and <br/> and <br />
              final lines = innerHtml.split(RegExp(r'<br\s*/?\s*>', caseSensitive: false));
              
              for (var line in lines) {
                line = line.trim();
                if (line.isEmpty) continue;
                
                // Check for section header: <strong>Section Name:</strong> pattern
                final strongMatch = RegExp(
                  r'^<strong[^>]*>([^<]+):?\s*</strong>\s*$',
                  caseSensitive: false,
                ).firstMatch(line);
                
                if (strongMatch != null) {
                  // This is a section header
                  var sectionName = _decodeHtml(strongMatch.group(1)?.trim() ?? '');
                  if (sectionName.endsWith(':')) {
                    sectionName = sectionName.substring(0, sectionName.length - 1).trim();
                  }
                  if (sectionName.isNotEmpty) {
                    rawIngredientStrings.add('[$sectionName]');
                  }
                } else {
                  // Regular ingredient line - strip all HTML tags
                  final text = _decodeHtml(line.replaceAll(RegExp(r'<[^>]+>'), '').trim());
                  if (text.isNotEmpty) {
                    rawIngredientStrings.add(text);
                  }
                }
              }
            }
            
            sibling = sibling.nextElementSibling;
          }
        }
        
        if (h4Text.contains('METHOD') || h4Text.contains('DIRECTIONS') || h4Text.contains('INSTRUCTIONS')) {
          // Get next sibling - usually a <p> tag with content
          var sibling = h4.nextElementSibling;
          while (sibling != null) {
            final tagName = sibling.localName?.toLowerCase() ?? '';
            
            // Stop at next h4 or h3/h2
            if (tagName == 'h4' || tagName == 'h3' || tagName == 'h2') {
              break;
            }
            
            if (tagName == 'p') {
              final innerHtml = sibling.innerHtml ?? '';
              
              // Split by <br> tags
              final lines = innerHtml.split(RegExp(r'<br\s*/?\s*>', caseSensitive: false));
              
              for (var line in lines) {
                line = line.trim();
                if (line.isEmpty) continue;
                
                // Check for section header: <strong>For the Section:</strong> pattern
                final strongMatch = RegExp(
                  r'^<strong[^>]*>([^<]+):?\s*</strong>\s*$',
                  caseSensitive: false,
                ).firstMatch(line);
                
                if (strongMatch != null) {
                  // This is a direction section header
                  var sectionName = _decodeHtml(strongMatch.group(1)?.trim() ?? '');
                  if (sectionName.endsWith(':')) {
                    sectionName = sectionName.substring(0, sectionName.length - 1).trim();
                  }
                  if (sectionName.isNotEmpty) {
                    rawDirections.add('[${_stripForThePrefix(sectionName)}]');
                  }
                } else {
                  // Regular direction step - strip all HTML tags
                  final text = _decodeHtml(line.replaceAll(RegExp(r'<[^>]+>'), '').trim());
                  if (text.isNotEmpty) {
                    rawDirections.add(text);
                  }
                }
              }
            }
            
            sibling = sibling.nextElementSibling;
          }
        }
      }
      
      // Extract yield from "Yield: X servings" text
      final bodyText = document.body?.text ?? '';
      final yieldMatch = RegExp(r'Yield:\s*(\d+)\s*(?:servings?|portions?)?', caseSensitive: false).firstMatch(bodyText);
      if (yieldMatch != null) {
        yield = yieldMatch.group(1);
      }
      
      // If we found content, skip all other handlers
      if (rawIngredientStrings.isNotEmpty || rawDirections.isNotEmpty) {
        usedStructuredFormat = true;
      }
    }
    
    // ===================================================================
    // Divi Builder pattern (WordPress): .et_pb_text_inner with h4/h5 headers
    // Detection: et_pb classes or known Divi sites like annaolson.ca
    // Structure: <div class="et_pb_text_inner"><h4>Prep Time:</h4><p>25 minutes</p></div>
    //           <div class="et_pb_text_inner"><h4>Cake:</h4><ul><li>...</li></ul></div>
    // Must run early to catch structured content before generic selectors
    // ===================================================================
    final isDivi = bodyHtmlCheck.contains('et_pb_') ||
        bodyHtmlCheck.contains('divi_') ||
        sourceUrl.contains('annaolson.ca');
    
    if (isDivi && !usedStructuredFormat) {
      
      final textInnerBlocks = document.querySelectorAll('.et_pb_text_inner');
      
      // === First Pass: Extract Metadata and Ingredients from .et_pb_text_inner blocks ===
      for (final block in textInnerBlocks) {
        final h4 = block.querySelector('h4');
        if (h4 == null) continue;
        
        final h4Text = (h4.text ?? '').trim();
        
        // === Extract Metadata (Time/Yield) ===
        if (h4Text.contains('Prep Time') || h4Text.contains('Cook Time') || h4Text.contains('Total Time')) {
          final nextP = h4.nextElementSibling;
          if (nextP?.localName == 'p') {
            final timeValue = _decodeHtml((nextP.text ?? '').trim());
            if (timing == null) {
              timing = timeValue;
            } else if (!timing.contains(timeValue)) {
              timing = '$timing, $timeValue';
            }
          }
        } else if (h4Text.contains('Makes') || h4Text.contains('Serves') || h4Text.contains('Yield')) {
          final nextP = h4.nextElementSibling;
          if (nextP?.localName == 'p') {
            yield = _decodeHtml((nextP.text ?? '').trim());
          }
        }
        
        // === Extract Ingredient Sections ===
        // Look for h4 followed by <ul> (ingredient list)
        else if (h4.nextElementSibling?.localName == 'ul') {
          // This is an ingredient section
          var sectionName = _decodeHtml(h4Text.trim());
          // Remove trailing colon
          if (sectionName.endsWith(':')) {
            sectionName = sectionName.substring(0, sectionName.length - 1).trim();
          }
          // Add section header
          if (sectionName.isNotEmpty && 
              !sectionName.toLowerCase().contains('ingredient') && // Don't add generic "Ingredients" header
              sectionName.length < _maxSectionHeaderLength) {
            rawIngredientStrings.add('[$sectionName]');
          }
          
          // Extract list items
          final ul = h4.nextElementSibling!;
          for (final li in ul.querySelectorAll('li')) {
            final text = _decodeHtml((li.text ?? '').trim());
            if (text.isNotEmpty && text.length < _maxIngredientLineLength) {
              rawIngredientStrings.add(text);
            }
          }
        }
        
        // === Extract Notes from <p> tags with <strong>NOTES:</strong> ===
        // Look for paragraphs that start with bold "NOTES:" text
        else if (h4Text.toUpperCase().startsWith('NOTES')) {
          // Legacy h4 NOTES header support (keep for backwards compatibility)
          var notesText = '';
          var sibling = h4.nextElementSibling;
          while (sibling != null) {
            // Stop at next heading
            if (sibling.querySelector('h2, h3, h4, h5') != null) break;
            
            final p = sibling.localName == 'p' ? sibling : sibling.querySelector('p');
            if (p != null) {
              final text = _decodeHtml((p.text ?? '').trim());
              if (text.isNotEmpty) {
                notesText = notesText.isEmpty ? text : '$notesText\n\n$text';
              }
            }
            
            sibling = sibling.nextElementSibling;
          }
          
          if (notesText.isNotEmpty) {
            htmlNotes = htmlNotes == null ? notesText : '$htmlNotes\n\n$notesText';
          }
        }
      }
      
      // === Extract Directions from Divi Sites ===
      final diviDirections = _extractDiviDirections(document);
      rawDirections.addAll(diviDirections);
      
      // === Extract Notes from <p><strong>NOTES:</strong>...</p> pattern ===
      // This handles Divi sites like annaolson.ca that use inline bold NOTES
      if (!usedStructuredFormat || htmlNotes == null) {
        final allParagraphs = document.querySelectorAll('p');
        for (final p in allParagraphs) {
          final pText = p.text?.trim() ?? '';
          // Check if paragraph starts with "NOTES:" (case-insensitive)
          if (RegExp(r'^NOTES:\s*', caseSensitive: false).hasMatch(pText)) {
            // Check if it has a <strong> tag containing "NOTES:"
            final strong = p.querySelector('strong');
            if (strong != null && strong.text?.toUpperCase().contains('NOTES') == true) {
              // Extract text after the NOTES: prefix
              var notesContent = pText.replaceFirst(RegExp(r'^NOTES:\s*', caseSensitive: false), '').trim();
              if (notesContent.isNotEmpty) {
                htmlNotes = htmlNotes == null ? notesContent : '$htmlNotes\n\n$notesContent';
                break; // Found notes, stop searching
              }
            }
          }
        }
      }
      
      // Mark as structured format if we found content
      if (rawIngredientStrings.isNotEmpty || rawDirections.isNotEmpty) {
        usedStructuredFormat = true;
      }
    }
    
    // Check for Shopify/Lyres-style embedded HTML in JSON (recipe-info divs in product description)
    // These sites embed HTML inside JSON strings with unicode escaping (\u003c for <)
    var bodyHtml = document.outerHtml;
    
    // Decode common unicode escapes that Shopify/Lyres uses
    bodyHtml = bodyHtml
        .replaceAll(r'\u003c', '<')
        .replaceAll(r'\u003e', '>')
        .replaceAll(r'\u0026', '&')
        .replaceAll(r'\/', '/')
        .replaceAll(r'\n', ' ')
        .replaceAll(r'\"', '"');
    
    // Also try the literal unicode escape format (without backslash interpretation)
    bodyHtml = bodyHtml
        .replaceAll('\\u003c', '<')
        .replaceAll('\\u003e', '>')
        .replaceAll('\\u0026', '&')
        .replaceAll('\\/', '/')
        .replaceAll('\\n', ' ')
        .replaceAll('\\"', '"');
    
    // Two-step approach for Lyres/Shopify embedded HTML:
    // Step 1: Find all recipe-info div sections
    final recipeInfoDivs = RegExp(
      r'<div[^>]*class="[^"]*recipe-info[^"]*"[^>]*>(.*?)</div>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(bodyHtml);
    
    for (final divMatch in recipeInfoDivs) {
      final divContent = divMatch.group(1) ?? '';
      
      // Step 2: Extract h4 title from this div (handles <h4 class="title">Text</h4>)
      final h4Match = RegExp(
        r'<h4[^>]*>(.*?)</h4>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(divContent);
      
      if (h4Match == null) continue;
      
      // Strip any HTML tags from the h4 content to get plain text
      final h4RawContent = h4Match.group(1) ?? '';
      final h4Title = h4RawContent.replaceAll(RegExp(r'<[^>]+>'), '').trim().toLowerCase();
      
      // Extract content after h4 - try ul first, then p tags
      final afterH4 = divContent.substring(h4Match.end);
      
      if (h4Title == 'method' || h4Title == 'directions' || h4Title == 'instructions') {
        // For method, collect all <p> content
        final pMatches = RegExp(r'<p[^>]*>(.*?)</p>', caseSensitive: false, dotAll: true).allMatches(afterH4);
        for (final pMatch in pMatches) {
          final text = _decodeHtml((pMatch.group(1) ?? '').replaceAll(RegExp(r'<[^>]+>'), '').trim());
          if (text.isNotEmpty && rawDirections.isEmpty) {
            // Split by periods for multiple sentences if it's a single paragraph
            if (text.contains('. ')) {
              rawDirections.addAll(text.split(RegExp(r'\.\s+')).where((s) => s.trim().isNotEmpty).map((s) => s.trim() + '.'));
            } else {
              rawDirections.add(text);
            }
          }
        }
      } else if (h4Title == 'glass' || h4Title == 'glassware') {
        final pMatch = RegExp(r'<p[^>]*>(.*?)</p>', caseSensitive: false, dotAll: true).firstMatch(afterH4);
        if (pMatch != null && glassType == null) {
          final text = _decodeHtml((pMatch.group(1) ?? '').replaceAll(RegExp(r'<[^>]+>'), '').trim());
          if (text.isNotEmpty) glassType = text;
        }
      } else if (h4Title == 'garnish') {
        final pMatch = RegExp(r'<p[^>]*>(.*?)</p>', caseSensitive: false, dotAll: true).firstMatch(afterH4);
        if (pMatch != null && garnishItems.isEmpty) {
          final text = _decodeHtml((pMatch.group(1) ?? '').replaceAll(RegExp(r'<[^>]+>'), '').trim());
          if (text.isNotEmpty) garnishItems = _splitGarnishText(text);
        }
      } else if (h4Title == 'ingredients' && rawIngredientStrings.isEmpty) {
        // Extract li items from the ul
        final liMatches = RegExp(r'<li[^>]*>(.*?)</li>', caseSensitive: false, dotAll: true).allMatches(afterH4);
        for (final li in liMatches) {
          final text = _decodeHtml((li.group(1) ?? '').replaceAll(RegExp(r'<[^>]+>'), '').trim());
          if (text.isNotEmpty) rawIngredientStrings.add(text);
        }
      }
    }
    
    // Fallback: try the original simpler pattern if no matches found
    if (rawIngredientStrings.isEmpty && glassType == null && garnishItems.isEmpty && rawDirections.isEmpty) {
      final embeddedRecipeMatch = RegExp(
        r'recipe-info[^>]*>.*?<h4[^>]*>([^<]+)</h4>\s*(?:<ul>.*?</ul>|<p>([^<]+)</p>)',
        caseSensitive: false,
        dotAll: true,
      ).allMatches(bodyHtml);
      
      if (embeddedRecipeMatch.isNotEmpty) {
        for (final match in embeddedRecipeMatch) {
          final h4Title = match.group(1)?.trim().toLowerCase() ?? '';
          // For ul-based content, extract from the full match
          final fullMatch = match.group(0) ?? '';
          final pContent = match.group(2)?.trim();
          
          if (h4Title == 'method' || h4Title == 'directions' || h4Title == 'instructions') {
            if (pContent != null && pContent.isNotEmpty && rawDirections.isEmpty) {
              rawDirections.add(_decodeHtml(pContent));
            }
          } else if (h4Title == 'glass' || h4Title == 'glassware') {
            if (pContent != null && pContent.isNotEmpty && glassType == null) {
              glassType = _decodeHtml(pContent);
            }
          } else if (h4Title == 'garnish') {
            if (pContent != null && pContent.isNotEmpty && garnishItems.isEmpty) {
              garnishItems = _splitGarnishText(_decodeHtml(pContent));
            }
          } else if (h4Title == 'ingredients' && rawIngredientStrings.isEmpty) {
            // Extract li items from the ul
            final liMatches = RegExp(r'<li>([^<]+)</li>', caseSensitive: false).allMatches(fullMatch);
            for (final li in liMatches) {
              final text = _decodeHtml(li.group(1)?.trim() ?? '');
              if (text.isNotEmpty) rawIngredientStrings.add(text);
            }
          }
        }
      }
    }
    
    // Additional fallback for Lyres: search for standalone h4>Method followed by p anywhere in the HTML
    // This handles cases where Method is not inside a recipe-info div
    // DO NOT run for Divi sites (prefer empty list over garbage data)
    if (rawDirections.isEmpty && !isDivi) {
      final methodMatch = RegExp(
        r'<h4[^>]*>\s*Method\s*</h4>\s*<p[^>]*>(.*?)</p>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(bodyHtml);
      if (methodMatch != null) {
        final text = _decodeHtml((methodMatch.group(1) ?? '').replaceAll(RegExp(r'<[^>]+>'), '').trim());
        if (text.isNotEmpty) {
          rawDirections.add(text);
        }
      }
    }
    
    // Check for "Cooked" recipe plugin format (WordPress plugin)
    // Uses classes like cooked-ing-amount, cooked-ing-name, cooked-dir-content
    final cookedIngredients = document.querySelectorAll('.cooked-single-ingredient.cooked-ingredient');
    
    if (cookedIngredients.isNotEmpty) {
      usedStructuredFormat = true; // Cooked plugin provides reliable structured data
      
      // Parse Cooked format ingredients
      for (final elem in cookedIngredients) {
        final amount = elem.querySelector('.cooked-ing-amount')?.text?.trim() ?? '';
        final unit = elem.querySelector('.cooked-ing-measurement')?.text?.trim() ?? '';
        final name = elem.querySelector('.cooked-ing-name')?.text?.trim() ?? '';
        
        if (name.isNotEmpty) {
          // Build the ingredient string
          String ingredientStr = '';
          if (amount.isNotEmpty) {
            ingredientStr = amount;
            if (unit.isNotEmpty) {
              ingredientStr += ' $unit';
            }
            ingredientStr += ' $name';
          } else {
            ingredientStr = name;
          }
          rawIngredientStrings.add(_decodeHtml(ingredientStr.trim()));
        }
      }
      
      // Parse Cooked format directions
      final cookedDirections = document.querySelectorAll('.cooked-single-direction.cooked-direction');
      for (final elem in cookedDirections) {
        // Get the content div which contains paragraphs
        final contentDiv = elem.querySelector('.cooked-dir-content');
        if (contentDiv != null) {
          // Get all paragraphs
          final paragraphs = contentDiv.querySelectorAll('p');
          for (final p in paragraphs) {
            final text = _decodeHtml((p.text ?? '').trim());
            if (text.isNotEmpty) {
              rawDirections.add(text);
            }
          }
          // If no paragraphs, try the content directly
          if (paragraphs.isEmpty) {
            final text = _decodeHtml((contentDiv.text ?? '').trim());
            if (text.isNotEmpty) {
              rawDirections.add(text);
            }
          }
        }
      }
      
      // Parse Cooked format time (prep/cook time)
      final prepTime = document.querySelector('.cooked-prep-time');
      final cookTime = document.querySelector('.cooked-cook-time');
      final totalTime = document.querySelector('.cooked-total-time');
      
      int totalMinutes = 0;
      
      // Extract time from cooked-time elements
      if (totalTime != null) {
        final timeText = totalTime.text ?? '';
        totalMinutes = _extractMinutes(timeText);
      } else {
        if (prepTime != null) {
          final prepText = prepTime.text ?? '';
          totalMinutes += _extractMinutes(prepText);
        }
        if (cookTime != null) {
          final cookText = cookTime.text ?? '';
          totalMinutes += _extractMinutes(cookText);
        }
      }
      
      if (totalMinutes > 0) {
        timing = '$totalMinutes min';
      }
    }
    
    // Check for AmazingFoodMadeEasy format EARLY - uses ingredient_dish_header for sections
    // Structure: ul.ingredient_list > li.category > h3.ingredient_dish_header for headers
    //            ul.ingredient_list > li.ingredient for ingredient items
    if (rawIngredientStrings.isEmpty) {
      // Try to find the ingredient list container
      var ingredientList = document.querySelector('ul.ingredient_list');
      ingredientList ??= document.querySelector('.ingredient_list');
      
      if (ingredientList != null) {
        usedStructuredFormat = true;
        
        // Iterate through all li children
        final allLiItems = ingredientList.querySelectorAll('li');
        for (final li in allLiItems) {
          final liClasses = li.attributes['class'] ?? '';
          
          // Check if this li contains an ingredient_dish_header (category row)
          if (liClasses.contains('category')) {
            // Look for the h3 header inside
            final headerElem = li.querySelector('h3');
            if (headerElem != null) {
              final sectionText = _decodeHtml((headerElem.text ?? '').trim());
              if (sectionText.isNotEmpty) {
                // Remove "For the " prefix if present
                final sectionName = _stripForThePrefix(sectionText);
                rawIngredientStrings.add('[$sectionName]');
              }
            }
          }
          // Check if this is an ingredient item
          else if (liClasses.contains('ingredient')) {
            final text = _decodeHtml((li.text ?? '').trim());
            if (text.isNotEmpty) {
              rawIngredientStrings.add(text);
            }
          }
        }
      }
      
      // Fallback: Query for h3.ingredient_dish_header and li.ingredient separately
      if (rawIngredientStrings.isEmpty) {
        // Check if these elements exist anywhere in the document
        final sectionHeaders = document.querySelectorAll('h3.ingredient_dish_header');
        final ingredientItems = document.querySelectorAll('li.ingredient');
        
        if (sectionHeaders.isNotEmpty || ingredientItems.isNotEmpty) {
          usedStructuredFormat = true;
          
          // Process in document order - get parent container and iterate
          // Get all li elements that are either category or ingredient
          final allLis = document.querySelectorAll('li.category, li.ingredient');
          
          for (final li in allLis) {
            final liClasses = li.attributes['class'] ?? '';
            
            if (liClasses.contains('category')) {
              final h3 = li.querySelector('h3');
              if (h3 != null) {
                final text = _decodeHtml((h3.text ?? '').trim());
                if (text.isNotEmpty) {
                  final sectionName = _stripForThePrefix(text);
                  rawIngredientStrings.add('[$sectionName]');
                }
              }
            } else if (liClasses.contains('ingredient')) {
              final text = _decodeHtml((li.text ?? '').trim());
              if (text.isNotEmpty) {
                rawIngredientStrings.add(text);
              }
            }
          }
        }
      }
    }
    
    // Try WordPress block heading pattern (sogoodmagazine.com style):
    // h3.wp-block-heading followed by ul (ingredients), then p (directions)
    // The content is within a .content-info section
    // Also extract "Assembly" section content into notes
    String? wpBlockAssemblyNotes;
    if (rawIngredientStrings.isEmpty) {
      final contentInfo = document.querySelector('.content-info');
      if (contentInfo != null) {
        final wpBlockHeadings = contentInfo.querySelectorAll('h3.wp-block-heading');
        if (wpBlockHeadings.isNotEmpty) {
          usedStructuredFormat = true;
          
          for (final heading in wpBlockHeadings) {
            final sectionName = _decodeHtml((heading.text ?? '').trim());
            if (sectionName.isEmpty) continue;
            
            final lowerSection = sectionName.toLowerCase();
            
            // Skip generic/promotional headings
            if (lowerSection.contains('discover') ||
                lowerSection.contains('related')) {
              continue;
            }
            
            // Capture "Assembly" section content for notes
            if (lowerSection == 'assembly') {
              final assemblyLines = <String>[];
              var sibling = heading.nextElementSibling;
              while (sibling != null) {
                final tagName = sibling.localName?.toLowerCase() ?? '';
                
                // Stop at next heading or horizontal rule
                if (tagName == 'h2' || tagName == 'h3' || tagName == 'h4' || tagName == 'hr') {
                  break;
                }
                
                if (tagName == 'p') {
                  final pText = _decodeHtml((sibling.text ?? '').trim());
                  if (pText.isNotEmpty && pText != '\u00a0') {
                    assemblyLines.add(pText);
                  }
                }
                
                sibling = sibling.nextElementSibling;
              }
              
              if (assemblyLines.isNotEmpty) {
                wpBlockAssemblyNotes = '**Assembly**\n${assemblyLines.join('\n\n')}';
              }
              continue;
            }
            
            // Skip "Others" section (typically just garnish items with no measurements)
            if (lowerSection == 'others') {
              continue;
            }
            
            // Look for ul sibling after this heading (may skip &nbsp; and hr)
            var sibling = heading.nextElementSibling;
            while (sibling != null) {
              final tagName = sibling.localName?.toLowerCase() ?? '';
              
              // Skip separators and whitespace-only elements
              if (tagName == 'hr') {
                sibling = sibling.nextElementSibling;
                continue;
              }
              if (tagName == 'p') {
                // Check if p is just whitespace/nbsp
                final pText = (sibling.text ?? '').trim();
                if (pText.isEmpty || pText == '\u00a0') {
                  sibling = sibling.nextElementSibling;
                  continue;
                }
                // Otherwise it's directions, stop looking for ul
                break;
              }
              
              if (tagName == 'ul') {
                // Found the ingredient list for this section
                final items = sibling.querySelectorAll('li');
                if (items.isNotEmpty) {
                  // Add section header
                  rawIngredientStrings.add('[$sectionName]');
                  for (final item in items) {
                    final text = _decodeHtml((item.text ?? '').trim());
                    if (text.isNotEmpty) {
                      rawIngredientStrings.add(text);
                    }
                  }
                }
                break;
              }
              
              // Stop at next heading
              if (tagName == 'h2' || tagName == 'h3' || tagName == 'h4') {
                break;
              }
              
              sibling = sibling.nextElementSibling;
            }
          }
        }
      }
    }
    
    // Try WordPress block heading pattern without .content-info wrapper (pastryartsmag.com style):
    // h3.wp-block-heading followed by ul (ingredients) directly on document level
    if (rawIngredientStrings.isEmpty) {
      final wpBlockHeadings = document.querySelectorAll('h3.wp-block-heading');
      if (wpBlockHeadings.isNotEmpty) {
        usedStructuredFormat = true;
        
        for (final heading in wpBlockHeadings) {
          final sectionName = _decodeHtml((heading.text ?? '').trim());
          if (sectionName.isEmpty) continue;
          
          final lowerSection = sectionName.toLowerCase();
          
          // Skip generic/promotional headings
          if (lowerSection.contains('discover') ||
              lowerSection.contains('related') ||
              lowerSection.contains('podcast') ||
              lowerSection.contains('latest')) {
            continue;
          }
          
          // Skip if section name looks like a link (e.g., "Recipe Name by Author")
          if (sectionName.contains(' by ') && lowerSection.contains('recipe')) {
            continue;
          }
          
          // Capture "Assembly" section content for notes
          if (lowerSection == 'assembly') {
            final assemblyLines = <String>[];
            var sibling = heading.nextElementSibling;
            while (sibling != null) {
              final tagName = sibling.localName?.toLowerCase() ?? '';
              
              // Stop at next heading or horizontal rule
              if (tagName == 'h2' || tagName == 'h3' || tagName == 'h4' || tagName == 'hr') {
                break;
              }
              
              // Handle numbered list (ol) for assembly steps
              if (tagName == 'ol') {
                final items = sibling.querySelectorAll('li');
                for (final item in items) {
                  final itemText = _decodeHtml((item.text ?? '').trim());
                  if (itemText.isNotEmpty) {
                    assemblyLines.add(itemText);
                  }
                }
              }
              
              if (tagName == 'p') {
                final pText = _decodeHtml((sibling.text ?? '').trim());
                if (pText.isNotEmpty && pText != '\u00a0') {
                  assemblyLines.add(pText);
                }
              }
              
              sibling = sibling.nextElementSibling;
            }
            
            if (assemblyLines.isNotEmpty) {
              if (wpBlockAssemblyNotes != null) {
                wpBlockAssemblyNotes = '$wpBlockAssemblyNotes\n\n**Assembly**\n${assemblyLines.join('\n\n')}';
              } else {
                wpBlockAssemblyNotes = '**Assembly**\n${assemblyLines.join('\n\n')}';
              }
            }
            continue;
          }
          
          // Skip "Others" section (typically just garnish items with no measurements)
          if (lowerSection == 'others') {
            continue;
          }
          
          // Look for ul sibling after this heading (may skip &nbsp;, hr, figure)
          var sibling = heading.nextElementSibling;
          while (sibling != null) {
            final tagName = sibling.localName?.toLowerCase() ?? '';
            
            // Skip separators, images, and whitespace-only elements
            if (tagName == 'hr' || tagName == 'figure') {
              sibling = sibling.nextElementSibling;
              continue;
            }
            if (tagName == 'p') {
              // Check if p is just whitespace/nbsp
              final pText = (sibling.text ?? '').trim();
              if (pText.isEmpty || pText == '\u00a0') {
                sibling = sibling.nextElementSibling;
                continue;
              }
              // Otherwise it's directions, stop looking for ul
              break;
            }
            
            if (tagName == 'ul') {
              // Found the ingredient list for this section
              final items = sibling.querySelectorAll('li');
              if (items.isNotEmpty) {
                // Add section header
                rawIngredientStrings.add('[$sectionName]');
                for (final item in items) {
                  final text = _decodeHtml((item.text ?? '').trim());
                  if (text.isNotEmpty) {
                    rawIngredientStrings.add(text);
                  }
                }
              }
              break;
            }
            
            // Stop at next heading
            if (tagName == 'h2' || tagName == 'h3' || tagName == 'h4') {
              break;
            }
            
            sibling = sibling.nextElementSibling;
          }
        }
      }
    }
    
    // Add WordPress block Assembly notes to htmlNotes if extracted
    if (wpBlockAssemblyNotes != null) {
      if (htmlNotes != null && htmlNotes.isNotEmpty) {
        htmlNotes = '$htmlNotes\n\n$wpBlockAssemblyNotes';
      } else {
        htmlNotes = wpBlockAssemblyNotes;
      }
    }
    
    // If Cooked format didn't find ingredients, try schema.org Microdata format
    // (distinct from JSON-LD - uses itemtype/itemprop attributes in HTML)
    if (rawIngredientStrings.isEmpty) {
      // Look for Recipe microdata container
      final recipeContainer = document.querySelector('[itemtype*="schema.org/Recipe"], [itemtype*="Recipe"]');
      if (recipeContainer != null) {
        usedStructuredFormat = true;
        
        // Track if we got ingredients from meta content (often incomplete)
        var gotFromMetaContent = false;
        
        // Extract ingredients from microdata
        final microdataIngredients = recipeContainer.querySelectorAll('[itemprop="recipeIngredient"], [itemprop="ingredients"]');
        for (final e in microdataIngredients) {
          // Check for content attribute first (common for meta tags)
          final contentAttr = e.attributes['content'];
          if (contentAttr != null && contentAttr.isNotEmpty) {
            gotFromMetaContent = true;
            // Content might be comma-separated list of ingredients
            // But don't split on commas inside parentheses
            if (contentAttr.contains(',') && !contentAttr.contains('(')) {
              final parts = contentAttr.split(',');
              for (final part in parts) {
                final cleaned = _decodeHtml(part.trim());
                if (cleaned.isNotEmpty) {
                  rawIngredientStrings.add(cleaned);
                }
              }
            } else {
              rawIngredientStrings.add(_decodeHtml(contentAttr));
            }
          } else {
            final text = _decodeHtml((e.text ?? '').trim());
            if (text.isNotEmpty) {
              rawIngredientStrings.add(text);
            }
          }
        }
        
        // If we got ingredients from meta content, they're likely just names without quantities.
        // Try to find better detailed ingredients with quantities from HTML structure.
        if (gotFromMetaContent && rawIngredientStrings.isNotEmpty) {
          final hasQuantities = rawIngredientStrings.any((item) =>
            RegExp(r'\d+\s*[gG](?:\s|$|\))|[\d½¼¾⅓⅔]+\s*(?:cup|cups|tbsp|tablespoon|tsp|teaspoon|oz|ml)', caseSensitive: false).hasMatch(item)
          );
          
          if (!hasQuantities) {
            // Try to find detailed ingredients from HTML structure
            final sectionResult = _parseHtmlBySections(document);
            final detailedIngredients = sectionResult['ingredients'] as List<String>? ?? [];
            
            // Check if detailed ingredients have quantities
            final detailedHasQuantities = detailedIngredients.any((item) =>
              RegExp(r'\d+\s*[gG](?:\s|$|\))|[\d½¼¾⅓⅔]+\s*(?:cup|cups|tbsp|tablespoon|tsp|teaspoon|oz|ml)', caseSensitive: false).hasMatch(item)
            );
            
            if (detailedHasQuantities && detailedIngredients.length >= rawIngredientStrings.length) {
              // Use detailed ingredients instead
              rawIngredientStrings = detailedIngredients;
            }
          }
        }
        
        // Extract directions from microdata
        if (rawDirections.isEmpty) {
          final microdataInstructions = recipeContainer.querySelectorAll('[itemprop="recipeInstructions"]');
          for (final e in microdataInstructions) {
            // Check if it contains nested steps
            final nestedSteps = e.querySelectorAll('[itemprop="itemListElement"], [itemprop="step"], li, p');
            if (nestedSteps.isNotEmpty) {
              for (final step in nestedSteps) {
                final text = _decodeHtml((step.text ?? '').trim());
                if (text.isNotEmpty && text.length > 10) {
                  rawDirections.add(text);
                }
              }
            } else {
              final text = _decodeHtml((e.text ?? '').trim());
              if (text.isNotEmpty) {
                // Split by newlines or periods followed by capital letters
                final steps = text.split(RegExp(r'\n+|\. (?=[A-Z])'));
                for (final step in steps) {
                  if (step.trim().isNotEmpty && step.trim().length > 10) {
                    rawDirections.add(step.trim());
                  }
                }
              }
            }
          }
        }
        
        // Extract time from microdata
        if (timing == null) {
          final totalTimeEl = recipeContainer.querySelector('[itemprop="totalTime"]');
          final prepTimeEl = recipeContainer.querySelector('[itemprop="prepTime"]');
          final cookTimeEl = recipeContainer.querySelector('[itemprop="cookTime"]');
          
          if (totalTimeEl != null) {
            final timeContent = totalTimeEl.attributes['content'] ?? totalTimeEl.attributes['datetime'] ?? totalTimeEl.text;
            if (timeContent != null) {
              timing = _parseDuration(timeContent);
            }
          } else {
            int totalMins = 0;
            if (prepTimeEl != null) {
              final timeContent = prepTimeEl.attributes['content'] ?? prepTimeEl.attributes['datetime'] ?? prepTimeEl.text;
              if (timeContent != null) totalMins += _parseDurationMinutes(timeContent);
            }
            if (cookTimeEl != null) {
              final timeContent = cookTimeEl.attributes['content'] ?? cookTimeEl.attributes['datetime'] ?? cookTimeEl.text;
              if (timeContent != null) totalMins += _parseDurationMinutes(timeContent);
            }
            if (totalMins > 0) timing = _formatMinutes(totalMins);
          }
        }
        
        // Extract yield from microdata
        if (yield == null) {
          final yieldEl = recipeContainer.querySelector('[itemprop="recipeYield"]');
          if (yieldEl != null) {
            yield = _decodeHtml((yieldEl.text ?? '').trim());
          }
        }
      }
    }
    
    // Try popular recipe plugin formats
    if (rawIngredientStrings.isEmpty) {
      // Tasty Recipes plugin
      final tastyIngredients = document.querySelectorAll('.tasty-recipes-ingredients li, .tasty-recipes-ingredient');
      if (tastyIngredients.isNotEmpty) {
        usedStructuredFormat = true;
        for (final e in tastyIngredients) {
          final text = _decodeHtml((e.text ?? '').trim());
          if (text.isNotEmpty) rawIngredientStrings.add(text);
        }
      }
      
      // Try Tasty Recipes directions
      if (rawDirections.isEmpty) {
        final tastyDirections = document.querySelectorAll('.tasty-recipes-instructions li, .tasty-recipes-instruction');
        for (final e in tastyDirections) {
          final text = _decodeHtml((e.text ?? '').trim());
          if (text.isNotEmpty) rawDirections.add(text);
        }
      }
    }
    
    if (rawIngredientStrings.isEmpty) {
      // EasyRecipe plugin
      final easyIngredients = document.querySelectorAll('.ERSIngredients li, .easy-recipe-ingredients li');
      if (easyIngredients.isNotEmpty) {
        usedStructuredFormat = true;
        for (final e in easyIngredients) {
          final text = _decodeHtml((e.text ?? '').trim());
          if (text.isNotEmpty) rawIngredientStrings.add(text);
        }
      }
      
      if (rawDirections.isEmpty) {
        final easyDirections = document.querySelectorAll('.ERSInstructions li, .easy-recipe-instructions li');
        for (final e in easyDirections) {
          final text = _decodeHtml((e.text ?? '').trim());
          if (text.isNotEmpty) rawDirections.add(text);
        }
      }
    }
    
    // Try Weber-specific ingredient parsing BEFORE generic selectors
    // Weber uses .ingredient-item with .screen-reader-text that should be excluded
    if (rawIngredientStrings.isEmpty) {
      final weberIngredients = document.querySelectorAll('.ingredient-item');
      if (weberIngredients.isNotEmpty) {
        // Check if this looks like Weber (has .ingredient-label children)
        final hasWeberFormat = weberIngredients.any((e) => e.querySelector('.ingredient-label') != null);
        if (hasWeberFormat) {
          for (final e in weberIngredients) {
            // Get the ingredient-label span, excluding screen-reader-text
            final labelSpan = e.querySelector('.ingredient-label');
            if (labelSpan != null) {
              // Clone the node to avoid modifying original document
              final labelClone = labelSpan.clone(true);
              // Remove screen-reader-text elements before extracting text
              final srTexts = labelClone.querySelectorAll('.screen-reader-text');
              for (final sr in srTexts) {
                sr.remove();
              }
              final text = _decodeHtml((labelClone.text ?? '').trim());
              // Clean up excessive whitespace from Weber's HTML
              final cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();
              if (cleaned.isNotEmpty) {
                rawIngredientStrings.add(cleaned);
              }
            }
          }
        }
      }
    }
    
    // Try Weber-specific serves/time extraction
    // Weber uses .attribute-item with .label and .copy children
    if (yield == null || timing == null) {
      int totalMinutes = 0;
      final weberAttributes = document.querySelectorAll('.attribute-item');
      for (final attr in weberAttributes) {
        final labelElem = attr.querySelector('.label');
        final copyElem = attr.querySelector('.copy');
        if (labelElem != null && copyElem != null) {
          final label = _decodeHtml((labelElem.text ?? '').trim().toLowerCase());
          final value = _decodeHtml((copyElem.text ?? '').trim());
          if (label.contains('people') || label.contains('serves') || label.contains('servings')) {
            // Extract just the number from "Serves 4"
            final servesMatch = RegExp(r'(\d+)').firstMatch(value);
            if (servesMatch != null) {
              yield = servesMatch.group(1);
            }
          } else if (label.contains('time') || label.contains('prep') || label.contains('cook') || label.contains('grill')) {
            // Parse and sum times instead of concatenating
            totalMinutes += _parseDurationMinutes(value);
          }
        }
      }
      // Format total minutes if we found any time values
      if (totalMinutes > 0 && timing == null) {
        timing = _formatMinutes(totalMinutes);
      }
    }
    
    // Generic h4 + <p><br> pattern fallback: For non-Squarespace sites with similar structure
    // (Squarespace is handled earlier with explicit detection)
    // Sections marked with <strong>Section Name:</strong>
    if (rawIngredientStrings.isEmpty || rawDirections.isEmpty) {
      // Look for h4 elements containing INGREDIENTS: or METHOD:
      final h4Elements = document.querySelectorAll('h4');
      
      for (final h4 in h4Elements) {
        final h4Text = (h4.text ?? '').trim().toUpperCase();
        
        if (h4Text.contains('INGREDIENTS') && rawIngredientStrings.isEmpty) {
          // Get next sibling - usually a <p> tag with content
          var sibling = h4.nextElementSibling;
          while (sibling != null) {
            final tagName = sibling.localName?.toLowerCase() ?? '';
            
            // Stop at next h4 (METHOD section) or h3/h2
            if (tagName == 'h4' || tagName == 'h3' || tagName == 'h2') {
              break;
            }
            
            if (tagName == 'p') {
              // Get the inner HTML to preserve <strong> and <br> tags
              final innerHtml = sibling.innerHtml ?? '';
              
              // Split by <br> and <br/> and <br />
              final lines = innerHtml.split(RegExp(r'<br\s*/?\s*>', caseSensitive: false));
              
              for (var line in lines) {
                // Decode HTML entities and strip remaining tags
                line = line.trim();
                if (line.isEmpty) continue;
                
                // Check for section header: <strong>Section Name:</strong> pattern
                final strongMatch = RegExp(
                  r'^<strong[^>]*>([^<]+):?\s*</strong>\s*$',
                  caseSensitive: false,
                ).firstMatch(line);
                
                if (strongMatch != null) {
                  // This is a section header
                  var sectionName = _decodeHtml(strongMatch.group(1)?.trim() ?? '');
                  // Remove trailing colon if present
                  if (sectionName.endsWith(':')) {
                    sectionName = sectionName.substring(0, sectionName.length - 1).trim();
                  }
                  if (sectionName.isNotEmpty) {
                    rawIngredientStrings.add('[$sectionName]');
                  }
                } else {
                  // Regular ingredient line - strip all HTML tags
                  final text = _decodeHtml(line.replaceAll(RegExp(r'<[^>]+>'), '').trim());
                  if (text.isNotEmpty) {
                    rawIngredientStrings.add(text);
                  }
                }
              }
            }
            
            sibling = sibling.nextElementSibling;
          }
        }
        
        if ((h4Text.contains('METHOD') || h4Text.contains('DIRECTIONS') || h4Text.contains('INSTRUCTIONS')) && rawDirections.isEmpty) {
          // Get next sibling - usually a <p> tag with content
          var sibling = h4.nextElementSibling;
          while (sibling != null) {
            final tagName = sibling.localName?.toLowerCase() ?? '';
            
            // Stop at next h4 or h3/h2 (like YIELD section)
            if (tagName == 'h4' || tagName == 'h3' || tagName == 'h2') {
              break;
            }
            
            if (tagName == 'p') {
              final innerHtml = sibling.innerHtml ?? '';
              
              // Split by <br> tags
              final lines = innerHtml.split(RegExp(r'<br\s*/?\s*>', caseSensitive: false));
              
              for (var line in lines) {
                line = line.trim();
                if (line.isEmpty) continue;
                
                // Check for section header: <strong>For the Section:</strong> pattern
                final strongMatch = RegExp(
                  r'^<strong[^>]*>([^<]+):?\s*</strong>\s*$',
                  caseSensitive: false,
                ).firstMatch(line);
                
                if (strongMatch != null) {
                  // This is a direction section header
                  var sectionName = _decodeHtml(strongMatch.group(1)?.trim() ?? '');
                  if (sectionName.endsWith(':')) {
                    sectionName = sectionName.substring(0, sectionName.length - 1).trim();
                  }
                  if (sectionName.isNotEmpty) {
                    rawDirections.add('[${_stripForThePrefix(sectionName)}]');
                  }
                } else {
                  // Regular direction step - strip all HTML tags
                  final text = _decodeHtml(line.replaceAll(RegExp(r'<[^>]+>'), '').trim());
                  if (text.isNotEmpty) {
                    rawDirections.add(text);
                  }
                }
              }
            }
            
            sibling = sibling.nextElementSibling;
          }
        }
      }
      
      // Extract yield from "Yield: X servings" text anywhere in page
      if (yield == null) {
        final bodyText = document.body?.text ?? '';
        final yieldMatch = RegExp(r'Yield:\s*(\d+)\s*(?:servings?|portions?)?', caseSensitive: false).firstMatch(bodyText);
        if (yieldMatch != null) {
          yield = yieldMatch.group(1);
        }
      }
    }
    
    if (rawIngredientStrings.isEmpty) {
      // Yummly / ZipList / other common formats (excluding .ingredient-item which is handled above)
      final yummlyIngredients = document.querySelectorAll('.recipe-ingredients li, .recipe-ingred_txt, .Ingredient, .p-ingredient');
      if (yummlyIngredients.isNotEmpty) {
        for (final e in yummlyIngredients) {
          final text = _decodeHtml((e.text ?? '').trim());
          if (text.isNotEmpty) rawIngredientStrings.add(text);
        }
      }
    }
    
    if (rawDirections.isEmpty && rawIngredientStrings.isNotEmpty) {
      // Try common instruction selectors
      final commonDirections = document.querySelectorAll('.recipe-instructions li, .recipe-procedure li, .instruction-item, .step-text, .p-instructions li, .Instruction');
      for (final e in commonDirections) {
        final text = _decodeHtml((e.text ?? '').trim());
        if (text.isNotEmpty) rawDirections.add(text);
      }
    }
    
    // If still empty, try standard selectors
    if (rawIngredientStrings.isEmpty) {
      final ingredientElements = document.querySelectorAll(
        // Standard recipe plugins and schema.org
        '.ingredients li, .ingredient-list li, [itemprop="recipeIngredient"], .wprm-recipe-ingredient, '
        // Shopify/blog patterns
        '.recipe-ingredients li, .recipe__ingredients li, [class*="ingredient"] li, '
        // Generic patterns for blog posts
        '.entry-content ul li, .post-content ul li, article ul li',
      );
      
      for (final e in ingredientElements) {
        final text = _decodeHtml((e.text ?? '').trim());
        if (text.isNotEmpty) {
          rawIngredientStrings.add(text);
        }
      }
    }
    
    // If standard selectors failed, try section-based parsing
    // This handles sites like Modernist Pantry that use headings + lists
    if (rawIngredientStrings.isEmpty) {
      final sectionResult = _parseHtmlBySections(document);
      rawIngredientStrings = sectionResult['ingredients'] ?? [];
      equipmentItems = sectionResult['equipment'] ?? [];
      glassType = sectionResult['glass'];
      garnishItems = sectionResult['garnish'] ?? [];
      yield = sectionResult['yield'];
      timing = sectionResult['timing'];
      htmlNotes = sectionResult['notes'] as String?;
      // Section-based parsing is semi-structured
      if (rawIngredientStrings.isNotEmpty) {
        usedStructuredFormat = true;
      }
    }
    
    // If still empty, try <br>-separated content in paragraphs (Bradley Smoker style)
    // Pattern: <h2>Ingredients</h2> followed by <p>item1<br>item2<br>item3</p>
    // Also handles Shopify blogs: <div class="h3">Ingredients</div> followed by metafield-rich_text_field
    if (rawIngredientStrings.isEmpty) {
      // Look for headings containing "Ingredients" - include actual headings and div.h3 patterns
      for (final heading in document.querySelectorAll('h1, h2, h3, .h3, [class*="heading"]')) {
        final headingText = (heading.text ?? '').toLowerCase().trim();
        if (headingText.contains('ingredient')) {
          // Get the next sibling div or paragraph
          var nextElement = heading.nextElementSibling;
          // Sometimes there's a wrapper div between heading and content (Shopify metafield pattern)
          if (nextElement?.localName == 'div') {
            // Check for metafield-rich_text_field or similar wrapper
            final innerP = nextElement!.querySelector('p');
            if (innerP != null) {
              nextElement = innerP;
            }
          }
          if (nextElement != null && (nextElement.localName == 'p' || nextElement.localName == 'div')) {
            // Get the inner HTML and split by <br>
            final innerHtml = nextElement.innerHtml;
            if (innerHtml.contains('<br')) {
              final parts = innerHtml.split(RegExp(r'<br\s*/?>', caseSensitive: false));
              for (final part in parts) {
                // Strip HTML tags and decode
                final text = _decodeHtml(part.replaceAll(RegExp(r'<[^>]+>'), '').trim());
                if (text.isNotEmpty) {
                  rawIngredientStrings.add(text);
                }
              }
              break;
            }
          }
        }
      }
    }
    
    // If still empty, try Shopify article-ingredients-list pattern directly
    if (rawIngredientStrings.isEmpty) {
      final shopifyIngredientContainer = document.querySelector('.article-ingredients-list p, [class*="ingredient-list"] p, [class*="ingredients-list"] p');
      if (shopifyIngredientContainer != null) {
        final innerHtml = shopifyIngredientContainer.innerHtml;
        if (innerHtml.contains('<br')) {
          final parts = innerHtml.split(RegExp(r'<br\s*/?>', caseSensitive: false));
          for (final part in parts) {
            final text = _decodeHtml(part.replaceAll(RegExp(r'<[^>]+>'), '').trim());
            if (text.isNotEmpty) {
              rawIngredientStrings.add(text);
            }
          }
        }
      }
    }
    
    if (rawIngredientStrings.isEmpty) {
      // Even if we found ingredients via other methods, still extract equipment
      // This handles sites that have structured ingredients but also equipment sections
      final sectionResult = _parseHtmlBySections(document);
      if ((sectionResult['equipment'] as List?)?.isNotEmpty ?? false) {
        equipmentItems = sectionResult['equipment'] ?? [];
      }
      if (sectionResult['glass'] != null) {
        glassType = sectionResult['glass'];
      }
      if ((sectionResult['garnish'] as List?)?.isNotEmpty ?? false) {
        garnishItems = sectionResult['garnish'] ?? [];
      }
      if (yield == null && sectionResult['yield'] != null) {
        yield = sectionResult['yield'];
      }
      if (timing == null && sectionResult['timing'] != null) {
        timing = sectionResult['timing'];
      }
      if (htmlNotes == null && sectionResult['notes'] != null) {
        htmlNotes = sectionResult['notes'] as String?;
      }
    } else {
      // Ingredients were found via other methods, still extract equipment/glass/garnish
      final sectionResult = _parseHtmlBySections(document);
      if ((sectionResult['equipment'] as List?)?.isNotEmpty ?? false) {
        equipmentItems = sectionResult['equipment'] ?? [];
      }
      if (sectionResult['glass'] != null) {
        glassType = sectionResult['glass'];
      }
      if ((sectionResult['garnish'] as List?)?.isNotEmpty ?? false) {
        garnishItems = sectionResult['garnish'] ?? [];
      }
      if (yield == null && sectionResult['yield'] != null) {
        yield = sectionResult['yield'];
      }
      if (timing == null && sectionResult['timing'] != null) {
        timing = sectionResult['timing'];
      }
      if (htmlNotes == null && sectionResult['notes'] != null) {
        htmlNotes = sectionResult['notes'] as String?;
      }
    }
    
    // Filter ingredients and extract directions/equipment that were mixed in
    // This handles sites where directions and equipment are in the same HTML list as ingredients
    List<String> extractedDirectionsFromIngredients = [];
    List<String> extractedEquipmentFromIngredients = [];
    
    if (rawIngredientStrings.isNotEmpty) {
      final filterResult = _filterIngredientStringsWithExtraction(rawIngredientStrings);
      rawIngredientStrings = filterResult['ingredients'] ?? [];
      extractedDirectionsFromIngredients = filterResult['directions'] ?? [];
      extractedEquipmentFromIngredients = filterResult['equipment'] ?? [];
      
      // Add extracted equipment to equipment list
      if (extractedEquipmentFromIngredients.isNotEmpty) {
        equipmentItems = [...equipmentItems, ...extractedEquipmentFromIngredients];
      }
    }
    
    // Parse ingredients - use _parseIngredients which properly handles section headers
    // by tracking them and applying to subsequent ingredients, rather than adding empty-name entries
    var ingredients = _parseIngredients(rawIngredientStrings);
    
    ingredients = _sortIngredientsByQuantity(ingredients);

    // If Cooked format didn't find directions, try standard selectors
    if (rawDirections.isEmpty) {
      final instructionElements = document.querySelectorAll(
        '.instructions li, .directions li, [itemprop="recipeInstructions"] li, .wprm-recipe-instruction, '
        // Shopify blog patterns - use specific method list, not generic metafield (which includes ingredients)
        '.article-method-list li, .article-method-list ol li, '
        // Generic method/preparation sections
        '[class*="method-list"] li, [class*="preparation"] li, [class*="instruction"] li, '
        // Generic article content - ol is typically for numbered instructions
        'article ol li, .entry-content ol li, .post-content ol li',
      );
      
      for (final e in instructionElements) {
        final text = _decodeHtml((e.text ?? '').trim());
        if (text.isNotEmpty) {
          rawDirections.add(text);
        }
      }
    }
    
    // Try WordPress block heading direction pattern (sogoodmagazine.com style):
    // p elements after ul (ingredients) within .content-info section
    // Structure: h3 → ul (ingredients) → p (directions) → hr → repeat
    if (rawDirections.isEmpty) {
      final contentInfo = document.querySelector('.content-info');
      if (contentInfo != null) {
        final wpBlockHeadings = contentInfo.querySelectorAll('h3.wp-block-heading');
        if (wpBlockHeadings.isNotEmpty) {
          for (final heading in wpBlockHeadings) {
            final sectionName = _decodeHtml((heading.text ?? '').trim());
            if (sectionName.isEmpty) continue;
            
            final lowerSection = sectionName.toLowerCase();
            // Skip non-recipe headings
            if (lowerSection.contains('discover') || lowerSection.contains('related')) {
              continue;
            }
            
            // Find the ul (ingredients) then get p elements after it
            var sibling = heading.nextElementSibling;
            var foundUl = false;
            
            while (sibling != null) {
              final tagName = sibling.localName?.toLowerCase() ?? '';
              
              // Skip hr separators and whitespace-only elements
              if (tagName == 'hr') {
                sibling = sibling.nextElementSibling;
                continue;
              }
              
              if (tagName == 'ul') {
                // Skip the ingredient list, mark that we found it
                foundUl = true;
                sibling = sibling.nextElementSibling;
                continue;
              }
              
              // After finding ul, extract p elements as directions until next h3/h2/hr
              if (foundUl && tagName == 'p') {
                final text = _decodeHtml((sibling.text ?? '').trim());
                // Skip whitespace-only paragraphs
                if (text.isNotEmpty && text != '\u00a0' && text.length > 15) {
                  rawDirections.add(text);
                }
              }
              
              // Skip figure elements (images between directions)
              if (tagName == 'figure') {
                sibling = sibling.nextElementSibling;
                continue;
              }
              
              // Stop at next heading or horizontal rule (new section)
              if (tagName == 'h2' || tagName == 'h3' || tagName == 'h4') {
                break;
              }
              
              sibling = sibling.nextElementSibling;
            }
          }
        }
      }
    }
    
    // Try WordPress block heading direction pattern without .content-info wrapper (pastryartsmag.com style):
    // h3.wp-block-heading followed by ul (ingredients) then ol/p (directions) on document level
    if (rawDirections.isEmpty) {
      final wpBlockHeadings = document.querySelectorAll('h3.wp-block-heading');
      if (wpBlockHeadings.isNotEmpty) {
        for (final heading in wpBlockHeadings) {
          final sectionName = _decodeHtml((heading.text ?? '').trim());
          if (sectionName.isEmpty) continue;
          
          final lowerSection = sectionName.toLowerCase();
          // Skip non-recipe headings
          if (lowerSection.contains('discover') || 
              lowerSection.contains('related') ||
              lowerSection.contains('podcast') ||
              lowerSection.contains('latest')) {
            continue;
          }
          
          // Skip if section name looks like a link (e.g., "Recipe Name by Author")
          if (sectionName.contains(' by ') && lowerSection.contains('recipe')) {
            continue;
          }
          
          // Add section header for multi-component recipes
          final sectionHeader = '**$sectionName**';
          var addedSectionHeader = false;
          
          // Find the ul (ingredients) then get ol/p elements after it
          var sibling = heading.nextElementSibling;
          var foundUl = false;
          
          while (sibling != null) {
            final tagName = sibling.localName?.toLowerCase() ?? '';
            
            // Skip hr separators and whitespace-only elements
            if (tagName == 'hr') {
              sibling = sibling.nextElementSibling;
              continue;
            }
            
            if (tagName == 'ul') {
              // Skip the ingredient list, mark that we found it
              foundUl = true;
              sibling = sibling.nextElementSibling;
              continue;
            }
            
            // After finding ul, extract ol (numbered list) or p elements as directions
            if (foundUl && tagName == 'ol') {
              final items = sibling.querySelectorAll('li');
              if (items.isNotEmpty) {
                // Add section header before directions
                if (!addedSectionHeader) {
                  rawDirections.add(sectionHeader);
                  addedSectionHeader = true;
                }
                for (final item in items) {
                  final text = _decodeHtml((item.text ?? '').trim());
                  if (text.isNotEmpty) {
                    rawDirections.add(text);
                  }
                }
              }
            }
            
            if (foundUl && tagName == 'p') {
              final text = _decodeHtml((sibling.text ?? '').trim());
              // Skip whitespace-only paragraphs
              if (text.isNotEmpty && text != '\u00a0' && text.length > 15) {
                // Add section header before first direction
                if (!addedSectionHeader) {
                  rawDirections.add(sectionHeader);
                  addedSectionHeader = true;
                }
                rawDirections.add(text);
              }
            }
            
            // Skip figure elements (images between directions)
            if (tagName == 'figure') {
              sibling = sibling.nextElementSibling;
              continue;
            }
            
            // Stop at next heading or horizontal rule (new section)
            if (tagName == 'h2' || tagName == 'h3' || tagName == 'h4') {
              break;
            }
            
            sibling = sibling.nextElementSibling;
          }
        }
      }
    }
    
    // If standard selectors found nothing but we extracted direction-like lines from ingredients,
    // use those as the directions
    if (rawDirections.isEmpty && extractedDirectionsFromIngredients.isNotEmpty) {
      rawDirections = extractedDirectionsFromIngredients;
    }
    
    // If standard selectors failed, try step-based parsing
    // This handles sites that use h3 headings for step names
    if (rawDirections.isEmpty) {
      rawDirections = _parseDirectionsBySections(document);
      // Section-based parsing with h3 headings is semi-structured
      if (rawDirections.isNotEmpty) {
        usedStructuredFormat = true;
      }
    }
    
    // If still empty, try <p> paragraph-based directions (Bradley Smoker style)
    // Pattern: <h2>Preparation</h2> followed by <ol>/<ul> or multiple <p> elements
    // This handles simple blog sites like bread-code.io with h2#instructions + <ol>
    if (rawDirections.isEmpty) {
      for (final heading in document.querySelectorAll('h1, h2, h3')) {
        final headingText = (heading.text ?? '').toLowerCase().trim();
        if (headingText.contains('preparation') || 
            headingText.contains('instruction') || 
            headingText.contains('direction') ||
            headingText.contains('method')) {
          // Get all sibling elements until next heading
          var sibling = heading.nextElementSibling;
          while (sibling != null && 
                 sibling.localName != 'h1' && 
                 sibling.localName != 'h2' && 
                 sibling.localName != 'h3') {
            // Handle ordered/unordered lists (most common for instructions)
            if (sibling.localName == 'ol' || sibling.localName == 'ul') {
              for (final li in sibling.querySelectorAll('li')) {
                final text = _decodeHtml((li.text ?? '').trim());
                if (text.isNotEmpty) {
                  rawDirections.add(text);
                }
              }
            } else if (sibling.localName == 'p') {
              final text = _decodeHtml((sibling.text ?? '').trim());
              if (text.isNotEmpty && text.length > 20) { // Skip short paragraphs
                rawDirections.add(text);
              }
            } else if (sibling.localName == 'div') {
              // Check for lists or paragraphs inside a wrapper div
              final nestedList = sibling.querySelector('ol, ul');
              if (nestedList != null) {
                for (final li in nestedList.querySelectorAll('li')) {
                  final text = _decodeHtml((li.text ?? '').trim());
                  if (text.isNotEmpty) {
                    rawDirections.add(text);
                  }
                }
              } else {
                for (final p in sibling.querySelectorAll('p')) {
                  final text = _decodeHtml((p.text ?? '').trim());
                  if (text.isNotEmpty && text.length > 20) {
                    rawDirections.add(text);
                  }
                }
              }
            }
            sibling = sibling.nextElementSibling;
          }
          if (rawDirections.isNotEmpty) break;
        }
      }
    }

    // Extract step images from direction content
    // Some sites (like AmazingFoodMadeEasy) embed images in direction paragraphs
    stepImages = _extractStepImages(document, sourceUrl);

    // If we still don't have ingredients or directions, try one more aggressive pass
    if (rawIngredientStrings.isEmpty && rawDirections.isEmpty) {
      // Last resort: look for ANY lists that might contain recipe data
      // This is very permissive but better than failing completely
      final allLists = document.querySelectorAll('ul, ol');
      for (final list in allLists) {
        final items = list.querySelectorAll('li');
        if (items.length >= 2) {
          final itemTexts = <String>[];
          for (final e in items) {
            final text = _decodeHtml((e.text ?? '').trim());
            if (text.isNotEmpty && text.length < 200) { // Reasonable length for ingredients/directions
              itemTexts.add(text);
            }
          }
          
          // Check if items look like ingredients (have measurements/quantities)
          final hasMeasurements = itemTexts.any((item) => 
            // Standard measurement patterns
            RegExp(r'\d+\s*[gG](?:\s|$|\))|\d+\s*(?:cup|cups|tbsp|tablespoon|tsp|teaspoon|oz|ounce|ml|lb|pound|kg|kilogram|gram)', caseSensitive: false).hasMatch(item) ||
            // Unicode fractions with units
            RegExp(r'[½¼¾⅓⅔⅛⅜⅝⅞]\s*(?:cup|cups|tbsp|tablespoon|tsp|teaspoon|oz|lb|kg|g)?', caseSensitive: false).hasMatch(item) ||
            // Items with parentheses often contain measurements
            RegExp(r'\(.*\d+.*\)').hasMatch(item) ||
            // Plain numbers followed by ingredient words
            RegExp(r'^\d+\s+(?:large|medium|small|cloves?|bunch|can|jar|package|pkg|head|stalk|piece|slice|sprig)s?\b', caseSensitive: false).hasMatch(item) ||
            // Dash-separated ranges like "1-2 cups"
            RegExp(r'\d+\s*[-–]\s*\d+\s*(?:cup|tbsp|tsp|oz|g|ml)', caseSensitive: false).hasMatch(item) ||
            // Common food words with amounts
            RegExp(r'^\d+\s+\w+\s+(?:chicken|beef|pork|fish|onion|garlic|butter|oil|flour|sugar|salt|pepper|egg|milk|cream|cheese|tomato|potato|carrot|celery)', caseSensitive: false).hasMatch(item),
          );
          
          // Check if items look like directions (longer text, action verbs)
          final hasDirections = itemTexts.any((item) => 
            item.length > 30 && (
              RegExp(r'\b(?:put|place|add|mix|stir|heat|cook|bake|blend|pour|whisk|chop|dice|slice|mince|preheat|combine|fold|serve|remove|transfer|let|allow|season|taste)\b', caseSensitive: false).hasMatch(item) ||
              RegExp(r'^\d+[\.\)]').hasMatch(item) // Numbered steps
            )
          );
          
          if (hasMeasurements && itemTexts.length >= 2) {
            rawIngredientStrings = _processIngredientListItems(itemTexts);
          } else if (hasDirections && itemTexts.length >= 2 && rawDirections.isEmpty) {
            rawDirections = itemTexts;
          }
          
          if (rawIngredientStrings.isNotEmpty || rawDirections.isNotEmpty) {
            break;
          }
        }
      }
    }
    
    // Super aggressive fallback: scan ALL text content for ingredient-like patterns
    if (rawIngredientStrings.isEmpty) {
      // Look for definition lists (dl/dt/dd) which some sites use
      final defLists = document.querySelectorAll('dl');
      for (final dl in defLists) {
        final terms = dl.querySelectorAll('dt, dd');
        if (terms.length >= 2) {
          final itemTexts = <String>[];
          for (final term in terms) {
            final text = _decodeHtml((term.text ?? '').trim());
            if (text.isNotEmpty && text.length < 150) {
              itemTexts.add(text);
            }
          }
          // Check if any have measurement patterns
          final hasMeasurements = itemTexts.any((item) => 
            RegExp(r'\d+\s*(?:g|kg|oz|lb|cup|tbsp|tsp|ml)', caseSensitive: false).hasMatch(item),
          );
          if (hasMeasurements) {
            rawIngredientStrings = _processIngredientListItems(itemTexts);
            break;
          }
        }
      }
    }
    
    // Try table-based recipes (some sites use tables for ingredients)
    if (rawIngredientStrings.isEmpty) {
      final tables = document.querySelectorAll('table');
      for (final table in tables) {
        final rows = table.querySelectorAll('tr');
        if (rows.length >= 2) {
          final itemTexts = <String>[];
          for (final row in rows) {
            final cells = row.querySelectorAll('td, th');
            if (cells.isNotEmpty) {
              // Combine cells into a single ingredient string
              final cellTexts = <String>[];
              for (final cell in cells) {
                final text = _decodeHtml((cell.text ?? '').trim());
                if (text.isNotEmpty) cellTexts.add(text);
              }
              if (cellTexts.isNotEmpty) {
                itemTexts.add(cellTexts.join(' '));
              }
            }
          }
          // Check if any have measurement patterns
          final hasMeasurements = itemTexts.any((item) => 
            RegExp(r'\d+\s*(?:g|kg|oz|lb|cup|tbsp|tsp|ml)', caseSensitive: false).hasMatch(item),
          );
          if (hasMeasurements && itemTexts.length >= 2) {
            rawIngredientStrings = _processIngredientListItems(itemTexts);
            break;
          }
        }
      }
    }
    
    // Final fallback: scan entire body for ingredient-like content
    // This handles sites like Modernist Pantry that use plain text bullets or unusual formatting
    if (rawIngredientStrings.isEmpty) {
      final bodyText = document.body?.text ?? '';
      
      // Try multiple bullet/separator characters
      final bulletChars = ['•', '\u2022', '\u2023', '\u25E6', '·', '●', '○'];
      String? bulletChar;
      for (final bc in bulletChars) {
        if (bodyText.contains(bc)) {
          bulletChar = bc;
          break;
        }
      }
      
      if (bulletChar != null) {
        // Split by the found bullet character
        final allBulletItems = bodyText.split(bulletChar);
        final potentialIngredients = <String>[];
        
        for (var item in allBulletItems) {
          // Take only first line of each bullet item
          final firstNewline = item.indexOf('\n');
          if (firstNewline > 0) {
            item = item.substring(0, firstNewline);
          }
          item = _decodeHtml(item.trim());
          
          if (item.isEmpty || item.length < 3 || item.length > 150) continue;
          
          // Skip if it looks like binary or encoded data
          if (_looksLikeBinaryOrEncoded(item)) continue;
          
          // Skip obvious non-ingredient lines
          if (item.toLowerCase().contains('subscribe') || 
              item.toLowerCase().contains('http') ||
              item.toLowerCase().contains('click') ||
              item.toLowerCase().contains('menu') ||
              item.toLowerCase().contains('instagram') ||
              item.toLowerCase().contains('facebook')) continue;
          
          // Check if this looks like an ingredient (has a measurement or is a section header)
          final looksLikeIngredient = 
              RegExp(r'\d+\s*[gG](?:\s|$|\))|\d+\s*(?:cup|cups|tbsp|tablespoon|tsp|teaspoon|oz|ounce|ml|lb|pound|kg)', caseSensitive: false).hasMatch(item) ||
              RegExp(r'[½¼¾⅓⅔⅛⅜⅝⅞]', caseSensitive: false).hasMatch(item) ||
              RegExp(r'\(\d+[^)]*\)', caseSensitive: false).hasMatch(item) || // Has parenthetical measurement
              item.endsWith(':'); // Section header like "Ingredients Black Garlic Honey:"
          
          if (looksLikeIngredient) {
            potentialIngredients.add(item);
          }
        }
        
        if (potentialIngredients.length >= 2) {
          rawIngredientStrings = _processIngredientListItems(potentialIngredients);
        }
      }
      
      // If still no ingredients, try line-by-line scanning for measurement patterns
      if (rawIngredientStrings.isEmpty) {
        final lines = bodyText.split('\n');
        final potentialIngredients = <String>[];
        bool inIngredientSection = false;
        
        for (var line in lines) {
          line = _decodeHtml(line.trim());
          if (line.isEmpty) continue;
          
          // Check if we're entering an ingredients section
          if (line.toLowerCase().contains('ingredient') && line.length < 50) {
            inIngredientSection = true;
            continue;
          }
          
          // Check if we're leaving the ingredients section
          if (inIngredientSection && 
              (line.toLowerCase().contains('equipment') ||
               line.toLowerCase().contains('direction') ||
               line.toLowerCase().contains('instruction') ||
               line.toLowerCase().contains('method') ||
               line.toLowerCase().contains('step') && line.length < 30)) {
            break;
          }
          
          if (inIngredientSection && line.length > 3 && line.length < 150) {
            // Skip if it looks like binary or encoded data
            if (_looksLikeBinaryOrEncoded(line)) continue;
            
            // Check if this looks like an ingredient
            final looksLikeIngredient = 
                RegExp(r'\d+\s*[gG](?:\s|$|\))|\d+\s*(?:cup|cups|tbsp|tablespoon|tsp|teaspoon|oz|ounce|ml|lb|pound|kg)', caseSensitive: false).hasMatch(line) ||
                RegExp(r'[½¼¾⅓⅔⅛⅜⅝⅞]', caseSensitive: false).hasMatch(line) ||
                RegExp(r'\(\d+[^)]*(?:cup|tbsp|tsp|oz|g)\)', caseSensitive: false).hasMatch(line) ||
                line.endsWith(':');
            
            if (looksLikeIngredient) {
              potentialIngredients.add(line);
            }
          }
        }
        
        if (potentialIngredients.length >= 2) {
          rawIngredientStrings = _processIngredientListItems(potentialIngredients);
        }
      }
      
      // Ultimate fallback: find ALL lines with measurement patterns anywhere in the body
      // This works even without section headers or proper line breaks
      if (rawIngredientStrings.isEmpty) {
        // Use regex to find measurement patterns with context
        final measurementPattern = RegExp(
          r'(\d+\s*[gG](?:\s|\))|(?:\d+\s*)?(?:[½¼¾⅓⅔⅛⅜⅝⅞])\s*(?:cup|cups|tbsp|tsp)?|\d+\s*(?:cup|cups|tbsp|tablespoon|tsp|teaspoon|oz|ounce|ml|lb|pound|kg|g)\b|\(\s*\d+[^)]*(?:cup|tbsp|tsp|oz|g)[^)]*\))',
          caseSensitive: false,
        );
        
        // Split body by potential line breaks or sentence endings
        final segments = bodyText.split(RegExp(r'\n|(?<=[.!?])\s+(?=[A-Z])'));
        final potentialIngredients = <String>[];
        
        for (var segment in segments) {
          segment = _decodeHtml(segment.trim());
          
          // Skip if too short or too long
          if (segment.length < 5 || segment.length > 200) continue;
          
          // Skip if it looks like base64 or binary data
          // Base64 has long strings without spaces and special char patterns
          if (_looksLikeBinaryOrEncoded(segment)) continue;
          
          // Skip if it looks like a direction/instruction (starts with verb)
          if (RegExp(r'^(put|place|add|mix|stir|pour|heat|cook|bake|preheat|combine|whisk|blend|let|allow)\b', caseSensitive: false).hasMatch(segment)) {
            continue;
          }
          
          // Skip navigation/social content
          if (segment.toLowerCase().contains('subscribe') ||
              segment.toLowerCase().contains('http') ||
              segment.toLowerCase().contains('click') ||
              segment.toLowerCase().contains('instagram') ||
              segment.toLowerCase().contains('facebook') ||
              segment.toLowerCase().contains('newsletter')) {
            continue;
          }
          
          // Check if segment contains a measurement pattern
          if (measurementPattern.hasMatch(segment)) {
            // Additional check: measurement should be near the start (first 60 chars)
            // This filters out sentences that mention measurements mid-way
            final match = measurementPattern.firstMatch(segment);
            if (match != null && match.start < 60) {
              potentialIngredients.add(segment);
            }
          }
        }
        
        if (potentialIngredients.length >= 2) {
          rawIngredientStrings = _processIngredientListItems(potentialIngredients);
        }
      }
      
      // Super simple bodyText pattern: just regex match "Xg (anything) Word" directly
      if (rawIngredientStrings.isEmpty) {
        final simplePattern = RegExp(
          r'(\d+\s*g\s*\([^)]+\)\s*[A-Za-z][A-Za-z\s]{1,30})',
          caseSensitive: false,
        );
        final matches = simplePattern.allMatches(bodyText);
        final potentialIngredients = <String>[];
        
        for (final match in matches) {
          final ingredient = _decodeHtml(match.group(1)?.trim() ?? '');
          if (_isValidIngredientCandidate(ingredient)) {
            potentialIngredients.add(ingredient);
          }
        }
        
        if (potentialIngredients.length >= 2) {
          rawIngredientStrings = _processIngredientListItems(potentialIngredients);
        }
      }
      
      // Dead simple: find ANY text around gram measurements
      // This is the most lenient fallback - captures surrounding context of "###g" or "### g"
      if (rawIngredientStrings.isEmpty) {
        // Find positions of all gram measurements in text (allow optional space before g)
        final gramPattern = RegExp(r'\d+\s*g\b', caseSensitive: false);
        final gramMatches = gramPattern.allMatches(bodyText).toList();
        final potentialIngredients = <String>[];
        
        for (final match in gramMatches) {
          // Capture 50 chars after the gram measurement
          final start = match.start;
          final end = (match.end + 50).clamp(0, bodyText.length);
          var snippet = bodyText.substring(start, end).trim();
          
          // Skip if too short
          if (snippet.length < 5) continue;
          
          // Clean up - stop at newline or next measurement
          final newlineIdx = snippet.indexOf('\n');
          if (newlineIdx > 0 && newlineIdx < 60) snippet = snippet.substring(0, newlineIdx);
          
          // Only look for next gram if snippet is long enough
          if (snippet.length > 5) {
            final nextGramIdx = snippet.indexOf(RegExp(r'\d+\s*g', caseSensitive: false), 5);
            if (nextGramIdx > 0 && nextGramIdx < 60) snippet = snippet.substring(0, nextGramIdx);
          }
          
          snippet = _decodeHtml(snippet.trim());
          
          // Basic validation - should have letters (ingredient name)
          if (snippet.length >= 8 && 
              snippet.length <= 100 &&
              RegExp(r'[A-Za-z]{3,}').hasMatch(snippet) &&
              !_looksLikeBinaryOrEncoded(snippet)) {
            potentialIngredients.add(snippet);
          }
        }
        
        if (potentialIngredients.length >= 2) {
          rawIngredientStrings = _processIngredientListItems(potentialIngredients);
        }
      }
    }
    
    // Raw HTML fallback: search the raw HTML source for ingredient patterns
    // This runs independently of DOM parsing and handles sites where DOM fails
    if (rawIngredientStrings.isEmpty && rawHtmlBody != null) {
      // Strip HTML tags to get clean text from raw HTML
      final cleanHtml = rawHtmlBody
          .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '')
          .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '')
          .replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll(RegExp(r'&bull;|&middot;|&#8226;|&#x2022;', caseSensitive: false), '•') // Preserve bullet entities as •
          .replaceAll(RegExp(r'&[a-z]+;', caseSensitive: false), ' ')
          .replaceAll(RegExp(r'&#\d+;'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ');
      
      final potentialIngredients = <String>[];
      
      // Pattern 1: Look for "Xg (Y Unit) Name" format (like Modernist Pantry)
      // Example: "200g (½ Cup) Honey" or "240g (1 Cup) Milk"
      final metricWithConversion = RegExp(
        r'(\d+g?\s*\([^)]{2,20}\)\s*[A-Za-z][A-Za-z\s\-]{2,40}?)(?=\s*\d+g|\s*•|\s*$|[,.])',
        caseSensitive: false,
      );
      
      for (final match in metricWithConversion.allMatches(cleanHtml)) {
        final ingredient = _decodeHtml(match.group(1)?.trim() ?? '');
        if (_isValidIngredientCandidate(ingredient)) {
          potentialIngredients.add(ingredient);
        }
      }
      
      // Pattern 2: Standard measurements with ingredient names
      if (potentialIngredients.isEmpty) {
        final standardMeasurement = RegExp(
          r'(\d+(?:\.\d+)?\s*(?:g|kg|oz|lb|lbs|cup|cups|tbsp|tablespoons?|tsp|teaspoons?|ml|liters?|litres?)\s+[A-Za-z][A-Za-z\s\-,]{2,50})',
          caseSensitive: false,
        );
        
        for (final match in standardMeasurement.allMatches(cleanHtml)) {
          final ingredient = _decodeHtml(match.group(1)?.trim() ?? '');
          if (_isValidIngredientCandidate(ingredient)) {
            potentialIngredients.add(ingredient);
          }
        }
      }
      
      // Pattern 3: Fractional measurements
      if (potentialIngredients.isEmpty) {
        final fractionalPattern = RegExp(
          r'([½¼¾⅓⅔⅛]\s*(?:cup|cups|tbsp|tsp|teaspoon|tablespoon)s?\s+[A-Za-z][A-Za-z\s\-,]{2,50})',
          caseSensitive: false,
        );
        
        for (final match in fractionalPattern.allMatches(cleanHtml)) {
          final ingredient = _decodeHtml(match.group(1)?.trim() ?? '');
          if (_isValidIngredientCandidate(ingredient)) {
            potentialIngredients.add(ingredient);
          }
        }
      }
      
      // Pattern 4: Ultra-simple gram pattern - just find "Xg (" or "X g (" followed by anything
      // This is very lenient for sites like Modernist Pantry
      if (potentialIngredients.isEmpty) {
        // Find all instances of "### g (..." in the text (allow space before g)
        final simpleGramPattern = RegExp(r'(\d+\s*g\s*\([^)]+\)\s*\S+(?:\s+\S+){0,5})', caseSensitive: false);
        
        for (final match in simpleGramPattern.allMatches(cleanHtml)) {
          var ingredient = match.group(1)?.trim() ?? '';
          // Clean up - take only reasonable length
          if (ingredient.length > 80) {
            ingredient = ingredient.substring(0, 80);
            // Cut at last space to avoid partial words
            final lastSpace = ingredient.lastIndexOf(' ');
            if (lastSpace > 20) ingredient = ingredient.substring(0, lastSpace);
          }
          if (_isValidIngredientCandidate(ingredient)) {
            potentialIngredients.add(ingredient);
          }
        }
      }
      
      if (potentialIngredients.length >= 2) {
        rawIngredientStrings = _processIngredientListItems(potentialIngredients);
      }
    }
    
    // Also try to extract directions from body text if still missing
    if (rawDirections.isEmpty && rawIngredientStrings.isNotEmpty) {
      final bodyText = document.body?.text ?? '';
      
      // Look for h3-style section headings in the text
      // Pattern: newline + "Create/Make/Prepare/Churn" at start of line
      final lines = bodyText.split('\n');
      String? currentStepTitle;
      final currentStepContent = <String>[];
      
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        
        // Check if this looks like a step heading
        final isStepHeading = RegExp(r'^(Create|Make|Prepare|Churn|Step\s*\d+)\b', caseSensitive: false).hasMatch(trimmed) &&
            trimmed.length < 80 &&
            !trimmed.contains('•');
        
        if (isStepHeading) {
          // Save previous step if any
          if (currentStepTitle != null && currentStepContent.isNotEmpty) {
            rawDirections.add('**$currentStepTitle**');
            rawDirections.addAll(currentStepContent);
          }
          currentStepTitle = trimmed;
          currentStepContent.clear();
        } else if (currentStepTitle != null) {
          // This is content for the current step
          if (trimmed.length > 20 && 
              !trimmed.contains('•') && 
              !trimmed.toLowerCase().contains('subscribe') &&
              !trimmed.toLowerCase().contains('http')) {
            currentStepContent.add(trimmed);
          }
        }
      }
      
      // Don't forget the last step
      if (currentStepTitle != null && currentStepContent.isNotEmpty) {
        rawDirections.add('**$currentStepTitle**');
        rawDirections.addAll(currentStepContent);
      }
    }
    
    if (rawIngredientStrings.isEmpty && rawDirections.isEmpty) {
      return null;
    }

    // Detect if this is a drink based on URL and content
    final isCocktailSite = _isCocktailSite(sourceUrl);
    final isBBQSite = _isBBQSite(sourceUrl);
    
    // Detect course using unified function (handles text-based and ingredient-aware detection)
    final titleLower = (title ?? '').toLowerCase();
    final urlLower = sourceUrl.toLowerCase();
    
    final courseResult = _detectCourseWithConfidence(
      titleLower: titleLower,
      urlLower: urlLower,
      ingredientStrings: rawIngredientStrings,
      isCocktailSite: isCocktailSite,
      isBBQSite: isBBQSite,
      document: document,
    );
    final course = courseResult.course;
    final courseConfidence = courseResult.confidence;
    
    // For drinks, detect the base spirit
    String? subcategory;
    final isDrink = isCocktailSite || course == 'Drinks';
    if (isDrink) {
      final spiritCode = _detectSpirit(ingredients);
      if (spiritCode != null) {
        subcategory = Spirit.toDisplayName(spiritCode);
      }
    }

    // Calculate confidence - structured formats (like Cooked plugin) are more reliable
    final baseConfidence = usedStructuredFormat ? 0.85 : 0.7;
    final nameConfidence = title != null && title.isNotEmpty ? baseConfidence : 0.0;
    
    // Filter out garbage (UI elements, ads, social media prompts) and deduplicate
    final filteredIngredientStrings = _filterIngredientStrings(rawIngredientStrings);
    
    final ingredientsConfidence = filteredIngredientStrings.isNotEmpty 
        ? (ingredients.length / filteredIngredientStrings.length) * baseConfidence 
        : 0.0;
    // Directions confidence: structured = 0.85, HTML with good extraction = 0.75, otherwise 0.6
    // Use rawDirections.length as proxy - if we have 3+ steps, it's likely a complete recipe
    final directionsConfidence = rawDirections.isNotEmpty 
        ? (usedStructuredFormat ? 0.85 : (rawDirections.length >= 3 ? 0.75 : 0.6)) 
        : 0.0;

    // Create raw ingredient data
    final rawIngredients = _buildRawIngredients(filteredIngredientStrings);

    // Build detected courses list - include the course we detected
    final detectedCourses = <String>[course];
    
    // Extract image from schema.org markup, og:image, or common recipe image selectors
    final String? imageUrl = _extractImageFromHtml(document);
    
    // Set confidence for optional fields when they have values
    final timeConfidence = timing != null && timing.isNotEmpty 
        ? (usedStructuredFormat ? 0.9 : 0.7) 
        : 0.0;
    
    // Normalize yield (strip "Servings: ", "Serves ", etc.)
    if (yield != null && yield.isNotEmpty) {
      yield = _normalizeServes(yield);
    }
    
    final servesConfidence = yield != null && yield.isNotEmpty 
        ? (usedStructuredFormat ? 0.9 : 0.7) 
        : 0.0;

    // Build image paths list: header image first, then step images
    // Filter out the header image from step images to avoid duplication
    List<String>? imagePaths;
    if (imageUrl != null || stepImages.isNotEmpty) {
      // Remove header image from step images if present
      final filteredStepImages = imageUrl != null
          ? stepImages.where((img) => img != imageUrl).toList()
          : stepImages;
      imagePaths = [
        if (imageUrl != null) imageUrl,
        ...filteredStepImages,
      ];
    }

    // Filter out junk direction lines (markdown titles, author bylines, etc.)
    // and deduplicate
    final filteredDirections = <String>[];
    final seenDirections = <String>{};
    for (final dir in rawDirections) {
      if (_isJunkDirectionLine(dir)) continue;
      final cleaned = _cleanDirectionLine(dir);
      if (cleaned.isEmpty) continue;
      final normalizedKey = cleaned.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
      if (seenDirections.contains(normalizedKey)) continue;
      seenDirections.add(normalizedKey);
      filteredDirections.add(cleaned);
    }

    return RecipeImportResult(
      name: title != null ? _cleanRecipeName(title) : null,
      course: course,
      subcategory: subcategory,
      serves: yield,
      imageUrl: imageUrl,
      time: timing,
      ingredients: _filterParsedIngredients(ingredients),
      directions: filteredDirections,
      comments: htmlNotes,
      equipment: equipmentItems,
      glass: glassType,
      garnish: garnishItems,
      rawIngredients: rawIngredients,
      rawDirections: filteredDirections,
      detectedCourses: detectedCourses,
      nameConfidence: nameConfidence,
      courseConfidence: courseConfidence,
      ingredientsConfidence: ingredientsConfidence,
      directionsConfidence: directionsConfidence,
      timeConfidence: timeConfidence,
      servesConfidence: servesConfidence,
      sourceUrl: sourceUrl,
      source: RecipeSource.url,
      imagePaths: imagePaths,
    );
  }
  
  /// Extract directions from Divi Builder sites (e.g., annaolson.ca)
  /// Scans for <h5> elements with "Step N" text pattern and extracts adjacent paragraph content
  List<String> _extractDiviDirections(dynamic document) {
    print('Using Divi/AnnaOlson extraction strategy');
    
    final directions = <String>[];
    final allElements = document.querySelectorAll('*');
    final stepPattern = RegExp(r'^\s*Step\s+\d+', caseSensitive: false);
    
    for (final element in allElements) {
      // Only process <h5> elements (ignore wrapper divs that inherit child text)
      if (element.localName?.toLowerCase() != 'h5') continue;
      
      final elementText = (element.text ?? '').trim();
      
      // Check if text starts with "Step N"
      if (stepPattern.hasMatch(elementText)) {
        // Strategy 1: Check immediate next sibling
        var content = element.nextElementSibling?.text?.trim();
        
        // Strategy 2: If sibling is empty/null, try parent's paragraph
        if (content == null || content.isEmpty) {
          content = element.parent?.querySelector('p')?.text?.trim();
        }
        
        if (content != null && content.isNotEmpty) {
          // Filter out footer/promotional content
          final lowerContent = content.toLowerCase();
          if (!lowerContent.contains('find me on') &&
              !lowerContent.contains('youtube') &&
              !lowerContent.contains('subscribe') &&
              !lowerContent.contains('follow me')) {
            directions.add(content);
          }
        }
      }
    }
    
    return directions;
  }
  
  /// Extract directions from raw HTML body, handling Shopify/Lyres-style embedded JSON
  /// with unicode escapes. This is needed for supplement logic when JSON-LD is missing directions.
  List<String> _extractDirectionsFromRawHtml(dynamic document, String rawBody) {
    final directions = <String>[];
    
    // Decode unicode escapes that Shopify/Lyres uses (embedded HTML in JSON)
    var bodyHtml = rawBody
        .replaceAll(r'\u003c', '<')
        .replaceAll(r'\u003e', '>')
        .replaceAll(r'\u0026', '&')
        .replaceAll(r'\/', '/')
        .replaceAll(r'\n', ' ')
        .replaceAll(r'\"', '"')
        .replaceAll('\\u003c', '<')
        .replaceAll('\\u003e', '>')
        .replaceAll('\\u0026', '&')
        .replaceAll('\\/', '/')
        .replaceAll('\\n', ' ')
        .replaceAll('\\"', '"');
    
    // Pattern 1: Lyres-style recipe-info divs with h4 Method title
    final recipeInfoDivs = RegExp(
      r'<div[^>]*class="[^"]*recipe-info[^"]*"[^>]*>(.*?)</div>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(bodyHtml);
    
    for (final divMatch in recipeInfoDivs) {
      final divContent = divMatch.group(1) ?? '';
      final h4Match = RegExp(
        r'<h4[^>]*>(.*?)</h4>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(divContent);
      
      if (h4Match == null) continue;
      
      final h4Title = (h4Match.group(1) ?? '').replaceAll(RegExp(r'<[^>]+>'), '').trim().toLowerCase();
      
      if (h4Title == 'method' || h4Title == 'directions' || h4Title == 'instructions') {
        final afterH4 = divContent.substring(h4Match.end);
        final pMatches = RegExp(r'<p[^>]*>(.*?)</p>', caseSensitive: false, dotAll: true).allMatches(afterH4);
        for (final pMatch in pMatches) {
          final text = _decodeHtml((pMatch.group(1) ?? '').replaceAll(RegExp(r'<[^>]+>'), '').trim());
          if (text.isNotEmpty) {
            // Split by periods if multiple sentences
            if (text.contains('. ')) {
              directions.addAll(text.split(RegExp(r'\.\s+')).where((s) => s.trim().isNotEmpty).map((s) {
                final trimmed = s.trim();
                return trimmed.endsWith('.') ? trimmed : '$trimmed.';
              }));
            } else {
              directions.add(text);
            }
          }
        }
        if (directions.isNotEmpty) return directions;
      }
    }
    
    // Pattern 2: Standalone h4>Method followed by p (not in recipe-info div)
    if (directions.isEmpty) {
      final methodMatch = RegExp(
        r'<h4[^>]*>\s*Method\s*</h4>\s*<p[^>]*>(.*?)</p>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(bodyHtml);
      if (methodMatch != null) {
        final text = _decodeHtml((methodMatch.group(1) ?? '').replaceAll(RegExp(r'<[^>]+>'), '').trim());
        if (text.isNotEmpty) {
          directions.add(text);
        }
      }
    }
    
    // Pattern 3: DOM-based extraction for h2/h3 Method or Directions heading
    if (directions.isEmpty) {
      for (final heading in document.querySelectorAll('h2, h3, h4')) {
        final headingText = (heading.text?.trim() ?? '').toLowerCase();
        if (headingText == 'method' || headingText == 'directions' || 
            headingText == 'instructions' || headingText == 'preparation') {
          // Get next sibling elements for content
          var sibling = heading.nextElementSibling;
          while (sibling != null) {
            final tagName = sibling.localName?.toLowerCase() ?? '';
            // Stop at next heading
            if (tagName.startsWith('h') && tagName.length == 2) break;
            
            if (tagName == 'p') {
              final text = _decodeHtml((sibling.text ?? '').trim());
              if (text.isNotEmpty) directions.add(text);
            } else if (tagName == 'ol' || tagName == 'ul') {
              for (final li in sibling.querySelectorAll('li')) {
                final text = _decodeHtml((li.text ?? '').trim());
                if (text.isNotEmpty) directions.add(text);
              }
            }
            sibling = sibling.nextElementSibling;
          }
          if (directions.isNotEmpty) break;
        }
      }
    }
    
    // Pattern 4: WordPress blog style - <p><strong>Preparation</strong></p> followed by <p> elements
    // This handles thegentlechef.com and similar WordPress sites
    if (directions.isEmpty) {
      final allParagraphs = document.querySelectorAll('p');
      for (int i = 0; i < allParagraphs.length; i++) {
        final p = allParagraphs[i];
        final pBold = p.querySelector('strong, b');
        if (pBold != null) {
          final boldText = pBold.text?.trim().toLowerCase() ?? '';
          // Check if this is a directions header
          if (boldText == 'preparation' || boldText == 'directions' || 
              boldText == 'instructions' || boldText == 'method' ||
              boldText == 'preparation:' || boldText == 'directions:') {
            // Collect all subsequent <p> elements until we hit another section header or end
            var nextElement = p.nextElementSibling;
            String? currentSection;
            
            while (nextElement != null) {
              final tagName = nextElement.localName?.toLowerCase();
              
              if (tagName == 'p') {
                final paragraphText = _decodeHtml((nextElement.text ?? '').trim());
                
                // Check if this <p> is a section header (entire paragraph is bold)
                final sectionBold = nextElement.querySelector('strong, b');
                if (sectionBold != null) {
                  final boldText = sectionBold.text?.trim() ?? '';
                  final sectionText = boldText.toLowerCase();
                  
                  // Check if bold text is the ENTIRE paragraph content (section header)
                  // vs inline emphasis (just a word or phrase within a longer sentence)
                  final isSectionHeader = boldText.isNotEmpty && 
                      (paragraphText == boldText || paragraphText == '$boldText:');
                  
                  if (isSectionHeader) {
                    // If it's a notes/tips section, stop
                    if (sectionText.contains('note') || sectionText.contains('tip')) {
                      break;
                    }
                    // Otherwise it might be a sub-section like "Pressure Cooker" - add as header
                    if (sectionText.isNotEmpty && 
                        !sectionText.contains('preparation') && 
                        !sectionText.contains('direction')) {
                      currentSection = TextNormalizer.toTitleCase(sectionText);
                      directions.add('**$currentSection**');
                    }
                  } else {
                    // Inline bold text - treat as regular direction
                    if (paragraphText.isNotEmpty && paragraphText.length > 10) {
                      directions.add(paragraphText);
                    }
                  }
                } else {
                  // Regular paragraph - add as direction
                  if (paragraphText.isNotEmpty && paragraphText.length > 10) {
                    directions.add(paragraphText);
                  }
                }
              } else if (tagName == 'ol' || tagName == 'ul') {
                for (final li in nextElement.querySelectorAll('li')) {
                  final text = _decodeHtml((li.text ?? '').trim());
                  if (text.isNotEmpty) directions.add(text);
                }
              } else if (tagName == 'h2' || tagName == 'h3' || tagName == 'h4') {
                // Hit a heading - stop
                break;
              }
              nextElement = nextElement.nextElementSibling;
            }
            if (directions.isNotEmpty) break;
          }
        }
      }
    }
    
    return directions;
  }
  
  /// Parse HTML by looking for section headings (h2, h3) followed by content
  /// This handles sites like Modernist Pantry that structure recipes with headings
  Map<String, dynamic> _parseHtmlBySections(dynamic document) {
    final result = <String, dynamic>{
      'ingredients': <String>[],
      'equipment': <String>[],
      'glass': null,
      'garnish': <String>[],
      'yield': null,
      'timing': null,
      'notes': null,
    };
    
    // First try: look for headings with id="ingredients" (common WordPress pattern)
    // This is more reliable as it uses explicit IDs
    final ingredientHeadingById = document.querySelector('h2#ingredients, h3#ingredients, [id="ingredients"]');
    if (ingredientHeadingById != null) {
      final ingredients = _extractListItemsFromSection(ingredientHeadingById, document);
      if (ingredients.isNotEmpty) {
        result['ingredients'] = ingredients;
      }
    }
    
    // Also check for equipment by ID
    final equipmentHeadingById = document.querySelector('h2#equipment, h3#equipment, [id="equipment"]');
    if (equipmentHeadingById != null) {
      final equipment = _extractListItemsFromSection(equipmentHeadingById, document);
      if (equipment.isNotEmpty) {
        result['equipment'] = equipment;
      }
    }
    
    // Check for glass by ID
    final glassHeadingById = document.querySelector('h2#glass, h3#glass, [id="glass"], h2#glassware, h3#glassware, [id="glassware"]');
    if (glassHeadingById != null) {
      final glassList = _extractListItemsFromSection(glassHeadingById, document);
      if (glassList.isNotEmpty) {
        result['glass'] = glassList.first;
      } else {
        // May be text after heading instead of a list
        final nextElement = glassHeadingById.nextElementSibling;
        if (nextElement != null) {
          final glassText = _decodeHtml(nextElement.text?.trim() ?? '');
          if (glassText.isNotEmpty) {
            result['glass'] = glassText;
          }
        }
      }
    }
    
    // Check for garnish by ID
    final garnishHeadingById = document.querySelector('h2#garnish, h3#garnish, [id="garnish"]');
    if (garnishHeadingById != null) {
      final garnish = _extractListItemsFromSection(garnishHeadingById, document);
      if (garnish.isNotEmpty) {
        result['garnish'] = garnish;
      }
    }
    
    // === DRINK-SPECIFIC PATTERNS ===
    
    // Pattern 1: Combined "Glass and Garnish" heading (Seedlip style)
    // First list item is glass, rest are garnish
    if (result['glass'] == null) {
      for (final heading in document.querySelectorAll('h2, h3')) {
        final headingText = heading.text?.trim().toLowerCase() ?? '';
        if (headingText.contains('glass') && headingText.contains('garnish')) {
          final items = _extractListItemsAfterHeading(heading, document);
          if (items.isNotEmpty) {
            // First item is glass type
            result['glass'] = items.first;
            // Rest are garnishes
            if (items.length > 1) {
              result['garnish'] = items.sublist(1);
            }
          }
          break;
        }
      }
    }
    
    // Pattern 2: H3 "Glass:" heading (Diffords style)
    // Also try looking for any element with text starting with "Glass:"
    // Diffords uses: <h3 class="m-0">Glass:</h3> <p>Serve in a <a>Glass Type</a></p>
    if (result['glass'] == null) {
      // First try h3 elements (including those with class="m-0")
      for (final h3 in document.querySelectorAll('h3')) {
        final h3Text = h3.text?.trim().toLowerCase() ?? '';
        if (h3Text == 'glass:' || h3Text == 'glass' || h3Text.startsWith('glass:')) {
          final nextElem = h3.nextElementSibling;
          if (nextElem != null) {
            // First try to get glass from link inside the paragraph
            final glassLink = nextElem.querySelector('a');
            if (glassLink != null) {
              final linkText = _decodeHtml(glassLink.text?.trim() ?? '');
              if (linkText.isNotEmpty) {
                result['glass'] = linkText;
                break;
              }
            }
            // Fallback to paragraph text
            var glassText = _decodeHtml(nextElem.text?.trim() ?? '');
            // Handle "Serve in a [Glass Type]" pattern
            final serveInMatch = RegExp(r'Serve\s+in\s+(?:an?\s+)?(.+)', caseSensitive: false).firstMatch(glassText);
            if (serveInMatch != null) {
              glassText = serveInMatch.group(1)?.trim() ?? glassText;
            }
            if (glassText.isNotEmpty) {
              result['glass'] = glassText;
            }
          }
          break;
        }
      }
    }
    
    // Pattern 2b: Diffords uses class="legacy-longform-heading" for "Glass:" label
    // Note: There may be multiple elements with this class (Glass:, Garnish:, etc.)
    if (result['glass'] == null) {
      final glassHeadings = document.querySelectorAll('.legacy-longform-heading');
      for (final glassHeading in glassHeadings) {
        final headingText = glassHeading.text?.trim().toLowerCase() ?? '';
        if (headingText == 'glass:') {
          // Check if there's a sibling paragraph or the parent has more content
          final parent = glassHeading.parent;
          if (parent != null) {
            // First try to get glass from link inside the parent
            final glassLink = parent.querySelector('a');
            if (glassLink != null) {
              final linkText = _decodeHtml(glassLink.text?.trim() ?? '');
              if (linkText.isNotEmpty) {
                result['glass'] = linkText;
                break;
              }
            }
            // Fallback to parent text
            var parentText = _decodeHtml(parent.text?.trim() ?? '');
            // Remove "Glass:" prefix
            parentText = parentText.replaceFirst(RegExp(r'^Glass:\s*', caseSensitive: false), '').trim();
            // Handle "Serve in a [Glass Type]" pattern
            final serveInMatch = RegExp(r'Serve\s+in\s+(?:an?\s+)?(.+)', caseSensitive: false).firstMatch(parentText);
            if (serveInMatch != null) {
              parentText = serveInMatch.group(1)?.trim() ?? parentText;
            }
            if (parentText.isNotEmpty) {
              result['glass'] = parentText;
              break;
            }
          }
        }
      }
    }
    
    // Pattern 3: Inline "Garnish:" span (Diffords style)
    // <p><span class="legacy-longform-heading">Garnish:</span> Raspberries</p>
    if ((result['garnish'] as List).isEmpty) {
      // Look for spans with class that might contain "Garnish:"
      final allSpans = document.querySelectorAll('span');
      for (final span in allSpans) {
        final spanText = span.text?.trim() ?? '';
        if (spanText.toLowerCase() == 'garnish:' || spanText.toLowerCase() == 'garnish') {
          // Get parent element text and extract garnish
          final parent = span.parent;
          if (parent != null) {
            var parentText = _decodeHtml(parent.text?.trim() ?? '');
            // Remove "Garnish:" prefix
            parentText = parentText.replaceFirst(RegExp(r'^Garnish:\s*', caseSensitive: false), '').trim();
            if (parentText.isNotEmpty) {
              // Split by comma for multiple garnishes, keep "or" options together
              final garnishes = _splitGarnishText(parentText);
              if (garnishes.isNotEmpty) {
                result['garnish'] = garnishes;
              }
            }
          }
          break;
        }
      }
    }
    
    // Pattern 3b: Look for paragraphs that start with "Garnish:" 
    if ((result['garnish'] as List).isEmpty) {
      for (final p in document.querySelectorAll('p')) {
        final pText = p.text?.trim() ?? '';
        if (pText.toLowerCase().startsWith('garnish:')) {
          var garnishText = pText.replaceFirst(RegExp(r'^Garnish:\s*', caseSensitive: false), '').trim();
          if (garnishText.isNotEmpty) {
            final garnishes = _splitGarnishText(garnishText);
            if (garnishes.isNotEmpty) {
              result['garnish'] = garnishes;
            }
          }
          break;
        }
      }
    }
    
    // Pattern 4: garn-glass class (Punch style)
    // <p class="garn-glass"><span>Garnish:</span> orange or lemon peel</p>
    if ((result['garnish'] as List).isEmpty || result['glass'] == null) {
      final garnGlass = document.querySelector('.garn-glass, .garnish-glass');
      if (garnGlass != null) {
        final fullText = _decodeHtml(garnGlass.text?.trim() ?? '');
        // Check for Garnish: pattern
        final garnishMatch = RegExp(r'Garnish:\s*(.+?)(?:\s*Glass:|$)', caseSensitive: false).firstMatch(fullText);
        if (garnishMatch != null && (result['garnish'] as List).isEmpty) {
          final garnishText = garnishMatch.group(1)?.trim() ?? '';
          if (garnishText.isNotEmpty) {
            final garnishes = _splitGarnishText(garnishText);
            result['garnish'] = garnishes;
          }
        }
        // Check for Glass: pattern
        final glassMatch = RegExp(r'Glass:\s*(.+?)(?:\s*Garnish:|$)', caseSensitive: false).firstMatch(fullText);
        if (glassMatch != null && result['glass'] == null) {
          result['glass'] = glassMatch.group(1)?.trim();
        }
      }
    }
    
    // Pattern 5: "Serve in a" text anywhere (common for cocktail sites)
    if (result['glass'] == null) {
      final allParagraphs = document.querySelectorAll('p');
      for (final p in allParagraphs) {
        final pText = p.text?.trim() ?? '';
        final serveInMatch = RegExp(r'Serve\s+in\s+(?:a\s+)?([A-Za-z][A-Za-z\s\-]+(?:glass|flute|coupe|tumbler|goblet|snifter|mug|cup))', caseSensitive: false).firstMatch(pText);
        if (serveInMatch != null) {
          result['glass'] = serveInMatch.group(1)?.trim();
          break;
        }
      }
    }
    
    // Pattern 6: Diffords-style table for ingredients (legacy-ingredients-table)
    // <table class="legacy-ingredients-table"><tr><td>amount</td><td>ingredient</td></tr></table>
    if ((result['ingredients'] as List).isEmpty) {
      final ingredientTable = document.querySelector('.legacy-ingredients-table, table.ingredients');
      if (ingredientTable != null) {
        final rows = ingredientTable.querySelectorAll('tr');
        final ingredients = <String>[];
        for (final row in rows) {
          final cells = row.querySelectorAll('td');
          if (cells.length >= 2) {
            final amount = _decodeHtml(cells[0].text?.trim() ?? '');
            final name = _decodeHtml(cells[1].text?.trim() ?? '');
            if (name.isNotEmpty) {
              ingredients.add(amount.isNotEmpty ? '$amount $name' : name);
            }
          }
        }
        if (ingredients.isNotEmpty) {
          result['ingredients'] = ingredients;
        }
      }
    }
    
    // Pattern 7: Lyres.com style - recipe-info divs with h4 titles
    // <div class="recipe-info"><h4 class="title">Glass</h4><p>Old Fashioned</p></div>
    if (result['glass'] == null || (result['garnish'] as List).isEmpty) {
      final recipeInfoDivs = document.querySelectorAll('.recipe-info, div.recipe-info');
      for (final div in recipeInfoDivs) {
        final h4 = div.querySelector('h4, .title');
        if (h4 != null) {
          final titleText = h4.text?.trim().toLowerCase() ?? '';
          final p = div.querySelector('p');
          if (p != null) {
            final content = _decodeHtml(p.text?.trim() ?? '');
            if (content.isNotEmpty) {
              if (titleText == 'glass' && result['glass'] == null) {
                result['glass'] = content;
              } else if (titleText == 'garnish' && (result['garnish'] as List).isEmpty) {
                result['garnish'] = _splitGarnishText(content);
              }
            }
          }
        }
      }
    }
    
    // === END DRINK-SPECIFIC PATTERNS ===
    
    // Find all h2 headings and check their text
    final headings = document.querySelectorAll('h2');
    
    for (final heading in headings) {
      final headingText = heading.text?.trim().toLowerCase() ?? '';
      
      // Find the next sibling elements after this heading
      final nextElement = heading.nextElementSibling;
      
      if (headingText.contains('ingredient')) {
        // Parse ingredients from the list following this heading
        // First try standard list extraction
        var ingredients = _extractListItemsAfterHeading(heading, document);
        
        // If that failed, try extracting bullet-point text content
        if (ingredients.isEmpty) {
          ingredients = _extractBulletPointsAfterHeading(heading, document);
        }
        
        if (ingredients.isNotEmpty) {
          result['ingredients'] = ingredients;
        }
      } else if (headingText.contains('equipment')) {
        // Parse equipment from the list following this heading
        var equipment = _extractListItemsAfterHeading(heading, document);
        
        // If that failed, try extracting bullet-point text content
        if (equipment.isEmpty) {
          equipment = _extractBulletPointsAfterHeading(heading, document);
        }
        
        result['equipment'] = equipment;
      } else if (headingText.contains('glass') || headingText.contains('glassware')) {
        // Extract glass type from next paragraph or list
        if (result['glass'] == null) {
          var glassList = _extractListItemsAfterHeading(heading, document);
          if (glassList.isNotEmpty) {
            result['glass'] = glassList.first;
          } else if (nextElement != null) {
            final glassText = _decodeHtml(nextElement.text?.trim() ?? '');
            if (glassText.isNotEmpty) {
              result['glass'] = glassText;
            }
          }
        }
      } else if (headingText.contains('garnish')) {
        // Extract garnish list from the list following this heading
        if ((result['garnish'] as List).isEmpty) {
          var garnish = _extractListItemsAfterHeading(heading, document);
          if (garnish.isEmpty) {
            garnish = _extractBulletPointsAfterHeading(heading, document);
          }
          // If still empty but there's a next element with text, use that
          if (garnish.isEmpty && nextElement != null) {
            final garnishText = _decodeHtml(nextElement.text?.trim() ?? '');
            if (garnishText.isNotEmpty) {
              // Split by comma or newline in case multiple garnishes in one line
              garnish = garnishText.split(RegExp(r'[,\n]'))
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList();
            }
          }
          result['garnish'] = garnish;
        }
      } else if (headingText.contains('yield') || headingText.contains('serves') || headingText.contains('serving')) {
        // Extract yield/serving info from next paragraph
        if (nextElement != null) {
          final yieldText = _decodeHtml(nextElement.text?.trim() ?? '');
          if (yieldText.isNotEmpty) {
            result['yield'] = yieldText;
          }
        }
      } else if (headingText.contains('timing') || headingText.contains('time')) {
        // Extract timing info from next paragraph
        if (nextElement != null) {
          final timingText = _decodeHtml(nextElement.text?.trim() ?? '');
          if (timingText.isNotEmpty) {
            // Try to parse the timing text
            result['timing'] = _parseTimingText(timingText);
          }
        }
      }
    }
    
    // If we didn't find ingredients with h2, try looking for H3 sub-sections within ingredient container
    // AmazingFoodMadeEasy uses: H2 "Ingredients for..." then H3 "For the X" sections with text ingredients
    if ((result['ingredients'] as List).isEmpty) {
      // Find h2 with "ingredient" and extract H3 subsections with their content
      for (final h2 in document.querySelectorAll('h2')) {
        final h2Text = h2.text?.trim().toLowerCase() ?? '';
        if (h2Text.contains('ingredient')) {
          final collectedItems = <String>[];
          
          // Walk through siblings after this H2 until next H2
          var sibling = h2.nextElementSibling;
          String? currentSection;
          
          while (sibling != null) {
            final siblingTag = sibling.localName?.toLowerCase();
            
            // Stop at next H2 (new major section)
            if (siblingTag == 'h2') break;
            
            // H3 is a sub-section header (e.g., "For the Sous Vide Pork Tenderloin")
            if (siblingTag == 'h3') {
              final sectionText = _decodeHtml(sibling.text?.trim() ?? '');
              // Check if this is a "For the X" section header, not instructions
              if (sectionText.isNotEmpty && 
                  !sectionText.toLowerCase().contains('instruction') &&
                  !sectionText.toLowerCase().contains('direction') &&
                  !sectionText.toLowerCase().contains('minutes') &&
                  !sectionText.toLowerCase().contains('hour')) {
                // Extract section name, removing "For the" prefix
                final sectionName = _stripForThePrefix(sectionText);
                currentSection = sectionName;
                collectedItems.add('[$currentSection]');
              }
            }
            // Text content (paragraphs, divs) might contain ingredients
            else if (siblingTag == 'p' || siblingTag == 'div') {
              final text = _decodeHtml(sibling.text?.trim() ?? '');
              // Check if this line has measurements (ingredient line) or is a food item
              if (text.isNotEmpty && _couldBeIngredientLine(text)) {
                // Split by newlines in case multiple ingredients in one paragraph
                for (final line in text.split('\n')) {
                  final trimmed = line.trim();
                  if (trimmed.isNotEmpty && trimmed.length > 2) {
                    collectedItems.add(trimmed);
                  }
                }
              }
            }
            // Also handle ul/ol lists within sections (common pattern)
            else if (siblingTag == 'ul' || siblingTag == 'ol') {
              final listItems = sibling.querySelectorAll('li');
              for (final li in listItems) {
                final text = _decodeHtml(li.text?.trim() ?? '');
                if (text.isNotEmpty && text.length > 2) {
                  collectedItems.add(text);
                }
              }
            }
            
            sibling = sibling.nextElementSibling;
          }
          
          if (collectedItems.isNotEmpty) {
            result['ingredients'] = collectedItems;
            break;
          }
        }
      }
    }
    
    // If we didn't find ingredients with h2, try looking for lists with specific patterns
    if ((result['ingredients'] as List).isEmpty) {
      // Also check h3 headings (some sites use h3 for recipe sections)
      final h3Headings = document.querySelectorAll('h3');
      for (final heading in h3Headings) {
        final headingText = heading.text?.trim().toLowerCase() ?? '';
        if (headingText.contains('ingredient')) {
          var ingredients = _extractListItemsAfterHeading(heading, document);
          
          // If list extraction failed, try bullet point extraction
          if (ingredients.isEmpty) {
            ingredients = _extractBulletPointsAfterHeading(heading, document);
          }
          
          if (ingredients.isNotEmpty) {
            result['ingredients'] = ingredients;
            break;
          }
        }
      }
    }
    
    // WordPress blog pattern: <p><strong>Ingredients</strong></p> followed by <ul><li>...</li></ul>
    // This handles thegentlechef.com and similar WordPress sites with section headers between lists
    // Must run BEFORE generic list pattern to capture section headers like "Dry Rub"
    if ((result['ingredients'] as List).isEmpty) {
      final allParagraphs = document.querySelectorAll('p');
      for (final p in allParagraphs) {
        final pBold = p.querySelector('strong, b');
        if (pBold != null) {
          final boldText = pBold.text?.trim().toLowerCase() ?? '';
          // Check if this is an ingredients header
          if (boldText == 'ingredients' || boldText == 'ingredients:') {
            // Look for lists in siblings - may have multiple sections
            final allIngredients = <String>[];
            var nextElement = p.nextElementSibling;
            
            while (nextElement != null) {
              final tagName = nextElement.localName?.toLowerCase();
              
              if (tagName == 'ul' || tagName == 'ol') {
                // Found a list - extract items
                final listItems = nextElement.querySelectorAll('li');
                for (final li in listItems) {
                  final text = _decodeHtml(li.text?.trim() ?? '');
                  if (text.isNotEmpty) {
                    allIngredients.add(text);
                  }
                }
              } else if (tagName == 'p') {
                final paragraphText = _decodeHtml((nextElement.text ?? '').trim());
                
                // Check if this <p> is a section header (entire paragraph is bold)
                final sectionBold = nextElement.querySelector('strong, b');
                if (sectionBold != null) {
                  final sectionBoldText = sectionBold.text?.trim() ?? '';
                  final sectionText = sectionBoldText.toLowerCase();
                  
                  // Check if bold text is the ENTIRE paragraph content (section header)
                  // vs inline emphasis (just a word or phrase within a longer sentence)
                  final isSectionHeader = sectionBoldText.isNotEmpty && 
                      (paragraphText == sectionBoldText || paragraphText == '$sectionBoldText:');
                  
                  if (isSectionHeader) {
                    // Stop if we hit directions/preparation
                    if (sectionText.contains('preparation') || 
                        sectionText.contains('direction') ||
                        sectionText.contains('instruction') ||
                        sectionText.contains('method') ||
                        sectionText.contains('step') ||
                        sectionText.contains('procedure')) {
                      break;
                    }
                    // Otherwise it's a sub-section like "Dry Rub" - add as section header
                    if (sectionText.isNotEmpty && !sectionText.contains('ingredient')) {
                      // Add section header with bracket format (recognized by import system)
                      final sectionName = TextNormalizer.toTitleCase(sectionText);
                      allIngredients.add('[$sectionName]');
                    }
                  }
                  // Note: paragraphs with inline bold are not ingredients, skip them
                }
              } else if (tagName == 'h2' || tagName == 'h3' || tagName == 'h4') {
                // Hit a heading - stop
                break;
              }
              nextElement = nextElement.nextElementSibling;
            }
            
            if (allIngredients.isNotEmpty) {
              result['ingredients'] = _processIngredientListItems(allIngredients);
              break;
            }
          }
        }
      }
    }
    
    // If still no ingredients, try looking for lists with specific patterns
    if ((result['ingredients'] as List).isEmpty) {
      // Look for lists that contain ingredient-like items (amounts + names)
      final allLists = document.querySelectorAll('ul, ol');
      for (final list in allLists) {
        final items = list.querySelectorAll('li');
        final itemTexts = <String>[];
        for (final e in items) {
          final text = _decodeHtml((e.text ?? '').trim());
          if (text.isNotEmpty) {
            itemTexts.add(text);
          }
        }
        
        // Check if this looks like an ingredient list (has quantities)
        // Enhanced pattern to match formats like "200g (½ Cup) Honey" or "60g (4 Tablespoons)"
        final hasQuantities = itemTexts.any((item) => 
          RegExp(r'\d+\s*[gG](?:\s|$|\))|\d+\s*(?:cup|cups|tbsp|tablespoon|tsp|teaspoon|oz|ounce|ml|lb|pound|kg|kilogram)', caseSensitive: false).hasMatch(item) ||
          RegExp(r'[½¼¾⅓⅔⅛]\s*(?:cup|cups|tbsp|tablespoon|tsp|teaspoon)', caseSensitive: false).hasMatch(item),
        );
        
        // Lower threshold - accept lists with 2+ items if they have quantities
        if (hasQuantities && itemTexts.length >= 2) {
          result['ingredients'] = _processIngredientListItems(itemTexts);
          break;
        }
      }
    }
    
    // Last resort: look for bold text patterns like "**Ingredients:**" followed by lists
    if ((result['ingredients'] as List).isEmpty) {
      // Look for strong/bold elements containing "ingredient"
      final boldElements = document.querySelectorAll('strong, b');
      for (final bold in boldElements) {
        final boldText = bold.text?.trim().toLowerCase() ?? '';
        if (boldText.contains('ingredient') && !boldText.contains('equipment')) {
          // Check if the bold is inside a list item - if so, get the parent list
          var parent = bold.parent;
          while (parent != null) {
            final parentTag = parent.localName?.toLowerCase();
            if (parentTag == 'ul' || parentTag == 'ol') {
              // Found the list - extract all items
              final listItems = parent.querySelectorAll('li');
              final itemTexts = <String>[];
              for (final li in listItems) {
                final text = _decodeHtml(li.text?.trim() ?? '');
                if (text.isNotEmpty) {
                  itemTexts.add(text);
                }
              }
              if (itemTexts.isNotEmpty) {
                result['ingredients'] = _processIngredientListItems(itemTexts);
                break;
              }
            } else if (parentTag == 'li') {
              // Bold is inside a list item - get the parent list
              var listParent = parent.parent;
              if (listParent != null) {
                final listTag = listParent.localName?.toLowerCase();
                if (listTag == 'ul' || listTag == 'ol') {
                  final listItems = listParent.querySelectorAll('li');
                  final itemTexts = <String>[];
                  for (final li in listItems) {
                    final text = _decodeHtml(li.text?.trim() ?? '');
                    if (text.isNotEmpty) {
                      itemTexts.add(text);
                    }
                  }
                  if (itemTexts.isNotEmpty) {
                    result['ingredients'] = _processIngredientListItems(itemTexts);
                    break;
                  }
                }
              }
              break;
            } else if (parentTag == 'p') {
              // Bold "Ingredients" is inside a <p> - check sibling <ul>
              // Pattern: <p><strong>Ingredients</strong></p><ul><li>...</li></ul>
              var nextElement = parent.nextElementSibling;
              while (nextElement != null) {
                final tagName = nextElement.localName?.toLowerCase();
                if (tagName == 'ul' || tagName == 'ol') {
                  final listItems = nextElement.querySelectorAll('li');
                  final itemTexts = <String>[];
                  for (final li in listItems) {
                    final text = _decodeHtml(li.text?.trim() ?? '');
                    if (text.isNotEmpty) {
                      itemTexts.add(text);
                    }
                  }
                  if (itemTexts.isNotEmpty) {
                    result['ingredients'] = _processIngredientListItems(itemTexts);
                    break;
                  }
                } else if (tagName == 'p') {
                  // Check if this <p> contains a section header like "Dry Rub" or "Preparation"
                  final pBold = nextElement.querySelector('strong, b');
                  if (pBold != null) {
                    final pBoldText = pBold.text?.trim().toLowerCase() ?? '';
                    // If we hit a non-ingredient section, stop
                    if (pBoldText.contains('preparation') || 
                        pBoldText.contains('direction') ||
                        pBoldText.contains('instruction') ||
                        pBoldText.contains('method') ||
                        pBoldText.contains('step')) {
                      break;
                    }
                    // If it's another ingredient section (like "Dry Rub"), continue to next ul
                  }
                } else if (tagName == 'h2' || tagName == 'h3' || tagName == 'h4') {
                  // Hit a heading - stop
                  break;
                }
                nextElement = nextElement.nextElementSibling;
              }
              if ((result['ingredients'] as List).isNotEmpty) break;
            }
            parent = parent.parent;
          }
          
          // Also try to find a list after this bold element (if not inside a list)
          if ((result['ingredients'] as List).isEmpty) {
            var nextElement = bold.parent?.nextElementSibling ?? bold.nextElementSibling;
            while (nextElement != null) {
              final tagName = nextElement.localName?.toLowerCase();
              if (tagName == 'ul' || tagName == 'ol') {
                final listItems = nextElement.querySelectorAll('li');
                final itemTexts = <String>[];
                for (final li in listItems) {
                  final text = _decodeHtml(li.text?.trim() ?? '');
                  if (text.isNotEmpty) {
                    itemTexts.add(text);
                  }
                }
                if (itemTexts.isNotEmpty) {
                  result['ingredients'] = _processIngredientListItems(itemTexts);
                  break;
                }
              } else if (tagName == 'h2' || tagName == 'h3' || tagName == 'strong' || tagName == 'b') {
                break;
              }
              nextElement = nextElement.nextElementSibling;
            }
          }
          
          if ((result['ingredients'] as List).isNotEmpty) break;
        }
      }
    }
    
    // Final fallback: Look for text blocks that contain bullet-point characters
    // This handles sites that use plain text with • or - characters as bullets
    if ((result['ingredients'] as List).isEmpty) {
      // Find all text-containing elements
      final textElements = document.querySelectorAll('p, div, span');
      for (final elem in textElements) {
        final text = elem.text?.trim() ?? '';
        
        // Check if this contains bullet-pointed items with ingredient-like content
        if (text.contains('•') || text.contains('- ')) {
          // Split by bullet characters
          final lines = text.split(RegExp(r'[•]\s*|\n+'));
          
          if (lines.length >= 3) {
            // Check if multiple lines have quantities (indicating ingredients)
            int quantityCount = 0;
            for (final line in lines) {
              if (RegExp(r'\d+\s*[gG](?:\s|$|\))|\d+\s*(?:cup|cups|tbsp|tablespoon|tsp|teaspoon|oz|ounce|ml|lb|pound|kg|kilogram)', caseSensitive: false).hasMatch(line)) {
                quantityCount++;
              }
            }
            
            // If we found multiple quantity-containing lines, these are likely ingredients
            if (quantityCount >= 2) {
              final items = <String>[];
              for (var line in lines) {
                line = _decodeHtml(line.trim());
                if (line.isEmpty || line.length < 3) continue;
                if (line.toLowerCase().contains('click') ||
                    line.toLowerCase().contains('subscribe') ||
                    line.toLowerCase().contains('http')) continue;
                items.add(line);
              }
              
              if (items.isNotEmpty) {
                result['ingredients'] = _processIngredientListItems(items);
                break;
              }
            }
          }
        }
      }
    }
    
    // Normalize glass (title case)
    if (result['glass'] != null && (result['glass'] as String).isNotEmpty) {
      result['glass'] = _toTitleCase(result['glass'] as String);
    }
    
    // Normalize garnish (remove leading articles, title case each item)
    final garnishList = result['garnish'] as List<String>;
    if (garnishList.isNotEmpty) {
      result['garnish'] = garnishList.map((g) => normalizeGarnish(g)).toList();
    }
    
    // Normalize yield/serves (strip prefixes)
    if (result['yield'] != null && (result['yield'] as String).isNotEmpty) {
      result['yield'] = _normalizeServes(result['yield'] as String);
    }
    
    // Extract editor's notes from HTML
    // Pattern 1: Punch-style editors-note or editor-note classes
    // Punch uses various selectors including recipe__editors-note, recipe-editors-note, etc.
    final editorsNoteElem = document.querySelector(
      '.editors-note, .editor-note, .editors_note, .recipe-editor-note, '
      '.recipe__editors-note, .recipe-editors-note, '
      '[class*="editor"][class*="note"], '
      '.recipe-note, .recipe__note'
    );
    if (editorsNoteElem != null) {
      final noteText = _decodeHtml(editorsNoteElem.text?.trim() ?? '');
      if (noteText.isNotEmpty) {
        result['notes'] = noteText.toLowerCase().startsWith('editor') ? noteText : "Editor's Note: $noteText";
      }
    }
    
    // Pattern 2: Blockquote with editor's note indicator
    if (result['notes'] == null) {
      final blockquotes = document.querySelectorAll('blockquote');
      for (final bq in blockquotes) {
        final text = _decodeHtml(bq.text?.trim() ?? '');
        final lowerText = text.toLowerCase();
        if (lowerText.startsWith('editor') || lowerText.contains('editor\'s note')) {
          result['notes'] = text.startsWith('Editor') ? text : "Editor's Note: $text";
          break;
        }
      }
    }
    
    // Pattern 3: Heading containing "Editor's Note" followed by paragraph content (Punch style)
    // Punch uses: <h2>Editor's Note</h2> followed by <p> paragraphs
    if (result['notes'] == null) {
      final headings = document.querySelectorAll('h1, h2, h3, h4, h5, h6');
      for (final heading in headings) {
        final headingText = heading.text?.trim().toLowerCase() ?? '';
        if (headingText.contains('editor') && headingText.contains('note')) {
          // Found "Editor's Note" heading - collect following paragraph text
          final paragraphs = <String>[];
          var sibling = heading.nextElementSibling;
          while (sibling != null) {
            final tagName = sibling.localName?.toLowerCase();
            // Stop at next heading or non-paragraph element
            if (tagName != null && tagName.startsWith('h')) break;
            if (tagName == 'p') {
              final pText = _decodeHtml(sibling.text?.trim() ?? '');
              if (pText.isNotEmpty) {
                paragraphs.add(pText);
              }
            }
            sibling = sibling.nextElementSibling;
          }
          if (paragraphs.isNotEmpty) {
            result['notes'] = "Editor's Note:\n${paragraphs.join('\n\n')}";
            break;
          }
        }
      }
    }
    
    // Pattern 4: Italicized text at top of article with editor's note content
    if (result['notes'] == null) {
      final italics = document.querySelectorAll('em, i');
      for (final em in italics) {
        final text = _decodeHtml(em.text?.trim() ?? '');
        if (text.length > 50 && text.length < 500) {
          final lowerText = text.toLowerCase();
          // Check if it looks like an editor's note (mentions author, origin, etc.)
          if (lowerText.contains('originally appeared') || 
              lowerText.contains('this recipe') ||
              lowerText.contains('adapted from') ||
              lowerText.contains('excerpt from')) {
            result['notes'] = "Editor's Note: $text";
            break;
          }
        }
      }
    }
    
    return result;
  }
  
  /// Extract list items from a section identified by a heading with a specific ID
  /// This handles WordPress-style markup where paragraphs/comments separate heading from list
  List<String> _extractListItemsFromSection(dynamic heading, dynamic document) {
    final items = <String>[];
    
    // Strategy 1: Look for h3/h4 sub-sections and ul/ol within the parent's wrapper
    // This preserves section structure by including sub-headings as section markers
    var parent = heading.parent;
    var searchLimit = 0;
    
    while (parent != null && searchLimit < 5) {
      final parentTag = parent.localName?.toLowerCase();
      
      // Find all h3, h4, ul, ol elements within the parent container to preserve order
      final elementsInParent = parent.querySelectorAll('h3, h4, ul, ol');
      final collectedItems = <String>[];
      var foundHeadingYet = false;
      
      for (final elem in elementsInParent) {
        // Skip elements that come before our main heading
        // Simple heuristic: check if this element is within the ingredient section
        final elemTag = elem.localName?.toLowerCase();
        
        if (elemTag == 'h3' || elemTag == 'h4') {
          final sectionText = _decodeHtml(elem.text?.trim() ?? '');
          if (sectionText.isNotEmpty && !sectionText.toLowerCase().contains('instruction') && !sectionText.toLowerCase().contains('direction')) {
            // Add as section marker with colon
            collectedItems.add('$sectionText:');
            foundHeadingYet = true;
          }
        } else if (elemTag == 'ul' || elemTag == 'ol') {
          final listItems = elem.querySelectorAll('li');
          for (final li in listItems) {
            final text = _decodeHtml(li.text?.trim() ?? '');
            if (text.isNotEmpty) {
              collectedItems.add(text);
            }
          }
        }
      }
      
      // Check if this looks like an ingredient list (has measurements)
      final hasQuantities = collectedItems.any((item) =>
        RegExp(r'\d+\s*[gG](?:\s|$|\))|[\d½¼¾⅓⅔]+\s*(?:cup|cups|tbsp|tablespoon|tsp|teaspoon|oz|ml)', caseSensitive: false).hasMatch(item)
      );
      
      if (hasQuantities && collectedItems.length >= 2) {
        return _processIngredientListItems(collectedItems);
      }
      
      parent = parent.parent;
      searchLimit++;
    }
    
    // Strategy 2: Skip over paragraph elements that may contain WP comments
    var nextElement = heading.nextElementSibling;
    var skippedCount = 0;
    
    while (nextElement != null && skippedCount < 10) {
      final tagName = nextElement.localName?.toLowerCase();
      
      if (tagName == 'ul' || tagName == 'ol') {
        // Found the list
        final listItems = nextElement.querySelectorAll('li');
        for (final li in listItems) {
          final text = _decodeHtml(li.text?.trim() ?? '');
          if (text.isNotEmpty) {
            items.add(text);
          }
        }
        // Continue to look for more lists after this one (for multiple sections)
      } else if (tagName == 'h2') {
        // Hit a major heading - stop completely
        break;
      } else if (tagName == 'h3' || tagName == 'h4') {
        // Sub-section heading - add as a section marker and continue
        final sectionText = _decodeHtml(nextElement.text?.trim() ?? '');
        if (sectionText.isNotEmpty) {
          // Add section header with trailing colon to mark it as a section
          items.add('$sectionText:');
        }
      } else if (tagName == 'p') {
        // Skip paragraph tags (might be WP comment wrappers)
        skippedCount++;
      } else if (tagName == 'div' || tagName == 'section') {
        // Check inside containers for lists and headings
        final nestedHeadings = nextElement.querySelectorAll('h3, h4');
        final nestedLists = nextElement.querySelectorAll('ul, ol');
        
        // Process headings and lists in order
        if (nestedHeadings.isNotEmpty || nestedLists.isNotEmpty) {
          // Get all h3, h4, ul, ol in document order
          final elements = nextElement.querySelectorAll('h3, h4, ul, ol');
          for (final elem in elements) {
            final elemTag = elem.localName?.toLowerCase();
            if (elemTag == 'h3' || elemTag == 'h4') {
              final sectionText = _decodeHtml(elem.text?.trim() ?? '');
              if (sectionText.isNotEmpty) {
                items.add('$sectionText:');
              }
            } else if (elemTag == 'ul' || elemTag == 'ol') {
              final listItems = elem.querySelectorAll('li');
              for (final li in listItems) {
                final text = _decodeHtml(li.text?.trim() ?? '');
                if (text.isNotEmpty) {
                  items.add(text);
                }
              }
            }
          }
        }
      }
      
      nextElement = nextElement.nextElementSibling;
    }
    
    return _processIngredientListItems(items);
  }

  /// Clean section name by removing trailing colon and "For the" prefix
  String _cleanSectionName(String text) {
    final cleaned = text.replaceAll(RegExp(r':$'), '').trim();
    return _stripForThePrefix(cleaned);
  }

  /// Extract ingredients using a site config
  /// Returns null if the config's selectors don't match the document
  List<String>? _extractWithSiteConfig(dynamic document, SiteConfig config) {
    final ingredients = <String>[];
    
    // Get the container (or use document)
    dynamic container = document;
    if (config.containerSelector != null) {
      // Try each selector in comma-separated list
      for (final selector in config.containerSelector!.split(',').map((s) => s.trim())) {
        container = document.querySelector(selector);
        if (container != null) break;
      }
      if (container == null) return null;
    }
    
    switch (config.mode) {
      case ExtractionMode.containerWithSections:
        // Get all section elements
        if (config.sectionSelector == null) return null;
        final sections = container.querySelectorAll(config.sectionSelector);
        if (sections.isEmpty) return null;
        
        for (final section in sections) {
          // Get section header
          String? headerText;
          if (config.headerIsDirectChild && config.headerChildTag != null) {
            // Look for direct child with matching tag
            for (final child in section.children) {
              if (child.localName == config.headerChildTag) {
                headerText = _decodeHtml((child.text ?? '').trim());
                break;
              }
            }
          } else if (config.headerSelector != null) {
            final header = section.querySelector(config.headerSelector);
            if (header != null) {
              headerText = _decodeHtml((header.text ?? '').trim());
            }
          }
          
          if (headerText != null && headerText.isNotEmpty) {
            ingredients.add('[${_cleanSectionName(headerText)}]');
          }
          
          // Get ingredients
          final items = section.querySelectorAll(config.ingredientSelector);
          for (final item in items) {
            final text = _decodeHtml((item.text ?? '').trim());
            if (text.isNotEmpty) {
              ingredients.add(text);
            }
          }
        }
        
      case ExtractionMode.siblingHeaderList:
        // Headers are followed by sibling ul elements
        if (config.headerSelector == null) return null;
        final headers = container.querySelectorAll(config.headerSelector);
        if (headers.isEmpty) return null;
        
        for (final header in headers) {
          final headerText = _decodeHtml((header.text ?? '').trim());
          if (headerText.isNotEmpty) {
            ingredients.add('[${_cleanSectionName(headerText)}]');
          }
          
          // Find the next ul sibling
          var sibling = header.nextElementSibling;
          while (sibling != null) {
            final tagName = sibling.localName?.toLowerCase() ?? '';
            
            if (tagName == 'ul' || tagName == 'ol') {
              final items = sibling.querySelectorAll(config.ingredientSelector);
              for (final item in items) {
                final text = _decodeHtml((item.text ?? '').trim());
                if (text.isNotEmpty) {
                  ingredients.add(text);
                }
              }
              break; // Found the list, move to next header
            } else if (tagName == 'h2' || tagName == 'h3' || tagName == 'h4' || tagName == 'p') {
              // Check if this is another header (stop searching)
              if (config.headerSelector != null) {
                final headerClass = header.attributes['class'] ?? '';
                final siblingClass = sibling.attributes['class'] ?? '';
                // If sibling matches header pattern, stop
                if (siblingClass.isNotEmpty && headerClass.contains(siblingClass.split(' ').first)) {
                  break;
                }
              }
              // Otherwise might be the next section header
              if (tagName == 'h2' || tagName == 'h3') break;
            }
            sibling = sibling.nextElementSibling;
          }
        }
        
      case ExtractionMode.mixedList:
        // Container has mixed category headers and ingredients as siblings
        // Get all items that match either header or ingredient selector
        final allItems = container.querySelectorAll('li');
        if (allItems.isEmpty) return null;
        
        for (final item in allItems) {
          final itemClass = item.attributes['class'] ?? '';
          
          // Check if this is a category/header item
          if (itemClass.contains('category')) {
            // Look for header element inside
            final headerElem = config.headerSelector != null 
                ? item.querySelector(config.headerSelector!.split(' ').last) // Get last part like 'h3'
                : item.querySelector('h3');
            if (headerElem != null) {
              final headerText = _decodeHtml((headerElem.text ?? '').trim());
              if (headerText.isNotEmpty) {
                ingredients.add('[${_cleanSectionName(headerText)}]');
              }
            }
          } else {
            // Regular ingredient item
            final text = _decodeHtml((item.text ?? '').trim());
            if (text.isNotEmpty) {
              ingredients.add(text);
            }
          }
        }
    }
    
    return ingredients.isNotEmpty ? _deduplicateIngredients(ingredients) : null;
  }

  /// Try all site configs and return the first successful extraction
  List<String>? _tryAllSiteConfigs(dynamic document) {
    for (final entry in _siteConfigs.entries) {
      final result = _extractWithSiteConfig(document, entry.value);
      if (result != null && result.isNotEmpty) {
        return result;
      }
    }
    return null;
  }
  
  /// Extract ingredients with section headers from HTML
  /// Handles sites like AmazingFoodMadeEasy that have structured HTML with sections
  /// but JSON-LD only has a flat ingredient list
  List<String> _extractIngredientsWithSections(dynamic document) {
    // Try config-driven extraction first
    final configResult = _tryAllSiteConfigs(document);
    if (configResult != null && configResult.isNotEmpty) {
      return configResult;
    }
    
    // Fallback to legacy extraction for any patterns not yet in configs
    final ingredients = <String>[];
    
    // Try King Arthur Baking format: div.ingredient-section with p for section name and ul.list--bullets
    final kingArthurSections = document.querySelectorAll('.ingredient-section');
    if (kingArthurSections.isNotEmpty) {
      for (final section in kingArthurSections) {
        // Get section name from the first <p> child (not inside ul)
        // We need to find a <p> that is a direct child of the section div
        for (final child in section.children) {
          if (child.localName == 'p') {
            var sectionText = _decodeHtml((child.text ?? '').trim());
            // Remove trailing colon if present
            sectionText = sectionText.replaceAll(RegExp(r':$'), '').trim();
            if (sectionText.isNotEmpty) {
              ingredients.add('[$sectionText]');
            }
            break; // Only get the first <p>
          }
        }
        
        // Get ingredients from ul li
        final items = section.querySelectorAll('ul li');
        for (final item in items) {
          final text = _decodeHtml((item.text ?? '').trim());
          if (text.isNotEmpty) {
            ingredients.add(text);
          }
        }
      }
      
      if (ingredients.isNotEmpty) return _deduplicateIngredients(ingredients);
    }
    
    // Try Tasty.co format: div.ingredients__section with p.ingredient-section-name and li.ingredient
    final tastySections = document.querySelectorAll('.ingredients__section');
    if (tastySections.isNotEmpty) {
      for (final section in tastySections) {
        // Get section name from p.ingredient-section-name
        final sectionNameElem = section.querySelector('.ingredient-section-name');
        if (sectionNameElem != null) {
          var sectionText = _decodeHtml((sectionNameElem.text ?? '').trim());
          // Remove trailing colon if present
          sectionText = sectionText.replaceAll(RegExp(r':$'), '').trim();
          if (sectionText.isNotEmpty) {
            ingredients.add('[$sectionText]');
          }
        }
        
        // Get ingredients from li.ingredient
        final items = section.querySelectorAll('li.ingredient');
        for (final item in items) {
          final text = _decodeHtml((item.text ?? '').trim());
          if (text.isNotEmpty) {
            ingredients.add(text);
          }
        }
      }
      
      if (ingredients.isNotEmpty) return _deduplicateIngredients(ingredients);
    }
    
    // Try Serious Eats format: p.structured-ingredients__list-heading followed by ul.structured-ingredients__list
    final seriousEatsHeaders = document.querySelectorAll('.structured-ingredients__list-heading');
    if (seriousEatsHeaders.isNotEmpty) {
      for (final header in seriousEatsHeaders) {
        var sectionText = _decodeHtml((header.text ?? '').trim());
        // Remove trailing colon if present
        sectionText = sectionText.replaceAll(RegExp(r':$'), '').trim();
        if (sectionText.isNotEmpty) {
          // Remove "For the" prefix if present
          final cleanedSection = _stripForThePrefix(sectionText);
          ingredients.add('[$cleanedSection]');
        }
        
        // Get the ul sibling that follows this header
        var sibling = header.nextElementSibling;
        while (sibling != null) {
          final tagName = sibling.localName?.toLowerCase() ?? '';
          
          if (tagName == 'ul') {
            // Get all li elements
            final items = sibling.querySelectorAll('li');
            for (final item in items) {
              final text = _decodeHtml((item.text ?? '').trim());
              if (text.isNotEmpty) {
                ingredients.add(text);
              }
            }
            break; // Found the ul, move to next section
          } else if (tagName == 'p' && sibling.attributes['class']?.contains('structured-ingredients__list-heading') == true) {
            break; // Next section header
          }
          sibling = sibling.nextElementSibling;
        }
      }
      
      if (ingredients.isNotEmpty) return _deduplicateIngredients(ingredients);
    }
    
    // Try AmazingFoodMadeEasy format: ul.ingredient_list with li.category and li.ingredient
    var ingredientList = document.querySelector('ul.ingredient_list');
    ingredientList ??= document.querySelector('.ingredient_list');
    
    if (ingredientList != null) {
      final allLiItems = ingredientList.querySelectorAll('li');
      for (final li in allLiItems) {
        final liClasses = li.attributes['class'] ?? '';
        
        if (liClasses.contains('category')) {
          final headerElem = li.querySelector('h3');
          if (headerElem != null) {
            final sectionText = _decodeHtml((headerElem.text ?? '').trim());
            if (sectionText.isNotEmpty) {
              final sectionName = _stripForThePrefix(sectionText);
              ingredients.add('[$sectionName]');
            }
          }
        } else if (liClasses.contains('ingredient')) {
          final text = _decodeHtml((li.text ?? '').trim());
          if (text.isNotEmpty) {
            ingredients.add(text);
          }
        }
      }
      
      if (ingredients.isNotEmpty) return _deduplicateIngredients(ingredients);
    }
    
    // Try NYT Cooking format: h3 with class containing "ingredientgroup_name" followed by ul with li.ingredient
    final nytSectionHeaders = document.querySelectorAll('[class*="ingredientgroup_name"]');
    if (nytSectionHeaders.isNotEmpty) {
      for (final header in nytSectionHeaders) {
        var sectionText = _decodeHtml((header.text ?? '').trim());
        if (sectionText.isNotEmpty) {
          // Remove "For the" prefix if present
          final cleanedSection = _stripForThePrefix(sectionText);
          ingredients.add('[$cleanedSection]');
        }
        
        // Get the ul sibling that follows this header
        var sibling = header.nextElementSibling;
        while (sibling != null) {
          final tagName = sibling.localName?.toLowerCase() ?? '';
          
          if (tagName == 'ul') {
            // Get all li elements (NYT uses class containing "ingredient")
            final items = sibling.querySelectorAll('li');
            for (final item in items) {
              final text = _decodeHtml((item.text ?? '').trim());
              if (text.isNotEmpty) {
                ingredients.add(text);
              }
            }
            break; // Found the ul, move to next section
          } else if (tagName == 'h3' || tagName == 'h2') {
            break; // Next section header
          }
          sibling = sibling.nextElementSibling;
        }
      }
      
      if (ingredients.isNotEmpty) return _deduplicateIngredients(ingredients);
    }
    
    // Try WPRM (WordPress Recipe Maker) format with ingredient groups
    final wprmGroups = document.querySelectorAll('.wprm-recipe-ingredient-group');
    if (wprmGroups.isNotEmpty) {
      for (final group in wprmGroups) {
        final groupName = group.querySelector('.wprm-recipe-group-name');
        if (groupName != null) {
          final sectionText = _decodeHtml((groupName.text ?? '').trim());
          if (sectionText.isNotEmpty) {
            ingredients.add('[$sectionText]');
          }
        }
        
        final items = group.querySelectorAll('.wprm-recipe-ingredient');
        for (final item in items) {
          final text = _decodeHtml((item.text ?? '').trim());
          if (text.isNotEmpty) {
            ingredients.add(text);
          }
        }
      }
      
      if (ingredients.isNotEmpty) return _deduplicateIngredients(ingredients);
    }
    
    // Try Tasty Recipes plugin format: .tasty-recipes-ingredients-body with h4 section headers followed by ul
    final tastyRecipesBody = document.querySelector('.tasty-recipes-ingredients-body');
    if (tastyRecipesBody != null) {
      // Iterate through children to preserve section order
      for (final child in tastyRecipesBody.children) {
        final tagName = child.localName?.toLowerCase() ?? '';
        
        if (tagName == 'h4') {
          // Section header
          var sectionText = _decodeHtml((child.text ?? '').trim());
          // Remove trailing colon if present
          sectionText = sectionText.replaceAll(RegExp(r':$'), '').trim();
          if (sectionText.isNotEmpty) {
            ingredients.add('[$sectionText]');
          }
        } else if (tagName == 'ul') {
          // Ingredient list
          final items = child.querySelectorAll('li');
          for (final item in items) {
            final text = _decodeHtml((item.text ?? '').trim());
            if (text.isNotEmpty) {
              ingredients.add(text);
            }
          }
        }
      }
      
      if (ingredients.isNotEmpty) return _deduplicateIngredients(ingredients);
    }
    
    // Try WordPress block heading pattern (sogoodmagazine.com style):
    // h3.wp-block-heading followed by ul (ingredients), then p (directions)
    // The content is within a .content-info section
    final contentInfo = document.querySelector('.content-info');
    if (contentInfo != null) {
      final wpBlockHeadings = contentInfo.querySelectorAll('h3.wp-block-heading');
      if (wpBlockHeadings.isNotEmpty) {
        for (final heading in wpBlockHeadings) {
          final sectionName = _decodeHtml((heading.text ?? '').trim());
          if (sectionName.isEmpty) continue;
          
          // Skip "Assembly" section (directions only) and generic headings
          final lowerSection = sectionName.toLowerCase();
          if (lowerSection == 'assembly' || 
              lowerSection.contains('discover') ||
              lowerSection.contains('related')) {
            continue;
          }
          
          // Look for ul sibling immediately after this heading (may skip &nbsp; and hr)
          var sibling = heading.nextElementSibling;
          var foundUl = false;
          while (sibling != null) {
            final tagName = sibling.localName?.toLowerCase() ?? '';
            
            // Skip separators and whitespace-only elements
            if (tagName == 'hr' || tagName == 'p') {
              // Check if p is just whitespace/nbsp
              final pText = (sibling.text ?? '').trim();
              if (pText.isEmpty || pText == '\u00a0') {
                sibling = sibling.nextElementSibling;
                continue;
              }
              // Otherwise it's directions, stop looking
              break;
            }
            
            if (tagName == 'ul') {
              // Found the ingredient list for this section
              final items = sibling.querySelectorAll('li');
              if (items.isNotEmpty) {
                // Add section header
                ingredients.add('[$sectionName]');
                for (final item in items) {
                  final text = _decodeHtml((item.text ?? '').trim());
                  if (text.isNotEmpty) {
                    ingredients.add(text);
                  }
                }
                foundUl = true;
              }
              break;
            }
            
            // Stop at next heading
            if (tagName == 'h2' || tagName == 'h3' || tagName == 'h4') {
              break;
            }
            
            sibling = sibling.nextElementSibling;
          }
        }
        
        if (ingredients.isNotEmpty) return _deduplicateIngredients(ingredients);
      }
    }
    
    // Try WordPress block heading pattern without .content-info wrapper (pastryartsmag.com style):
    // h3.wp-block-heading followed by ul (ingredients) directly on document level
    if (ingredients.isEmpty) {
      final wpBlockHeadings = document.querySelectorAll('h3.wp-block-heading');
      if (wpBlockHeadings.isNotEmpty) {
        for (final heading in wpBlockHeadings) {
          final sectionName = _decodeHtml((heading.text ?? '').trim());
          if (sectionName.isEmpty) continue;
          
          // Skip "Assembly" section (directions only) and generic headings
          final lowerSection = sectionName.toLowerCase();
          if (lowerSection == 'assembly' || 
              lowerSection.contains('discover') ||
              lowerSection.contains('related') ||
              lowerSection.contains('podcast') ||
              lowerSection.contains('latest')) {
            continue;
          }
          
          // Skip if section name looks like a link (e.g., "Recipe Name by Author")
          if (sectionName.contains(' by ') && lowerSection.contains('recipe')) {
            continue;
          }
          
          // Look for ul sibling immediately after this heading
          var sibling = heading.nextElementSibling;
          while (sibling != null) {
            final tagName = sibling.localName?.toLowerCase() ?? '';
            
            // Skip separators and whitespace-only elements
            if (tagName == 'hr' || tagName == 'p' || tagName == 'figure') {
              // Check if p is just whitespace/nbsp
              final pText = (sibling.text ?? '').trim();
              if (pText.isEmpty || pText == '\u00a0') {
                sibling = sibling.nextElementSibling;
                continue;
              }
              // Otherwise it's directions, stop looking for ul
              break;
            }
            
            if (tagName == 'ul') {
              // Found the ingredient list for this section
              final items = sibling.querySelectorAll('li');
              if (items.isNotEmpty) {
                // Add section header
                ingredients.add('[$sectionName]');
                for (final item in items) {
                  final text = _decodeHtml((item.text ?? '').trim());
                  if (text.isNotEmpty) {
                    ingredients.add(text);
                  }
                }
              }
              break;
            }
            
            // Stop at next heading
            if (tagName == 'h2' || tagName == 'h3' || tagName == 'h4') {
              break;
            }
            
            sibling = sibling.nextElementSibling;
          }
        }
        
        if (ingredients.isNotEmpty) return _deduplicateIngredients(ingredients);
      }
    }
    
    // Try generic section headers: h3 or h4 followed by ul/li
    final sectionHeaders = document.querySelectorAll('.ingredient-section-header, .ingredients h3, .ingredients h4');
    if (sectionHeaders.isNotEmpty) {
      for (final header in sectionHeaders) {
        final sectionText = _decodeHtml((header.text ?? '').trim());
        if (sectionText.isNotEmpty) {
          final sectionName = _stripForThePrefix(sectionText);
          ingredients.add('[$sectionName]');
        }
        
        // Get ingredients after this header
        var sibling = header.nextElementSibling;
        while (sibling != null) {
          final tagName = sibling.localName?.toLowerCase() ?? '';
          
          if (tagName == 'ul' || tagName == 'ol') {
            final items = sibling.querySelectorAll('li');
            for (final item in items) {
              final text = _decodeHtml((item.text ?? '').trim());
              if (text.isNotEmpty) {
                ingredients.add(text);
              }
            }
          } else if (tagName == 'h3' || tagName == 'h4' || tagName == 'h2') {
            break; // Next section
          }
          
          sibling = sibling.nextElementSibling;
        }
      }
      
      if (ingredients.isNotEmpty) return _deduplicateIngredients(ingredients);
    }
    
    // Try to find a specific ingredient container first (Saveur, etc.)
    // This avoids duplicate ingredients when the page has multiple copies for mobile/desktop views
    final ingredientContainerSelectors = [
      '#recipe-ingredients',           // Saveur uses id="recipe-ingredients"
      'ul.ingredients',                // Common pattern
      '.ingredients ul',               // ul inside .ingredients
      '.recipe-ingredients',           // Common class
      '[data-recipe-ingredients]',     // Data attribute pattern
    ];
    
    for (final selector in ingredientContainerSelectors) {
      // Use querySelector to get only the FIRST container
      final container = document.querySelector(selector);
      if (container != null) {
        final containerLis = container.querySelectorAll('li');
        if (containerLis.isNotEmpty) {
          for (final li in containerLis) {
            final liClasses = li.attributes['class'] ?? '';
            
            if (liClasses.contains('category')) {
              final h3 = li.querySelector('h3');
              if (h3 != null) {
                final text = _decodeHtml((h3.text ?? '').trim());
                if (text.isNotEmpty) {
                  final sectionName = _stripForThePrefix(text);
                  ingredients.add('[$sectionName]');
                }
              }
            } else {
              final text = _decodeHtml((li.text ?? '').trim());
              if (text.isNotEmpty) {
                ingredients.add(text);
              }
            }
          }
          
          if (ingredients.isNotEmpty) return _deduplicateIngredients(ingredients);
        }
      }
    }
    
    // Fallback: Query li.category and li.ingredient in document order
    // Apply deduplication to handle pages with multiple ingredient lists
    final allLis = document.querySelectorAll('li.category, li.ingredient');
    if (allLis.isNotEmpty) {
      for (final li in allLis) {
        final liClasses = li.attributes['class'] ?? '';
        
        if (liClasses.contains('category')) {
          final h3 = li.querySelector('h3');
          if (h3 != null) {
            final text = _decodeHtml((h3.text ?? '').trim());
            if (text.isNotEmpty) {
              final sectionName = _stripForThePrefix(text);
              ingredients.add('[$sectionName]');
            }
          }
        } else if (liClasses.contains('ingredient')) {
          final text = _decodeHtml((li.text ?? '').trim());
          if (text.isNotEmpty) {
            ingredients.add(text);
          }
        }
      }
    }
    
    return _deduplicateIngredients(ingredients);
  }
  
  /// Extract list items that follow a heading element
  List<String> _extractListItemsAfterHeading(dynamic heading, dynamic document) {
    final items = <String>[];
    
    // First try: look for ul immediately after the heading
    var nextElement = heading.nextElementSibling;
    while (nextElement != null) {
      final tagName = nextElement.localName?.toLowerCase();
      
      if (tagName == 'ul' || tagName == 'ol') {
        // Found a list - extract items
        final listItems = nextElement.querySelectorAll('li');
        for (final li in listItems) {
          final text = _decodeHtml(li.text?.trim() ?? '');
          if (text.isNotEmpty) {
            items.add(text);
          }
        }
        // Continue to look for more (might have sub-sections)
      } else if (tagName == 'h2') {
        // Hit a major heading - stop searching
        break;
      } else if (tagName == 'h3' || tagName == 'h4') {
        // Sub-section heading - add as section marker and continue
        final sectionText = _decodeHtml(nextElement.text?.trim() ?? '');
        if (sectionText.isNotEmpty) {
          items.add('$sectionText:');
        }
      }
      
      nextElement = nextElement.nextElementSibling;
    }
    
    // Second try: if heading has an id, look for lists in any wrapper after it
    if (items.isEmpty) {
      final headingId = heading.attributes['id'];
      if (headingId != null) {
        // Look for lists in parent's subsequent children
        final parent = heading.parent;
        if (parent != null) {
          var foundHeading = false;
          for (final child in parent.children) {
            if (child == heading) {
              foundHeading = true;
              continue;
            }
            if (foundHeading) {
              final tagName = child.localName?.toLowerCase();
              if (tagName == 'ul' || tagName == 'ol') {
                final listItems = child.querySelectorAll('li');
                for (final li in listItems) {
                  final text = _decodeHtml(li.text?.trim() ?? '');
                  if (text.isNotEmpty) {
                    items.add(text);
                  }
                }
                // Continue looking for more sections
              } else if (tagName == 'h2') {
                break;
              } else if (tagName == 'h3' || tagName == 'h4') {
                final sectionText = _decodeHtml(child.text?.trim() ?? '');
                if (sectionText.isNotEmpty) {
                  items.add('$sectionText:');
                }
              }
            }
          }
        }
      }
    }
    
    return _processIngredientListItems(items);
  }
  
  /// Extract items from bullet-point text content after a heading
  /// Handles sites like Modernist Pantry that use • characters instead of <ul>/<li>
  List<String> _extractBulletPointsAfterHeading(dynamic heading, dynamic document) {
    final items = <String>[];
    
    // Look for content following the heading until the next h2/h3
    var nextElement = heading.nextElementSibling;
    
    while (nextElement != null) {
      final tagName = nextElement.localName?.toLowerCase();
      
      // Stop at next heading
      if (tagName == 'h2' || tagName == 'h3') break;
      
      // Get text content - try the element itself first
      var textContent = nextElement.text?.trim() ?? '';
      
      // If the element is a container (div, section), also try getting all child text
      if (textContent.isEmpty && (tagName == 'div' || tagName == 'section' || tagName == 'article')) {
        // Get all text from descendants
        final allText = <String>[];
        final descendants = nextElement.querySelectorAll('p, span, div, li');
        for (final desc in descendants) {
          final descText = desc.text?.trim() ?? '';
          if (descText.isNotEmpty) {
            allText.add(descText);
          }
        }
        textContent = allText.join('\n');
      }
      
      if (textContent.isNotEmpty) {
        // Split by common bullet point characters
        // Common patterns: • (bullet), - (dash at start of line), * (asterisk), or newlines
        // Use more careful splitting to avoid breaking ingredient text with dashes
        final lines = textContent.split(RegExp(r'[•]\s*|\n+|(?:^|\n)\s*[-\*]\s+'));
        
        for (var line in lines) {
          line = _decodeHtml(line.trim());
          
          // Also handle cases where bullet is at start of line
          if (line.startsWith('•') || line.startsWith('- ') || line.startsWith('* ')) {
            line = line.substring(line.indexOf(' ') + 1).trim();
          }
          
          // Skip empty lines and very short lines (likely fragments)
          if (line.isEmpty || line.length < 3) continue;
          
          // Skip obvious non-ingredient content (links, navigation, etc.)
          if (line.toLowerCase().contains('click') || 
              line.toLowerCase().contains('subscribe') ||
              line.toLowerCase().contains('http')) continue;
          
          items.add(line);
        }
      }
      
      nextElement = nextElement.nextElementSibling;
    }
    
    // If we didn't find anything using siblings, try a broader search
    // Look for any text containing • within the heading's parent section
    if (items.isEmpty) {
      final parent = heading.parent;
      if (parent != null) {
        final fullText = parent.text ?? '';
        // Find the section after "Ingredients" heading
        final headingText = heading.text?.trim() ?? '';
        final headingIndex = fullText.indexOf(headingText);
        if (headingIndex >= 0) {
          var afterHeading = fullText.substring(headingIndex + headingText.length);
          // Find the next major section (Equipment, Directions, etc.)
          final nextSectionMatch = RegExp(r'\n(Equipment|Directions?|Instructions?|Method|Steps?|Timing|Yield)\b', caseSensitive: false).firstMatch(afterHeading);
          if (nextSectionMatch != null) {
            afterHeading = afterHeading.substring(0, nextSectionMatch.start);
          }
          // Now split by bullets
          final lines = afterHeading.split(RegExp(r'[•]\s*'));
          for (var line in lines) {
            line = _decodeHtml(line.trim());
            if (line.isEmpty || line.length < 3) continue;
            // Skip section-like headers that might have been caught
            if (RegExp(r'^(Equipment|Directions?|Instructions?|Method|Steps?|Timing|Yield)\b', caseSensitive: false).hasMatch(line)) continue;
            if (line.toLowerCase().contains('click') || 
                line.toLowerCase().contains('subscribe') ||
                line.toLowerCase().contains('http')) continue;
            items.add(line);
          }
        }
      }
    }
    
    return _processIngredientListItems(items);
  }
  
  /// Process ingredient list items - handles section headers within ingredients
  /// Detects patterns like "Ingredients for Sauce:" as section headers
  /// Also handles "and/or" patterns between consecutive ingredients
  List<String> _processIngredientListItems(List<String> items) {
    final processed = <String>[];
    int sectionCount = 0;
    
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      
      // Check if this is already a bracketed section header [Section Name]
      if (item.startsWith('[') && item.endsWith(']')) {
        sectionCount++;
        processed.add(item);
        continue;
      }
      
      // Check if this is a section header - must:
      // 1. End with colon
      // 2. Not contain numbers (which would indicate an amount)
      // 3. Not be too long (section headers are typically short)
      // 4. Optionally start with "Ingredients" or "For"
      final isLikelySectionHeader = item.endsWith(':') && 
          !RegExp(r'\d').hasMatch(item) &&  // No numbers
          item.length < 60 &&  // Not too long
          !RegExp(r',\s').hasMatch(item);  // No commas (which indicate ingredient lists)
      
      final sectionHeaderMatch = isLikelySectionHeader ? RegExp(
        r'^(?:Ingredients?\s+(?:for\s+)?|For\s+(?:the\s+)?)?(.+?)[:]\s*$',
        caseSensitive: false,
      ).firstMatch(item) : null;
      
      if (sectionHeaderMatch != null) {
        final sectionName = sectionHeaderMatch.group(1)?.trim() ?? item;
        sectionCount++;
        // Add all section headers - we'll use them for grouping
        processed.add('[${_capitalise(sectionName)}]');
      } else if (item.isNotEmpty) {
        // Check for "and/or" pattern - if this ingredient ends with "and/or" or "; and/or"
        // and there's a next ingredient, merge them with the next as a note
        final andOrMatch = RegExp(r'^(.+?)[;,]?\s*(?:and/or)\s*$', caseSensitive: false).firstMatch(item);
        if (andOrMatch != null && i + 1 < items.length) {
          final baseIngredient = andOrMatch.group(1)?.trim() ?? item;
          final nextItem = items[i + 1];
          
          // Check if next item is an ingredient (starts with a number or fraction)
          // and not a section header
          if (!nextItem.startsWith('[') && 
              !nextItem.endsWith(':') &&
              RegExp(r'^[\d½⅓¼⅔¾⅕⅖⅗⅘⅙⅚⅛⅜⅝⅞]').hasMatch(nextItem)) {
            // Merge: base ingredient with note "and/or [next ingredient]"
            processed.add('$baseIngredient (and/or $nextItem)');
            i++; // Skip the next item since we merged it
            continue;
          }
        }
        
        // Check if this item starts with "and/or" - it should be merged with previous
        if (RegExp(r'^and/or\s+', caseSensitive: false).hasMatch(item) && processed.isNotEmpty) {
          final lastIndex = processed.length - 1;
          final lastItem = processed[lastIndex];
          // Don't merge with section headers
          if (!lastItem.startsWith('[') && !lastItem.endsWith(']')) {
            // Append this as a note to the previous ingredient
            final cleanedItem = item.replaceFirst(RegExp(r'^and/or\s+', caseSensitive: false), '');
            processed[lastIndex] = '${lastItem.replaceAll(RegExp(r'[;,]\s*$'), '')} (and/or $cleanedItem)';
            continue;
          }
        }
        
        processed.add(item);
      }
    }
    
    // If there was only one section header at the start, it's redundant - remove it
    if (sectionCount == 1 && processed.isNotEmpty && processed.first.startsWith('[') && processed.first.endsWith(']')) {
      processed.removeAt(0);
    }
    
    return processed;
  }
  
  /// Extract recipe image from HTML document
  /// Checks schema.org markup, Open Graph meta tags, and common recipe image selectors
  String? _extractImageFromHtml(dynamic document) {
    // Helper to get image URL from various attributes
    String? getImageUrl(dynamic element) {
      if (element == null) return null;
      // Try various attributes - sites use different ones for lazy loading
      final attrs = ['src', 'content', 'data-src', 'data-lazy-src', 'data-original', 'srcset'];
      for (final attr in attrs) {
        var value = element.attributes[attr];
        if (value != null && value.isNotEmpty) {
          // For srcset, take the first URL
          if (attr == 'srcset') {
            value = value.split(',').first.split(' ').first.trim();
          }
          // Skip placeholder images
          if (value.contains('data:image') || 
              value.contains('placeholder') ||
              value.contains('loading') ||
              value.contains('blank')) {
            continue;
          }
          return value;
        }
      }
      return null;
    }
    
    // 1. Try schema.org Recipe image (itemprop="image")
    final schemaImg = document.querySelector('[itemscope][itemtype*="Recipe"] [itemprop="image"]');
    if (schemaImg != null) {
      final url = getImageUrl(schemaImg);
      if (url != null) return url;
    }
    
    // 2. Try itemprop="image" directly (without parent scope check)
    final itempropImg = document.querySelector('[itemprop="image"]');
    if (itempropImg != null) {
      final url = getImageUrl(itempropImg);
      if (url != null) return url;
    }
    
    // 3. Try Open Graph image meta tag
    final ogImage = document.querySelector('meta[property="og:image"]');
    if (ogImage != null) {
      final content = ogImage.attributes['content'];
      if (content != null && content.isNotEmpty) return content;
    }
    
    // 4. Try Twitter card image
    final twitterImage = document.querySelector('meta[name="twitter:image"]');
    if (twitterImage != null) {
      final content = twitterImage.attributes['content'];
      if (content != null && content.isNotEmpty) return content;
    }
    
    // 5. Try preloaded image link (used by some sites like Seedlip)
    final preloadImage = document.querySelector('link[rel="preload"][as="image"]');
    if (preloadImage != null) {
      final href = preloadImage.attributes['href'];
      if (href != null && href.isNotEmpty && !href.contains('icon') && !href.contains('logo')) {
        return href;
      }
    }
    
    // 5b. Try Divi Builder image (et_pb_image with fetchpriority="high")
    // Divi sites often mark the main recipe image with fetchpriority="high"
    final diviImageHigh = document.querySelector('.et_pb_image img[fetchpriority="high"]');
    if (diviImageHigh != null) {
      final url = getImageUrl(diviImageHigh);
      if (url != null && !url.contains('icon') && !url.contains('logo')) {
        return url;
      }
    }
    
    // 5c. Try any Divi Builder image (.et_pb_image) as fallback
    final diviImage = document.querySelector('.et_pb_image img');
    if (diviImage != null) {
      final url = getImageUrl(diviImage);
      if (url != null && !url.contains('icon') && !url.contains('logo')) {
        return url;
      }
    }
    
    // 6. Try common recipe image class selectors
    final commonSelectors = [
      '.recipe-image img',
      '.recipe-photo img',
      '.wprm-recipe-image img',
      '.tasty-recipes-image img',
      '.snippet-image img',
      'article img',
      'picture source', // For picture elements with source tags
      'picture img',
    ];
    
    for (final selector in commonSelectors) {
      final element = document.querySelector(selector);
      if (element != null) {
        final url = getImageUrl(element);
        if (url != null && !url.contains('icon') && !url.contains('logo')) {
          return url;
        }
      }
    }
    
    return null;
  }
  
  /// Extract step images from direction/instruction content
  /// Handles sites like AmazingFoodMadeEasy that embed images in paragraphs
  List<String> _extractStepImages(dynamic document, String baseUrl) {
    final images = <String>[];
    final seenUrls = <String>{};
    
    // Helper to resolve relative URLs
    String resolveUrl(String src) {
      if (src.startsWith('http://') || src.startsWith('https://')) {
        return src;
      }
      if (src.startsWith('//')) {
        return 'https:$src';
      }
      // Relative URL - try to resolve against base
      try {
        final base = Uri.parse(baseUrl);
        return base.resolve(src).toString();
      } catch (_) {
        return src;
      }
    }
    
    // Helper to check if an image is inside promotional/related content sections
    // (e.g., "Discover more", "Related recipes", magazine ads)
    bool isInPromotionalSection(dynamic img) {
      // Walk up parent tree to check for promotional content indicators
      var parent = img.parent;
      int depth = 0;
      while (parent != null && depth < 10) {
        final tagName = parent.localName?.toLowerCase() ?? '';
        final classes = parent.attributes['class']?.toLowerCase() ?? '';
        
        // Check for related/promotional section classes
        if (classes.contains('related') || 
            classes.contains('promo') ||
            classes.contains('discover') ||
            classes.contains('advertisement') ||
            classes.contains('sidebar') ||
            classes.contains('so-good-related-post')) {
          return true;
        }
        
        // Check if this is a gallery after a "Discover" paragraph
        if (tagName == 'figure' && classes.contains('wp-block-gallery')) {
          // Check if preceding sibling is a paragraph with "Discover"
          final prevSibling = parent.previousElementSibling;
          if (prevSibling != null) {
            final prevText = (prevSibling.text ?? '').toLowerCase();
            if (prevText.contains('discover') || 
                prevText.contains('related') ||
                prevText.contains('other recipes')) {
              return true;
            }
          }
        }
        
        parent = parent.parent;
        depth++;
      }
      return false;
    }
    
    // Look for images in direction/instruction sections
    final directionSelectors = [
      '.recipe-instructions img',
      '.instructions img',
      '.instructions img.body_image', // AmazingFoodMadeEasy
      '.directions img',
      '.recipe-procedure img',
      '[itemprop="recipeInstructions"] img',
      '.step-content img',
      '.instruction-step img',
      '.method img',
      // AmazingFoodMadeEasy uses paragraphs with embedded image links
      '.entry-content p a img',
      '.post-content p a img',
      'article p a img',
      // Direct images in content
      '.entry-content p img',
      '.post-content p img',
    ];
    
    for (final selector in directionSelectors) {
      final imgElements = document.querySelectorAll(selector);
      for (final img in imgElements) {
        // Skip images in promotional/related content sections
        if (isInPromotionalSection(img)) continue;
        
        // Get the src, checking data-src for lazy-loaded images too
        // Prefer data-src (full quality) over src (low quality placeholder)
        var src = img.attributes['data-src'] ?? 
                  img.attributes['data-lazy-src'] ??
                  img.attributes['src'];
        
        if (src == null || src.isEmpty) continue;
        
        // Skip icons, logos, and tiny images
        if (src.contains('icon') || 
            src.contains('logo') || 
            src.contains('avatar') ||
            src.contains('emoji') ||
            src.contains('1x1') ||
            src.contains('pixel') ||
            src.contains('low_quality')) continue; // Skip low quality placeholders
        
        // Skip if we've already seen this URL
        final resolvedUrl = resolveUrl(src);
        if (seenUrls.contains(resolvedUrl)) continue;
        seenUrls.add(resolvedUrl);
        
        images.add(resolvedUrl);
      }
    }
    
    // AmazingFoodMadeEasy: Look for a.image_href anchors with S3 URLs
    try {
      final imageHrefAnchors = document.querySelectorAll('a.image_href, .instructions a[href*="s3.amazonaws.com"]');
      for (final anchor in imageHrefAnchors) {
        final href = anchor.attributes['href'];
        if (href != null && href.isNotEmpty) {
          final resolvedUrl = resolveUrl(href);
          // Check if it's an image URL
          final lower = resolvedUrl.toLowerCase();
          if (lower.contains('.jpg') || lower.contains('.jpeg') || lower.contains('.png') || lower.contains('.webp')) {
            if (!seenUrls.contains(resolvedUrl)) {
              seenUrls.add(resolvedUrl);
              images.add(resolvedUrl);
            }
          }
        }
      }
    } catch (_) {
      // Selector not supported
    }
    
    // Also look for images in anchor tags within content (common pattern)
    final anchorImgSelectors = [
      '.entry-content a[href*=".jpg"] img',
      '.entry-content a[href*=".png"] img',
      '.entry-content a[href*=".webp"] img',
      '.post-content a[href*=".jpg"] img',
      'article a[href*=".jpg"] img',
    ];
    
    for (final selector in anchorImgSelectors) {
      try {
        final anchors = document.querySelectorAll(selector);
        for (final anchor in anchors) {
          // Prefer the anchor href (usually full-size image)
          final parent = anchor.parent;
          if (parent != null && parent.localName?.toLowerCase() == 'a') {
            final href = parent.attributes['href'];
            if (href != null && href.isNotEmpty) {
              final resolvedUrl = resolveUrl(href);
              if (!seenUrls.contains(resolvedUrl)) {
                seenUrls.add(resolvedUrl);
                images.add(resolvedUrl);
              }
              continue;
            }
          }
          
          // Fall back to img src
          var src = anchor.attributes['src'] ?? anchor.attributes['data-src'];
          if (src != null && src.isNotEmpty) {
            final resolvedUrl = resolveUrl(src);
            if (!seenUrls.contains(resolvedUrl)) {
              seenUrls.add(resolvedUrl);
              images.add(resolvedUrl);
            }
          }
        }
      } catch (_) {
        // Selector might not be supported
      }
    }
    
    // Helper to check if URL is a valid step image
    bool isValidImageUrl(String url) {
      if (url.isEmpty) return false;
      final lower = url.toLowerCase();
      // Must have image extension or be S3/cloudfront URL
      final hasImageExt = lower.contains('.jpg') || 
          lower.contains('.jpeg') || 
          lower.contains('.png') || 
          lower.contains('.webp') ||
          lower.contains('.gif');
      final isS3 = lower.contains('s3.amazonaws.com') || lower.contains('cloudfront');
      if (!hasImageExt && !isS3) return false;
      // Skip icons, logos, avatars, tiny images
      if (lower.contains('icon') || 
          lower.contains('logo') || 
          lower.contains('avatar') ||
          lower.contains('emoji') ||
          lower.contains('1x1') ||
          lower.contains('pixel') ||
          lower.contains('badge') ||
          lower.contains('button') ||
          lower.contains('book-cover') ||
          lower.contains('headshot')) return false;
      return true;
    }
    
    // AmazingFoodMadeEasy embeds images as anchor tags with S3 URLs
    // Look for anchors with image hrefs
    try {
      final allAnchors = document.querySelectorAll('a[href*="s3.amazonaws.com"], a[href*=".jpg"], a[href*=".png"]');
      for (final anchor in allAnchors) {
        final href = anchor.attributes['href'];
        if (href != null && isValidImageUrl(href)) {
          final resolvedUrl = resolveUrl(href);
          if (!seenUrls.contains(resolvedUrl)) {
            seenUrls.add(resolvedUrl);
            images.add(resolvedUrl);
          }
        }
      }
    } catch (_) {
      // Selector not supported
    }
    
    // Also look for image links in raw HTML content (markdown-style image references)
    // Pattern: [alt text](https://...image.jpg)
    try {
      final bodyHtml = document.body?.innerHtml ?? '';
      final markdownImagePattern = RegExp(
        r'\[([^\]]+)\]\((https?://[^\s\)]+\.(?:jpg|jpeg|png|webp|gif))\)',
        caseSensitive: false,
      );
      for (final match in markdownImagePattern.allMatches(bodyHtml)) {
        final imageUrl = match.group(2);
        if (imageUrl != null && isValidImageUrl(imageUrl)) {
          if (!seenUrls.contains(imageUrl)) {
            seenUrls.add(imageUrl);
            images.add(imageUrl);
          }
        }
      }
    } catch (_) {
      // Error parsing HTML
    }
    
    // AmazingFoodMadeEasy: Images appear between H3 direction headings
    // Look for H3 headings that look like steps, then find images before/after them
    try {
      final h3Elements = document.querySelectorAll('h3');
      for (final h3 in h3Elements) {
        final h3Text = h3.text?.toLowerCase() ?? '';
        
        // Skip non-direction headings
        if (h3Text.contains('ingredient') || h3Text.contains('equipment')) continue;
        
        // Skip promotional/related content headings
        if (h3Text.contains('discover') || h3Text.contains('related') || h3Text.contains('also like')) continue;
        
        // Look for images in siblings before/after this H3
        // Check previous siblings
        var sibling = h3.previousElementSibling;
        for (int i = 0; i < 3 && sibling != null; i++) {
          final tagName = sibling.localName?.toLowerCase() ?? '';
          
          // Found an image or figure
          if (tagName == 'img') {
            if (!isInPromotionalSection(sibling)) {
              final src = sibling.attributes['src'] ?? sibling.attributes['data-src'];
              if (src != null && isValidImageUrl(src)) {
                final resolvedUrl = resolveUrl(src);
                if (!seenUrls.contains(resolvedUrl)) {
                  seenUrls.add(resolvedUrl);
                  images.add(resolvedUrl);
                }
              }
            }
          } else if (tagName == 'figure' || tagName == 'p' || tagName == 'div') {
            // Skip if this element is in a promotional section
            if (!isInPromotionalSection(sibling)) {
              // Check for images inside
              final innerImgs = sibling.querySelectorAll('img');
              for (final img in innerImgs) {
                if (isInPromotionalSection(img)) continue;
                final src = img.attributes['src'] ?? img.attributes['data-src'];
                if (src != null && isValidImageUrl(src)) {
                  final resolvedUrl = resolveUrl(src);
                  if (!seenUrls.contains(resolvedUrl)) {
                    seenUrls.add(resolvedUrl);
                    images.add(resolvedUrl);
                  }
                }
              }
              // Also check for anchor links to images
              final innerAnchors = sibling.querySelectorAll('a');
              for (final anchor in innerAnchors) {
                final href = anchor.attributes['href'];
                if (href != null && isValidImageUrl(href)) {
                  final resolvedUrl = resolveUrl(href);
                  if (!seenUrls.contains(resolvedUrl)) {
                    seenUrls.add(resolvedUrl);
                    images.add(resolvedUrl);
                  }
                }
              }
            }
          }
          
          // Stop if we hit another H3
          if (tagName == 'h3') break;
          
          sibling = sibling.previousElementSibling;
        }
        
        // Check next siblings for images too
        sibling = h3.nextElementSibling;
        for (int i = 0; i < 3 && sibling != null; i++) {
          final tagName = sibling.localName?.toLowerCase() ?? '';
          
          // Stop if we hit another H3 (that's the next step)
          if (tagName == 'h3') break;
          
          // Found an image or figure
          if (tagName == 'img') {
            if (!isInPromotionalSection(sibling)) {
              final src = sibling.attributes['src'] ?? sibling.attributes['data-src'];
              if (src != null && isValidImageUrl(src)) {
                final resolvedUrl = resolveUrl(src);
                if (!seenUrls.contains(resolvedUrl)) {
                  seenUrls.add(resolvedUrl);
                  images.add(resolvedUrl);
                }
              }
            }
          } else if (tagName == 'figure' || tagName == 'p' || tagName == 'div') {
            // Skip if this element is in a promotional section
            if (!isInPromotionalSection(sibling)) {
              // Check for images inside
              final innerImgs = sibling.querySelectorAll('img');
              for (final img in innerImgs) {
                if (isInPromotionalSection(img)) continue;
                final src = img.attributes['src'] ?? img.attributes['data-src'];
                if (src != null && isValidImageUrl(src)) {
                  final resolvedUrl = resolveUrl(src);
                  if (!seenUrls.contains(resolvedUrl)) {
                    seenUrls.add(resolvedUrl);
                    images.add(resolvedUrl);
                  }
                }
              }
              // Also check for anchor links to images
              final innerAnchors = sibling.querySelectorAll('a');
              for (final anchor in innerAnchors) {
                final href = anchor.attributes['href'];
                if (href != null && isValidImageUrl(href)) {
                  final resolvedUrl = resolveUrl(href);
                  if (!seenUrls.contains(resolvedUrl)) {
                    seenUrls.add(resolvedUrl);
                    images.add(resolvedUrl);
                  }
                }
              }
            }
          }
          
          sibling = sibling.nextElementSibling;
        }
      }
    } catch (_) {
      // Error parsing H3 structure
    }
    
    return images;
  }
  
  /// Parse directions by looking for step-based structure (h3 headings or numbered sections)
  List<String> _parseDirectionsBySections(dynamic document) {
    final directions = <String>[];
    
    // Look for h3 headings that might be step titles
    final stepHeadings = document.querySelectorAll('h3');
    
    bool isFirstSection = true;
    
    for (final heading in stepHeadings) {
      final stepTitle = _decodeHtml(heading.text?.trim() ?? '');
      if (stepTitle.isEmpty) continue;
      
      // Skip if this looks like a non-recipe heading (navigation, etc.)
      if (_isNavigationHeading(stepTitle)) continue;
      
      // Skip if this looks like a step number prefix (e.g., "Step 1" with content in divs)
      final looksLikeStepNumber = RegExp(r'^Step\s*\d+$', caseSensitive: false).hasMatch(stepTitle);
      
      // Check if this h3 is followed by a ul (ingredient section) - skip ingredient sections
      // This handles sogoodmagazine.com style where h3 → ul (ingredients) → p (directions)
      var checkSibling = heading.nextElementSibling;
      bool isIngredientSection = false;
      while (checkSibling != null) {
        final checkTag = checkSibling.localName?.toLowerCase() ?? '';
        // Skip whitespace/hr elements
        if (checkTag == 'hr') {
          checkSibling = checkSibling.nextElementSibling;
          continue;
        }
        if (checkTag == 'p') {
          final pText = (checkSibling.text ?? '').trim();
          if (pText.isEmpty || pText == '\u00a0') {
            checkSibling = checkSibling.nextElementSibling;
            continue;
          }
          // Non-empty p means this is a directions section
          break;
        }
        if (checkTag == 'ul') {
          // This h3 is followed by ul - it's an ingredient section header
          isIngredientSection = true;
          break;
        }
        break; // Unknown element, stop checking
      }
      
      // Skip ingredient section headers - only process direction sections
      if (isIngredientSection) continue;
      
      // For non-first sections, add the section title as its own direction step
      if (!isFirstSection && !looksLikeStepNumber) {
        // Add section header as a step (like "Create Ice Cream Base")
        directions.add('**$stepTitle**');
      }
      isFirstSection = false;
      
      // Collect text content after this heading until the next h3
      var nextElement = heading.nextElementSibling;
      
      while (nextElement != null) {
        final tagName = nextElement.localName?.toLowerCase();
        
        // Stop at the next step heading
        if (tagName == 'h3' || tagName == 'h2') break;
        
        // Skip hr separators and whitespace-only elements
        if (tagName == 'hr') {
          nextElement = nextElement.nextElementSibling;
          continue;
        }
        
        // Skip ul elements - these are typically ingredient lists, not directions
        // Directions in recipe sites are usually in p, ol, or div elements
        if (tagName == 'ul') {
          nextElement = nextElement.nextElementSibling;
          continue;
        }
        
        // First try to extract nested paragraphs/divs from ol (ordered instruction lists)
        bool foundNested = false;
        if (tagName == 'div' || tagName == 'ol') {
          final nestedDivs = nextElement.querySelectorAll('div, p, li');
          for (final nested in nestedDivs) {
            final text = _decodeHtml(nested.text?.trim() ?? '');
            if (text.isNotEmpty && text != ' ' && text.length > 15) {
              // Avoid duplicates
              if (directions.isEmpty || directions.last != text) {
                directions.add(text);
                foundNested = true;
              }
            }
          }
        }
        
        // If no nested elements found, try to split the text by paragraphs
        if (!foundNested && (tagName == 'div' || tagName == 'p' || tagName == 'span')) {
          // Get HTML content to preserve paragraph breaks
          final htmlContent = nextElement.innerHtml ?? '';
          
          // Split by br tags or double newlines to get separate paragraphs
          final paragraphs = htmlContent
              .replaceAll(RegExp(r'<br\s*/?>'), '\n\n')
              .replaceAll(RegExp(r'</p>\s*<p[^>]*>'), '\n\n')
              .split(RegExp(r'\n\s*\n'))
              .map((p) => _decodeHtml(p.replaceAll(RegExp(r'<[^>]+>'), '').trim()))
              .where((p) => p.isNotEmpty && p.length > 15)
              .toList();
          
          if (paragraphs.length > 1) {
            // Multiple paragraphs found, add each separately
            for (final para in paragraphs) {
              if (directions.isEmpty || directions.last != para) {
                directions.add(para);
              }
            }
          } else {
            // Single block of text - add as is
            final text = _decodeHtml(nextElement.text?.trim() ?? '');
            if (text.isNotEmpty && text != ' ' && text.length > 15) {
              directions.add(text);
            }
          }
        } else if (!foundNested && tagName == 'li') {
          // Handle list items (from ol only, since we skip ul)
          final text = _decodeHtml(nextElement.text?.trim() ?? '');
          if (text.isNotEmpty && text.length > 15) {
            directions.add(text);
          }
        }
        
        nextElement = nextElement.nextElementSibling;
      }
    }
    
    // If no h3-based steps found, try looking for ordered lists or numbered paragraphs
    if (directions.isEmpty) {
      final orderedLists = document.querySelectorAll('ol');
      for (final ol in orderedLists) {
        final items = ol.querySelectorAll('li');
        for (final li in items) {
          final text = _decodeHtml(li.text?.trim() ?? '');
          if (text.isNotEmpty && text.length > 20) {
            directions.add(text);
          }
        }
        if (directions.isNotEmpty) break;
      }
    }
    
    return directions;
  }
  
  /// Check if text could be an ingredient line (more flexible than strict measurement matching)
  bool _couldBeIngredientLine(String text) {
    // Has standard measurements
    if (RegExp(r'\d+\s*(?:g|grams?|kg|oz|ounce|lb|pound|cup|cups|tbsp|tablespoon|tsp|teaspoon|ml|l)', caseSensitive: false).hasMatch(text)) {
      return true;
    }
    // Starts with a number
    if (RegExp(r'^\d+\s+').hasMatch(text)) {
      return true;
    }
    // Starts with a fraction
    if (RegExp(r'^[½¼¾⅓⅔⅛⅜⅝⅞]').hasMatch(text)) {
      return true;
    }
    // Contains common food words (be permissive for paragraph-style ingredients)
    final lower = text.toLowerCase();
    const foodWords = [
      'salt', 'pepper', 'oil', 'butter', 'sugar', 'flour', 'water', 'milk',
      'chicken', 'beef', 'pork', 'fish', 'garlic', 'onion', 'tomato', 'cheese',
      'cream', 'sauce', 'stock', 'broth', 'vinegar', 'lemon', 'honey', 'eggs',
      'fresh', 'dried', 'chopped', 'minced', 'sliced', 'diced', 'ground',
    ];
    if (foodWords.any((word) => lower.contains(word))) {
      // Only if the line is reasonably short (not a full paragraph of text)
      return text.length < 150;
    }
    return false;
  }
  
  /// Check if a heading looks like navigation or non-recipe content
  bool _isNavigationHeading(String text) {
    final lower = text.toLowerCase();
    const navPatterns = [
      'menu', 'navigation', 'search', 'cart', 'login', 'sign in', 'sign up',
      'categories', 'related', 'popular', 'latest', 'subscribe', 'newsletter',
      'about', 'contact', 'privacy', 'terms', 'copyright', 'share', 'comment',
    ];
    return navPatterns.any((pattern) => lower.contains(pattern));
  }
  
  /// Parse timing text like "Active Time: 30 Minutes Total Time: 1 Hour"
  String? _parseTimingText(String text) {
    // Try to extract total time
    final totalMatch = RegExp(
      r'Total\s+Time[:\s]+(\d+)\s*(minutes?|mins?|hours?|hrs?|h)',
      caseSensitive: false,
    ).firstMatch(text);
    
    if (totalMatch != null) {
      final value = int.tryParse(totalMatch.group(1) ?? '') ?? 0;
      final unit = totalMatch.group(2)?.toLowerCase() ?? '';
      
      if (unit.startsWith('h')) {
        return '$value hr';
      } else {
        return '$value min';
      }
    }
    
    // Try to extract any time mention
    final anyTimeMatch = RegExp(
      r'(\d+)\s*(minutes?|mins?|hours?|hrs?|h)',
      caseSensitive: false,
    ).firstMatch(text);
    
    if (anyTimeMatch != null) {
      final value = int.tryParse(anyTimeMatch.group(1) ?? '') ?? 0;
      final unit = anyTimeMatch.group(2)?.toLowerCase() ?? '';
      
      if (unit.startsWith('h')) {
        return '$value hr';
      } else {
        return '$value min';
      }
    }
    
    return null;
  }
  
  /// Check if this looks like a modernist gastronomy recipe
  bool _isModernistRecipe(dynamic document, String sourceUrl, List<String> ingredients) {
    final lowerUrl = sourceUrl.toLowerCase();
    
    // First, check if this is a pickle/fermentation context
    // Calcium chloride is commonly used for crisp pickles (Pickle Crisp), not just modernist
    const pickleContextIndicators = [
      'pickle', 'pickled', 'brine', 'brined', 'brining',
      'ferment', 'fermented', 'lacto', 'kimchi', 'sauerkraut',
      'canning', 'preserve', 'preserved',
    ];
    final isPickleContext = pickleContextIndicators.any((p) => lowerUrl.contains(p));
    
    // Check if this is a pastry/dessert context where 'foam' and 'gel' keywords would be misleading
    // Mousse, mousseline, chantilly, etc. are traditional pastry, not modernist
    // Gelatin and gel-like textures are common in desserts
    const pastryContextIndicators = [
      'pastry', 'dessert', 'cake', 'mousse', 'mousseline', 'chantilly',
      'ganache', 'entremet', 'patisserie', 'baking', 'chocolate',
      'vegan', 'cupcake', 'tart', 'pie', 'cream', 'custard', 'pudding',
    ];
    final isPastryContext = pastryContextIndicators.any((p) => lowerUrl.contains(p));
    
    // If this is clearly a pastry/dessert context, require explicit modernist URL indicators
    // to classify as modernist - don't rely on technique keywords alone
    if (isPastryContext) {
      // Only consider modernist if URL explicitly mentions it
      if (lowerUrl.contains('modernist') || 
          lowerUrl.contains('molecular') ||
          lowerUrl.contains('chefsteps')) {
        return true;
      }
      // For pastry context, skip technique keyword detection entirely
      // as mousse, gel, foam are all traditional pastry terms
      return false;
    }
    
    // Check URL for modernist indicators
    if (lowerUrl.contains('modernist') || 
        lowerUrl.contains('molecular') ||
        lowerUrl.contains('chefsteps') ||
        lowerUrl.contains('science') ||
        lowerUrl.contains('technique')) {
      return true;
    }
    
    // Check ingredients for modernist additives
    // Exclude calcium chloride if in pickle context (it's Pickle Crisp)
    final modernistIngredients = [
      'agar', 'sodium alginate', 'calcium lactate',
      'xanthan', 'lecithin', 'maltodextrin', 'tapioca maltodextrin',
      'methylcellulose', 'gellan', 'carrageenan', 'transglutaminase',
      'activa', 'foam magic', 'versawhip', 'ultra-tex', 'ultratex',
      'sodium citrate', 'sodium hexametaphosphate', 'isomalt',
      'liquid nitrogen', 'immersion circulator', 'sous vide',
      // Only include calcium chloride if NOT in pickle context
      if (!isPickleContext) 'calcium chloride',
    ];
    
    final allText = ingredients.join(' ').toLowerCase();
    for (final ingredient in modernistIngredients) {
      if (allText.contains(ingredient)) {
        return true;
      }
    }
    
    // Check page content for technique keywords
    final bodyText = document.body?.text?.toLowerCase() ?? '';
    const techniqueKeywords = [
      'spherification', 'gelification', 'emulsification',
      'sous vide', 'pressure cooking', 'vacuum seal',
      'caviar', 'pearls',
    ];
    
    int matchCount = 0;
    for (final keyword in techniqueKeywords) {
      if (bodyText.contains(keyword)) matchCount++;
    }
    
    // Require at least 2 technique keywords for modernist classification
    // This helps avoid false positives from single keyword matches
    return matchCount >= 2;
  }
  
  // NOTE: The following course detection functions were consolidated into:
  // - _detectCourseWithConfidence() - unified course detection with confidence scoring
  // - _matchesCourseKeywords() - text-based keyword matching using _courseKeywords map
  // - _hasSpiritsInIngredients() - drinks ingredient detection
  // - _hasSmokingIndicators() - smoking/BBQ wood type detection
  // - _hasBreadIndicators() - bread flour+yeast detection
  // Old functions removed: _isBreadRecipe, _isDessertRecipe, _isSoupRecipe, 
  //   _isSauceRecipe, _isSideRecipe, _isAppRecipe, _isSmokingRecipe, _isDrinkRecipeByContent
}

// Provider for URL recipe importer
final urlImporterProvider = Provider<UrlRecipeImporter>((ref) {
  return UrlRecipeImporter();
});
