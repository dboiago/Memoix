import 'package:flutter/material.dart';
import '../../app/app.dart';

/// Centralized SnackBar helper for consistent behavior across the app.
/// 
/// All SnackBars shown through this helper will:
/// - Use the global ScaffoldMessenger (survives navigation)
/// - Clear any existing SnackBars before showing
/// - Auto-dismiss after a short duration
/// - Have consistent styling from the theme
class MemoixSnackBar {
  MemoixSnackBar._();

  /// Default duration for simple messages
  static const Duration defaultDuration = Duration(seconds: 2);

  /// Duration for messages with action buttons (slightly longer to allow tap)
  static const Duration actionDuration = Duration(seconds: 4);

  /// Show a simple message SnackBar
  static void show(String message) {
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: defaultDuration,
      ),
    );
  }

  /// Show a SnackBar with an action button
  static void showWithAction({
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: actionDuration,
        showCloseIcon: false,
        action: SnackBarAction(
          label: actionLabel,
          onPressed: onAction,
        ),
      ),
    );
  }

  /// Show a "logged cook" SnackBar with Stats action
  /// Common pattern used across all detail screens
  static void showLoggedCook({
    required String recipeName,
    required VoidCallback onViewStats,
  }) {
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Logged cook for $recipeName'),
        duration: actionDuration,
        showCloseIcon: false,
        action: SnackBarAction(
          label: 'Stats',
          onPressed: onViewStats,
        ),
      ),
    );
  }

  /// Show a "saved" SnackBar with View action
  /// Common pattern used after saving/editing items
  static void showSaved({
    required String itemName,
    required String actionLabel,
    required VoidCallback onView,
    Duration? duration,
  }) {
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text('$itemName saved'),
        duration: duration ?? actionDuration,
        showCloseIcon: false,
        action: SnackBarAction(
          label: actionLabel,
          onPressed: onView,
        ),
      ),
    );
  }

  /// Show an error message
  static void showError(String message) {
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: actionDuration,
      ),
    );
  }

  /// Show a success message
  static void showSuccess(String message) {
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: defaultDuration,
      ),
    );
  }

  /// Clear any visible SnackBars
  static void clear() {
    rootScaffoldMessengerKey.currentState?.clearSnackBars();
  }
}
