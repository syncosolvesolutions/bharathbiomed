import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/notifications/push_notification_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_controller.dart';
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
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        tracking.handleAppPaused();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
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

    return MaterialApp.router(
      title: 'Bharath Biomed Pharma',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
