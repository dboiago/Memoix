import 'ai_provider_config.dart';
import '../import/ai/ai_provider.dart';

class AiSettings {
  final Map<AiProvider, AiProviderConfig> providers;

  factory AiSettings.defaults() => const AiSettings(providers: {});
  
  /// Sticky preference
  final bool autoSelectProvider;
  final AiProvider? preferredProvider;

  const AiSettings({
    required this.providers,
    this.autoSelectProvider = true,
    this.preferredProvider,
  });

  AiProviderConfig configFor(AiProvider provider) {
    return providers[provider] ??
        AiProviderConfig(provider: provider);
  }

  List<AiProviderConfig> get activeProviders =>
      providers.values.where((p) => p.isActive).toList();

  AiSettings copyWith({
    Map<AiProvider, AiProviderConfig>? providers,
    bool? autoSelectProvider,
    AiProvider? preferredProvider,
  }) {
    return AiSettings(
      providers: providers ?? this.providers,
      autoSelectProvider: autoSelectProvider ?? this.autoSelectProvider,
      preferredProvider: preferredProvider ?? this.preferredProvider,
    );
  }

  Map<String, dynamic> toJson() => {
        'autoSelectProvider': autoSelectProvider,
        'preferredProvider': preferredProvider?.name,
        'providers': providers.map(
          (key, value) => MapEntry(key.name, value.toJson()),
        ),
      };

  static AiSettings fromJson(Map<String, dynamic> json) {
    final providersJson = json['providers'] as Map<String, dynamic>? ?? {};

    final providers = <AiProvider, AiProviderConfig>{};

    for (final entry in providersJson.entries) {
      final provider = AiProvider.values.firstWhere(
        (e) => e.name == entry.key,
      );
      providers[provider] =
          AiProviderConfig.fromJson(entry.value);
    }

    return AiSettings(
      autoSelectProvider: json['autoSelectProvider'] ?? true,
      preferredProvider: json['preferredProvider'] != null
          ? AiProvider.values.firstWhere(
              (e) => e.name == json['preferredProvider'],
            )
          : null,
      providers: providers,
    );
  }

  static AiSettings empty() => const AiSettings(providers: {});
}
