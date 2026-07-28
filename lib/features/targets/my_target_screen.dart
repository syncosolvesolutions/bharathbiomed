import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/user_facing_error.dart';
import 'my_target_controller.dart';

/// The signed-in user's current-month target vs. their real order
/// achievement — see [MyTargetController].
class MyTargetScreen extends ConsumerWidget {
  const MyTargetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(myTargetControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Target')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(myTargetControllerProvider.notifier).refresh(),
        child: progressAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Failed to load target: ${UserFacingError.describe(error)}')),
          data: (progress) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(progress.period, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                if (progress.target == null)
                  const Text('No target has been set for you this month yet.')
                else ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(value: progress.fraction, minHeight: 12),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${progress.achievement.toStringAsFixed(2)} of ${progress.target!.targetValue.toStringAsFixed(2)}'
                    ' (${(progress.fraction * 100).round()}%)',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  'Achievement is based on your approved, dispatched, or invoiced orders this month — not pending or rejected ones.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
