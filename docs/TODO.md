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
