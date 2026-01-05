/// Current sync operation status
/// 
/// Used for UI indicators in the app bar and settings screen.
enum SyncStatus {
  /// No sync operation in progress
  idle,

  /// Currently pushing local data to remote storage
  pushing,

  /// Currently pulling remote data to local
  pulling,

  /// Last sync operation failed
  error,
}

extension SyncStatusExtension on SyncStatus {
  /// Whether a sync operation is currently in progress
  bool get isInProgress => this == SyncStatus.pushing || this == SyncStatus.pulling;

  /// Whether the status indicates an error state
  bool get isError => this == SyncStatus.error;

  /// Whether the status is idle (no operation, no error)
  bool get isIdle => this == SyncStatus.idle;

  /// Human-readable status message
  String get displayMessage {
    switch (this) {
      case SyncStatus.idle:
        return 'Synced';
      case SyncStatus.pushing:
        return 'Pushing...';
      case SyncStatus.pulling:
        return 'Pulling...';
      case SyncStatus.error:
        return 'Sync failed';
    }
  }
}
