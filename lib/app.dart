import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/connectivity/connectivity_provider.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/sync/sync_controller.dart';
import 'features/sync/sync_overlay.dart';
import 'features/tracking/usage_tracking_service.dart';

/// App root: theme + go_router wiring, plus the app-lifecycle hooks that
/// drive MR usage-session tracking (see features/tracking/). All
/// Firebase/error-handling setup happens in main.dart before this widget is
/// ever built.
class BharathBioMedApp extends ConsumerStatefulWidget {
  const BharathBioMedApp({super.key});

  @override
  ConsumerState<BharathBioMedApp> createState() => _BharathBioMedAppState();
}

class _BharathBioMedAppState extends ConsumerState<BharathBioMedApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Remove the native splash once this root widget has its first frame,
    // regardless of which route the router lands on first — a signed-in
    // user is redirected straight past LoginScreen (the only other place
    // that used to call this), so splash removal can't live there alone.
    WidgetsBinding.instance.addPostFrameCallback((_) => FlutterNativeSplash.remove());
    // Best-effort, fire-and-forget: subscribes this device to catalog-update
    // pushes and wires up foreground/tap handling. A failure here (denied
    // permission, no Google Play services) shouldn't block the app itself —
    // the manual sync button still works either way.
    unawaited(ref.read(pushNotificationServiceProvider).initialize());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final tracking = ref.read(usageTrackingServiceProvider);
    switch (state) {
      case AppLifecycleState.resumed:
        tracking.handleAppResumed(ref.read(authControllerProvider).value);
        // Covers reopening the app when it was already online (so the
        // connectivity listener below never sees a live offline→online
        // edge) — e.g. it was backgrounded while offline and connectivity
        // came back while it wasn't running at all.
        final connectivity = ref.read(connectivityProvider).value;
        if (connectivity != null && !NetworkStatus.isOffline(connectivity)) _checkForUpdates('app resumed online');
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        tracking.handleAppPaused();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  /// Checks whether there's anything to sync (new server data, and/or data
  /// queued locally) and — if so — surfaces the tappable banner from
  /// [SyncAvailableBanner]. Never syncs by itself: the actual pull-and-push
  /// only runs when the signed-in user taps the banner (or the manual sync
  /// button), per [SyncController.startSync].
  void _checkForUpdates(String reason) {
    if (ref.read(authControllerProvider).value == null) return;
    debugPrint('BharathBioMedApp._checkForUpdates: checking for updates ($reason)');
    unawaited(ref.read(syncControllerProvider.notifier).checkForUpdates());
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final syncState = ref.watch(syncControllerProvider);

    // Covers cold start with an already-persisted session (no lifecycle
    // transition fires in that case, since the app starts "resumed") and a
    // fresh sign-in while already running. Also the first point a
    // just-resolved signed-in session can trigger an update check.
    ref.listen<AsyncValue<User?>>(authControllerProvider, (previous, next) {
      final user = next.value;
      if (user != null) {
        ref.read(usageTrackingServiceProvider).handleAppResumed(user);
        _checkForUpdates('auth resolved');
      }
    });

    // A signed-in user works offline when there's no network; as soon as
    // connectivity comes back, check whether there's anything new to sync
    // and — if so — show the tappable banner rather than syncing silently.
    // Only fires on a genuine offline→online edge (both `previous` and
    // `next` must already have a value).
    ref.listen<AsyncValue<List<ConnectivityResult>>>(connectivityProvider, (previous, next) {
      final previousResults = previous?.value;
      final nextResults = next.value;
      if (previousResults == null || nextResults == null) return;
      final cameBackOnline = NetworkStatus.isOffline(previousResults) && !NetworkStatus.isOffline(nextResults);
      if (cameBackOnline) _checkForUpdates('connectivity restored');
    });

    return MaterialApp.router(
      title: 'Bharath Biomed Pharma',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
      builder: (context, child) {
        return GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              if (child != null) child,
              if (syncState.availability.hasSomethingToSync && !syncState.isSyncing)
                const Positioned(top: 0, left: 0, right: 0, child: SyncAvailableBanner()),
              if (syncState.progress != null) SyncProgressOverlay(progress: syncState.progress!),
            ],
          ),
        );
      },
    );
  }
}
