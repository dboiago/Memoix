/// Abstract interface for cloud storage providers
/// 
/// Defines the contract that all cloud storage implementations must follow.
/// This enables multi-provider support (Google Drive, OneDrive, etc.)
abstract class CloudStorageProvider {
  /// Initialize the provider (restore previous session if available)
  Future<void> init();

  /// Sign in to the cloud storage provider
  Future<void> signIn();

  /// Sign out from the cloud storage provider
  Future<void> signOut();

  /// Check if user is currently connected to the provider
  Future<bool> get isConnected;

  /// Sync recipes (push local data to cloud)
  Future<void> syncRecipes();

  /// Create a new folder/repository in the cloud storage
  /// Returns the folder ID
  Future<String> createFolder(String name);

  /// Switch the active repository to a different folder
  Future<void> switchRepository(String folderId, String name);
}
