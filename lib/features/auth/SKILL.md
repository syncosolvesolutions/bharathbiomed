# Auth feature

Firebase-email/password sign-in, used only to unlock the "sync" action — this
app is designed to be used offline day-to-day (see `catalog/SKILL.md`).

## Files

- `auth_controller.dart` — `authControllerProvider` (`AsyncNotifier<User?>`).
  `build()` returns the current Firebase user (if any); `signIn()` /
  `signOut()` drive it. Also exposes `authStateChangesProvider`, the raw
  Firebase stream, which `core/router/app_router.dart` watches to skip the
  login screen when a session already exists on launch.
- `login_screen.dart` — the only screen with two entry points:
  - **Continue Offline** (primary): opens the catalog using whatever was
    last synced. If nothing has ever been synced, this tells the user to
    sign in first instead of silently trying the network.
  - **Sign in to sync data** (secondary, collapsed by default): authenticates,
    then immediately calls `catalogControllerProvider.notifier.sync()` and
    reports success/failure before continuing to the catalog.

## Extending

- New sign-in methods (SSO, phone, etc.) belong in `data/remote/auth_remote_data_source.dart`
  and `data/repositories/auth_repository.dart` — `AuthController` and the UI
  shouldn't need to know which method was used.
- Don't add logic here that decides *what* to sync — that belongs to
  `features/catalog/catalog_controller.dart`. This feature only answers "is
  the user allowed to trigger a sync".
