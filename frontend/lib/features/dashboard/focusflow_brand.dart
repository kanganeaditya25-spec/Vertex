import 'package:flutter/material.dart';

class FocusFlowBrand extends StatelessWidget {
  const FocusFlowBrand({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mark = Container(
      width: compact ? 30 : 42,
      height: compact ? 30 : 42,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(compact ? 9 : 12),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.24)),
      ),
      child: Icon(Icons.track_changes_rounded,
          size: compact ? 18 : 25, color: scheme.primary),
    );
    if (compact) return mark;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      mark,
      const SizedBox(width: 10),
      Text('FocusFlow',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w800)),
    ]);
  }
}
