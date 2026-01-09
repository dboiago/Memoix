/// Result of merging a pulled bundle into local database
/// 
/// Tracks counts of added, updated, and unchanged items per domain.
class MergeResult {
  /// Number of new items added (by UUID not existing locally)
  final int added;

  /// Number of existing items updated (remote was newer)
  final int updated;

  /// Number of items unchanged (local was same or newer)
  final int unchanged;

  /// Optional error message if merge failed
  final String? error;

  const MergeResult({
    this.added = 0,
    this.updated = 0,
    this.unchanged = 0,
    this.error,
  });

  /// Create a skipped result (no merge performed)
  factory MergeResult.skipped() {
    return const MergeResult();
  }

  /// Create a failed result with error message
  factory MergeResult.failed(Object error) {
    return MergeResult(error: error.toString());
  }

  /// Total items processed
  int get total => added + updated + unchanged;

  /// Whether any items were added or updated
  bool get hasChanges => added > 0 || updated > 0;

  /// Whether the merge failed
  bool get hasFailed => error != null;

  /// Whether the merge was successful
  bool get isSuccess => error == null;

  /// Combine two merge results (for aggregating across domains)
  MergeResult operator +(MergeResult other) {
    if (error != null) return this;
    if (other.error != null) return other;
    
    return MergeResult(
      added: added + other.added,
      updated: updated + other.updated,
      unchanged: unchanged + other.unchanged,
    );
  }

  /// User-friendly summary message
  String get summaryMessage {
    if (hasFailed) return 'Sync failed: $error';
    if (!hasChanges) return 'Everything up to date';
    
    final parts = <String>[];
    if (added > 0) parts.add('$added added');
    if (updated > 0) parts.add('$updated updated');
    return parts.join(', ');
  }

  @override
  String toString() {
    if (hasFailed) return 'MergeResult.failed($error)';
    return 'MergeResult(added: $added, updated: $updated, unchanged: $unchanged)';
  }
}

/// Result of a pull operation
/// 
/// Extends MergeResult with additional pull-specific metadata.
class PullResult extends MergeResult {
  /// Whether the pull was skipped (e.g., already up to date)
  final bool wasSkipped;

  /// Remote recipe count before merge
  final int remoteCount;

  const PullResult({
    super.added = 0,
    super.updated = 0,
    super.unchanged = 0,
    super.error,
    this.wasSkipped = false,
    this.remoteCount = 0,
  });

  /// Create a skipped result
  factory PullResult.skipped() {
    return const PullResult(wasSkipped: true);
  }

  /// Create a failed result
  factory PullResult.failed(Object error) {
    return PullResult(error: error.toString());
  }

  /// Create from a merge result
  factory PullResult.fromMerge(MergeResult merge, {int remoteCount = 0}) {
    return PullResult(
      added: merge.added,
      updated: merge.updated,
      unchanged: merge.unchanged,
      error: merge.error,
      remoteCount: remoteCount,
    );
  }

  @override
  String toString() {
    if (wasSkipped) return 'PullResult.skipped()';
    if (hasFailed) return 'PullResult.failed($error)';
    return 'PullResult(added: $added, updated: $updated, unchanged: $unchanged, '
        'remoteCount: $remoteCount)';
  }
}
