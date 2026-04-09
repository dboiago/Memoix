/// Extracts unique non-null, non-empty string values from [items] using the
/// scalar [selector]. Returns a sorted list.
List<String> extractUniqueStrings<T>(
  List<T> items,
  String? Function(T) selector,
) {
  final result = <String>{};
  for (final item in items) {
    final value = selector(item);
    if (value != null && value.isNotEmpty) result.add(value);
  }
  return result.toList()..sort();
}

/// Extracts unique strings from the list-valued [selector] applied to each
/// element of [items]. Returns a sorted list.
List<String> extractUniqueStringLists<T>(
  List<T> items,
  Iterable<String> Function(T) selector,
) {
  final result = <String>{};
  for (final item in items) {
    result.addAll(selector(item));
  }
  return result.toList()..sort();
}
