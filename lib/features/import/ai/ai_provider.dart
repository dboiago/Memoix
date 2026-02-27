enum AiProvider {
  openai,
  claude,
  gemini,
}

/// Available models per provider.
///
/// Models are ordered from most capable / recommended to least.
/// The first entry in each list is the default.
const Map<AiProvider, List<String>> aiProviderModels = {
  AiProvider.openai: [
    'gpt-4.1',
    'gpt-4.1-mini',
    'gpt-4.1-nano',
    'gpt-4o',
    'gpt-4o-mini',
    'o3-mini',
  ],
  AiProvider.claude: [
    'claude-sonnet-4-20250514',
    'claude-3-7-sonnet-20250219',
    'claude-3-5-sonnet-20241022',
    'claude-3-5-haiku-20241022',
  ],
  AiProvider.gemini: [
    'gemini-2.5-flash-lite',
    'gemini-2.0-flash',
    'gemini-2.5-flash-preview-05-20',
    'gemini-2.5-pro-preview-05-06',
    'gemini-1.5-pro',
    'gemini-1.5-flash',
  ],
};

/// Returns the default model for the given provider.
String defaultModelFor(AiProvider provider) =>
    aiProviderModels[provider]!.first;
