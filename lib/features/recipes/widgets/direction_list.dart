import 'package:flutter/material.dart';

/// Capitalize the first letter of a sentence
String _capitalizeSentence(String text) {
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1);
}

class DirectionList extends StatefulWidget {
  final List<String> directions;

  const DirectionList({super.key, required this.directions});

  @override
  State<DirectionList> createState() => _DirectionListState();
}

class _DirectionListState extends State<DirectionList> {
  final Set<int> _completedSteps = {};

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
        ));
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
      ));
      
      lastEnd = match.end;
    }

    // Add remaining text after last match
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
      ));
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
            padding: EdgeInsets.only(top: index > 0 ? 16 : 0, bottom: 8),
            child: Text(
              _getSectionName(step),
              style: theme.textTheme.titleSmall?.copyWith(
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

        return InkWell(
          onTap: () {
            setState(() {
              if (isCompleted) {
                _completedSteps.remove(index);
              } else {
                _completedSteps.add(index);
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step number circle
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? Colors.green
                        : theme.colorScheme.secondary,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : Text(
                            '$displayNumber',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSecondary,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),

                // Step text with optional/alternative parts in italics
                Expanded(
                  child: _buildStyledText(
                    _capitalizeSentence(step),
                    theme.textTheme.bodyMedium,
                    isCompleted,
                    theme,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
