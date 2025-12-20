import 'dart:async';
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

  /// Active timer for auto-dismiss (cancelled when new snackbar shown)
  static Timer? _dismissTimer;

  /// Default duration for simple messages
  static const Duration defaultDuration = Duration(seconds: 2);

  /// Duration for messages with action buttons (slightly longer to allow tap)
  static const Duration actionDuration = Duration(seconds: 2);

  /// Cancel any pending dismiss timer
  static void _cancelTimer() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
  }

  /// Start auto-dismiss timer
  static void _startDismissTimer(Duration duration) {
    _cancelTimer();
    _dismissTimer = Timer(duration, () {
      rootScaffoldMessengerKey.currentState?.hideCurrentSnackBar();
    });
  }

  /// Show a simple message SnackBar
  static void show(String message) {
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;
    _cancelTimer();
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
    _cancelTimer();
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: actionDuration,
        showCloseIcon: false,
        action: SnackBarAction(
          label: actionLabel,
          onPressed: () {
            _cancelTimer();
            onAction();
          },
        ),
      ),
    );
    _startDismissTimer(actionDuration);
  }

  /// Show a "logged cook" SnackBar with Stats action
  /// Common pattern used across all detail screens
  static void showLoggedCook({
    required String recipeName,
    required VoidCallback onViewStats,
  }) {
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;
    _cancelTimer();
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Logged cook for $recipeName'),
        duration: actionDuration,
        showCloseIcon: false,
        action: SnackBarAction(
          label: 'Stats',
          onPressed: () {
            _cancelTimer();
            onViewStats();
          },
        ),
      ),
    );
    _startDismissTimer(actionDuration);
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
    _cancelTimer();
    messenger.clearSnackBars();
    final dur = duration ?? actionDuration;
    messenger.showSnackBar(
      SnackBar(
        content: Text('$itemName saved'),
        duration: dur,
        showCloseIcon: false,
        action: SnackBarAction(
          label: actionLabel,
          onPressed: () {
            _cancelTimer();
            onView();
          },
        ),
      ),
    );
    _startDismissTimer(dur);
  }

  /// Show an error message
  static void showError(String message) {
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;
    _cancelTimer();
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
    _cancelTimer();
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: defaultDuration,
      ),
    );
  }

  /// Show a persistent alarm notification with Done and View buttons
  /// This snackbar does NOT auto-dismiss - user must interact with it
  /// Format: "<TimerName> [Done]       View"
  static void showAlarm({
    required String timerLabel,
    required VoidCallback onDismiss,
    required VoidCallback onGoToAlarm,
  }) {
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;
    _cancelTimer(); // Don't auto-dismiss alarms
    messenger.clearSnackBars();
    
    // Get the snackbar action color from theme (same as SnackBarAction uses)
    final context = rootNavigatorKey.currentContext;
    final actionColor = context != null 
        ? Theme.of(context).colorScheme.inversePrimary
        : Colors.lightBlueAccent;
    
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Expanded(
              child: Text(
                timerLabel.isNotEmpty ? timerLabel : 'Timer',
              ),
            ),
            TextButton(
              onPressed: () {
                messenger.hideCurrentSnackBar();
                onDismiss();
              },
              style: TextButton.styleFrom(
                foregroundColor: actionColor,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Done'),
            ),
          ],
        ),
        duration: const Duration(days: 1), // Effectively infinite
        behavior: SnackBarBehavior.floating,
        showCloseIcon: false,
        action: SnackBarAction(
          label: 'View',
          onPressed: () {
            messenger.hideCurrentSnackBar();
            onGoToAlarm();
          },
        ),
      ),
    );
  }

  /// Clear any visible SnackBars
  static void clear() {
    _cancelTimer();
    rootScaffoldMessengerKey.currentState?.clearSnackBars();
  }
}
