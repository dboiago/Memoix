import 'dart:async';
import 'package:flutter/material.dart';

/// Kitchen timer tool with support for multiple simultaneous timers
class KitchenTimerWidget extends StatefulWidget {
  const KitchenTimerWidget({super.key});

  @override
  State<KitchenTimerWidget> createState() => _KitchenTimerWidgetState();
}

class _KitchenTimerWidgetState extends State<KitchenTimerWidget> {
  final List<TimerInstance> _timers = [];
  int _nextTimerId = 1;

  void _addTimer() {
    showDialog(
      context: context,
      builder: (ctx) => _TimerInputDialog(
        onTimerCreated: (duration, label) {
          setState(() {
            _timers.add(TimerInstance(
              id: _nextTimerId++,
              duration: duration,
              label: label,
            ));
          });
        },
      ),
    );
  }

  void _removeTimer(int id) {
    setState(() {
      final timer = _timers.firstWhere((t) => t.id == id);
      timer.dispose();
      _timers.removeWhere((t) => t.id == id);
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
                  onDelete: () => _removeTimer(_timers[index].id),
                );
              },
            ),
    );
  }
}

/// Dialog for creating a new timer
class _TimerInputDialog extends StatefulWidget {
  final Function(Duration, String) onTimerCreated;

  const _TimerInputDialog({required this.onTimerCreated});

  @override
  State<_TimerInputDialog> createState() => _TimerInputDialogState();
}

class _TimerInputDialogState extends State<_TimerInputDialog> {
  final _labelController = TextEditingController();
  int _hours = 0;
  int _minutes = 10;
  int _seconds = 0;

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
            // Quick presets
            Wrap(
              spacing: 8,
              children: [
                _PresetChip('1 min', () => _setTime(0, 1, 0)),
                _PresetChip('5 min', () => _setTime(0, 5, 0)),
                _PresetChip('10 min', () => _setTime(0, 10, 0)),
                _PresetChip('15 min', () => _setTime(0, 15, 0)),
                _PresetChip('30 min', () => _setTime(0, 30, 0)),
                _PresetChip('1 hour', () => _setTime(1, 0, 0)),
              ],
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
  final VoidCallback onDelete;

  const _TimerCard({
    required this.timer,
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
    final cardColor = isFinished
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
                      if (timer.label.isNotEmpty)
                        Text(
                          timer.label,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: textColor,
                          ),
                        ),
                      Text(
                        _formatDuration(timer.duration),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: theme.colorScheme.onSurfaceVariant),
                  onPressed: widget.onDelete,
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
                if (!timer.isRunning)
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
  final Duration duration;
  final String label;

  Timer? _timer;
  int remainingSeconds;
  bool isRunning = false;
  bool isPaused = false;

  TimerInstance({
    required this.id,
    required this.duration,
    required this.label,
  }) : remainingSeconds = duration.inSeconds;

  double get progress {
    if (duration.inSeconds == 0) return 1.0;
    return 1.0 - (remainingSeconds / duration.inSeconds);
  }

  void start() {
    if (isRunning) return;
    isRunning = true;
    isPaused = false;
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
    notifyListeners();
  }

  void _startTicking() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (remainingSeconds > 0) {
        remainingSeconds--;
        notifyListeners();
      } else {
        _timer?.cancel();
        _playAlarm();
      }
    });
  }

  Future<void> _playAlarm() async {
    // Play a system beep sound (you can replace with custom sound file)
    // For now, we'll just trigger a notification
    // In a real app, you'd use flutter_local_notifications or similar
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
