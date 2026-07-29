# Business Overview & Functionality Checklist — Bharath Biomed Pharma App

_Last updated: 2026-07-29_

This is a plain-language description of what the app actually does today,
organized so you can go through it screen-by-screen and confirm it matches
what you expect. Where something needs action from you specifically (not a
code change), it's called out under **Needs your action**.

This app has grown well past its original "catalog + admin" scope. It now
covers doctors and visit planning, distributors and pharmacies, orders with
dispatch and delivery confirmation, sales targets, retail-chemist audits
(RCPA), UCPMP compliance logging, a team-hierarchy/approvals system, expense
claims, and a desktop admin console — on top of the original catalog,
slideshow, and usage-tracking foundation. Invoicing, cheques, and payments
are handled entirely offline, outside the app. It's also built as a
white-label product: the same codebase can be rebranded and redeployed for
a different pharma company as its own tenant.

---

## 1. Who uses this app

| Role | How they get an account | What they can do |
|---|---|---|
| **Admin** | A fixed allowlist of emails (currently `bharathbiomedpharma@gmail.com` and `sudhakar.gotte@bharathbiomedpharma.com`), not created in-app | Everything — every screen in the app and the admin web console, unconditionally |
| **Office Admin** | An employee whose job title (designation) is categorized as "Office Administration" — any number of employees can hold this designation | Manage agencies/pharmacies (create, deactivate/reactivate), review Agency/Pharmacy change requests, and manage inventory (stock/batches/expiry alerts) — narrower than the Admin above, available on both the tablet app and the admin web console (§9) |
| **Manager** (any designation holding a specific permission — see §9) | An employee, created by the admin, whose designation grants e.g. "Approve Orders" or "Approve Expenses" | Sees "My Team": their own reporting-chain downline's orders, expenses, visit plans, targets, RCPA entries, compliance logs, and usage — acts on whichever of those their specific permissions cover; a designation holding "Approve Requests" can also review Doctor and Agency/Pharmacy proposals company-wide (§8) |
| **Medical Representative (MR)** | Created *by* the admin, in-app | Browse the catalog, present the slideshow, manage their own doctors/visit plan, place orders and confirm delivery, file expense claims, log RCPA and compliance entries, see their own targets, sync — nothing outside their own data |

There is a fixed admin allowlist rather than one single account. If the list
of who has full admin rights needs to change, that's a config change (see
§10's white-label section), not a code change — `lib/core/auth/admin_access.dart`.

## 2. The sales flow (what an MR sees)

1. **Open the app.** If they signed in before, they go straight to the
   catalog — no need to sign in every time.
2. **Continue Offline** (the main button): opens whatever catalog was last
   downloaded to this tablet. Works with no internet connection at all.
3. **Sign in to sync data** (secondary, tap to expand): an MR enters the
   **username (or their real email, if the admin gave them one) and
   password**, signs in, and the app immediately downloads the current
   catalog for later offline use.
4. **Browse the catalog:** products are grouped into departments (horizontal
   scrolling rows), each showing a photo, tap to select/deselect.
5. **Present:** tap the play button to open a full-screen, swipeable,
   pinch-to-zoom slideshow of only the products they selected, **in the exact
   order they selected them** — not catalog order.
6. **Sync:** a unified "new data available" banner tracks anything worth
   syncing — new products/doctors/agencies/pharmacies from the server, or
   anything this device has queued but not yet uploaded (orders, RCPA
   entries, expense claims, compliance logs, visit plans,
   visit logs, change requests, usage sessions). Tapping it shows a
   step-by-step progress overlay ("Syncing… 42% — Uploading orders") so an MR
   knows not to close the app mid-sync.
7. **Change Password** (lock icon, top of the catalog screen, visible once
   signed in): lets anyone — MR or admin — change their own password by
   entering their current one first.

**What happens if something goes wrong:** network errors, sign-in errors, and
sync failures show a plain-language message (not a raw error code) and, where
it makes sense, a Retry button. A failed sync never wipes out data already on
the device — the tablet keeps showing the last successful sync until a new
one succeeds.

## 3. Doctors, visit planning, and RCPA

- **Doctor directory:** each MR sees the doctors assigned to them (name,
  specialty, contact, linked pharmacies). An MR can propose a new doctor;
  the admin reviews and approves/rejects that proposal before it becomes a
  real record.
- **Weekly visit plan (beat/route plan):** each MR maintains their own
  recurring weekly schedule — which doctors they plan to see on which day.
  A manager holding the right permission can require this to go through an
  approval step (Submit for Approval → a manager approves/rejects); once
  submitted, the MR can't edit it until the review is decided.
- **Today's visits & visit logs:** a daily view of who's planned for today,
  with a quick "log this visit" action recording that the visit actually
  happened and how it went. Logs are permanent (never edited/deleted) and
  offline-first like everything else.
- **RCPA (Retail Chemist Prescription Audit):** at a selected pharmacy, an
  MR logs a script/sales count for each of your own products (pulled from
  the synced catalog) plus freeform competitor-brand counts, with an
  optional note and GPS location. This is a self-serve log with no approval
  step — a manager reviews the team's entries afterward (informational, not
  a gate), from Team → RCPA Entries.

## 4. Agencies, pharmacies, and orders

- **Agencies** (distributors/stockists) and **Pharmacies** (chemists) are
  two separate directories — name, contact, GST (agencies), address/GPS,
  active/inactive flag. Any signed-in user can see the full lists.
- **Who can add one:** an Office Admin (or the Admin) can create or
  deactivate an agency/pharmacy directly. Anyone else can "Propose" one
  instead — it queues offline and, once synced, shows up in an Office
  Admin's **Agency/Pharmacy Requests** queue to approve or reject.
- **Orders:** an MR places an order against an Agency (a distributor) — this
  is always a company→distributor ("primary") sale; there's no
  distributor→pharmacy ("secondary sale") order flow yet (see §8). Full
  lifecycle: submitted → approved/rejected by a manager → dispatched by the
  office (decrements stock, and where batch/expiry tracking is used,
  consumes the oldest-expiring stock first) → delivered, marked by the same
  MR who placed the order once the product physically arrives.
- **Invoicing, cheques, and payments are handled entirely offline**, outside
  the app — there's no in-app invoice generation or payment tracking.
  "Delivered" is the last status an order reaches here; the office's own
  paper/manual process picks up from there.
- **Pharmacy is not yet a commerce entity** — today it's used as the
  location an MR selects for an RCPA entry and as a doctor-affiliation
  reference, not for placing orders.

## 5. Sales targets

- A manager sets a monthly rupee target for each person in their downline
  (one target per employee per calendar month).
- **Achievement is never manually entered** — it's always calculated live
  from that employee's own orders in that month that reached at least
  "approved" status (pending/rejected orders don't count).
- Every MR sees "My Target" (their own progress bar); managers see "Team
  Targets" for their whole downline, with CSV/PDF export.

## 6. Expenses

- **Expense claims:** an MR files a TA/DA (travel & daily allowance) claim —
  category, date, amount, optional description and receipt photo. A manager
  with the right permission approves or rejects it. Everything about a
  claim is offline-first except the receipt photo, which needs a live
  connection to upload at the time it's picked.
- A claim pushes a notification to whoever needs to act (a manager on
  submission, the MR back on the approve/reject decision).
- **Leave requests and attendance tracking have been removed** — this app
  no longer has a Leave Requests flow or a derived Attendance view. The
  underlying app-usage session data (open/close timestamps, duration,
  location at open) is still recorded and still feeds the admin's Usage
  Dashboard (§9.3) — only the day-by-day "was this MR present" derived view
  built on top of it is gone.

## 7. UCPMP compliance logging

- An MR logs anything given to a doctor — a product sample, gift,
  sponsorship, or hospitality — with its value, for UCPMP (India's
  pharmaceutical marketing code) auditability. This exists to make what
  actually happened visible, not to authorize or encourage it.
- It's an append-only log with no approval step. A manager's dashboard
  aggregates by **doctor**, not by MR, since the real compliance question is
  "has this doctor received too much" regardless of who gave it — a
  configurable annual limit per doctor flags entries in red on the
  dashboard, but never blocks anyone from logging something over it (an
  audit log that refused to record a violation would defeat its purpose).

## 8. Team hierarchy & approvals — how visibility works

- Every employee has a designation (job title) with a permission set and a
  place in the reporting ladder (MR → Area Business Manager → Regional →
  Zonal, or your tenant's equivalent). A manager's "downline" is computed
  automatically from that ladder.
- **My Team** is a manager's single hub — reachable by anyone, showing
  empty states if they don't manage anyone — covering: usage & location,
  visit logs, order approvals/dispatch, targets, RCPA entries, expense
  approvals, visit-plan approvals, and UCPMP compliance. Being able to
  *see* a list is separate from being able to *act* on it — each screen's
  action buttons check a specific permission (Approve Orders, Approve
  Expenses, Dispatch Orders, Manage Targets, Manage Agencies, Approve
  Requests). One permission, "View Global Data," overrides normal downline
  scoping entirely and shows everyone, for whoever needs company-wide
  visibility.
- **Doctor and Agency/Pharmacy request review** used to be Office-Admin/
  Admin-only regardless of who held "Approve Requests." That gap is closed:
  a designation holding "Approve Requests" — typically assigned to Area
  Business Manager and above — can now review both queues too (two extra
  tiles in My Team, "Doctor Requests" and "Agency / Pharmacy Requests"),
  alongside the existing unconditional access for the hardcoded admin
  (Doctor requests) and any Office Administration designation (Agency/
  Pharmacy requests) — nobody loses access, this only adds a second path.
  This access is category-agnostic by design: a field designation and an
  Office Administration designation qualify the same way once "Approve
  Requests" is checked.

## 9. Admin flow, inventory, and the web console

Reachable via a shield icon in the catalog screen's top bar — only visible
to an allowlisted admin account.

### 9.1 Products, departments, designations, employees

Unchanged from before: full CRUD on products (with department + sort
position), departments, designations (job-title list, pre-filled with a
standard pharma field-force ladder), and employees (auto-generated
`firstname_lastname` username, default password, optional real email for
self-service password reset, per-employee Reset Password action).

### 9.2 Inventory & batch/expiry tracking

- **Stock levels:** every product has a flat stock count, adjustable
  directly ("Adjust Stock" delta) — this is the number that gates whether
  an order can be dispatched at all.
- **Batch/lot tracking (optional, additive):** on top of that same stock
  count, batches can be recorded with their own expiry dates. Adding or
  removing a batch moves the stock count by the same amount, so the two
  stay in sync as long as every stock movement goes through batches — a
  plain stock adjustment with no batch attached is a legitimate way to move
  stock without touching any batch, so it's expected (not a bug) if the two
  numbers diverge for a product that mixes both methods.
- **Expiry alerts:** a dashboard of everything expiring within 90 days,
  across every product.
- **FEFO dispatch (First-Expiry-First-Out):** when an order ships, stock is
  decremented as always, and — best-effort — the system also consumes
  batches oldest-expiry-first to attribute the dispatch to specific lots.
  If a product has no batches recorded, the dispatch still goes through;
  it's just not attributed to a lot.
- **Office Admin access:** an Office Admin (not the allowlisted Admin) can
  reach these three screens too — a toolbar icon on the catalog screen
  (mobile) or the reduced sidebar in the admin web console (§9.5) — since
  you confirmed Office Admins should manage inventory day-to-day. Everything
  else in this admin section (Employees, Designations, Departments, full
  Product edit, Notifications) stays Admin-only.

### 9.3 Usage Dashboard

A bar-chart icon in the admin screen opens a list of every MR with: how
many times they've opened the app, total time spent in it, and when they
last opened it. Tap any MR to see their individual sessions — each with a
timestamp, duration, and device location at the moment the app was opened
(if location access was granted). This data is uploaded from each MR's
device the next time they sync (see §10).

### 9.4 Reminders

Both the admin and any MR can create personal to-do reminders (title, note,
due date/time). The admin can also assign a reminder directly to a
specific MR. There's no push/alarm notification here — just a live list
with an overdue flag and manual complete/delete.

### 9.5 Admin web console

Everything above (plus the team-hierarchy screens) is also available as a
wide desktop console, built from this same codebase for the web instead of
mobile — a sidebar + the exact same screens, sharing every controller and
Firestore query unchanged with the mobile app. The Admin allowlist sees the
full sidebar; an Office Admin sees a reduced one (just Agencies/Pharmacies/
Agency-Pharmacy-Requests and Inventory/Expiry Alerts). Any other manager who
isn't either of those still only gets the mobile app, even on a web build.
It has no offline support (unlike mobile, it always reads live) and hasn't
been deployed yet (see §12).

## 10. MR location & usage tracking — how it actually works

- **What's recorded, per MR:** every time they open the app, the app notes
  the timestamp, and (if location permission is granted on that device) the
  GPS coordinates at that moment. When they close or background the app, it
  notes how long that session lasted. This never applies to an admin
  account.
- **Offline-first:** none of this is sent anywhere in real time. It's saved
  on the device and only uploaded the next time that MR's device syncs. If
  an MR never syncs, their usage data never leaves their device.
- **Not shown to the MR, not blocking their work:** no in-app popup tells
  the MR this is happening (a deliberate choice), and if they deny the
  location permission, the app works exactly the same — time is still
  tracked, just without a location for that session.
- The same underlying location helper also powers the "Use Current
  Location" button on Agency/Pharmacy/RCPA forms — it's shared
  infrastructure, not exclusive to usage tracking.
- **Where you see it:** the Usage Dashboard (§9.3) only — there's no
  derived attendance view built on top of it anymore.

## 11. Profile & account basics

- Every MR can edit their own photo, name, mobile number, and date of
  birth; username, email, designation, and territory stay admin-managed
  only (read-only to the MR).
- A newly created MR is walked through a mandatory one-time "Complete Your
  Profile" step (photo + name) before they can use the rest of the app.
- A "Happy Birthday" celebration shows once a year on the employee's
  birthday, revisitable later via a cake icon.

## 12. White-label / multi-tenant system

This app is built to be resold to other pharma companies from the same
codebase, each as its own **tenant** — its own Firebase project, its own
branding, its own admin emails, tax rate, and legal-jurisdiction defaults,
all driven by one `tenants/<tenantId>/tenant.json` config file (name, logo,
colors, support email, default password for new MRs, UCPMP gift limit,
GST/tax rate, payment terms, designation ladder, etc.). Onboarding a new
tenant is a scripted process (`scripts/new_tenant.sh`) that regenerates the
app's branding, admin allowlists (both in the app and in the server-side
rules/functions), and the Terms & Conditions/Privacy Policy text — some
steps (creating the new Firebase project, configuring it, deploying) are
still manual by design. Today there is exactly one live tenant,
**bharathbiomed**.

## 13. Terms & Conditions and Privacy Policy

- The login screen shows "By continuing, you agree to our Terms & Conditions
  and Privacy Policy," each a tappable link to a full in-app screen — no
  checkbox to tick, since nobody self-registers in this app (accounts are
  created by the admin).
- Both documents are bundled in the app itself (not fetched from a website),
  so they're always available, even offline, and are templated per-tenant
  (company name, jurisdiction, support email) from the same tenant config
  above — `docs/TERMS_AND_CONDITIONS.md`/`docs/PRIVACY_POLICY.md` are
  regenerated from the in-app content, not maintained separately.
- The Privacy Policy explicitly discloses the location/usage tracking
  described in §10.

## 14. Business rules worth knowing about

- **Offline-first, by design:** the sales app never contacts the server on
  its own for day-to-day use — only when someone taps Sync or signs in.
  This is intentional (field reps may have poor/no connectivity).
- **A sync never deletes data on a device based on a bad server response.**
  If the server ever returns empty/failed data, the device keeps its last
  good copy instead of wiping itself.
- **Deleting an employee is immediate and permanent** for that login —
  there's no "deactivate and restore later" option currently.
- **Approval is a snapshot-in-time signal, not a continuously enforced
  constraint** — e.g. editing a visit plan after it's been approved or
  rejected doesn't reset it back to pending review.
- **No currency formatting anywhere** — compliance values, targets, and
  order amounts are all plain numbers, assumed to be your local currency.
- **No in-app tracking disclosure/consent screen for MRs** — a deliberate
  choice; the disclosure lives in the Privacy Policy link instead.

## 15. Deliberately deferred — real scope, not overlooked

- **Secondary sales** (distributor→pharmacy — what actually reached retail)
  — would need orders placeable against a Pharmacy, a genuinely new flow.
- **In-app invoicing/payment tracking** — deliberately removed; invoices,
  cheques, and payments are handled entirely offline by the office once an
  order is delivered, not something this app digitizes.
- **Target-threshold push alerts** (e.g. "80% of target reached").

## 16. Needs your action (not something I can do from here)

- [ ] **Deploy the Cloud Functions and Firestore rules** — see the
      "Backend" section of [README.md](../README.md). Nothing about
      dispatch/invoicing, notifications, or payment recording works
      end-to-end until this is deployed.
- [ ] **Confirm the Firebase project is on the Blaze (pay-as-you-go) plan** —
      required for Cloud Functions.
- [ ] **Review `firestore.rules` against what's actually live in the
      Firebase console** before deploying.
- [ ] **Check Firebase Storage's actual upload rules** for the
      `employee_photos/`/`expense_receipts/` paths.
- [ ] **Confirm Firebase Authentication's email templates** are
      configured/branded the way you want.
- [ ] **Legal review of the Terms & Conditions / Privacy Policy content**
      (`lib/features/legal/legal_content.dart`) — drafted with an
      India-governing-law default; get actual counsel sign-off.
- [ ] **Decide whether to retire `bharathbiomedpharma_admin`** (the old,
      separate admin app) now that everything it did lives in this app.
- [ ] **Set up the admin web console's hosting** — a one-time Firebase
      Hosting multi-site setup, deliberately not done automatically (see
      `features/admin_web/SKILL.md`).

## 17. What to check first

If you're cross-verifying, a reasonable order:

1. Sign in as admin → confirm the shield icon appears and every admin
   screen loads without errors.
2. Add a test department/product, confirm it shows up in the catalog after
   a sync, and the slideshow plays selected products back in tap order.
3. Add a test employee, sign in as them, confirm they land in the normal
   catalog view with no shield icon, and a usage session appears on the
   dashboard after their next sync.
4. As that MR: add a doctor proposal, build a weekly visit plan, log a
   visit, place an order, file an expense claim, log an RCPA entry and a
   compliance entry — sync, then confirm all of it shows up correctly on
   the corresponding Team dashboards for their manager.
5. As a manager: approve/reject the order and expense claim, dispatch the
   order; confirm the MR sees the updated status after their next sync,
   then sign back in as that MR and mark the order delivered.
6. Try Change Password as both admin and a test MR.
7. Delete the test employee, confirm that login stops working, and clean
   up the test product/department.
