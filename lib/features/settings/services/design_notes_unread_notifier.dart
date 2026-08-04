import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final designNotesLastSeenVersionProvider =
    StateNotifierProvider<DesignNotesLastSeenVersionNotifier, int?>((ref) {
  return DesignNotesLastSeenVersionNotifier();
});

class DesignNotesLastSeenVersionNotifier extends StateNotifier<int?> {
  static const _key = 'last_seen_design_notes_version';
  final _loadCompleter = Completer<void>();

  /// Completes when persisted state has been loaded from SharedPreferences.
  Future<void> get ready => _loadCompleter.future;

  DesignNotesLastSeenVersionNotifier() : super(null) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getInt(_key) ?? 0;
    _loadCompleter.complete();
  }

  Future<void> markAsSeen(int designNotesVersion) async {
    await ready;
    if (state == designNotesVersion) return;

    state = designNotesVersion;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, designNotesVersion);
  }
}