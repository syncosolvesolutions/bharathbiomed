# Next session — what's left

Snapshot as of 2026-07-29, end of the "white-label + full gap closure"
roadmap session (all 8 phases had a pass — see `docs/TODO.md` for the
full history/reasoning behind each). Split into what Claude can pick up
directly next session, and what only you can do.

**Update (2026-07-29, later same day):** a follow-up session closed out
every "Can be done by Claude" item below, including the Office Admin nav
gap once you confirmed the decision (Office Admins get both the tablet app
and the web console, are created like any other employee via a designation
categorized Office Administration, and there can be multiple). Details:

- `docs/BUSINESS_OVERVIEW.md` fully rewritten to cover every feature built
  since the original catalog+admin app (doctors, agencies/pharmacies,
  orders/dispatch/invoicing, targets, RCPA, team hierarchy, expenses,
  leave, attendance, compliance, inventory/batches, the web console, and
  the white-label/tenant system).
- Added `test/features/admin/{employee,designation,admin_catalog,usage_dashboard}_controller_test.dart`
  and `test/features/tracking/{location_service,usage_tracking_service}_test.dart`
  (34 new tests, all passing — `flutter test` is now 172 tests total).
- JDK 21 was installed (alongside the existing 17, which stays the
  machine's default `java`) and used to download the Firestore emulator.
  Cloud Functions + Firestore rules tests both now exist and run via
  `cd functions && npm test`, which builds, then wraps a Jest run in
  `firebase emulators:exec` with `JAVA_HOME` scoped to 21 only for that
  subshell (`functions/scripts/test-with-emulator.sh` — the machine-wide
  default `java` is untouched). 48 tests total:
  `functions/src/__tests__/{dispatchOrder,generateInvoice,recordPayment}.test.ts`
  (17 tests, covering the three financial Cloud Functions — FEFO batch
  consumption, sequential invoice numbering, tax bake-in, overpayment
  rejection) and `firestoreRules.test.ts` (31 tests, covering
  Products/Users/Orders/DoctorVisitPlans/Agencies/Invoices/Payments/
  DeviceTokens — including the exact "can't self-approve, can't edit
  while pending, review write is field-restricted" invariants that
  `docs/TODO.md` section 9 mentions catching manually before).
- New dev dependencies: Flutter side added `geolocator_platform_interface`
  + `plugin_platform_interface` (faking `GeolocatorPlatform.instance` in
  tests); Functions side added `jest`, `ts-jest`, `firebase-functions-test`,
  `@firebase/rules-unit-testing` (all dev-only, nothing shipped changes).
- **Office Admin nav gap closed**: `app_router.dart`'s `/admin*` redirect
  now also lets an Office Admin through, scoped to just the Inventory
  routes (`/admin/inventory`, `/admin/inventory/batches`,
  `/admin/inventory/expiry-alerts`) — Employees/Designations/Departments/
  Products CRUD stay hardcoded-admin-only (still `requireAdmin`-gated
  server-side). Mobile: a new toolbar icon on the catalog screen
  (`product_list_screen.dart`) takes an Office Admin straight to
  Inventory, skipping `AdminHomeScreen`'s full tile grid. Web: the same
  redirect sends them to the `/admin` route, where `AdminWebShell`
  (`admin_web_shell.dart`) now shows a role-filtered sidebar — full for
  the hardcoded admin, reduced to Agencies/Pharmacies/Agency-Pharmacy-
  Requests + Inventory/Expiry Alerts for an Office Admin. Employee
  creation with an Office Administration designation, and having multiple
  such employees, already worked with no code change needed. See
  `features/admin/SKILL.md` and `features/admin_web/SKILL.md` for the
  updated notes. Not covered by an automated test (no existing router/
  widget-test harness for this shell to extend cheaply) — verified via
  `flutter analyze` + the full `flutter test` suite staying green; a real
  device/emulator check (see the on-device orientation item below) is the
  next verification step if you want one.
- Not done: Cloud Functions/rules coverage is representative (the highest-
  value/highest-risk functions and collections), not exhaustive — there
  are more callables and collections that could still get direct test
  coverage if you want it (e.g. `createEmployee`/`updateEmployee`/
  `deleteEmployee`, the notification triggers, `SalesTargets`/
  `ExpenseClaims`/`LeaveRequests` rules).

---

## Can be done by Claude (paste any line back as a prompt)

### Real code gaps
- [ ] Broaden Cloud Functions/rules test coverage beyond the
      representative set added 2026-07-29 (see the update note above) if
      you want closer-to-exhaustive coverage rather than just the
      highest-value paths.

### Features deliberately deferred (real scope, not small)
- [ ] Secondary sales (distributor→pharmacy) — needs orders placeable
      against a `Pharmacy`, not just an `Agency`; a genuinely new flow,
      not a field added to `Order`. See `features/orders/SKILL.md`.
- [ ] Target-threshold push alerts (e.g. "80% of target reached") —
      needs either a scheduled function or a trigger on every order
      status change plus an "already notified" flag to avoid spamming.

**Update (2026-07-29, later still):** Invoices/Payments, Leave Requests,
and Attendance were removed entirely per a later same-day request —
invoicing/cheques/payments are handled offline by the office, so an
order's lifecycle now ends at `delivered` (marked by the MR who placed it,
once dispatched). Doctor/Agency-Pharmacy request review was also opened up
to any `approve_requests` holder (not just the hardcoded admin/Office
Admin) — see `docs/BUSINESS_OVERVIEW.md` §4/§6/§8 and
`features/orders/SKILL.md` for the current state. This makes the two
deferred bullets that used to be here ("Accounting-ledger export" and
"Leave-balance tracking") no longer applicable — there's no Invoices layer
to export from and no Leave feature to add a balance to.

---

## Manual — needs you specifically

### Device/environment
- [ ] **Phase 2's on-device orientation check** — rotate a real
      tablet (or a working emulator) through every screen; confirm
      portrait/landscape both render correctly and the slideshow forces
      landscape and restores on exit. No device/emulator was available
      in the session environment (the one installed Android system image
      couldn't be turned into a working AVD — `avdmanager` errored on a
      missing `devices.xml`).

### Firebase deployment (nothing this session was deployed — only built/verified locally)
- [ ] `firebase deploy --only functions` — ships every Cloud Function
      change from this session (dispatch/invoice tax+payment, the four
      new notification triggers, `recordPayment`, the tenant-generated
      config). **Nothing works end-to-end until this runs.**
- [ ] `firebase deploy --only firestore:rules` — ships every rules
      change (Batches, Payments, ExpenseClaims, LeaveRequests,
      ComplianceLogs, the DoctorVisitPlans approval workflow + this
      session's bug fixes). Review against the live console rules first
      per this file's own long-standing warning at the top.
- [ ] Confirm the Firebase project is still on the **Blaze** plan
      (required for Cloud Functions).
- [ ] Admin web console hosting: `firebase hosting:sites:create`, a
      hosting target, then `firebase deploy --only hosting:admin-console`
      — full steps in `features/admin_web/SKILL.md`. Deliberately not
      done automatically since repointing the existing `hosting.public`
      risks breaking the already-public Play Store privacy-policy URL.

### iOS-specific (from the earlier push-notification work, still open)
- [ ] Enable Push Notifications + Background Modes (Remote notifications)
      capabilities for the Runner target in Xcode.
- [ ] Upload an APNs Authentication Key in the Firebase console.

### Business/legal
- [ ] Review Firebase Storage rules for `employee_photos/`/
      `expense_receipts/` upload paths.
- [ ] Confirm Firebase Auth email templates are branded.
- [ ] Legal review of the Terms & Conditions / Privacy Policy content —
      drafted with a India-governing-law default, needs actual counsel
      sign-off before treating it as real legal terms.
- [ ] Decide whether to retire `bharathbiomedpharma_admin` (the old,
      fully-superseded separate admin app/repo).
