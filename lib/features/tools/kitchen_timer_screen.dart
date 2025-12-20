import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'timer_service.dart';
import '../../core/widgets/memoix_snackbar.dart';
import '../../app/routes/router.dart';

/// Kitchen timer tool with support for multiple simultaneous timers
/// Uses a global service so timers persist across navigation
class KitchenTimerWidget extends ConsumerStatefulWidget {
  const KitchenTimerWidget({super.key});

  @override
  ConsumerState<KitchenTimerWidget> createState() => _KitchenTimerWidgetState();
}

class _KitchenTimerWidgetState extends ConsumerState<KitchenTimerWidget> {
  @override
  void initState() {
    super.initState();
    // Set up alarm callback to show persistent notification
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupAlarmCallbacks();
    });
  }

  void _setupAlarmCallbacks() {
    final timerService = ref.read(timerServiceProvider.notifier);
    timerService.onAlarmTriggered = (timer) {
      _showAlarmNotification(timer);
    };
    timerService.onAllAlarmsDismissed = () {
      MemoixSnackBar.clear();
    };
  }

  void _showAlarmNotification(TimerData timer) {
    MemoixSnackBar.showAlarm(
      timerLabel: timer.label,
      onDismiss: () {
        ref.read(timerServiceProvider.notifier).stopAlarm(timer.id);
      },
      onGoToAlarm: () {
        // Already on the timer screen, just scroll to the timer
        // For now, just dismiss and let user see the card
        ref.read(timerServiceProvider.notifier).stopAlarm(timer.id);
      },
    );
  }

  void _addTimer() {
    showDialog(
      context: context,
      builder: (ctx) => _TimerInputDialog(
        onTimerCreated: (duration, label, sound) {
          ref.read(timerServiceProvider.notifier).addTimer(
            duration: duration,
            label: label,
            sound: sound,
          );
        },
      ),
    );
  }

  void _editTimer(TimerData timer) {
    showDialog(
      context: context,
      builder: (ctx) => _TimerEditDialog(
        initialDuration: timer.duration,
        initialLabel: timer.label,
        initialSound: timer.sound,
        onSave: (duration, label, sound) {
          ref.read(timerServiceProvider.notifier).updateTimer(
            timer.id,
            duration,
            label,
            sound,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timerState = ref.watch(timerServiceProvider);
    final timers = timerState.timers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kitchen Timers'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTimer,
        child: const Icon(Icons.add),
      ),
      body: timers.isEmpty
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
              itemCount: timers.length,
              itemBuilder: (context, index) {
                return _TimerCard(
                  timer: timers[index],
                  onEdit: () => _editTimer(timers[index]),
                  onDuplicate: () => ref.read(timerServiceProvider.notifier).duplicateTimer(timers[index].id),
                  onDelete: () => ref.read(timerServiceProvider.notifier).removeTimer(timers[index].id),
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
class _TimerCard extends ConsumerWidget {
  final TimerData timer;
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
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
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
                        onEdit();
                        break;
                      case 'duplicate':
                        onDuplicate();
                        break;
                      case 'delete':
                        onDelete();
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
                    onPressed: () => ref.read(timerServiceProvider.notifier).stopAlarm(timer.id),
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop Alarm'),
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.secondary,
                    ),
                  )
                else if (!timer.isRunning)
                  FilledButton.icon(
                    onPressed: () => ref.read(timerServiceProvider.notifier).startTimer(timer.id),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start'),
                  )
                else if (timer.isPaused)
                  FilledButton.icon(
                    onPressed: () => ref.read(timerServiceProvider.notifier).resumeTimer(timer.id),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Resume'),
                  )
                else
                  FilledButton.icon(
                    onPressed: () => ref.read(timerServiceProvider.notifier).pauseTimer(timer.id),
                    icon: const Icon(Icons.pause),
                    label: const Text('Pause'),
                  ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => ref.read(timerServiceProvider.notifier).resetTimer(timer.id),
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

  String _formatRemaining(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
