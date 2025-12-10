import 'package:flutter/material.dart';

class DirectionList extends StatefulWidget {
  final List<String> directions;

  const DirectionList({super.key, required this.directions});

  @override
  State<DirectionList> createState() => _DirectionListState();
}

class _DirectionListState extends State<DirectionList> {
  final Set<int> _completedSteps = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.directions.isEmpty) {
      return const Text(
        'No directions listed',
        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
      );
    }

    return Column(
      children: List.generate(widget.directions.length, (index) {
        final step = widget.directions[index];
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
                            '${index + 1}',
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
