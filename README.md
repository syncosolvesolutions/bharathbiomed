# Bharath Biomed Pharma

A tablet-only, landscape-locked, offline-first Flutter app for Bharath
Biomed's field sales team, plus an in-app admin section for managing the
product catalog and Medical Representative (MR) accounts.

For **what the app does** (features, user roles, business rules) see
[docs/BUSINESS_OVERVIEW.md](docs/BUSINESS_OVERVIEW.md) — that's the
cross-verification checklist. This README is the technical/setup side.

## What's in this repo

- **Flutter app** (`lib/`) — the sales catalog/slideshow app and the admin
  section, one codebase, one APK.
- **Cloud Functions** (`functions/`) — server-side logic for creating/deleting
  MR accounts (must run with the Admin SDK, not the client SDK — see
  [functions/src/index.ts](functions/src/index.ts)).
- **Firestore rules** (`firestore.rules`) — who can read/write what.
- `docs/` — business overview, Play Store submission checklist, privacy policy.

## Architecture

Riverpod for state/DI, go_router for navigation, a layered structure per
feature:

```
lib/
  domain/models/       Plain data classes (Product, Employee, Designation, UsageSession)
  data/
    local/              sqflite — the offline catalog cache + queued usage sessions
    remote/             Firestore/Storage/Cloud Functions calls, nothing else
    repositories/        Combine local+remote, own the business rules
  features/
    auth/                Sign-in (admin email or MR username/email), change/forgot password
    catalog/             Browse-by-department, multi-select, slideshow hand-off
    slideshow/           Full-screen swipeable/zoomable product viewer
    admin/               Product/department/designation CRUD, employee management, usage dashboard
    tracking/            MR app-open/close/location session tracking (admin-facing, MR-invisible)
    legal/               Bundled Terms & Conditions / Privacy Policy content + viewer
  core/
    auth/                Admin-email allowlist, MR username<->email translation
    router/              go_router config + auth/admin route guards
    error/                User-facing error message mapping, Crashlytics wiring
    connectivity/         Network status (informational only — see below)
```

**Offline-first is the load-bearing design decision**: `features/catalog` only
ever reads the local sqflite cache. The only place that talks to Firestore for
the sales flow is `ProductRepository.sync()`, triggered explicitly (login
screen or the in-app sync button) — never automatically. The admin section is
the exception: it always reads/writes Firestore directly, since the admin
needs to see and change current server data, not a stale local cache (see
`features/admin/admin_catalog_controller.dart`).

Each feature folder that predates the admin merge has its own `SKILL.md` with
more detail (`features/auth`, `features/catalog`, `features/slideshow`,
`core`, `data`) — read those before making non-trivial changes in that area.

## Prerequisites

- Flutter SDK (see `environment.sdk` in `pubspec.yaml` for the version range)
- A Firebase CLI login with access to the `bharathbiomedpharma-6c6c3` project
  (`firebase login`, then `firebase use bharathbiomedpharma-6c6c3`)
- Node.js 20+ (for `functions/`)

## Running the app

```bash
flutter pub get
flutter run
```

This is a tablet-only app (locked to landscape, fullscreen) — run it on a
tablet or a tablet-sized emulator/simulator for a representative layout.

## Testing

```bash
flutter analyze
flutter test
```

Unit/widget tests live under `test/`, mirroring the `lib/` structure. Repository
tests mock the remote/local data sources (mocktail) so they don't touch real
Firebase — see `test/data/repositories/` for the pattern to follow when adding
new repository methods.

## Backend: Cloud Functions & Firestore rules

Four admin actions — creating, editing, and deleting an MR account, and
resetting an MR's password — run as Cloud Functions instead of client-side
Firebase Auth calls, because the client SDK signs you in as whatever account
it just created/touched. Doing that from the admin's own device would sign
the admin out of their own session. The functions use the Admin SDK instead,
so the admin's session is never touched. See
[functions/src/index.ts](functions/src/index.ts): `createEmployee`,
`updateEmployee`, `deleteEmployee`, `resetEmployeePassword`.

**First-time setup / after changing `functions/` or `firestore.rules`:**

```bash
cd functions
npm install
npm run build      # compiles TypeScript -> lib/, catches type errors early
cd ..
firebase deploy --only functions,firestore:rules
```

Before deploying `firestore.rules` for the first time: this repo had no rules
file under version control until the admin merge, so whatever's live in the
Firebase console today is the actual source of truth. Diff the two before
deploying so you don't accidentally loosen or break existing access.

Cloud Functions require the Firebase project to be on the **Blaze**
(pay-as-you-go) plan — the free Spark plan can't run them. Blaze still has a
generous free tier; this app's realistic usage is unlikely to be billed.

## Admin access

Only the email in `lib/core/auth/admin_access.dart` (`adminEmails`) sees the
Admin section. That list is mirrored in two other places that actually
enforce it server-side — keep all three in sync if you ever change it:

- `lib/core/auth/admin_access.dart` (client UI gating)
- `functions/src/adminAccess.ts` (`ADMIN_EMAILS` — the real enforcement point)
- `firestore.rules` (`isAdmin()`)

## Medical Representative login

By default MRs don't get a real email address. The admin creates their
account with a first/last name; the app derives a username
(`first_lastname`, deduped with a numeric suffix on collision) and shows it
to the admin alongside the password to hand to that MR. Under the hood,
Firebase Auth still needs an email-shaped identifier, so the username is
turned into `mr-<username>@bharathbiomedpharma-6c6c3.firebaseapp.com` — see
`lib/core/auth/employee_login.dart` and `functions/src/adminAccess.ts`
(`usernameToEmail`), which must stay in sync.

The admin can optionally give an MR a **real** email instead (Add/Edit
Employee → Email). When set, that real email becomes the account's actual
Firebase Auth sign-in email — the MR then logs in with it directly (the
login field's `resolveLoginEmail` passes anything containing `@` through
unchanged), and Firebase's native "forgot password" email works for them.
Without one, only the admin can reset that MR's password
(`resetEmployeePassword`).

## MR usage tracking (location + time in app)

For MR accounts only (never the admin's), the app records each app open/close
as a `UsageSession` — timestamp, duration, and GPS location at open time (if
granted; foreground-only permission, no background location). This is
recorded locally (new `usage_sessions` sqflite table, see
`lib/data/local/app_database.dart`'s v2 migration) and uploaded to the
`UsageSessions` Firestore collection only when that device's owner syncs —
see `CatalogController.sync()` and `UsageSessionRepository.uploadPending()`.
The admin views it via the Usage Dashboard
(`lib/features/admin/usage_dashboard_screen.dart`). Full behavior and the
privacy/consent reasoning behind it are in
[docs/BUSINESS_OVERVIEW.md](docs/BUSINESS_OVERVIEW.md).

## Retired

`bharathbiomedpharma_admin` (a separate app/repo) is fully superseded by the
Admin section in this app and can be retired once you've verified the merged
flow end-to-end.
