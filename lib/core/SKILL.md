# Core

Cross-cutting building blocks shared by every feature. Nothing here should
import from `features/`.

## Files

- `router/app_router.dart` — go_router setup. `GoRouterRefreshStream` bridges
  `authStateChangesProvider`'s stream into a `Listenable` so the router
  re-evaluates its `redirect` whenever Firebase's auth state changes (used to
  skip the login screen if a session already exists on launch). The redirect
  only ever pushes an already-authenticated user off `/login` — it never
  forces a logged-out user off `/catalog`, since offline catalog access
  without signing in is intentional.
- `theme/app_theme.dart` — single source of the app's color/typography.
- `error/crash_reporter.dart` — Crashlytics wiring + device identification.
  Only handles Android/iOS (the two platforms this app actually ships to,
  see `android/`, `ios/`).
- `connectivity/connectivity_provider.dart` — network status. Purely
  informational (shown on the login screen); nothing in `features/` gates
  behavior on it. See `features/catalog/SKILL.md` for why.
- `utils/validators.dart` — form-field validators shared across auth forms.
