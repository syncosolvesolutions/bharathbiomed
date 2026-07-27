import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/product_repository.dart';
import '../../features/catalog/catalog_controller.dart';
import '../../firebase_options.dart';

/// Every device subscribes to this topic; the `onProductsChanged` /
/// `onDepartmentsChanged` Cloud Functions (functions/src/index.ts) publish to
/// it whenever the catalog changes. Broadcasting to a topic means there's no
/// per-device token to store, refresh, or garbage-collect — every signed-in
/// or signed-out device on this tablet fleet wants the same catalog.
const catalogUpdatesTopic = 'catalog-updates';

/// The data-message key the Cloud Functions side sets so a client can tell a
/// catalog-update push apart from any other kind of message this project
/// might send in future without relying on notification text.
const _catalogUpdatedType = 'catalog_updated';

/// Registered in main.dart (`FirebaseMessaging.onBackgroundMessage`) before
/// `runApp`, so a data message can trigger a sync while the app is
/// backgrounded or fully terminated. This runs in its own background isolate
/// with no access to the app's `ProviderScope`, so — unlike the foreground
/// path — it talks to Firestore directly through a fresh [ProductRepository]
/// instead of going through a provider.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (message.data['type'] != _catalogUpdatedType) return;
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  try {
    await ProductRepository().sync();
  } catch (error) {
    debugPrint('PushNotificationService: background sync failed: $error');
  }
}

/// Subscribes this device to catalog-update pushes and re-syncs the catalog
/// whenever one arrives, so the offline cache (and whatever's on screen)
/// stays current without a field rep having to notice a change happened and
/// reach for the manual sync button themselves.
class PushNotificationService {
  PushNotificationService(this._ref);

  final Ref _ref;

  Future<void> initialize() async {
    final messaging = FirebaseMessaging.instance;

    // Best-effort: a user who denies the permission prompt (or is on a
    // platform/version where it's not required) still gets pushes on
    // Android; iOS/web just won't display the notification banner, but the
    // silent-sync data payload still works via the background handler.
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    await messaging.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
    await messaging.subscribeToTopic(catalogUpdatesTopic);

    // App already running, in the foreground or background: the OS delivers
    // straight to these listeners rather than the top-level background
    // handler.
    FirebaseMessaging.onMessage.listen(_handleMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

    // App was fully terminated and this push is why it launched.
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) unawaited(_handleMessage(initialMessage));
  }

  Future<void> _handleMessage(RemoteMessage message) async {
    if (message.data['type'] != _catalogUpdatedType) return;
    try {
      await _ref.read(catalogControllerProvider.notifier).sync();
    } catch (error) {
      debugPrint('PushNotificationService: foreground sync failed: $error');
    }
  }
}

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService(ref);
});
