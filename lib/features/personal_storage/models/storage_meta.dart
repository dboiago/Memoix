/// Metadata file for external storage sync
/// Stored as `.memoix_meta.json` in the remote storage folder
/// 
/// Structure matches Section 3.2 of EXTERNAL_STORAGE.md
class StorageMeta {
  /// Schema version for this meta file format
  final int version;
  
  /// Schema version of the recipe data format
  final int schemaVersion;
  
  /// Bundle format: "single-file" or "split-by-course"
  final String bundleFormat;
  
  /// Last modification timestamp (ISO 8601)
  final DateTime lastModified;
  
  /// Device identifier that last pushed (e.g., "iPhone 15 Pro")
  final String lastModifiedBy;
  
  /// Total number of recipes across all domains
  final int recipeCount;
  
  /// SHA256 checksum of the bundle for integrity verification
  final String? checksum;
  
  /// Recipe counts per domain (recipes, pizzas, sandwiches, etc.)
  final DomainCounts domains;

  const StorageMeta({
    required this.version,
    required this.schemaVersion,
    required this.bundleFormat,
    required this.lastModified,
    required this.lastModifiedBy,
    required this.recipeCount,
    this.checksum,
    required this.domains,
  });

  /// Create from JSON map
  factory StorageMeta.fromJson(Map<String, dynamic> json) {
    return StorageMeta(
      version: json['version'] as int? ?? 1,
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      bundleFormat: json['bundleFormat'] as String? ?? 'single-file',
      lastModified: DateTime.parse(json['lastModified'] as String),
      lastModifiedBy: json['lastModifiedBy'] as String? ?? 'Unknown',
      recipeCount: json['recipeCount'] as int? ?? 0,
      checksum: json['checksum'] as String?,
      domains: DomainCounts.fromJson(
        json['domains'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'schemaVersion': schemaVersion,
      'bundleFormat': bundleFormat,
      'lastModified': lastModified.toUtc().toIso8601String(),
      'lastModifiedBy': lastModifiedBy,
      'recipeCount': recipeCount,
      if (checksum != null) 'checksum': checksum,
      'domains': domains.toJson(),
    };
  }

  /// Create a new StorageMeta for a push operation
  factory StorageMeta.create({
    required String deviceName,
    required DomainCounts domains,
    String? checksum,
    String bundleFormat = 'single-file',
  }) {
    return StorageMeta(
      version: 1,
      schemaVersion: 3,
      bundleFormat: bundleFormat,
      lastModified: DateTime.now().toUtc(),
      lastModifiedBy: deviceName,
      recipeCount: domains.total,
      checksum: checksum,
      domains: domains,
    );
  }

  /// Check if remote data is newer than local timestamp
  bool isNewerThan(DateTime localTimestamp) {
    return lastModified.isAfter(localTimestamp);
  }

  @override
  String toString() {
    return 'StorageMeta(version: $version, lastModified: $lastModified, '
        'recipeCount: $recipeCount, by: $lastModifiedBy)';
  }
}

/// Recipe counts per domain (for quick reference without downloading full bundle)
class DomainCounts {
  final int recipes;
  final int pizzas;
  final int sandwiches;
  final int cheeses;
  final int cellar;
  final int smoking;
  final int modernist;

  const DomainCounts({
    this.recipes = 0,
    this.pizzas = 0,
    this.sandwiches = 0,
    this.cheeses = 0,
    this.cellar = 0,
    this.smoking = 0,
    this.modernist = 0,
  });

  /// Total count across all domains
  int get total =>
      recipes + pizzas + sandwiches + cheeses + cellar + smoking + modernist;

  /// Create from JSON map
  factory DomainCounts.fromJson(Map<String, dynamic> json) {
    return DomainCounts(
      recipes: json['recipes'] as int? ?? 0,
      pizzas: json['pizzas'] as int? ?? 0,
      sandwiches: json['sandwiches'] as int? ?? 0,
      cheeses: json['cheeses'] as int? ?? 0,
      cellar: json['cellar'] as int? ?? 0,
      smoking: json['smoking'] as int? ?? 0,
      modernist: json['modernist'] as int? ?? 0,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'recipes': recipes,
      'pizzas': pizzas,
      'sandwiches': sandwiches,
      'cheeses': cheeses,
      'cellar': cellar,
      'smoking': smoking,
      'modernist': modernist,
    };
  }

  @override
  String toString() {
    return 'DomainCounts(recipes: $recipes, pizzas: $pizzas, '
        'sandwiches: $sandwiches, cheeses: $cheeses, cellar: $cellar, '
        'smoking: $smoking, modernist: $modernist, total: $total)';
  }
}
