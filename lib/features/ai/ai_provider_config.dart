class AiProviderConfig {
  final bool enabled;
  final String? apiKey;
  final String? defaultModel;
  final DateTime? validatedAt;

  const AiProviderConfig({
    required this.enabled,
    this.apiKey,
    this.defaultModel,
    this.validatedAt,
  });

  bool get isConfigured => enabled && apiKey != null;

  factory AiProviderConfig.fromJson(Map<String, dynamic> json) {
    return AiProviderConfig(
      enabled: json['enabled'] ?? false,
      apiKey: json['apiKey'],
      defaultModel: json['defaultModel'],
      validatedAt: json['validatedAt'] != null
          ? DateTime.parse(json['validatedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        if (apiKey != null) 'apiKey': apiKey,
        if (defaultModel != null) 'defaultModel': defaultModel,
        if (validatedAt != null)
          'validatedAt': validatedAt!.toIso8601String(),
      };
}
