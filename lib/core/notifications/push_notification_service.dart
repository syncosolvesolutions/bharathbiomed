import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/product_repository.dart';
import '../../features/catalog/catalog_controller.dart';
import '../../firebase_options.dart';
import '../auth/admin_access.dart';
import '../error/app_logger.dart';
import '../../features/auth/auth_controller.dart';

/// Every device subscribes to this topic; the `onProductsChanged` /
/// `onDepartmentsChanged` Cloud Functions (functions/src/index.ts) publish to
/// it whenever the catalog changes. Broadcasting to a topic means there's no
/// per-device token to store, refresh, or garbage-collect — every signed-in
/// or signed-out device on this tablet fleet wants the same catalog.
const catalogUpdatesTopic = 'catalog-updates';

/// Only the admin's own device(s) subscribe to this — see
/// `_syncAdminTopicSubscription` below — so an MR's device never receives a
/// push meant for the admin (e.g. "an MR's date of birth changed", sent by
/// the `onEmployeeDobChanged` Cloud Function trigger).
const adminNotificationsTopic = 'admin-notifications';

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
  debugPrint('firebaseMessagingBackgroundHandler: received message type=${message.data['type']}');
  if (message.data['type'] != _catalogUpdatedType) return;
  debugPrint('firebaseMessagingBackgroundHandler: initializing Firebase in background isolate');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('firebaseMessagingBackgroundHandler: Firebase initialized, syncing product repository');
  try {
    await ProductRepository().sync();
    debugPrint('firebaseMessagingBackgroundHandler: background sync succeeded');
  } catch (error, stackTrace) {
    debugPrint('firebaseMessagingBackgroundHandler: background sync failed error=$error');
    AppLogger.error('PushNotification', 'background sync failed', error: error, stackTrace: stackTrace);
  }
}

/// Subscribes this device to catalog-update pushes and re-syncs the catalog
/// whenever one arrives, so the offline cache (and whatever's on screen)
/// stays current without a field rep having to notice a change happened and
/// reach for the manual sync button themselves.

Future<bool> checkIsPhysicalDevice() async {
  debugPrint('checkIsPhysicalDevice: querying device info platform channel');
  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

  if (Platform.isIOS) {
    IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
    debugPrint('checkIsPhysicalDevice: iOS isPhysicalDevice=${iosInfo.isPhysicalDevice}');
    return iosInfo.isPhysicalDevice;
  } else if (Platform.isAndroid) {
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    debugPrint('checkIsPhysicalDevice: Android isPhysicalDevice=${androidInfo.isPhysicalDevice}');
    return androidInfo.isPhysicalDevice;
  }

  // Fallback for other platforms (Web, Desktop, etc.)
  return true;
}


class PushNotificationService {
  PushNotificationService(this._ref);

  final Ref _ref;

  Future<void> initialize() async {
    debugPrint('PushNotificationService.initialize: starting push notification setup');
    final messaging = FirebaseMessaging.instance;

    bool isRealDevice = await checkIsPhysicalDevice();
    if (!isRealDevice) {
      debugPrint('PushNotificationService: running on an emulator/simulator, skipping push notification setup.');
      return;
    }
    // Best-effort: a user who denies the permission prompt (or is on a
    // platform/version where it's not required) still gets pushes on
    // Android; iOS/web just won't display the notification banner, but the
    // silent-sync data payload still works via the background handler.
    debugPrint('PushNotificationService.initialize: requesting notification permission');
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    debugPrint('PushNotificationService.initialize: setting foreground notification presentation options');
    await messaging.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
    debugPrint('PushNotificationService.initialize: subscribing to topic=$catalogUpdatesTopic');
    await messaging.subscribeToTopic(catalogUpdatesTopic);
    debugPrint('PushNotificationService.initialize: subscribed to catalog updates topic');

    // Keep the admin-notifications subscription in sync with whoever's
    // signed in on this device — an MR's device must never end up
    // subscribed (it would otherwise receive pushes about other MRs).
    await _syncAdminTopicSubscription(_ref.read(authStateChangesProvider).value);
    _ref.listen<AsyncValue<User?>>(authStateChangesProvider, (previous, next) {
      unawaited(_syncAdminTopicSubscription(next.value));
    });

    // App already running, in the foreground or background: the OS delivers
    // straight to these listeners rather than the top-level background
    // handler.
    FirebaseMessaging.onMessage.listen(_handleMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

    // App was fully terminated and this push is why it launched.
    debugPrint('PushNotificationService.initialize: checking for initial message');
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) unawaited(_handleMessage(initialMessage));
  }

  bool? _subscribedToAdminTopic;

  /// Subscribes/unsubscribes this device from [adminNotificationsTopic]
  /// based on whether [user] is the admin — tracked in [_subscribedToAdminTopic]
  /// so a sign-in/sign-out that doesn't change admin-ness (e.g. two sign-ins
  /// by the same admin) doesn't redundantly call the platform channel.
  Future<void> _syncAdminTopicSubscription(User? user) async {
    final shouldBeSubscribed = isAdminEmail(user?.email);
    if (_subscribedToAdminTopic == shouldBeSubscribed) return;
    _subscribedToAdminTopic = shouldBeSubscribed;

    final messaging = FirebaseMessaging.instance;
    if (shouldBeSubscribed) {
      debugPrint('PushNotificationService._syncAdminTopicSubscription: subscribing to $adminNotificationsTopic');
      await messaging.subscribeToTopic(adminNotificationsTopic);
    } else {
      debugPrint('PushNotificationService._syncAdminTopicSubscription: unsubscribing from $adminNotificationsTopic');
      await messaging.unsubscribeFromTopic(adminNotificationsTopic);
    }
  }

  Future<void> _handleMessage(RemoteMessage message) async {
    debugPrint('PushNotificationService._handleMessage: received message type=${message.data['type']}');
    if (message.data['type'] != _catalogUpdatedType) return;
    try {
      debugPrint('PushNotificationService._handleMessage: syncing catalog controller');
      await _ref.read(catalogControllerProvider.notifier).sync();
      debugPrint('PushNotificationService._handleMessage: foreground sync succeeded');
    } catch (error, stackTrace) {
      debugPrint('PushNotificationService._handleMessage: foreground sync failed error=$error');
      AppLogger.error('PushNotification', 'foreground sync failed', error: error, stackTrace: stackTrace);
    }
  }
}

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService(ref);
});
