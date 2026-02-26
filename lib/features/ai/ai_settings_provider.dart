import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_settings.dart';
import 'ai_provider_config.dart';
import 'services/ai_key_storage.dart';
import '../import/ai/ai_provider.dart';

/// Riverpod provider
final aiSettingsProvider =
    StateNotifierProvider<AiSettingsNotifier, AiSettings>((ref) {
  return AiSettingsNotifier();
});

class AiSettingsNotifier extends StateNotifier<AiSettings> {
  static const _prefsKey = 'ai_settings';

  AiSettingsNotifier() : super(AiSettings.defaults()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);

    AiSettings loaded;
    if (raw == null) {
      loaded = AiSettings.defaults();
    } else {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        loaded = AiSettings.fromJson(json);
      } catch (_) {
        loaded = AiSettings.defaults();
      }
    }

    // Migrate: if legacy JSON contained plain-text apiKey values,
    // move them into secure storage and strip them from SharedPreferences.
    var migrated = false;
    final migratedProviders = <AiProvider, AiProviderConfig>{};

    for (final provider in AiProvider.values) {
      var config = loaded.configFor(provider);

      // Check if secure storage actually has a key
      final hasKey = await AiKeyStorage.hasToken(provider);

      // Legacy migration: the old JSON format stored 'apiKey' inline.
      // If we detect a key in the parsed config but secure storage is empty,
      // move it across.
      if (!hasKey && raw != null) {
        try {
          final jsonMap = jsonDecode(raw) as Map<String, dynamic>;
          final providersMap =
              jsonMap['providers'] as Map<String, dynamic>? ?? {};
          final pJson = providersMap[provider.name] as Map<String, dynamic>?;
          if (pJson != null) {
            final legacyKey = pJson['apiKey'] as String?;
            if (legacyKey != null && legacyKey.isNotEmpty) {
              await AiKeyStorage.saveToken(provider, legacyKey);
              config = config.copyWith(hasKeyStored: true);
              migrated = true;
            }
          }
        } catch (_) {
          // Ignore parse errors during migration
        }
      } else {
        config = config.copyWith(hasKeyStored: hasKey);
      }

      migratedProviders[provider] = config;
    }

    state = loaded.copyWith(providers: migratedProviders);

    if (migrated) {
      // Re-save without legacy apiKey fields
      await _save();
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(state.toJson()),
    );
  }

  /// Enable / disable a provider
  Future<void> setProviderEnabled(AiProvider provider, bool enabled) async {
    final updatedProviders = {
      ...state.providers,
      provider: state.providers[provider]!.copyWith(enabled: enabled),
    };

    state = AiSettings(
      providers: updatedProviders,
      preferredProvider: state.preferredProvider,
      autoSelectProvider: state.autoSelectProvider,
    );

    await _save();
  }

  /// Set preferred provider (used when autoSelectProvider = false)
  Future<void> setPreferredProvider(AiProvider provider) async {
    state = AiSettings(
      providers: state.providers,
      preferredProvider: provider,
      autoSelectProvider: state.autoSelectProvider,
    );

    await _save();
  }

  /// Toggle auto-selection
  Future<void> setAutoSelectProvider(bool value) async {
    state = AiSettings(
      providers: state.providers,
      preferredProvider: state.preferredProvider,
      autoSelectProvider: value,
    );

    await _save();
  }

  /// Save or update the API key for [provider] in secure storage,
  /// then update the in-memory state.
  Future<void> setApiKey(AiProvider provider, String key) async {
    if (key.trim().isEmpty) {
      await clearApiKey(provider);
      return;
    }

    await AiKeyStorage.saveToken(provider, key.trim());

    final updatedConfig =
        state.configFor(provider).copyWith(hasKeyStored: true);

    state = state.copyWith(providers: {
      ...state.providers,
      provider: updatedConfig,
    });

    await _save();
  }

  /// Remove the API key for [provider].
  Future<void> clearApiKey(AiProvider provider) async {
    await AiKeyStorage.clearToken(provider);

    final updatedConfig =
        state.configFor(provider).copyWith(hasKeyStored: false, enabled: false);

    state = state.copyWith(providers: {
      ...state.providers,
      provider: updatedConfig,
    });

    await _save();
  }

  /// Set the selected model for [provider].
  Future<void> setModel(AiProvider provider, String? model) async {
    final updated = model == null
        ? state.configFor(provider).copyWith(clearModel: true)
        : state.configFor(provider).copyWith(selectedModel: model);

    state = state.copyWith(providers: {
      ...state.providers,
      provider: updated,
    });

    await _save();
  }

  /// Whether at least one provider is enabled and has a key.
  bool get hasActiveProvider => state.activeProviders.isNotEmpty;
}
