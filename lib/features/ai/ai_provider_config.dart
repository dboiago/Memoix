import '../import/ai/ai_provider.dart';

class AiProviderConfig {
  final AiProvider provider;
  final String? apiKey;
  final bool enabled;
  final DateTime? validatedAt;

  const AiProviderConfig({
    required this.provider,
    this.apiKey,
    this.enabled = false,
    this.validatedAt,
  });

  bool get isConfigured => apiKey != null && apiKey!.isNotEmpty;
  bool get isActive => enabled && isConfigured;

  AiProviderConfig copyWith({
    String? apiKey,
    bool? enabled,
    DateTime? validatedAt,
  }) {
    return AiProviderConfig(
      provider: provider,
      apiKey: apiKey ?? this.apiKey,
      enabled: enabled ?? this.enabled,
      validatedAt: validatedAt ?? this.validatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'provider': provider.name,
        'apiKey': apiKey,
        'enabled': enabled,
        'validatedAt': validatedAt?.toIso8601String(),
      };

  static AiProviderConfig fromJson(Map<String, dynamic> json) {
    return AiProviderConfig(
      provider: AiProvider.values.firstWhere(
        (e) => e.name == json['provider'],
      ),
      apiKey: json['apiKey'],
      enabled: json['enabled'] ?? false,
      validatedAt: json['validatedAt'] != null
          ? DateTime.parse(json['validatedAt'])
          : null,
    );
  }
}
