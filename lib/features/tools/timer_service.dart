import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Available timer alarm sounds (maps to system sounds)
enum TimerSound {
  alarm('Alarm'),
  notification('Notification'),
  ringtone('Ringtone');

  final String displayName;

  const TimerSound(this.displayName);
}

/// Individual timer data
class TimerData {
  final int id;
  Duration duration;
  String label;
  TimerSound sound;
  int remainingSeconds;
  bool isRunning;
  bool isPaused;
  bool isAlarming;

  TimerData({
    required this.id,
    required this.duration,
    required this.label,
    required this.sound,
  })  : remainingSeconds = duration.inSeconds,
        isRunning = false,
        isPaused = false,
        isAlarming = false;

  double get progress {
    if (duration.inSeconds == 0) return 1.0;
    return 1.0 - (remainingSeconds / duration.inSeconds);
  }

  TimerData copyWith({
    Duration? duration,
    String? label,
    TimerSound? sound,
    int? remainingSeconds,
    bool? isRunning,
    bool? isPaused,
    bool? isAlarming,
  }) {
    return TimerData(
      id: id,
      duration: duration ?? this.duration,
      label: label ?? this.label,
      sound: sound ?? this.sound,
    )
      ..remainingSeconds = remainingSeconds ?? this.remainingSeconds
      ..isRunning = isRunning ?? this.isRunning
      ..isPaused = isPaused ?? this.isPaused
      ..isAlarming = isAlarming ?? this.isAlarming;
  }
}

/// Global timer service state
class TimerServiceState {
  final List<TimerData> timers;
  final bool hasAlarmingTimer;

  const TimerServiceState({
    this.timers = const [],
    this.hasAlarmingTimer = false,
  });

  TimerServiceState copyWith({
    List<TimerData>? timers,
    bool? hasAlarmingTimer,
  }) {
    return TimerServiceState(
      timers: timers ?? this.timers,
      hasAlarmingTimer: hasAlarmingTimer ?? this.hasAlarmingTimer,
    );
  }
}

/// Callback type for alarm notifications
typedef AlarmCallback = void Function(TimerData timer);

/// Global timer service that persists across navigation
class TimerService extends StateNotifier<TimerServiceState> {
  TimerService() : super(const TimerServiceState());

  int _nextTimerId = 1;
  Timer? _tickTimer;
  Timer? _alarmLoopTimer;
  bool _isAlarmPlaying = false;
  
  /// Callback for when an alarm triggers (to show notification)
  AlarmCallback? onAlarmTriggered;
  
  /// Callback for when all alarms are dismissed
  VoidCallback? onAllAlarmsDismissed;

  @override
  void dispose() {
    _tickTimer?.cancel();
    _alarmLoopTimer?.cancel();
    _updateWakelock();
    super.dispose();
  }

  /// Add a new timer
  void addTimer({
    required Duration duration,
    required String label,
    required TimerSound sound,
  }) {
    final timer = TimerData(
      id: _nextTimerId++,
      duration: duration,
      label: label,
      sound: sound,
    );
    state = state.copyWith(timers: [...state.timers, timer]);
    _updateWakelock();
  }

  /// Start a timer
  void startTimer(int id) {
    final timers = state.timers.map((t) {
      if (t.id == id && !t.isRunning) {
        return t.copyWith(isRunning: true, isPaused: false, isAlarming: false);
      }
      return t;
    }).toList();
    state = state.copyWith(timers: timers);
    _ensureTickerRunning();
    _updateWakelock();
  }

  /// Pause a timer
  void pauseTimer(int id) {
    final timers = state.timers.map((t) {
      if (t.id == id && t.isRunning && !t.isPaused) {
        return t.copyWith(isPaused: true);
      }
      return t;
    }).toList();
    state = state.copyWith(timers: timers);
    _updateWakelock();
  }

  /// Resume a paused timer
  void resumeTimer(int id) {
    final timers = state.timers.map((t) {
      if (t.id == id && t.isPaused) {
        return t.copyWith(isPaused: false);
      }
      return t;
    }).toList();
    state = state.copyWith(timers: timers);
    _ensureTickerRunning();
    _updateWakelock();
  }

  /// Reset a timer to its original duration
  void resetTimer(int id) {
    final timers = state.timers.map((t) {
      if (t.id == id) {
        final wasAlarming = t.isAlarming;
        final reset = t.copyWith(
          remainingSeconds: t.duration.inSeconds,
          isRunning: false,
          isPaused: false,
          isAlarming: false,
        );
        if (wasAlarming) {
          _checkAndStopAlarm();
        }
        return reset;
      }
      return t;
    }).toList();
    state = state.copyWith(
      timers: timers,
      hasAlarmingTimer: timers.any((t) => t.isAlarming),
    );
    _updateWakelock();
  }

  /// Stop the alarm for a specific timer and stop it from running
  void stopAlarm(int id) {
    final timers = state.timers.map((t) {
      if (t.id == id && t.isAlarming) {
        // Stop alarm AND stop timer running state to prevent re-trigger
        return t.copyWith(isAlarming: false, isRunning: false, isPaused: false);
      }
      return t;
    }).toList();
    state = state.copyWith(
      timers: timers,
      hasAlarmingTimer: timers.any((t) => t.isAlarming),
    );
    _checkAndStopAlarm();
    _updateWakelock();
  }

  /// Stop all alarms
  void stopAllAlarms() {
    final timers = state.timers.map((t) {
      if (t.isAlarming) {
        return t.copyWith(isAlarming: false);
      }
      return t;
    }).toList();
    state = state.copyWith(timers: timers, hasAlarmingTimer: false);
    _stopAlarmSound();
    onAllAlarmsDismissed?.call();
    _updateWakelock();
  }

  /// Remove a timer
  void removeTimer(int id) {
    final timer = state.timers.firstWhere((t) => t.id == id, orElse: () => throw StateError('Timer not found'));
    if (timer.isAlarming) {
      _checkAndStopAlarm();
    }
    final timers = state.timers.where((t) => t.id != id).toList();
    state = state.copyWith(
      timers: timers,
      hasAlarmingTimer: timers.any((t) => t.isAlarming),
    );
    _updateWakelock();
  }

  /// Update timer settings
  void updateTimer(int id, Duration duration, String label, TimerSound sound) {
    final timers = state.timers.map((t) {
      if (t.id == id) {
        final wasAlarming = t.isAlarming;
        if (wasAlarming) {
          _checkAndStopAlarm();
        }
        return TimerData(
          id: id,
          duration: duration,
          label: label,
          sound: sound,
        );
      }
      return t;
    }).toList();
    state = state.copyWith(
      timers: timers,
      hasAlarmingTimer: timers.any((t) => t.isAlarming),
    );
    _updateWakelock();
  }

  /// Duplicate a timer
  void duplicateTimer(int id) {
    final original = state.timers.firstWhere((t) => t.id == id);
    addTimer(
      duration: original.duration,
      label: original.label.isNotEmpty ? '${original.label} (Copy)' : '',
      sound: original.sound,
    );
  }

  /// Ensure the global ticker is running
  void _ensureTickerRunning() {
    if (_tickTimer != null && _tickTimer!.isActive) return;
    
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _tick();
    });
  }

  /// Process one tick for all running timers
  void _tick() {
    bool anyRunning = false;
    bool anyNewAlarm = false;
    
    final timers = state.timers.map((t) {
      if (t.isRunning && !t.isPaused && !t.isAlarming) {
        anyRunning = true;
        if (t.remainingSeconds > 0) {
          return t.copyWith(remainingSeconds: t.remainingSeconds - 1);
        } else {
          // Timer finished - trigger alarm
          anyNewAlarm = true;
          return t.copyWith(isAlarming: true);
        }
      }
      if (t.isRunning && !t.isPaused) anyRunning = true;
      return t;
    }).toList();

    state = state.copyWith(
      timers: timers,
      hasAlarmingTimer: timers.any((t) => t.isAlarming),
    );

    if (anyNewAlarm) {
      final alarmingTimer = timers.firstWhere((t) => t.isAlarming);
      _playAlarmSound(alarmingTimer.sound);
      onAlarmTriggered?.call(alarmingTimer);
    }

    // Stop ticker if no timers are actively running
    if (!anyRunning) {
      _tickTimer?.cancel();
      _tickTimer = null;
    }
  }

  /// Play alarm - uses device's built-in sounds
  /// Note: Sound only works on Android/iOS. Windows/Linux/macOS have no sound.
  Future<void> _playAlarmSound(TimerSound sound) async {
    if (_isAlarmPlaying) return;
    _isAlarmPlaying = true;
    
    // Desktop platforms don't support ringtone playback
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return;
    }
    
    // Haptic feedback on mobile for extra attention
    HapticFeedback.heavyImpact();
    
    final player = FlutterRingtonePlayer();
    
    // Play the selected sound type
    // Only alarm supports native looping, others need manual looping
    // All use asAlarm: true to use the ALARM audio stream (bypasses silent mode)
    switch (sound) {
      case TimerSound.alarm:
        player.playAlarm(looping: true, volume: 1.0, asAlarm: true);
        break;
      case TimerSound.notification:
        // Notification doesn't support looping param, so we loop manually
        _startManualLoop(() {
          player.play(android: AndroidSounds.notification, ios: IosSounds.triTone, volume: 1.0, asAlarm: true);
        });
        break;
      case TimerSound.ringtone:
        // Ringtone doesn't support looping param, so we loop manually  
        _startManualLoop(() {
          player.play(android: AndroidSounds.ringtone, ios: IosSounds.bell, volume: 1.0, asAlarm: true);
        });
        break;
    }
  }
  
  /// Start a manual loop for sounds that don't support native looping
  void _startManualLoop(VoidCallback playSound) {
    playSound(); // Play immediately
    _alarmLoopTimer?.cancel();
    _alarmLoopTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_isAlarmPlaying) {
        playSound();
      } else {
        _alarmLoopTimer?.cancel();
        _alarmLoopTimer = null;
      }
    });
  }

  /// Check if we should stop the alarm sound
  void _checkAndStopAlarm() {
    final hasAlarming = state.timers.any((t) => t.isAlarming);
    if (!hasAlarming) {
      _stopAlarmSound();
      onAllAlarmsDismissed?.call();
    }
  }

  /// Stop alarm sound
  Future<void> _stopAlarmSound() async {
    _isAlarmPlaying = false;
    _alarmLoopTimer?.cancel();
    _alarmLoopTimer = null;
    FlutterRingtonePlayer().stop();
  }

  /// Keep screen awake while timers are running
  void _updateWakelock() {
    final hasActiveTimer = state.timers.any((t) => t.isRunning && !t.isPaused);
    if (hasActiveTimer) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  /// Get a specific timer by ID
  TimerData? getTimer(int id) {
    try {
      return state.timers.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }
}

/// Provider for the global timer service
final timerServiceProvider = StateNotifierProvider<TimerService, TimerServiceState>((ref) {
  return TimerService();
});
