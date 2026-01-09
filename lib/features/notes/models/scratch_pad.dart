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

/// Embedded ingredient for recipe drafts
@embedded
class DraftIngredient {
  String name = '';
  String? quantity;
  String? unit;
  String? preparation;

  DraftIngredient({
    this.name = '',
    this.quantity,
    this.unit,
    this.preparation,
  });

  /// Format as display string
  String toDisplayString() {
    final parts = <String>[];
    if (quantity != null && quantity!.isNotEmpty) parts.add(quantity!);
    if (unit != null && unit!.isNotEmpty) parts.add(unit!);
    parts.add(name);
    if (preparation != null && preparation!.isNotEmpty) {
      parts.add('($preparation)');
    }
    return parts.join(' ');
  }
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

  /// Structured ingredients (new format)
  List<DraftIngredient> structuredIngredients = [];

  /// Structured directions (new format)
  List<String> structuredDirections = [];

  /// Legacy raw ingredients text (for backward compatibility)
  /// Will be migrated to structuredIngredients on first load
  String? legacyIngredients;

  /// Legacy raw directions text (for backward compatibility)
  /// Will be migrated to structuredDirections on first load
  String? legacyDirections;

  /// Freeform notes section
  String notes = '';

  /// When the draft was created
  DateTime createdAt = DateTime.now();

  /// When the draft was last updated
  DateTime updatedAt = DateTime.now();

  /// Helper getters for backward compatibility with existing UI code
  @ignore
  String get ingredients {
    // If we have structured ingredients, convert them to text
    if (structuredIngredients.isNotEmpty) {
      return structuredIngredients
          .map((i) => i.toDisplayString())
          .join('\n');
    }
    // Otherwise return legacy text
    return legacyIngredients ?? '';
  }

  /// Helper setter for backward compatibility - writes to legacy field
  @ignore
  set ingredients(String value) {
    legacyIngredients = value;
    // Clear structured data when writing raw text
    structuredIngredients = [];
  }

  @ignore
  String get directions {
    // If we have structured directions, convert them to text
    if (structuredDirections.isNotEmpty) {
      return structuredDirections.join('\n\n');
    }
    // Otherwise return legacy text
    return legacyDirections ?? '';
  }

  /// Helper setter for backward compatibility - writes to legacy field
  @ignore
  set directions(String value) {
    legacyDirections = value;
    // Clear structured data when writing raw text
    structuredDirections = [];
  }

  /// Helper getter/setter for comments field (renamed to notes)
  @ignore
  String get comments => notes;

  @ignore
  set comments(String value) {
    notes = value;
  }
}
