# Admin web console feature

A wide-layout desktop console for the admin — reachable by building this
same codebase for the web (`flutter build web`) instead of mobile. One
file, `admin_web_shell.dart`: a sidebar (grouped by section) + content
area that swaps in the **exact same screen widgets the mobile app already
uses** (`ManageEmployeesScreen`, `OrderApprovalScreen`, etc.) — every
controller, repository, and Firestore query is shared, unchanged, with
mobile. This folder adds zero new business logic; it's a navigation shell.

## How it's wired in

`core/router/app_router.dart`'s `/admin` route renders `AdminWebShell`
instead of `AdminHomeScreen` when `kIsWeb` is true — same route, same
`isAdminEmail`-gated redirect that already exists, so **every destination
in the shell is safe to show unconditionally**: nobody reaches `/admin` at
all (mobile or web) without already being the one hardcoded admin account
(see the shell's own doc comment, and `hasPermissionProvider`/
`hasGlobalVisibilityProvider`, both of which already auto-pass for
`isAdminProvider`).

## What had to change to make `kIsWeb` builds work at all

Scaffolding the web platform (`flutter create . --platforms web`) exposed
two real platform incompatibilities in code that was previously
mobile-only but sits on the shared `main.dart`/`app.dart` startup path:

- **`lib/core/notifications/push_notification_service.dart`** imported
  `dart:io` (for `Platform.isIOS`/`isAndroid`) — `dart:io` doesn't compile
  for web *at all*, so this broke the web build outright until switched to
  `defaultTargetPlatform` (`package:flutter/foundation.dart`, web-safe).
  `PushNotificationService.initialize()` also now returns immediately on
  `kIsWeb` — web push needs a service worker this project doesn't have,
  and the console has no offline catalog to re-sync on a push anyway.
- **Crashlytics has no web SDK at all** (unlike Analytics, which does
  support web) — `main.dart` now skips every Crashlytics call
  (`FlutterError.onError`, `PlatformDispatcher.instance.onError`,
  `CrashReporter.initialize()`) on `kIsWeb`, matching
  `CrashReporter`'s own doc comment, which already scoped itself to
  Android/iOS only.
- The mobile orientation lock / kiosk fullscreen mode
  (`SystemChrome.setPreferredOrientations`/`setEnabledSystemUIMode`) is
  also skipped on `kIsWeb` — meaningless for a browser tab.

Both `flutter build web` and `flutter build apk --debug` were run to
verify these changes (not just `flutter analyze`, which doesn't catch
platform-target-specific compile errors like the `dart:io` one above).

## Deploying — deliberately NOT done here

`firebase.json`'s `hosting.public` still points at `public/`, which serves
`public/privacy-policy.html` — the Play Store listing's live privacy
policy URL (see `docs/PLAY_STORE_CHECKLIST.md`). **This was deliberately
left untouched**: repointing hosting at `build/web` (the Flutter web
output) would either break that already-public URL or require Firebase
Hosting's multi-site feature, which needs a second Hosting site created in
the Firebase console — a real infrastructure action, not something to do
unilaterally from a code change. To actually deploy this console:

1. `firebase hosting:sites:create <admin-console-site-id>` (console/CLI
   action, one-time).
2. `firebase target:apply hosting admin-console <admin-console-site-id>`
   (one-time, maps a local name to that site).
3. Change `firebase.json`'s `hosting` key to an array with two entries —
   one keeping today's `public: "public"` config (the privacy policy,
   still on the default site), one with `"target": "admin-console"` and
   `"public": "build/web"`.
4. `flutter build web && firebase deploy --only hosting:admin-console`.

## Known scope limits

- **No parallel wide-layout redesign of each screen** — every destination
  is the literal mobile widget, tablet-oriented AppBars and all. This was
  the deliberate tradeoff for reusing 20+ screens' logic unchanged rather
  than rebuilding each one's presentation layer; a screen-by-screen
  desktop redesign is a plausible follow-up, not done here.
- **Admin-only** — a manager (Office Admin or otherwise) who isn't the
  hardcoded admin account still gets the mobile catalog+`/team` flow even
  on a web build, since `/team` isn't routed through this shell. Extending
  the shell to managers is a reasonable next step if office staff who
  aren't the admin need this too.
- **No offline support** — unlike the mobile app, this console always
  reads Firestore live (same as every embedded screen already did on
  mobile for admin/team data — nothing new here, just calling it out since
  "offline-first" is this app's headline design principle everywhere else).
