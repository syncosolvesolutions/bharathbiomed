# Doctors feature

Doctor master data an MR is assigned, their weekly recurring visit plan
(beat/route plan), and daily visit-log capture ("who did I see today and
how did it go").

## Files

- `mr_doctors_screen.dart` / `doctor_detail_screen.dart` / `doctor_form_screen.dart`
  — an MR's assigned-doctor list, detail view, and propose-a-new-doctor
  form (goes through `DoctorChangeRequests`, reviewed by the admin — see
  `data/repositories/doctor_change_request_repository.dart`, not this
  folder).
- `today_visits_screen.dart` / `visit_log_dialog.dart` — today's planned
  visits (from the weekly plan, see below) with a quick "log this visit"
  dialog. Logs are append-only, offline-first (`DoctorVisitLog`).
- `doctor_controller.dart` — the MR's assigned-doctor list, offline-first
  like the catalog (`DoctorController.build()` reads the local cache only;
  `sync()` is the one place that hits Firestore, called from
  `CatalogController.sync`).

### Weekly visit plan (beat/route plan) + approval workflow

- `doctor_visit_plan_controller.dart` / `visit_plan_screen.dart` — the MR's
  own recurring weekly schedule editor (`DoctorVisitPlans/{mrUid}`, one doc
  per MR, one weekday tab each). `toggleDoctor` saves immediately
  (best-effort online, falls back to a local unsynced flag — see
  `DoctorVisitPlanRepository.save`).
- **Approval workflow on top of that plan** (`VisitPlanStatus` on
  `domain/models/doctor_visit_plan.dart`): the MR taps "Submit for
  Approval" (`DoctorVisitPlanController.submitForApproval`), a manager
  holding `approve_requests` reviews it from
  `visit_plan_approval_screen.dart` / `visit_plan_approval_controller.dart`
  (route `/team/visit-plans`). Content edits are blocked by
  `firestore.rules` while a review is `pending` — `visit_plan_screen.dart`
  disables its checkboxes in that state rather than letting a save fail
  server-side. Editing after an `approved`/`rejected` decision does **not**
  reset the status back to `draft` — see `DoctorVisitPlan`'s class doc
  comment for why (approval is a snapshot-in-time signal, not a
  continuously-enforced constraint).
- This is the first feature to actually check the `approve_requests`
  permission (previously defined but unused — see its doc comment in
  `domain/models/permission.dart`).
- **Targeted notifications**: `functions/src/index.ts`'s
  `onDoctorVisitPlanWritten` fires only on an actual `status` transition
  (content-only edits don't touch it, and the first-ever save defaults to
  `draft`, not `pending` — see its own doc comment) — submitting for
  approval pushes whoever holds `approve_requests` in the MR's chain, a
  decision pushes the MR back. Same shared
  `notifyReportingChainWithPermission` helper as
  `features/orders`/`features/expenses`.

## Extending

New visit-plan fields (e.g. a per-visit time window): extend
`domain/models/doctor_visit_plan.dart` and
`data/remote/doctor_visit_plan_remote_data_source.dart` together, same as
any other feature here — the Firestore shape (`toJson`/`fromJson`) and the
local sqflite blob cache (`data/local/doctor_local_data_source.dart`'s
`getVisitPlan`/`saveVisitPlan`) both need to agree.
