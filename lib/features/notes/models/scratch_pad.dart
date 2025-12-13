import 'package:isar/isar.dart';

part 'scratch_pad.g.dart';

/// Persisted scratch pad data including quick notes and recipe drafts
@collection
class ScratchPad {
  Id id = Isar.autoIncrement;

  /// Quick notes text content
  String quickNotes = '';

  /// Last updated timestamp
  DateTime updatedAt = DateTime.now();
}

/// Persisted temporary recipe draft
@collection
class RecipeDraft {
  Id id = Isar.autoIncrement;

  /// Unique identifier for the draft
  @Index(unique: true, replace: true)
  late String uuid;

  /// Recipe name
  String name = '';

  /// Local image path
  String? imagePath;

  /// Number of servings
  String? serves;

  /// Cooking time
  String? time;

  /// Raw ingredients text (one per line)
  String ingredients = '';

  /// Raw directions text (steps separated by blank lines)
  String directions = '';

  /// Additional comments/notes
  String comments = '';

  /// When the draft was created
  DateTime createdAt = DateTime.now();

  /// When the draft was last updated
  DateTime updatedAt = DateTime.now();
}
