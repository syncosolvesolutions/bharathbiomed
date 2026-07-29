# Pre-launch TODO — testing, verification, Play Store

Snapshot as of 2026-07-27. Checked by running `flutter test`, `flutter analyze`,
and reading every test/feature file in the repo. Update this file's checkboxes
as items get done — don't let it go stale.

## 1. Testing gaps

Current state: 24 unit/widget tests (using `mocktail` for mocking) covering
auth + catalog basics, plus one on-device functional test that also takes
screenshots. Nothing else has coverage.

- [ ] **Admin module unit tests** (`lib/features/admin/` — 13 files, biggest
      untested surface in the app):
  - [ ] `employee_controller.dart`, `designation_controller.dart`,
        `admin_catalog_controller.dart`, `usage_dashboard_controller.dart` —
        test state transitions with mocked repositories (mocktail), same
        pattern as `test/features/catalog/selection_controller_test.dart`.
  - [ ] `usage_format.dart` — pure function, easy pure-unit test for
        edge cases (zero duration, >24h duration, null end time).
- [ ] **Repository unit tests** for the new repositories, mocking the remote
      data source (same pattern as `auth_repository_test.dart`):
  - [ ] `designation_repository.dart`
  - [ ] `employee_repository.dart`
  - [ ] `usage_session_repository.dart`
  - [ ] Include failure-path cases: remote throws / offline / permission
        denied — these aren't tested anywhere today, only the happy path is.
- [ ] **Tracking module tests** (`lib/features/tracking/`):
  - [ ] `location_service.dart` — test permission-denied and
        location-unavailable branches with a fake/mocked platform channel.
  - [ ] `usage_tracking_service.dart` — test session start/stop/duration
        math without touching real GPS or Firestore.
- [ ] **Auth additions**:
  - [ ] `change_password_screen.dart` — widget test for validation errors
        (mismatched confirmation, weak password, wrong current password).
- [ ] **Cloud Functions** (`functions/src/adminAccess.ts`, `index.ts` —
      `createEmployee` / `deleteEmployee`): currently zero tests. Use the
      Firebase emulator + a Jest/Mocha test hitting the callable functions
      to verify: non-admin caller is rejected, duplicate employee email is
      rejected, delete removes both Auth user and Firestore doc.
- [ ] **Load / stress testing** (none exists — worth doing before rollout
      to many field reps):
  - [ ] Seed the local SQLite cache (`app_database.dart`) with a large
        product catalog (500–1000+ products) and confirm catalog list/scroll
        stays smooth and sync time is acceptable.
  - [ ] Cloud Functions: simulate concurrent `createEmployee` calls (e.g. a
        small script firing 20–50 parallel requests) to confirm no race
        condition creates duplicate employees or double-charges Auth quota.
  - [ ] Firestore read volume: check the security rules (`firestore.rules`)
        and query patterns don't cause N+1 reads at catalog-sync time as
        product count grows.
- [ ] **Widen the functional/integration flow** in
      `integration_test/app_screenshot_test.dart` (or a sibling file) to also
      exercise: admin login → create employee → assign designation → manage
      departments → usage dashopard, and the offline-mode path (airplane
      mode, cached catalog still browsable). Today it only covers the MR
      login → catalog → slideshow path.

## 2. Functionality / production-grade verification

- [x] `flutter analyze` — clean, no issues.
- [x] `flutter test` — 24/24 passing.
- [ ] Manually walk every screen as **both** an MR (field rep) and an Admin
      account on a real device, specifically:
  - [ ] Offline-first: force airplane mode mid-session, confirm catalog and
        selection state survive and slideshow still works.
  - [ ] Employee create/edit/delete end-to-end against real Firestore +
        Cloud Functions (not just emulator).
  - [ ] Department / designation create-edit-delete, then confirm catalog
        product forms reflect changes immediately.
  - [ ] Usage dashboard numbers match actual tracked session data (spot
        check one MR's login/logout against Firestore).
  - [ ] Change-password flow with a real account, then confirm re-login
        with the new password.
  - [ ] Legal screens (`legal_document_screen.dart`) open the correct terms
        / privacy content and back-navigation works.
- [ ] Confirm `firestore.rules` actually denies non-admin writes to
      employee/designation collections (test this from a non-admin signed-in
      session, not just by reading the rules file).
- [ ] Crashlytics + Analytics: trigger one deliberate error per major flow
      (bad login, failed image upload) and confirm it shows up in Firebase
      Console — verifies wiring, not just that the SDK is imported.
- [ ] Reconcile `docs/PLAY_STORE_CHECKLIST.md`, which says version
      `1.0.0+4`, against `pubspec.yaml`, which currently says `1.0.0+1` —
      decide which is correct before building the release bundle.
- [ ] Revisit the Data Safety table in `docs/PLAY_STORE_CHECKLIST.md`: it
      says "no user-facing account deletion flow exists" — confirm that's
      still true now that the admin/employee module exists, and if Play
      Console requires a deletion path/URL, add one.

## 3. Screenshots for Play Store

Existing (`./screenshots/`, captured 2026-07-26): `01_login.png`,
`02_catalog.png`, `03_catalog_selected.png`, `04_slideshow.png`. This clears
Play Store's bare minimum (2 required, 8 max for phone), but doesn't
represent the admin/tracking/legal side of the app at all.

- [ ] Extend `integration_test/app_screenshot_test.dart` (or add a second
      script, e.g. `app_screenshot_admin_test.dart`) to capture, at minimum:
  - [ ] Admin home screen
  - [ ] Manage employees screen (list)
  - [ ] Employee form screen (create/edit)
  - [ ] Manage designations screen
  - [ ] Manage departments screen
  - [ ] Product form screen
  - [ ] Usage dashboard screen
  - [ ] Employee sessions screen
  - [ ] Change password screen
  - [ ] A legal document screen (terms or privacy)
- [ ] Re-run the existing MR-flow screenshot test after any UI changes so
      `01`–`04` stay current (the checklist doc already documents the
      command: `flutter drive --driver=test_driver/integration_test.dart
      --target=integration_test/app_screenshot_test.dart -d <deviceId>
      --dart-define=TEST_EMAIL=... --dart-define=TEST_PASSWORD=...`).
- [ ] Pick the best 6–8 across both MR and Admin flows for the actual Play
      Store listing (Play Store doesn't require every screen — but with an
      admin module this size, showing only the MR flow undersells the app).
- [ ] Feature graphic (1024×500) — not automated, needs to be designed
      separately; not currently in the repo.

## 4. Play Store submission (from `docs/PLAY_STORE_CHECKLIST.md` — unchanged, still applies)

- [ ] Generate upload keystore, create `android/key.properties` (you hold
      the password — not something that can be automated here).
- [ ] `flutter build appbundle --release`.
- [ ] Fill in Data Safety form (update per the item in section 2 above).
- [ ] Host `docs/PRIVACY_POLICY.md` at a public URL, paste into Play
      Console.
- [ ] Upload screenshots from section 3, plus feature graphic.
- [ ] Submit to **Internal testing** track first, verify on a real device,
      then promote to Production.

## 5. Production-grade review (2026-07-27, second pass)

A full read-through of the admin, data/backend, and auth/tracking/routing
layers turned up real bugs, which are now fixed and verified (`flutter
analyze` clean, `flutter test` 26/26 passing, Cloud Functions `tsc` build
clean):

- [x] Router crash: `state.extra as T` casts on `/slideshow`,
      `/admin/departments/products`, `/admin/employees/edit`,
      `/admin/products/edit`, `/admin/dashboard/sessions` would crash if
      Android killed the app and restored the last route without `extra`.
      Now redirects to a safe parent screen instead.
- [x] `createEmployee`/`updateEmployee` Cloud Functions could leave an
      orphaned Auth account or an Auth/Firestore mismatch if the second step
      failed after the first succeeded. Now compensates (deletes the
      just-created Auth user / rolls back the email change) on failure.
- [x] Designation and department names had no duplicate check — two entries
      with the same name (case-insensitive) could exist side by side and be
      indistinguishable in dropdowns. Now rejected with a clear error.
- [x] Employee form's optional email field had no format validation.
- [x] `image_uploader.dart` only enforced the 16:9 crop when the picked
      image was *smaller* than the minimum size — a large wrong-aspect image
      skipped cropping and uploaded distorted. Now aspect ratio is always
      checked.
- [x] Delete/reset-password buttons in Manage Employees had no in-flight
      state — rapid taps could fire duplicate Cloud Function calls. Now
      shows a spinner and disables the row while a call is in flight.
- [x] `usage_format.dart` treated a negative duration (clock skew / corrupt
      data) as `<1m` instead of flagging it — now shows `invalid`.
- [x] Reaching Change Password while signed out threw a raw `Bad state: No
      signed-in user...` string. Now guarded by the router and given a
      proper user-facing message.
- [x] `firestore.rules`: an MR could rewrite `openedAt`/`latitude`/
      `longitude` on their own usage-session doc after creation, fabricating
      usage history. Now locked to only allow `closedAt`/`durationSeconds`
      changes after creation. **Requires `firebase deploy --only
      firestore:rules` to take effect** — a code change alone doesn't ship
      new rules.
- [x] Department-rename/delete migration and usage-session upload both used
      a single Firestore batch, which hard-caps at 500 writes — silently
      failing partway through past that size. Both now chunk into batches.

### Not changed — needs your call, not a silent fix

- **Admin identity is hardcoded in 3 places** (`lib/core/auth/admin_access.dart`,
  `firestore.rules`, `functions/src/adminAccess.ts`), kept in sync only by
  code comments. Works today, but a future admin-email change means editing
  and redeploying all three in lockstep. A custom-claims-based admin flag
  would remove the duplication, but that's an auth architecture change I
  didn't want to make without your sign-off and a real device test.
- **New-password complexity**: only a 6-character minimum is enforced
  (matches Firebase's own floor). Tightening this is a product decision,
  not a bug.
- **No image compression pipeline** — `image_uploader.dart` only enforces a
  minimum resolution/aspect ratio, not a max file size. Fine at current
  catalog size; worth revisiting if product photos start ballooning device
  storage.

### Missing crucial functionality (not bugs — gaps worth deciding on)

- ~~No way to deactivate/reactivate an employee~~ — **done 2026-07-27**: see
  §6 below (suspend/reactivate).
- ~~No search/filter... (employees, products, designations, departments)~~ —
  **done 2026-07-27**: see §6 below. Usage-session list (inside "Employee
  Sessions", per-employee drill-down) still has no search — low priority
  since it's already scoped to one employee. No pagination anywhere yet —
  still a gap if any list grows into the thousands.
- No screen for an MR to see their own past usage sessions (admin-only
  today).
- No "N sessions pending upload" indicator for the offline usage-tracking
  queue.
- No self-service username recovery for MRs without a real email on file —
  **narrowed 2026-07-27**: email is now mandatory for every MR going
  forward (see §6), so this only affects employees created before that
  change until an admin edits their profile and adds one.

## 6. Email-mandatory, suspend/reactivate, search & filters (2026-07-27, third pass)

Implemented per your request. Verified with `flutter analyze` (clean),
`flutter test` (26/26 passing), and a clean Cloud Functions `tsc` build.

- [x] **Email is now mandatory for every MR.** Enforced in both places that
      matter: `employee_form_screen.dart` (the field is no longer optional,
      validated with `Validators.email`) and, more importantly, server-side
      in `createEmployee`/`updateEmployee` (`functions/src/index.ts`) — a
      modified client can't skip it. Existing employees created before this
      change keep working via their synthetic username-based login until an
      admin edits their profile and adds a real email (at which point the
      form will require one).
- [x] **Suspend / reactivate for MRs**, as an alternative to permanently
      deleting an account:
  - New `setEmployeeStatus` Cloud Function (admin-only, same
    `requireAdmin`/`requireMrUserDoc` guards as the others) flips Firebase
    Auth's `disabled` flag and mirrors it onto the Firestore profile, with
    rollback if the second write fails (same pattern as the
    `createEmployee`/`updateEmployee` fixes from §5).
  - A suspended MR's sign-in is rejected by Firebase itself with
    `user-disabled`, already shown to them as "This account has been
    disabled. Contact your administrator." (see `UserFacingError`) — no new
    client-side error handling needed.
  - `Employee.disabled` (default `false`) now round-trips through
    Firestore; Manage Employees shows a red "Suspended" badge and a
    suspend/reactivate icon button (with the same in-flight busy-guard as
    delete/reset-password).
- [x] **Search added to every admin list**: Manage Employees (name,
      username, area, designation, email), Manage Designations, Manage
      Departments, Department Products (product name within a department),
      and Usage Dashboard (employee name/username/area). All filter
      client-side against the already-fetched list — no new network calls.
- [x] **Account-status filter on Manage Employees**: All / Active /
      Suspended, combinable with the search box.

Not done: pagination (still just filtering an already-fetched list — fine
at current team/catalog size, revisit if any list grows past a few hundred
rows) and a search box on the per-employee session-history drill-down
(low-value since that list is already scoped to one employee).

## 7. Push notifications for catalog sync (2026-07-27, fourth pass)

Every device now auto-syncs when the admin changes the catalog, instead of
relying on a field rep noticing and tapping the manual sync button.
Verified with `flutter analyze` (clean) and a clean Cloud Functions `tsc`
build.

- [x] Client subscribes every device to the `catalog-updates` FCM topic on
      launch (`lib/core/notifications/push_notification_service.dart`) —
      topic broadcast, not per-device token storage, so there's nothing to
      register/refresh/garbage-collect per device.
- [x] New `onProductsChanged` / `onDepartmentsChanged` Cloud Functions
      (`functions/src/index.ts`) fire on any `Products`/`Department` write
      and push to that topic. Debounced 15s via a `CatalogMeta/pushState`
      doc + transaction, so a bulk edit (e.g. `renameDepartment`, which can
      touch hundreds of product docs) sends one notification instead of a
      burst.
- [x] Receiving the push re-runs `ProductRepository.sync()` — in the
      foreground/background via `PushNotificationService`, and when fully
      terminated via the top-level `firebaseMessagingBackgroundHandler`
      registered in `main.dart`.
- [x] Android: `POST_NOTIFICATIONS` permission + default notification
      channel/icon meta-data added to `AndroidManifest.xml`.
- [x] iOS: `UIBackgroundModes: remote-notification` added to `Info.plist`.

### Manual steps still required before this works end-to-end

- [ ] **Deploy**: `firebase deploy --only functions` ships the two new
      triggers — nothing sends until this runs.
- [ ] **iOS only**: enable the Push Notifications and Background Modes
      (Remote notifications) capabilities for the Runner target in Xcode
      (Signing & Capabilities) — this generates `Runner.entitlements` and
      wires it into the build settings, which can't be done from a plain
      text edit. Then upload an APNs Authentication Key for this project in
      the Firebase console (Project settings → Cloud Messaging). Without
      this, iOS devices won't receive the push at all (Android needs
      neither step).
- [ ] Real-device check: change a product as admin, confirm a second device
      (MR login) gets the push and its catalog updates without anyone
      tapping sync.

## 8. White-label foundation, orientation support, and roadmap builds (2026-07-29)

Working through the "white-label + full gap closure" roadmap (see the plan
this session was executed from, or re-derive it from the git history around
this date if the plan file itself isn't checked in). Verified with `flutter
analyze` (clean), `flutter test` (all passing), and a clean Cloud Functions
`tsc` build throughout.

- [x] **Tenant config foundation** — every previously-hardcoded
      Bharath-Biomed-specific value (admin emails, app name/colors, default
      password, support email, legal jurisdiction, designation ladder,
      Firebase project id, Android app id/label) now comes from
      `tenants/<tenantId>/tenant.json` via `lib/core/tenant/tenant_config.dart`
      and `scripts/apply_tenant.dart`/`scripts/new_tenant.sh`. See those
      scripts' own doc comments for the onboarding workflow.
- [x] **Portrait + landscape support** — the app now supports both
      orientations everywhere except the slideshow presentation screen,
      which forces landscape on entry and restores on exit (see
      `features/slideshow/SKILL.md`).
- [x] **Expense claims (Phase 3 of the roadmap)** — TA/DA claims with an
      approval workflow, following the existing `Order`
      offline-first-queue-then-approve pattern. See
      `features/expenses/SKILL.md`.
- [x] **Beat/route (weekly visit) plan approval (Phase 3)** — a manager
      approve/reject workflow added on top of the existing
      `DoctorVisitPlans` doc, gated by the previously-unused
      `approve_requests` permission. See `features/doctors/SKILL.md`.
- [x] **Leave requests (Phase 3)** — structurally identical to expense
      claims. See `features/leave/SKILL.md` (also notes what's
      deliberately not built: leave-balance tracking, a team leave
      calendar, and any interaction with attendance/usage-session data).
- [x] **Attendance (Phase 3)** — a pure derived view over existing
      `UsageSession` records, no new backend surface. Also closes an
      older-flagged gap: an MR can now see their own usage-session history
      (`/attendance`), previously admin/manager-only. See
      `features/attendance/SKILL.md`.
- [x] **Batch/expiry inventory tracking (Phase 3)** — an optional layer on
      top of the existing flat `stockQuantity`, plus FEFO-aware dispatch
      and an expiry-alerts view. See `features/admin/SKILL.md`, which also
      flags a known gap: Office Admins can't reach these screens today
      (admin-allowlist-gated routes) despite already having the Firestore
      rules permission to manage them.
- [x] **UCPMP compliance log (Phase 3 — final item, Phase 3 now complete)**
      — append-only gift/sample/sponsorship logging per doctor, with a
      per-doctor (not per-MR) team dashboard flagging anyone over
      `TenantConfig.ucpmpAnnualLimitPerDoctor`. The limit is a dashboard
      flag only, never a block on logging — see `features/compliance/SKILL.md`.
      Added a new tenant-config field (`ucpmpAnnualLimitPerDoctor`, default
      `0`), so `scripts/apply_tenant.dart` and `tenants/bharathbiomed/tenant.json`
      changed too.
- [x] **Order/invoice tax & payment depth (Phase 4)** — `generateInvoice`
      now bakes in a tenant-configurable tax rate (`TenantConfig.taxLabel`/
      `taxRatePercent`, new `functions/src/generatedTenantConfig.ts` for
      the Cloud-Functions-side twin); a new `recordPayment` Cloud Function
      + `Payments` collection track `PaymentStatus`
      (unpaid/partial/paid) and a derived `Invoice.isOverdue`. See
      `features/orders/SKILL.md`.
  - Deliberately **not built** in this pass (see the same SKILL.md's "Not
    built" section): a primary-vs-secondary-sales distinction (would need
    orders placeable against a `Pharmacy`, not just an `Agency` — a
    genuinely different feature, not a same-shape field on `Order`), and
    accounting-ledger CSV export (belongs with Phase 5's reporting/export
    infra, not built standalone here).
- [x] **Reporting & exports (Phase 5)** — a shared `ReportExportService`
      (`core/utils/`) + `ExportMenuButton` (`core/widgets/`) added CSV and
      formatted-PDF export to the Usage Dashboard, RCPA Dashboard, Team
      Targets, and Invoices screens, via the OS share sheet (`csv`/`pdf`/
      `printing` packages — new native dependencies, verified with a real
      `flutter build apk --debug`, not just `flutter analyze`). See
      `core/SKILL.md`.
  - Not built: trend/period-over-period comparison views (the roadmap's
    other Phase 5 idea) — the export infra above was the higher-value
    half of this phase; trend views are a smaller follow-up whenever
    picked up.
- [x] **Admin web console (Phase 6)** — `flutter build web` now works;
      `AdminWebShell` (`features/admin_web/`) is a wide-layout navigation
      shell reusing every admin/team screen unchanged, wired in at the
      `/admin` route when `kIsWeb`. Scaffolding the web platform surfaced
      two real platform bugs on the shared startup path (fixed, and
      verified with actual `flutter build web`/`flutter build apk --debug`
      runs, not just `flutter analyze`): `push_notification_service.dart`
      imported `dart:io` (doesn't compile for web at all — switched to
      `defaultTargetPlatform`), and Crashlytics (no web SDK) was being
      called unconditionally in `main.dart`. See
      `features/admin_web/SKILL.md`, which also explains why actually
      deploying this to Firebase Hosting was left as a documented manual
      step rather than done here (repointing `hosting.public` risks
      breaking the already-public Play Store privacy-policy URL).
  - [ ] **Manual step**: `firebase hosting:sites:create` + hosting target
        setup + `firebase deploy --only hosting:admin-console` — see that
        SKILL.md's exact steps.
  - **Gotcha for next time**: `flutter create . --platforms web` silently
    rewrote `android/app/src/main/AndroidManifest.xml` (dropped the
    tablet-only `supports-screens` restriction and the UCropActivity
    landscape lock + its explanatory comment), `MainActivity.kt`, and
    `styles.xml` (both toward a newer edge-to-edge template) —
    none of that was requested by adding the web platform. Caught via
    `git diff` after the fact and fixed: manifest/UCropActivity reverted
    to their original tablet-only intent, the edge-to-edge Kotlin/styles
    changes were kept (they're a genuine, harmless modern-Android pattern
    that doesn't conflict with this app's kiosk-mode fullscreen) but had
    their stripped explanatory comments restored. **If you ever re-run
    `flutter create`** (any `--platforms` flag) on this repo, diff
    `android/app/src/main/AndroidManifest.xml` afterward before trusting
    it — this is apparently a "recreate the whole project scaffold" pass
    under the hood, not additive-only to the platform you asked for.
- [x] **Notification expansion (Phase 7)** — four new Cloud Function
      triggers (`onOrderWritten`, `onExpenseClaimWritten`,
      `onLeaveRequestWritten`, `onDoctorVisitPlanWritten`) react to the
      existing direct client writes for each workflow — a new pending
      item pushes whoever in the creator's reporting chain holds the
      matching `approve_*` permission (a new shared
      `notifyReportingChainWithPermission` helper), and a decision pushes
      the creator back. Reuses the pre-existing `sendPushToUser`/
      `DeviceTokens` primitive unchanged; no client-side Dart changes were
      needed (an unrecognized push `type` is already a no-op in
      `PushNotificationService._handleMessage`, so the OS notification
      banner shows regardless). See the "Targeted notifications" section
      each of `features/orders`, `features/expenses`, `features/leave`,
      and `features/doctors`'s `SKILL.md` now has.
  - Not built: target-threshold alerts (e.g. "80% of target reached") —
    the roadmap's other Phase 7 idea. Achievement is computed on demand
    from `Order` sums, not stored, so a real implementation needs either a
    scheduled function or a trigger on every order status change plus an
    "already notified this crossing" flag to avoid re-notifying on every
    subsequent order — more involved than the four triggers above, and
    lower-value without a specific request for it.
## 9. Production readiness pass (Phase 8, 2026-07-29)

- [x] **`firestore.rules` self-review** of every rule added/changed in
      Phases 3-7 (no Firestore emulator available in this environment —
      `firebase emulators:exec` needs a JDK 21+, only 17 was installed —
      so this was a careful manual read, not an automated rules-emulator
      test suite). Found and fixed two real gaps in the `DoctorVisitPlans`
      rules specifically:
  - The `allow create` had no `status` restriction at all — an MR could
    have created their very first plan doc with `status: 'approved'`,
    forging their own manager sign-off. Now restricted to
    `status in ['draft', 'pending']` on create, matching the
    exact-match `status == 'pending'` restriction Orders/ExpenseClaims/
    LeaveRequests already had on their own create rules (those three were
    fine; this one was missed when the approval workflow was added).
  - The MR's own content-edit `allow update` checked that the *old*
    status wasn't `pending`, but never restricted what the *new* status
    could become — an MR could take a `rejected` plan and, via a
    content-edit-shaped write, set `status: 'approved'` themselves. Fixed
    to only allow the new status to stay unchanged or become `pending`;
    only the separate manager-decision `allow update` block can ever
    produce `approved`/`rejected`.
  - Also simplified a redundant `isAdmin() || isOfficeAdmin()` condition
    on the `Batches` subcollection rule to just `isOfficeAdmin()` (which
    already includes `isAdmin()`).
- [x] **Caught and fixed an unrelated regression**: `flutter create .
      --platforms web` (Phase 6) had silently rewritten
      `AndroidManifest.xml`, dropping the tablet-only `supports-screens`
      restriction and the UCropActivity landscape lock. See Phase 6's
      entry above ("Gotcha for next time") for the full story and fix —
      caught via a targeted re-check of `AndroidManifest.xml`/
      `MainActivity.kt` after the fact, not caught immediately when the
      web platform was first scaffolded.
- [x] **Pagination — investigated, deliberately not added.** Every admin
      list (Manage Employees, etc.) fetches its full collection once and
      searches client-side over the whole thing. Real query-level
      pagination would either silently make search incomplete (only
      searching loaded pages) or require a dedicated search index — a
      real infrastructure decision, not a small change, and not justified
      at this app's realistic scale (`ListView.builder` already lazily
      renders, so there's no rendering-performance problem today). See
      `features/admin/SKILL.md`'s "Pagination" section for the full
      reasoning and what to do if this ever becomes real — don't
      `.limit()` a `fetchAll()`-backed screen without also deciding what
      happens to its search box.
- [x] **Per-tenant data export runbook** —
      [docs/DATA_EXPORT_RUNBOOK.md](DATA_EXPORT_RUNBOOK.md): `gcloud
      firestore export` + a Storage bucket copy, leaning on the fact that
      each tenant already has their own Firebase project (per Phase 1's
      per-tenant-build decision), so "export tenant X's data" is just
      "export project X" — no per-tenant filtering needed. Manual runbook,
      not automated in-app on purpose.
- [ ] **Still open** (not attempted this pass, still real gaps):
  - Historical test-coverage gaps from before this roadmap started:
    admin controllers (`employee_controller.dart`,
    `designation_controller.dart`, `admin_catalog_controller.dart`,
    `usage_dashboard_controller.dart`), the tracking module
    (`location_service.dart`, `usage_tracking_service.dart`), and Cloud
    Functions (zero tests today — would need the Firebase emulator, which
    needs a JDK 21+ this environment doesn't have installed). Every *new*
    module built in Phases 3-7 does have real test coverage (see each
    phase's own entry above) — this remaining gap is specifically the
    pre-existing, pre-roadmap surface flagged back in section 1.
  - No automated Firestore-rules test suite (the emulator-based kind
    `docs/TODO.md` section 2 already called for) — this pass's rules
    review was manual reading, which is exactly the kind of check an
    automated test suite exists to make less error-prone and repeatable.
    Worth real investment once a JDK is available in whatever environment
    picks this up next.

## Roadmap status (through Phase 8, 2026-07-29)

All 8 phases of the "white-label + full gap closure" roadmap have had at
least one pass: **Phase 1** (white-label/tenant config), **Phase 2**
(portrait+landscape), **Phase 3** (expenses, visit-plan approval, leave,
attendance, batch/expiry inventory, UCPMP compliance), **Phase 4**
(order/invoice tax & payment), **Phase 5** (CSV/PDF export), **Phase 6**
(admin web console), **Phase 7** (targeted approval notifications),
**Phase 8** (this section). Every phase's own entry above lists what was
deliberately *not* built alongside what was — read those before assuming
a phase is 100% complete rather than "has real, working coverage of its
core ask." The two things every phase's work agreed to leave for genuine
follow-up work, not oversights:

1. **`docs/BUSINESS_OVERVIEW.md` needs a full refresh pass** — it
   predates the doctors/agencies/orders/targets/RCPA/team hierarchy merge
   entirely (still describes only the catalog+admin app from before
   that), so it's no longer a reliable cross-verification checklist for
   what the app actually does today. Each feature folder's own `SKILL.md`
   is the accurate source until that refresh happens.
2. **Phase 2's manual on-device orientation verification** was never done
   (no emulator/device was available in the environment that built it) —
   `flutter analyze`/`flutter test`/real device builds all pass, but
   nobody has actually rotated a physical device through every screen yet.
