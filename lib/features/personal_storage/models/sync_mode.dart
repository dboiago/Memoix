/// Sync behavior mode for external storage
/// 
/// See EXTERNAL_STORAGE.md Section 4 for details.
enum SyncMode {
  /// User explicitly taps Push or Pull buttons. No automatic operations.
  /// Best for: Users who want full control, multiple devices, limited data plans.
  manual,

  /// Push/pull operations triggered at specific app lifecycle events.
  /// Best for: Users with one primary device who want "it just works" behavior.
  automatic,
}

extension SyncModeExtension on SyncMode {
  /// Human-readable name
  String get displayName {
    switch (this) {
      case SyncMode.manual:
        return 'Manual';
      case SyncMode.automatic:
        return 'Automatic';
    }
  }

  /// Description for UI
  String get description {
    switch (this) {
      case SyncMode.manual:
        return 'Only sync when you tap Push or Pull.';
      case SyncMode.automatic:
        return 'Sync when you open the app or save a recipe.';
    }
  }

  /// Whether this mode is the default
  bool get isDefault => this == SyncMode.manual;
}
