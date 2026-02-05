import 'package:flutter/foundation.dart'; // For ChangeNotifier
import 'ai_provider_config.dart';
import '../import/ai/ai_provider.dart'; 
import '../import/ai/ai_recipe_importer.dart';
import '../import/ai/openai_client.dart';
import '../import/ai/claude_client.dart';
import '../import/ai/gemini_client.dart';

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

class AiSettingsRepository {
  static const _key = 'ai_settings';

  final SettingsStore store; // whatever you already use

  AiSettingsRepository(this.store);

  AiSettings load() {
    final json = store.getJson(_key);
    if (json == null) return AiSettings.empty();
    return AiSettings.fromJson(json);
  }

  Future<void> save(AiSettings settings) {
    return store.setJson(_key, settings.toJson());
  }
}

class AiSettingsNotifier extends ChangeNotifier {
  final AiSettingsRepository repo;

  late AiSettings _settings;

  AiSettingsNotifier(this.repo) {
    _settings = repo.load();
  }

  AiSettings get settings => _settings;

  void updateProvider(AiProviderConfig config) {
    final updated = Map<AiProvider, AiProviderConfig>.from(
      _settings.providers,
    )..[config.provider] = config;

    _settings = _settings.copyWith(providers: updated);
    repo.save(_settings);
    notifyListeners();
  }

  void setAutoSelect(bool value) {
    _settings = _settings.copyWith(autoSelectProvider: value);
    repo.save(_settings);
    notifyListeners();
  }

  void setPreferredProvider(AiProvider? provider) {
    _settings = _settings.copyWith(preferredProvider: provider);
    repo.save(_settings);
    notifyListeners();
  }
}

AiRecipeImporter fromSettings(AiSettings settings) {
  return AiRecipeImporter(
    openAi: OpenAiClient(settings.configFor(AiProvider.openai).apiKey!),
    claude: ClaudeClient(settings.configFor(AiProvider.claude).apiKey!),
    gemini: GeminiClient(settings.configFor(AiProvider.gemini).apiKey!),
    defaultProvider:
        settings.preferredProvider ?? AiProvider.openai,
    autoSelect: settings.autoSelectProvider,
  );
}

