import 'package:flutter/material.dart';

/// Shown in place of a [StreamBuilder]'s content when its stream errors —
/// e.g. a missing composite index or a permissions rejection — instead of
/// falling through to the same empty-state message used when there's
/// genuinely no data. Silent failures of that kind cost real debugging time
/// in Phase 9 and Phase 11.
class StreamErrorView extends StatelessWidget {
  final Object? error;

  const StreamErrorView({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              'Couldn\'t load this data.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
