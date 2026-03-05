import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes/router.dart';
import '../../../core/widgets/memoix_snackbar.dart';
import '../../../shared/widgets/time_picker_column.dart';
import '../models/recipe.dart';
import '../../../core/utils/timer_duration_extractor.dart';
import '../../tools/timer_service.dart';

/// Capitalize the first letter of a sentence
String _capitalizeSentence(String text) {
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1);
}

class DirectionList extends ConsumerStatefulWidget {
  final List<String> directions;
  final Recipe? recipe;  // Optional: pass recipe for step image support
  final VoidCallback? onStepImageTap;  // Callback when step image icon is tapped
  final Function(int stepIndex)? onScrollToImage;  // Callback to scroll to image
  final bool isCompact;
  final bool enableTimerLongPress;

  const DirectionList({
    super.key,
    required this.directions,
    this.recipe,
    this.onStepImageTap,
    this.onScrollToImage,
    this.isCompact = false,
    this.enableTimerLongPress = false,
  });

  @override
  ConsumerState<DirectionList> createState() => _DirectionListState();
}

class _DirectionListState extends ConsumerState<DirectionList> {
  final Set<int> _completedSteps = {};

  /// Set to true by GestureDetector.onLongPress so the InkWell.onTap
  /// that fires on finger-lift is swallowed and does not mark the step complete.
  bool _suppressNextTap = false;

  // Check if a step is a section header (wrapped in square brackets)
  bool _isSection(String step) {
    final trimmed = step.trim();
    return trimmed.startsWith('[') && trimmed.endsWith(']');
  }

  // Extract section name from brackets
  String _getSectionName(String step) {
    final trimmed = step.trim();
    return trimmed.substring(1, trimmed.length - 1);
  }

  // Pattern to match optional/alternative text
  static final RegExp _optionalPattern = RegExp(
    r'(\(optional\)|\(opt\.\)|\(alt\.?\)|\(alternative\)|optional:|alt:|alternative:)',
    caseSensitive: false,
  );

  // Build styled text with optional/alternative parts in italics
  Widget _buildStyledText(String text, TextStyle? baseStyle, bool isCompleted, ThemeData theme) {
    final matches = _optionalPattern.allMatches(text).toList();
    
    if (matches.isEmpty) {
      // No optional text found, return plain text
      return Text(
        text,
        style: baseStyle?.copyWith(
          decoration: isCompleted ? TextDecoration.lineThrough : null,
          color: isCompleted
              ? theme.colorScheme.onSurface.withOpacity(0.5)
              : null,
          height: 1.5,
        ),
      );
    }

    // Build spans with italic styling for optional parts
    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      // Add text before the match
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
        ),);
      }
      
      // Add the optional/alt text in italics with secondary color
      spans.add(TextSpan(
        text: match.group(0),
        style: TextStyle(
          fontStyle: FontStyle.italic,
          color: isCompleted 
              ? theme.colorScheme.onSurface.withOpacity(0.4)
              : theme.colorScheme.secondary,
        ),
      ),);
      
      lastEnd = match.end;
    }

    // Add remaining text after last match
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
      ),);
    }

    return RichText(
      text: TextSpan(
        style: baseStyle?.copyWith(
          decoration: isCompleted ? TextDecoration.lineThrough : null,
          color: isCompleted
              ? theme.colorScheme.onSurface.withOpacity(0.5)
              : theme.colorScheme.onSurface,
          height: 1.5,
        ),
        children: spans,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Compact sizing
    final circleSize = widget.isCompact ? 22.0 : 28.0;
    final circleIconSize = widget.isCompact ? 12.0 : 16.0;
    final circleFontSize = widget.isCompact ? 12.0 : 14.0;
    final verticalPadding = widget.isCompact ? 4.0 : 8.0;
    final textStyle = widget.isCompact ? theme.textTheme.bodySmall : theme.textTheme.bodyMedium;
    final gapWidth = widget.isCompact ? 8.0 : 12.0;

    if (widget.directions.isEmpty) {
      return const Text(
        'No directions listed',
        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
      );
    }

    // Track step number (excluding section headers)
    int stepNumber = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(widget.directions.length, (index) {
        final step = widget.directions[index];
        
        // Check if this is a section header
        if (_isSection(step)) {
          return Padding(
            padding: EdgeInsets.only(top: index > 0 ? (widget.isCompact ? 10 : 16) : 0, bottom: widget.isCompact ? 4 : 8),
            child: Text(
              _getSectionName(step),
              style: (widget.isCompact ? theme.textTheme.labelLarge : theme.textTheme.titleSmall)?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          );
        }

        // Regular step
        stepNumber++;
        final displayNumber = stepNumber;
        final isCompleted = _completedSteps.contains(index);
        final hasImage = widget.recipe?.getStepImageIndex(index) != null;

        final rowContent = Padding(
            padding: EdgeInsets.symmetric(vertical: verticalPadding),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step number circle
                Container(
                  width: circleSize,
                  height: circleSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? theme.colorScheme.surfaceContainerHighest
                        : theme.colorScheme.secondary.withOpacity(0.15),
                    border: Border.all(
                      color: isCompleted
                          ? theme.colorScheme.outline.withOpacity(0.5)
                          : theme.colorScheme.secondary,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: isCompleted
                        ? Icon(Icons.check, size: circleIconSize, color: theme.colorScheme.outline)
                        : Text(
                            '$displayNumber',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: circleFontSize,
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                  ),
                ),
                SizedBox(width: gapWidth),

                // Step text with optional/alternative parts in italics
                Expanded(
                  child: _buildStyledText(
                    _capitalizeSentence(step),
                    textStyle,
                    isCompleted,
                    theme,
                  ),
                ),

                // Step image icon if this step has an associated image
                if (hasImage)
                  IconButton(
                    icon: Icon(
                      Icons.image_outlined,
                      size: widget.isCompact ? 16 : 20,
                      color: theme.colorScheme.primary,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(minWidth: widget.isCompact ? 24 : 32, minHeight: widget.isCompact ? 24 : 32),
                    tooltip: 'View step image',
                    onPressed: () {
                      if (widget.onScrollToImage != null) {
                        widget.onScrollToImage!(index);
                      }
                    },
                  ),
              ],
            ),
        );

        if (!widget.enableTimerLongPress) {
          return GestureDetector(
            onTap: () {
              setState(() {
                if (isCompleted) {
                  _completedSteps.remove(index);
                } else {
                  _completedSteps.add(index);
                }
              });
            },
            child: rowContent,
          );
        }

        return GestureDetector(
          onTap: () {
            if (_suppressNextTap) {
              _suppressNextTap = false;
              return;
            }
            setState(() {
              if (isCompleted) {
                _completedSteps.remove(index);
              } else {
                _completedSteps.add(index);
              }
            });
          },
          child: InkWell(
            onLongPress: () async {
              _suppressNextTap = true;
              final duration = extractTimerDuration(step);
              if (duration == null) {
                _suppressNextTap = false;
                return;
              }
              await HapticFeedback.mediumImpact();
              if (context.mounted) {
                _showTimerBottomSheet(context, ref, duration, step);
              }
            },
            child: rowContent,
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Timer quick-start bottom sheet
// ---------------------------------------------------------------------------

String _formatTimerDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

void _showTimerBottomSheet(
  BuildContext context,
  WidgetRef ref,
  Duration duration,
  String stepText,
) {
  final label = stepText.length > 60 ? '${stepText.substring(0, 60)}\u2026' : stepText;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      int hours = duration.inHours;
      int minutes = duration.inMinutes.remainder(60);
      int seconds = duration.inSeconds.remainder(60);

      return StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final theme = Theme.of(sheetContext);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TimePickerColumn(
                        label: 'Hours',
                        value: hours,
                        max: 23,
                        onChanged: (v) => setSheetState(() => hours = v),
                      ),
                      TimePickerColumn(
                        label: 'Min',
                        value: minutes,
                        max: 59,
                        onChanged: (v) => setSheetState(() => minutes = v),
                      ),
                      TimePickerColumn(
                        label: 'Sec',
                        value: seconds,
                        max: 59,
                        onChanged: (v) => setSheetState(() => seconds = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {
                          final d = Duration(
                            hours: hours,
                            minutes: minutes,
                            seconds: seconds,
                          );
                          if (d.inSeconds > 0) {
                            ref.read(timerServiceProvider.notifier).addTimer(
                              duration: d,
                              label: label,
                              sound: TimerSound.alarm,
                            );
                            final timers = ref.read(timerServiceProvider).timers;
                            if (timers.isNotEmpty) {
                              ref.read(timerServiceProvider.notifier).startTimer(timers.last.id);
                            }
                            final rootCtx = sheetContext;
                            Navigator.pop(ctx);
                            MemoixSnackBar.showWithAction(
                              message: 'Timer started - ${_formatTimerDuration(d)}',
                              actionLabel: 'View',
                              onAction: () => AppRoutes.toKitchenTimer(rootCtx),
                            );
                          } else {
                            Navigator.pop(ctx);
                          }
                        },
                        child: const Text('Start'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
