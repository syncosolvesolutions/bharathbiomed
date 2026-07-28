import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sync_controller.dart';

/// Slim top banner shown app-wide whenever there's something to sync (new
/// server data and/or data queued locally) and no sync is currently
/// running. Tap anywhere on it to start [SyncController.startSync].
class SyncAvailableBanner extends ConsumerWidget {
  const SyncAvailableBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: false,
      child: Material(
        color: scheme.primaryContainer,
        child: InkWell(
          onTap: () => ref.read(syncControllerProvider.notifier).startSync(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.sync, color: scheme.onPrimaryContainer, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'New data available — tap to sync',
                    style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(Icons.chevron_right, color: scheme.onPrimaryContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen blocking overlay shown app-wide while a sync is running: a
/// progress bar, percentage, current step label, and an explicit warning not
/// to close the app — a killed process mid-upload just leaves the local
/// queues exactly as unsynced as they were before this run started, so the
/// warning is about wasted time, not data loss, but there's no way to
/// convey that nuance briefly, so it stays simple.
class SyncProgressOverlay extends StatelessWidget {
  const SyncProgressOverlay({required this.progress, super.key});

  final SyncProgress progress;

  @override
  Widget build(BuildContext context) {
    final percent = (progress.fraction.clamp(0, 1) * 100).round();
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.6),
        child: Center(
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Syncing…', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(value: progress.fraction, minHeight: 8),
                  ),
                  const SizedBox(height: 12),
                  Text('$percent% — ${progress.label}', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(
                    "Please don't close the app while syncing.",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
