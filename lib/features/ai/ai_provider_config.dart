import '../import/ai/ai_provider.dart';

class AiProviderConfig {
  final AiProvider provider;

  /// Whether a key is stored in secure storage.
  ///
  /// The actual key is never held in memory beyond the HTTP request scope.
  /// Use [AiKeyStorage] to read/write keys.
  final bool hasKeyStored;

  final bool enabled;
  final DateTime? validatedAt;

  const AiProviderConfig({
    required this.provider,
    this.hasKeyStored = false,
    this.enabled = false,
    this.validatedAt,
  });

  bool get isConfigured => hasKeyStored;
  bool get isActive => enabled && isConfigured;

  AiProviderConfig copyWith({
    bool? hasKeyStored,
    bool? enabled,
    DateTime? validatedAt,
  }) {
    return AiProviderConfig(
      provider: provider,
      hasKeyStored: hasKeyStored ?? this.hasKeyStored,
      enabled: enabled ?? this.enabled,
      validatedAt: validatedAt ?? this.validatedAt,
    );
  }

  /// Serialise to JSON for SharedPreferences.
  ///
  /// The API key is **never** written here – it lives in secure storage only.
  Map<String, dynamic> toJson() => {
        'provider': provider.name,
        'hasKeyStored': hasKeyStored,
        'enabled': enabled,
        'validatedAt': validatedAt?.toIso8601String(),
      };

  static AiProviderConfig fromJson(Map<String, dynamic> json) {
    return AiProviderConfig(
      provider: AiProvider.values.firstWhere(
        (e) => e.name == json['provider'],
      ),
      // Support legacy data that stored 'apiKey' directly
      hasKeyStored: json['hasKeyStored'] ??
          (json['apiKey'] != null &&
              (json['apiKey'] as String).isNotEmpty),
      enabled: json['enabled'] ?? false,
      validatedAt: json['validatedAt'] != null
          ? DateTime.parse(json['validatedAt'])
          : null,
    );
  }
}
