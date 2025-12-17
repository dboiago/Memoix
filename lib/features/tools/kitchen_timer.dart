import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Available timer alarm sounds
enum TimerSound {
  bell('Bell', 'assets/audio/alarm_bell.mp3'),
  beep('Beep', 'assets/audio/alarm_beep.mp3'),
  gentle('Gentle', 'assets/audio/alarm_gentle.mp3');

  final String displayName;
  final String assetPath;

  const TimerSound(this.displayName, this.assetPath);
}

/// Kitchen timer tool with support for multiple simultaneous timers
class KitchenTimerWidget extends StatefulWidget {
  const KitchenTimerWidget({super.key});

  @override
  State<KitchenTimerWidget> createState() => _KitchenTimerWidgetState();
}

class _KitchenTimerWidgetState extends State<KitchenTimerWidget> {
  final List<TimerInstance> _timers = [];
  int _nextTimerId = 1;
  bool _isAlarmPlaying = false;

  @override
  void initState() {
    super.initState();
  }

  void _addTimer() {
    showDialog(
      context: context,
      builder: (ctx) => _TimerInputDialog(
        onTimerCreated: (duration, label, sound) {
          setState(() {
            _timers.add(TimerInstance(
              id: _nextTimerId++,
              duration: duration,
              label: label,
              sound: sound,
              onAlarm: _playAlarm,
              onStop: _stopAlarm,
            ),);
          });
        },
      ),
    );
  }

  Future<void> _playAlarm(TimerSound sound) async {
    _isAlarmPlaying = true;
    // Use haptic feedback on mobile, system sounds where available
    if (!Platform.isWindows && !Platform.isLinux) {
      HapticFeedback.vibrate();
    }
    // The visual alert is handled by the timer card's alarm state
  }

  Future<void> _stopAlarm() async {
    _isAlarmPlaying = false;
  }

  void _removeTimer(int id) {
    setState(() {
      final timer = _timers.firstWhere((t) => t.id == id);
      timer.dispose();
      _timers.removeWhere((t) => t.id == id);
    });
    _stopAlarm();
  }

  void _editTimer(TimerInstance timer) {
    showDialog(
      context: context,
      builder: (ctx) => _TimerEditDialog(
        initialDuration: timer.duration,
        initialLabel: timer.label,
        initialSound: timer.sound,
        onSave: (duration, label, sound) {
          setState(() {
            timer.updateSettings(duration, label, sound);
          });
        },
      ),
    );
  }

  void _duplicateTimer(TimerInstance timer) {
    setState(() {
      _timers.add(TimerInstance(
        id: _nextTimerId++,
        duration: timer.duration,
        label: timer.label.isNotEmpty ? '${timer.label} (Copy)' : '',
        sound: timer.sound,
        onAlarm: _playAlarm,
        onStop: _stopAlarm,
      ));
    });
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kitchen Timers'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTimer,
        child: const Icon(Icons.add),
      ),
      body: _timers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 64,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No active timers',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to add a timer',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _timers.length,
              itemBuilder: (context, index) {
                return _TimerCard(
                  timer: _timers[index],
                  onEdit: () => _editTimer(_timers[index]),
                  onDuplicate: () => _duplicateTimer(_timers[index]),
                  onDelete: () => _removeTimer(_timers[index].id),
                );
              },
            ),
    );
  }
}

/// Dialog for creating a new timer
class _TimerInputDialog extends StatefulWidget {
  final Function(Duration, String, TimerSound) onTimerCreated;

  const _TimerInputDialog({required this.onTimerCreated});

  @override
  State<_TimerInputDialog> createState() => _TimerInputDialogState();
}

class _TimerInputDialogState extends State<_TimerInputDialog> {
  final _labelController = TextEditingController();
  int _hours = 0;
  int _minutes = 10;
  int _seconds = 0;
  TimerSound _selectedSound = TimerSound.bell;

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('New Timer'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'Label (optional)',
                hintText: 'e.g., Boil pasta',
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Duration',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _TimePickerColumn(
                  label: 'Hours',
                  value: _hours,
                  max: 23,
                  onChanged: (v) => setState(() => _hours = v),
                ),
                _TimePickerColumn(
                  label: 'Min',
                  value: _minutes,
                  max: 59,
                  onChanged: (v) => setState(() => _minutes = v),
                ),
                _TimePickerColumn(
                  label: 'Sec',
                  value: _seconds,
                  max: 59,
                  onChanged: (v) => setState(() => _seconds = v),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Quick presets - additive
            Wrap(
              spacing: 8,
              children: [
                _PresetChip('+1 min', () => _addTime(0, 1, 0)),
                _PresetChip('+5 min', () => _addTime(0, 5, 0)),
                _PresetChip('+10 min', () => _addTime(0, 10, 0)),
                _PresetChip('+15 min', () => _addTime(0, 15, 0)),
                _PresetChip('+30 min', () => _addTime(0, 30, 0)),
                _PresetChip('+1 hour', () => _addTime(1, 0, 0)),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Alarm Sound',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: TimerSound.values.map((sound) {
                final isSelected = _selectedSound == sound;
                return FilterChip(
                  label: Text(sound.displayName),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedSound = sound),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  selectedColor: theme.colorScheme.secondary.withOpacity(0.15),
                  showCheckmark: false,
                  side: BorderSide(
                    color: isSelected
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.outline.withOpacity(0.2),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.onSurface,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final duration = Duration(
              hours: _hours,
              minutes: _minutes,
              seconds: _seconds,
            );
            if (duration.inSeconds > 0) {
              widget.onTimerCreated(
                duration,
                _labelController.text.trim(),
                _selectedSound,
              );
              Navigator.pop(context);
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }

  void _setTime(int h, int m, int s) {
    setState(() {
      _hours = h;
      _minutes = m;
      _seconds = s;
    });
  }

  void _addTime(int h, int m, int s) {
    setState(() {
      final totalSeconds = (_hours * 3600) + (_minutes * 60) + _seconds + (h * 3600) + (m * 60) + s;
      _hours = (totalSeconds ~/ 3600).clamp(0, 23);
      _minutes = ((totalSeconds % 3600) ~/ 60).clamp(0, 59);
      _seconds = (totalSeconds % 60).clamp(0, 59);
    });
  }
}

/// Dialog for editing an existing timer
class _TimerEditDialog extends StatefulWidget {
  final Duration initialDuration;
  final String initialLabel;
  final TimerSound initialSound;
  final Function(Duration, String, TimerSound) onSave;

  const _TimerEditDialog({
    required this.initialDuration,
    required this.initialLabel,
    required this.initialSound,
    required this.onSave,
  });

  @override
  State<_TimerEditDialog> createState() => _TimerEditDialogState();
}

class _TimerEditDialogState extends State<_TimerEditDialog> {
  late final TextEditingController _labelController;
  late int _hours;
  late int _minutes;
  late int _seconds;
  late TimerSound _selectedSound;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.initialLabel);
    _hours = widget.initialDuration.inHours;
    _minutes = widget.initialDuration.inMinutes.remainder(60);
    _seconds = widget.initialDuration.inSeconds.remainder(60);
    _selectedSound = widget.initialSound;
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Edit Timer'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'Label (optional)',
                hintText: 'e.g., Boil pasta',
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Duration',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _TimePickerColumn(
                  label: 'Hours',
                  value: _hours,
                  max: 23,
                  onChanged: (v) => setState(() => _hours = v),
                ),
                _TimePickerColumn(
                  label: 'Min',
                  value: _minutes,
                  max: 59,
                  onChanged: (v) => setState(() => _minutes = v),
                ),
                _TimePickerColumn(
                  label: 'Sec',
                  value: _seconds,
                  max: 59,
                  onChanged: (v) => setState(() => _seconds = v),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Quick presets - additive
            Wrap(
              spacing: 8,
              children: [
                _PresetChip('+1 min', () => _addTime(0, 1, 0)),
                _PresetChip('+5 min', () => _addTime(0, 5, 0)),
                _PresetChip('+10 min', () => _addTime(0, 10, 0)),
                _PresetChip('+15 min', () => _addTime(0, 15, 0)),
                _PresetChip('+30 min', () => _addTime(0, 30, 0)),
                _PresetChip('+1 hour', () => _addTime(1, 0, 0)),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Alarm Sound',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: TimerSound.values.map((sound) {
                final isSelected = _selectedSound == sound;
                return FilterChip(
                  label: Text(sound.displayName),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedSound = sound),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  selectedColor: theme.colorScheme.secondary.withOpacity(0.15),
                  showCheckmark: false,
                  side: BorderSide(
                    color: isSelected
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.outline.withOpacity(0.2),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.onSurface,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final duration = Duration(
              hours: _hours,
              minutes: _minutes,
              seconds: _seconds,
            );
            if (duration.inSeconds > 0) {
              widget.onSave(
                duration,
                _labelController.text.trim(),
                _selectedSound,
              );
              Navigator.pop(context);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _setTime(int h, int m, int s) {
    setState(() {
      _hours = h;
      _minutes = m;
      _seconds = s;
    });
  }

  void _addTime(int h, int m, int s) {
    setState(() {
      final totalSeconds = (_hours * 3600) + (_minutes * 60) + _seconds + (h * 3600) + (m * 60) + s;
      _hours = (totalSeconds ~/ 3600).clamp(0, 23);
      _minutes = ((totalSeconds % 3600) ~/ 60).clamp(0, 59);
      _seconds = (totalSeconds % 60).clamp(0, 59);
    });
  }
}

class _TimePickerColumn extends StatelessWidget {
  final String label;
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  const _TimePickerColumn({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_up),
                onPressed: () => onChanged(value < max ? value + 1 : 0),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  value.toString().padLeft(2, '0'),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down),
                onPressed: () => onChanged(value > 0 ? value - 1 : max),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PresetChip(this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
    );
  }
}

/// Individual timer card
class _TimerCard extends StatefulWidget {
  final TimerInstance timer;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const _TimerCard({
    required this.timer,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
  });

  @override
  State<_TimerCard> createState() => _TimerCardState();
}

class _TimerCardState extends State<_TimerCard> {
  @override
  void initState() {
    super.initState();
    widget.timer.addListener(_onTimerUpdate);
  }

  @override
  void dispose() {
    widget.timer.removeListener(_onTimerUpdate);
    super.dispose();
  }

  void _onTimerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timer = widget.timer;
    final isFinished = timer.remainingSeconds == 0 && timer.isRunning;
    
    // Use card color with explicit text colors for readability
    final cardColor = isFinished || timer.isAlarming
        ? theme.colorScheme.secondary.withValues(alpha: 0.3)
        : timer.isPaused
            ? theme.colorScheme.surfaceContainerHighest
            : theme.cardTheme.color ?? theme.colorScheme.surface;
    final textColor = theme.colorScheme.onSurface;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        timer.label.isNotEmpty ? timer.label : 'Timer',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                      Text(
                        timer.sound.displayName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: theme.colorScheme.onSurfaceVariant),
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        widget.onEdit();
                        break;
                      case 'duplicate':
                        widget.onDuplicate();
                        break;
                      case 'delete':
                        widget.onDelete();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete', style: TextStyle(color: theme.colorScheme.secondary)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Timer display
            Text(
              _formatRemaining(timer.remainingSeconds),
              style: theme.textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.w500,
                fontFeatures: [const FontFeature.tabularFigures()],
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: timer.progress,
                minHeight: 6,
                backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
              ),
            ),
            const SizedBox(height: 16),
            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (timer.isAlarming)
                  FilledButton.icon(
                    onPressed: timer.stopAlarm,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop Alarm'),
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.secondary,
                    ),
                  )
                else if (!timer.isRunning)
                  FilledButton.icon(
                    onPressed: timer.start,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start'),
                  )
                else if (timer.isPaused)
                  FilledButton.icon(
                    onPressed: timer.resume,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Resume'),
                  )
                else
                  FilledButton.icon(
                    onPressed: timer.pause,
                    icon: const Icon(Icons.pause),
                    label: const Text('Pause'),
                  ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: timer.reset,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  String _formatRemaining(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

/// Timer instance model
class TimerInstance extends ChangeNotifier {
  final int id;
  Duration duration;
  String label;
  TimerSound sound;
  final Future<void> Function(TimerSound) onAlarm;
  final Future<void> Function() onStop;

  Timer? _timer;
  int remainingSeconds;
  bool isRunning = false;
  bool isPaused = false;
  bool isAlarming = false;

  TimerInstance({
    required this.id,
    required this.duration,
    required this.label,
    required this.sound,
    required this.onAlarm,
    required this.onStop,
  }) : remainingSeconds = duration.inSeconds;

  double get progress {
    if (duration.inSeconds == 0) return 1.0;
    return 1.0 - (remainingSeconds / duration.inSeconds);
  }

  void updateSettings(Duration newDuration, String newLabel, TimerSound newSound) {
    duration = newDuration;
    label = newLabel;
    sound = newSound;
    // Reset timer with new duration
    _timer?.cancel();
    remainingSeconds = duration.inSeconds;
    isRunning = false;
    isPaused = false;
    if (isAlarming) {
      isAlarming = false;
      onStop();
    }
    notifyListeners();
  }

  void start() {
    if (isRunning) return;
    isRunning = true;
    isPaused = false;
    isAlarming = false;
    _startTicking();
    notifyListeners();
  }

  void pause() {
    if (!isRunning || isPaused) return;
    isPaused = true;
    _timer?.cancel();
    notifyListeners();
  }

  void resume() {
    if (!isRunning || !isPaused) return;
    isPaused = false;
    _startTicking();
    notifyListeners();
  }

  void reset() {
    _timer?.cancel();
    remainingSeconds = duration.inSeconds;
    isRunning = false;
    isPaused = false;
    if (isAlarming) {
      isAlarming = false;
      onStop();
    }
    notifyListeners();
  }

  void stopAlarm() {
    if (isAlarming) {
      isAlarming = false;
      onStop();
      notifyListeners();
    }
  }

  void _startTicking() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (remainingSeconds > 0) {
        remainingSeconds--;
        notifyListeners();
      } else {
        _timer?.cancel();
        _triggerAlarm();
      }
    });
  }

  Future<void> _triggerAlarm() async {
    isAlarming = true;
    notifyListeners();
    await onAlarm(sound);
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (isAlarming) {
      onStop();
    }
    super.dispose();
  }
}
