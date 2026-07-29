# Bharath Biomed Pharma

A tablet-only, offline-first Flutter app for a pharma field sales team —
catalog/slideshow presentation, doctor visits, orders, RCPA, expenses,
and more — plus an in-app admin section and a separate desktop web
console (same codebase, `flutter build web`) for office staff. Portrait
and landscape are both supported everywhere except the slideshow
presentation screen, which stays landscape-only (see
[features/slideshow/SKILL.md](lib/features/slideshow/SKILL.md)). White-
label: every company-specific value (branding, admin identity, business
defaults) comes from `tenants/<tenantId>/tenant.json`, not hardcoded — see
[core/tenant/tenant_config.dart](lib/core/tenant/tenant_config.dart).

For **what the mobile/admin app does** (features, user roles, business
rules) see [docs/BUSINESS_OVERVIEW.md](docs/BUSINESS_OVERVIEW.md) — note
it predates most of the feature folders below (see its own note in
`docs/TODO.md`); each feature's `SKILL.md` is the accurate source until
that doc gets a refresh pass. This README is the technical/setup side.

## What's in this repo

- **Flutter app** (`lib/`) — the mobile sales/admin app, the web admin
  console (`features/admin_web/`), one codebase across both.
- **Cloud Functions** (`functions/`) — server-side logic for creating/deleting
  MR accounts, dispatch/invoicing/payments, and tenant-generated config
  (must run with the Admin SDK, not the client SDK — see
  [functions/src/index.ts](functions/src/index.ts)).
- **Firestore rules** (`firestore.rules`) — who can read/write what.
- **`tenants/`** — one `tenant.json` (+ `tenant.properties`) per pharma
  company deployment; `scripts/apply_tenant.dart`/`scripts/new_tenant.sh`
  turn one into a branded build — see
  [core/tenant/tenant_config.dart](lib/core/tenant/tenant_config.dart)'s
  doc comment for the full mechanism.
- `docs/` — business overview, Play Store submission checklist, privacy
  policy, and a [per-tenant data export runbook](docs/DATA_EXPORT_RUNBOOK.md)
  (a buyer-trust deliverable: any tenant can get their own data out on
  request).

## Architecture

Riverpod for state/DI, go_router for navigation, a layered structure per
feature:

```
lib/
  domain/models/       Plain data classes (Product, Employee, Designation, Order,
                        ExpenseClaim, RcpaEntry, Doctor, Agency, Pharmacy, ...)
  data/
    local/              sqflite — the offline catalog cache + every feature's
                        queued-for-upload local tables (usage sessions, orders,
                        expense claims, visit logs, RCPA entries, ...)
    remote/             Firestore/Storage/Cloud Functions calls, nothing else
    repositories/        Combine local+remote, own the business rules — one per
                        feature, wired together in data/providers.dart
  features/
    auth/                Sign-in (admin email or MR username/email), change/forgot password
    catalog/             Browse-by-department, multi-select, slideshow hand-off
    slideshow/           Full-screen swipeable/zoomable product viewer (landscape-only,
                        see its own SKILL.md — the rest of the app is portrait+landscape)
    admin/               Product/department/designation CRUD, employee management, usage
                        dashboard, batch/expiry inventory tracking — see its SKILL.md
    doctors/             Doctor master data, weekly visit plans (+ manager approval
                        workflow) and daily visit-log capture — see its SKILL.md
    agencies/, pharmacies/  Distributor/chemist master data an MR orders against or audits
    entity_requests/     An MR's proposed new agency/pharmacy, pending Office Admin (or an
                        approve_requests holder) review
    orders/              MR order-booking + team approve/dispatch workflow, ending at the
                        MR's own delivery confirmation — see its SKILL.md
    rcpa/                Retail Chemist Prescription Audit entries + team dashboard
    expenses/            TA/DA expense claims + team approval workflow (mirrors orders/,
                        see its own SKILL.md for how the two patterns differ)
    compliance/            UCPMP compliance logging (gifts/samples/sponsorships
                        given to doctors) — see its SKILL.md
    targets/             Monthly sales targets + live achievement tracking
    team/                A manager's rollup views across their reporting-chain downline
                        (usage/location, visit logs, orders, targets, RCPA, expenses)
    reminders/            Due-date reminders for the signed-in user
    tracking/            MR app-open/close/location session tracking (admin-facing, MR-invisible)
    sync/                 The "new data available" banner/progress overlay driving
                        CatalogController.sync — see the offline-first note below
    legal/               Bundled Terms & Conditions / Privacy Policy content + viewer
                        (tenant-templated, see core/tenant/ below)
    admin_web/             The web-build desktop admin console — a navigation
                        shell reusing every admin/team screen above unchanged,
                        see its SKILL.md
  core/
    auth/                Admin-email allowlist (tenant-sourced), MR username<->email translation
    tenant/               TenantConfig — every value that varies per pharma-company
                        deployment (branding, admin emails, defaults); see
                        tenants/<tenantId>/tenant.json and scripts/apply_tenant.dart
    hierarchy/            Reporting-chain/permission resolution shared by every
                        "my team" screen (see features/team/team_access.dart)
    router/               go_router config + auth/admin route guards
    error/                User-facing error message mapping, Crashlytics wiring
    connectivity/         Network status (informational only — see below)
    notifications/        FCM topic subscription + per-user targeted push
    utils/report_export_service.dart, widgets/export_menu_button.dart
                        Shared CSV/PDF "Export" action used by several
                        dashboards — see core/SKILL.md
```

Each feature folder above that has non-obvious rules or extension points has
its own `SKILL.md` — read the relevant one before making a non-trivial change
there rather than relying on this table alone.

**Offline-first is the load-bearing design decision**: `features/catalog` only
ever reads the local sqflite cache. The only place that talks to Firestore for
the sales flow is `ProductRepository.sync()`, triggered explicitly (login
screen or the in-app sync button) — never automatically. The admin section is
the exception: it always reads/writes Firestore directly, since the admin
needs to see and change current server data, not a stale local cache (see
`features/admin/admin_catalog_controller.dart`).

## Prerequisites

- Flutter SDK (see `environment.sdk` in `pubspec.yaml` for the version range)
- A Firebase CLI login with access to the `bharathbiomed-14368` project
  (`firebase login`, then `firebase use bharathbiomed-14368`)
- Node.js 20+ (for `functions/`)

## Running the app

```bash
flutter pub get
flutter run
```

This is a tablet-only app on Android/iOS (kiosk-style fullscreen; portrait
and landscape both supported except the slideshow, which stays
landscape-only) — run it on a tablet or a tablet-sized emulator/simulator
for a representative layout.

### Running the web admin console

```bash
flutter run -d chrome
```

Lands on the login screen like mobile; signing in with the admin account
routes to `AdminWebShell` (see
[features/admin_web/SKILL.md](lib/features/admin_web/SKILL.md)) instead of
the mobile admin home screen — same login, same Firebase project, no
separate setup. That SKILL.md also covers what deploying this to Firebase
Hosting actually requires (deliberately not automated here).

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
turned into `mr-<username>@bharathbiomed-14368.firebaseapp.com` — see
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
