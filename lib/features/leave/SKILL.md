# Leave requests feature

An MR's leave requests (sick/casual/earned/other), approved or rejected by
a manager holding `approve_leave`. Structurally identical to
`features/expenses` — read that folder's `SKILL.md` first; this one only
notes what's different.

## Files

- `leave_request_form_screen.dart` — type, a date range (`showDateRangePicker`,
  same-day requests have `startDate == endDate`), optional reason.
- `my_leave_requests_screen.dart` / `my_leave_requests_controller.dart` —
  the signed-in MR's own filed requests and their live status (route
  `/leave`).
- `leave_request_approval_screen.dart` / `leave_request_approval_controller.dart`
  — a manager's review queue (route `/team/leave`), scoped via
  `resolveVisibleEmployees`.

## Data layer

`data/local/leave_request_local_data_source.dart`,
`data/remote/leave_request_remote_data_source.dart`,
`data/repositories/leave_request_repository.dart` — byte-for-byte the same
shape as the expense-claims equivalents (offline queue -> `LeaveRequests`
Firestore collection -> direct rules-gated approve/reject writes, no Cloud
Function needed).

## Targeted notifications

`functions/src/index.ts`'s `onLeaveRequestWritten` mirrors
`onExpenseClaimWritten` exactly — a new `pending` request pushes whoever
holds `approve_leave` in the MR's reporting chain, a decision pushes the
MR back. See `features/orders/SKILL.md`'s equivalent note for the shared
`notifyReportingChainWithPermission` helper.

## What's NOT here yet

This is a leave *request* workflow only — there's no leave-balance
tracking (how many sick/casual/earned days this MR has left this year), no
calendar view of who's out, and no interaction with the attendance/usage-
session data in `features/tracking/`. Approving a leave request here
doesn't automatically suppress or annotate that MR's usage-session records
for the approved dates. All of that is a plausible next iteration, not
built — flag it if the business needs it.
