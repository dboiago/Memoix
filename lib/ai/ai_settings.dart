class AiSettings {
  final Map<AiProvider, AiProviderConfig> providers;
  final AiProvider preferredProvider;
  final bool autoSelect;

  const AiSettings({
    required this.providers,
    required this.preferredProvider,
    required this.autoSelect,
  });

  factory AiSettings.defaults() {
    return AiSettings(
      providers: {
        for (final p in AiProvider.values)
          p: const AiProviderConfig(enabled: false),
      },
      preferredProvider: AiProvider.openai,
      autoSelect: true,
    );
  }

  factory AiSettings.fromJson(Map<String, dynamic> json) {
    return AiSettings(
      providers: {
        for (final p in AiProvider.values)
          p: AiProviderConfig.fromJson(json[p.name] ?? {}),
      },
      preferredProvider: AiProvider.values.firstWhere(
        (p) => p.name == json['preferredProvider'],
        orElse: () => AiProvider.openai,
      ),
      autoSelect: json['autoSelect'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        for (final entry in providers.entries)
          entry.key.name: entry.value.toJson(),
        'preferredProvider': preferredProvider.name,
        'autoSelect': autoSelect,
      };
}
