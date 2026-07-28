import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/connectivity/connectivity_provider.dart';
import 'core/error/app_logger.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/catalog/catalog_controller.dart';
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
        // connectivity listener above never sees a live offline→online
        // edge) — e.g. it was backgrounded while offline and connectivity
        // came back while it wasn't running at all.
        final connectivity = ref.read(connectivityProvider).value;
        if (connectivity != null && !NetworkStatus.isOffline(connectivity)) _autoSync('app resumed online');
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        tracking.handleAppPaused();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  /// Fires the same pull-and-push sync the login screen and manual sync
  /// button use, but automatically — the signed-in user just needs
  /// connectivity, no explicit tap. Best-effort: failures are logged, not
  /// surfaced, since this runs with no UI to report to.
  void _autoSync(String reason) {
    if (ref.read(authControllerProvider).value == null) return;
    debugPrint('BharathBioMedApp._autoSync: triggering sync ($reason)');
    unawaited(
      ref.read(catalogControllerProvider.notifier).sync().catchError((Object error, StackTrace stackTrace) {
        AppLogger.error('BharathBioMedApp', 'auto-sync failed ($reason)', error: error, stackTrace: stackTrace);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    // Covers cold start with an already-persisted session (no lifecycle
    // transition fires in that case, since the app starts "resumed") and a
    // fresh sign-in while already running.
    ref.listen<AsyncValue<User?>>(authControllerProvider, (previous, next) {
      final user = next.value;
      if (user != null) {
        ref.read(usageTrackingServiceProvider).handleAppResumed(user);
      }
    });

    // Requirement: a signed-in user works offline when there's no network,
    // and gets synced (both pulling fresh data and pushing anything queued
    // locally) as soon as connectivity comes back — without needing to open
    // the app to a specific screen or tap a button. Only fires on a genuine
    // offline→online edge (both `previous` and `next` must already have a
    // value), so it never double-fires alongside the explicit sync that
    // already happens right after sign-in.
    ref.listen<AsyncValue<List<ConnectivityResult>>>(connectivityProvider, (previous, next) {
      final previousResults = previous?.value;
      final nextResults = next.value;
      if (previousResults == null || nextResults == null) return;
      final cameBackOnline = NetworkStatus.isOffline(previousResults) && !NetworkStatus.isOffline(nextResults);
      if (cameBackOnline) _autoSync('connectivity restored');
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
          child: child,
        );
      },
    );
  }
}
