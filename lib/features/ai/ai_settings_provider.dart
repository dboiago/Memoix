import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_settings.dart';
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

    if (raw == null) return;

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      state = AiSettings.fromJson(json);
    } catch (_) {
      // If something goes wrong, fall back to defaults
      state = AiSettings.defaults();
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
      autoSelect: state.autoSelect,
    );

    await _save();
  }

  /// Set preferred provider (used when autoSelect = false)
  Future<void> setPreferredProvider(AiProvider provider) async {
    state = AiSettings(
      providers: state.providers,
      preferredProvider: provider,
      autoSelect: state.autoSelect,
    );

    await _save();
  }

  /// Toggle auto-selection
  Future<void> setAutoSelect(bool value) async {
    state = AiSettings(
      providers: state.providers,
      preferredProvider: state.preferredProvider,
      autoSelect: value,
    );

    await _save();
  }

  /// Update API key or provider config
  Future<void> updateProviderConfig(
    AiProvider provider,
    AiProviderConfig config,
  ) async {
    state = AiSettings(
      providers: {
        ...state.providers,
        provider: config,
      },
      preferredProvider: state.preferredProvider,
      autoSelect: state.autoSelect,
    );

    await _save();
  }
}
