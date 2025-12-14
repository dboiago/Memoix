import 'package:flutter/material.dart';

import '../models/recipe.dart';

/// Capitalize the first letter of a sentence
String _capitalizeSentence(String text) {
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1);
}

class DirectionList extends StatefulWidget {
  final List<String> directions;
  final Recipe? recipe;  // Optional: pass recipe for step image support
  final VoidCallback? onStepImageTap;  // Callback when step image icon is tapped
  final Function(int stepIndex)? onScrollToImage;  // Callback to scroll to image

  const DirectionList({
    super.key,
    required this.directions,
    this.recipe,
    this.onStepImageTap,
    this.onScrollToImage,
  });

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
        final hasImage = widget.recipe?.getStepImageIndex(index) != null;

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
                        ? Icon(Icons.check, size: 16, color: theme.colorScheme.outline)
                        : Text(
                            '$displayNumber',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.secondary,
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

                // Step image icon if this step has an associated image
                if (hasImage)
                  IconButton(
                    icon: Icon(
                      Icons.image_outlined,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'View step image',
                    onPressed: () {
                      if (widget.onScrollToImage != null) {
                        widget.onScrollToImage!(index);
                      }
                    },
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
