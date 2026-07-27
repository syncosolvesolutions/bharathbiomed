# Business Overview & Functionality Checklist — Bharath Biomed Pharma App

_Last updated: 2026-07-27_

This is a plain-language description of what the app actually does today,
organized so you can go through it screen-by-screen and confirm it matches
what you expect. Where something needs action from you specifically (not a
code change), it's called out under **Needs your action**.

---

## 1. Who uses this app

| Role | How they get an account | What they can do |
|---|---|---|
| **Admin** | One fixed account (`bharathbiomedpharma@gmail.com`), not created in-app | Everything: manage the product catalog, departments, designations, Medical Representative accounts, and view the usage dashboard |
| **Medical Representative (MR)** | Created *by* the admin, in-app | Browse the catalog, present the slideshow, sync the latest catalog, change their own password — nothing else |

There is currently **one hardcoded admin email**. If more than one person
should have full admin rights, or a specific person should be admin instead
of this shared account, that's a change to make now rather than after rollout
— see `lib/core/auth/admin_access.dart`.

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
6. **Sync button** (top of the catalog screen): re-downloads the latest
   catalog from the server at any time, without needing to sign out/in again.
   This is also the moment any queued usage-tracking data (see §6) uploads.
7. **Change Password** (lock icon, top of the catalog screen, visible once
   signed in): lets anyone — MR or admin — change their own password by
   entering their current one first.

**What happens if something goes wrong:** network errors, sign-in errors, and
sync failures show a plain-language message (not a raw error code) and, where
it makes sense, a Retry button. A failed sync never wipes out the catalog
already on the device — the tablet keeps showing the last successful sync
until a new one succeeds.

## 3. The admin flow (what the admin sees)

Reachable via a shield icon in the catalog screen's top bar — **only visible
to the admin account**, nobody else sees it.

### 3.1 Products

- **Add a product:** name, description, a photo, and which department(s) it
  appears in (with a position number controlling sort order within each
  department — lower numbers show first).
- **Edit a product:** same form, pre-filled, from tapping any product tile in
  a department view.
- **Delete a product:** confirmation prompt, then removed everywhere.
- **Photo requirements:** photos should be at least 1920×1200 and ideally
  16:9 — the app enforces this at upload time (it'll prompt to crop a
  too-small photo) so photos look sharp on the full-screen slideshow.

### 3.2 Departments

- **Add, rename, delete** departments from one screen (Manage Departments).
- Renaming or deleting a department automatically updates every product that
  referenced it — you won't end up with products silently orphaned from a
  renamed department.

### 3.3 Designations (job titles for employees)

- A separate managed list (Manage Designations), starting pre-filled with a
  standard pharma field-force ladder (Medical Representative → Senior Medical
  Representative → Area/Regional/Zonal Business Manager — modeled on Mankind
  Pharma's structure, since that's what you asked to check).
- Add, rename, delete freely — this list is only used when creating/viewing
  employee profiles, it's not shown to MRs.

### 3.4 Employees (Medical Representatives)

- **Add Employee:** first name, last name, photo, area/territory, designation
  (picked from the list above), mobile number (optional), an optional real
  email address, and a password that **defaults to `Bharathbio@2026`** but
  you can change it per person.
- **The app generates the login username automatically** as
  `firstname_lastname` (e.g. `rajesh_kumar`). If that's already taken, it
  appends a number (`rajesh_kumar2`, etc.) automatically — you don't have to
  think about uniqueness.
- **Real email is optional but changes how that person logs in and recovers
  their password:**
  - **No email given (default):** they log in with their username. If they
    forget their password, only you can reset it (see below) — there's no
    self-service recovery, because there's no real inbox behind their
    account.
  - **Email given:** they log in with that email instead of a username, and
    can use "Forgot password?" on the login screen to reset it themselves —
    Firebase emails them a reset link directly, no action needed from you.
- After creating an employee, the app shows you the exact login (username or
  email) and password to hand to that person — **write it down or share it
  immediately**, since the app doesn't re-display a password after this
  screen closes.
- **Edit Employee:** tap any employee in the list to edit their profile,
  including their username or add/remove a real email after the fact.
- **Reset Password:** a per-employee action in Manage Employees — sets a new
  password directly and shows it to you to hand over. Works regardless of
  whether that employee has a real email on file.
- **Manage Employees:** the full list, with each person's name, designation,
  area, and login (username or email) visible, and a delete action to remove
  someone's access entirely (revokes their login immediately).

### 3.5 Usage Dashboard

- A bar-chart icon in the admin screen opens a list of every MR with: how
  many times they've opened the app, total time spent in it, and when they
  last opened it.
- Tap any MR to see their individual sessions — each with a timestamp,
  duration, and the device's location at the moment the app was opened (if
  location access was granted on that device).
- This data is uploaded from each MR's device the next time **they** sync —
  see §6 for exactly how this works and what it means.

## 4. Password & account recovery, end to end

- **Change Password** (anyone, while signed in): enter your current password
  once, then a new one. Available from the catalog screen's lock icon.
- **Forgot password, MR with a real email on file:** the login screen's
  "Forgot password?" link sends them a real reset email via Firebase — fully
  self-service, no admin involvement needed.
- **Forgot password, MR with no email on file (the default):** the same link
  tells them to contact their admin. You reset it from Manage Employees →
  Reset Password and hand them the new one directly.
- **Admin forgets their own password:** not handled in-app (there's only one
  admin account, set up outside this system) — reset it from the Firebase
  console directly.

## 5. Terms & Conditions and Privacy Policy

- The login screen shows "By continuing, you agree to our Terms & Conditions
  and Privacy Policy," each a tappable link to a full in-app screen — no
  checkbox to tick, since nobody self-registers in this app (accounts are
  created by the admin). This was a deliberate simplification you confirmed.
- Both documents are bundled in the app itself (not fetched from a website),
  so they're always available, even offline. The same content is also kept
  as `docs/TERMS_AND_CONDITIONS.md` and `docs/PRIVACY_POLICY.md` for hosting
  publicly if you ever need a public URL (e.g. for a Play Store listing).
- The Privacy Policy explicitly discloses the location/usage tracking
  described below.

## 6. MR location & usage tracking — how it actually works

- **What's recorded, per MR:** every time they open the app, the app notes
  the timestamp, and (if location permission is granted on that device) the
  GPS coordinates at that moment. When they close or background the app, it
  notes how long that session lasted.
- **Offline-first, like everything else in this app:** none of this is sent
  anywhere in real time. It's saved on the device, and only uploaded to the
  server the next time that MR's device does a catalog sync (signing in, or
  tapping the sync button). If an MR never syncs, their usage data never
  leaves their device.
- **Not shown to the MR, not blocking their work:** there's no in-app popup
  telling the MR this is happening (you confirmed you didn't want one), and
  if they deny the location permission, the app works exactly the same —
  time is still tracked, just without a location for that session.
- **Never applies to the admin's own account.**
- **Where you see it:** the Usage Dashboard (§3.5).

## 7. Business rules worth knowing about

- **Offline-first, by design:** the sales app never contacts the server on
  its own — only when someone taps Sync or signs in. This is intentional
  (field reps may have poor/no connectivity) — don't expect real-time catalog
  or usage-dashboard updates without that MR syncing first.
- **A sync never deletes data on a device based on a bad server response.**
  If the server ever returns an empty catalog (a bug, a permissions mistake,
  a dropped connection), the device keeps its last good copy instead of
  wiping itself.
- **Deleting an employee is immediate and permanent** for that login — there's
  no "deactivate and restore later" option currently. If you want a
  suspend/reactivate option instead of hard delete, that's an enhancement to
  request.
- **One admin account today.** Adding a second admin, or a middle tier (e.g.
  a Regional Manager who can manage MRs in their region but not the whole
  catalog), is not built — flag it if you need it.
- **No in-app tracking disclosure/consent screen for MRs** — a deliberate
  choice you made. The disclosure lives in the Privacy Policy link instead.
  If you change your mind later, revisit this.

## 8. Needs your action (not something I can do from here)

These are things only you can do — I don't have access to your Play Console,
billing, or the ability to knowingly deploy production changes without your
sign-off:

- [ ] **Deploy the Cloud Functions and Firestore rules** — see the "Backend"
      section of [README.md](../README.md). Nothing about Employees, password
      resets, or the usage dashboard works until this is deployed.
- [ ] **Confirm the Firebase project is on the Blaze (pay-as-you-go) plan** —
      required for the Cloud Functions above.
- [ ] **Review `firestore.rules` against what's actually live in the Firebase
      console** before deploying — this repo had no rules file under version
      control before now, so the console is today's real source of truth.
- [ ] **Check Firebase Storage's actual upload rules** for the
      `employee_photos/` path — I can't see your Storage rules from here, and
      if they're scoped per-folder rather than open to any signed-in write,
      employee photo uploads could fail.
- [ ] **Confirm Firebase Authentication's email templates** (Firebase console
      → Authentication → Templates) are configured/branded the way you want,
      since MRs with a real email on file will receive Firebase's password
      reset email directly.
- [ ] **Review the Terms & Conditions / Privacy Policy content**
      (`lib/features/legal/legal_content.dart`, mirrored in
      `docs/TERMS_AND_CONDITIONS.md` / `docs/PRIVACY_POLICY.md`) — I drafted
      reasonable content including a governing-law clause defaulting to
      India; have this reviewed by counsel before treating it as your actual
      legal terms.
- [ ] **Decide whether to retire `bharathbiomedpharma_admin`** (the old,
      separate admin app) now that everything it did lives in this app.

## 9. What to check first

If you're cross-verifying, a reasonable order:

1. Sign in as admin → confirm the shield icon appears and all five admin
   screens (Products via department tap, Manage Departments, Manage
   Designations, Manage Employees, Usage Dashboard) load without errors.
2. Add a test department, add a test product to it, confirm it shows up in
   the normal (non-admin) catalog view after a sync, and that the slideshow
   plays selected products back in the order you tapped them.
3. Add a test employee **without** an email, note the generated
   username/password, sign out, sign back in as that employee using the
   username — confirm they land in the normal catalog view with **no**
   shield icon, and that a session appears on the Usage Dashboard after their
   next sync.
4. Edit that employee, add a real email to their profile, save, sign out,
   sign back in using that email instead of the username — confirm it works,
   then test "Forgot password?" on the login screen with that email.
5. From Manage Employees, use Reset Password on a test employee and confirm
   the new password works.
6. Try Change Password as both admin and a test MR.
7. Delete the test employee, confirm that login stops working.
8. Delete the test product and department to clean up.
