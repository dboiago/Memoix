enum AiProvider {
  memoix,
  openai,
  claude,
  gemini,
}

/// Available models per provider.
///
/// Models are ordered from most capable / recommended to least.
/// The first entry in each list is the default.
const Map<AiProvider, List<String>> aiProviderModels = {
  AiProvider.memoix: [],
  AiProvider.openai: [
    'gpt-5.5',
    'gpt-5.4',
    'gpt-5.4-mini',
    'gpt-5.4-nano',
  ],
  AiProvider.claude: [
    'claude-sonnet-4-20250514',
    'claude-3-7-sonnet-20250219',
    'claude-3-5-sonnet-20241022',
    'claude-3-5-haiku-20241022',
  ],
  AiProvider.gemini: [
    'gemini-2.5-flash-lite',
    'gemini-2.5-flash',
    'gemini-2.5-flash-preview-05-20',
    'gemini-2.5-pro-preview-05-06',
  ],
};

/// Returns the default model for the given provider.
/// Returns an empty string for providers with no available models.
String defaultModelFor(AiProvider provider) {
  final models = aiProviderModels[provider];
  if (models == null || models.isEmpty) return '';
  return models.first;
}
