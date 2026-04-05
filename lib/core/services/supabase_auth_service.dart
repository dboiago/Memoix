import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Auth service for the invite-only sync feature.
///
/// All methods are static and never throw — errors are logged via [debugPrint]
/// and the app continues normally. Guards against Supabase not being
/// initialized (e.g. when keys are absent from .env).
abstract class SupabaseAuthService {
  SupabaseAuthService._();

  // Cached group UUID fetched from memoix.group_members.
  // Cleared on sign-in and sign-out to force a fresh fetch.
  static String? _cachedGroupId;

  // ─────────────────────────────────────────────────────────────────────
  // Internal helpers
  // ─────────────────────────────────────────────────────────────────────

  static SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      // Supabase not initialized — keys were absent at startup.
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // Public API
  // ─────────────────────────────────────────────────────────────────────

  /// Signs in with [email] and [password].
  ///
  /// Returns `true` on success, `false` on any error.
  static Future<bool> signIn(String email, String password) async {
    _cachedGroupId = null; // invalidate cached group on new sign-in attempt
    try {
      final client = _client;
      if (client == null) {
        debugPrint('SupabaseAuthService.signIn: Supabase not initialized.');
        return false;
      }
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response.session != null;
    } catch (e) {
      debugPrint('SupabaseAuthService.signIn error: $e');
      return false;
    }
  }

  /// Signs out the current session.
  ///
  /// Never throws.
  static Future<void> signOut() async {
    _cachedGroupId = null;
    try {
      final client = _client;
      if (client == null) return;
      await client.auth.signOut();
    } catch (e) {
      debugPrint('SupabaseAuthService.signOut error: $e');
    }
  }

  /// Returns `true` if there is a current active session.
  static bool get isSignedIn {
    try {
      return _client?.auth.currentSession != null;
    } catch (_) {
      return false;
    }
  }

  /// Returns the current user's ID, or `null` if not signed in.
  static String? get currentUserId {
    try {
      return _client?.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  /// Returns the current user's group UUID from `memoix.group_members`.
  ///
  /// The result is cached after the first successful fetch so subsequent
  /// calls do not hit the network. Returns `null` if not signed in, the
  /// user has no group, or any error occurs.
  static Future<String?> get groupId async {
    if (_cachedGroupId != null) return _cachedGroupId;

    final uid = currentUserId;
    if (uid == null) return null;

    try {
      final client = _client;
      if (client == null) return null;

      final result = await client
          .schema('memoix')
          .from('group_members')
          .select('group_id')
          .eq('user_id', uid)
          .maybeSingle();

      final id = result?['group_id'] as String?;
      if (id != null && id.isNotEmpty) {
        _cachedGroupId = id;
      }
      return _cachedGroupId;
    } catch (e) {
      debugPrint('SupabaseAuthService.groupId error: $e');
      return null;
    }
  }
}
