import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/app_logger.dart';
import '../../core/error/user_facing_error.dart';
import '../../data/providers.dart';
import '../../domain/models/admin_notification.dart';
import 'admin_notifications_controller.dart';

String _relativeTime(DateTime? time) {
  if (time == null) return 'Just now';
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

/// Lists every `AdminNotifications` doc (currently only "an MR's date of
/// birth was set/changed" — see the onEmployeeDobChanged Cloud Function
/// trigger). Tapping one marks it read.
class AdminNotificationsScreen extends ConsumerWidget {
  const AdminNotificationsScreen({super.key});

  Future<void> _markRead(BuildContext context, WidgetRef ref, AdminNotification notification) async {
    if (notification.read) return;
    try {
      await ref.read(adminNotificationsRepositoryProvider).markRead(notification.id);
    } catch (error, stackTrace) {
      AppLogger.error('AdminNotifications', 'markRead failed', error: error, stackTrace: stackTrace);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to update: ${UserFacingError.describe(error)}')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(adminNotificationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load notifications: ${UserFacingError.describe(error)}')),
        data: (notifications) {
          if (notifications.isEmpty) {
            return const Center(child: Text('No notifications yet.', textAlign: TextAlign.center));
          }
          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return ListTile(
                onTap: () => _markRead(context, ref, notification),
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                  child: const Text('🎂'),
                ),
                title: Text(
                  notification.employeeName,
                  style: TextStyle(fontWeight: notification.read ? FontWeight.normal : FontWeight.bold),
                ),
                subtitle: Text(notification.message),
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_relativeTime(notification.createdAt), style: Theme.of(context).textTheme.bodySmall),
                    if (!notification.read) ...[
                      const SizedBox(height: 4),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
