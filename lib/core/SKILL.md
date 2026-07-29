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
- `tenant/tenant_config.dart` — `TenantConfig`/`currentTenant`: every value
  that varies per pharma-company deployment. See its own doc comment and
  `tenants/<tenantId>/tenant.json` / `scripts/apply_tenant.dart`.
- `utils/report_export_service.dart` + `widgets/export_menu_button.dart` —
  the shared "Export" action used by every dashboard that offers CSV/PDF
  export (Usage Dashboard, RCPA Dashboard, Team Targets). Both
  hand off to the OS share sheet (`share_plus`/`printing`) rather than
  writing to app storage — this app doesn't otherwise touch the
  filesystem for user-facing files. `ExportMenuButton` owns its own
  in-flight spinner and error snackbar; a call site only supplies the two
  export callbacks (typically `ref.read(reportExportServiceProvider)
  .exportCsv(...)`/`.exportSimpleTablePdf(...)` with that screen's own
  row-building logic — see any of the four screens above for the pattern).
  `exportSimpleTablePdf` only covers a single-table report; anything more
  elaborate should build a `pw.Document` directly and call `sharePdf`.
