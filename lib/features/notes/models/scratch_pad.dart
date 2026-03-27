


/// Embedded ingredient for recipe drafts
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
