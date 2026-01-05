import '../models/recipe_bundle.dart';
import '../models/storage_meta.dart';

/// Abstract interface for external storage providers
/// 
/// Each provider (Google Drive, GitHub, iCloud) implements this interface.
/// See EXTERNAL_STORAGE.md Section 2.2 for capability flags.
abstract class ExternalStorageProvider {
  /// Provider display name (e.g., "Google Drive")
  String get name;

  /// Provider identifier for persistence (e.g., "google_drive")
  String get id;

  /// Whether this provider supports automatic sync mode
  /// Disable Automatic Mode option for providers where this is false.
  bool get supportsAutomaticSync;

  /// Whether this provider can check remote meta cheaply (without full download)
  /// Skip remote meta check on pull for providers where this is false.
  bool get supportsFastMetaCheck;

  /// Whether writes to this provider are atomic
  bool get supportsAtomicWrites;

  /// Whether this provider supports folder organization
  bool get supportsFolders;

  /// Whether this provider requires technical knowledge
  /// Show "Advanced" badge and warnings for providers where this is true.
  bool get isAdvanced;

  /// Whether currently connected/authenticated
  bool get isConnected;

  /// Display path of connected storage location (e.g., "/My Drive/Memoix")
  String? get connectedPath;

  /// Connect to the provider (OAuth flow or native auth)
  /// Returns true if connection was successful.
  Future<bool> connect();

  /// Disconnect from the provider
  /// Clears stored credentials but does not delete remote data.
  Future<void> disconnect();

  /// Push a recipe bundle to remote storage
  /// Overwrites existing files.
  Future<void> push(RecipeBundle bundle);

  /// Pull recipe bundle from remote storage
  /// Returns null if no data exists at the location.
  Future<RecipeBundle?> pull();

  /// Get metadata from remote storage (for smart sync decisions)
  /// Returns null if meta file doesn't exist.
  Future<StorageMeta?> getMeta();

  /// Update the remote meta file after push
  Future<void> updateMeta(StorageMeta meta);
}

/// Provider capability summary for UI decisions
class ProviderCapabilities {
  final bool supportsAutomaticSync;
  final bool supportsFastMetaCheck;
  final bool supportsAtomicWrites;
  final bool supportsFolders;
  final bool isAdvanced;

  const ProviderCapabilities({
    required this.supportsAutomaticSync,
    required this.supportsFastMetaCheck,
    required this.supportsAtomicWrites,
    required this.supportsFolders,
    required this.isAdvanced,
  });

  /// Google Drive capabilities
  static const googleDrive = ProviderCapabilities(
    supportsAutomaticSync: true,
    supportsFastMetaCheck: true,
    supportsAtomicWrites: true,
    supportsFolders: true,
    isAdvanced: false,
  );

  /// GitHub capabilities
  static const github = ProviderCapabilities(
    supportsAutomaticSync: false,
    supportsFastMetaCheck: false,
    supportsAtomicWrites: false,
    supportsFolders: true,
    isAdvanced: true,
  );

  /// iCloud capabilities
  static const icloud = ProviderCapabilities(
    supportsAutomaticSync: true,
    supportsFastMetaCheck: false, // Partial support
    supportsAtomicWrites: false,  // Partial support
    supportsFolders: true,
    isAdvanced: false,
  );
}
