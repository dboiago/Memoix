import 'package:flutter/material.dart';

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
                        : theme.colorScheme.primaryContainer,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : Text(
                            '$displayNumber',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),

                // Step text
                Expanded(
                  child: Text(
                    step,
                    style: TextStyle(
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                      color: isCompleted
                          ? theme.colorScheme.onSurface.withOpacity(0.5)
                          : null,
                      height: 1.5,
                    ),
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
