# Expense claims feature

An MR's TA/DA (Travel & Daily Allowance) expense claims: file one, a
manager with `approve_expenses` approves/rejects it. Same offline-first
approval-workflow shape as `features/orders` (see that folder's screens for
the fullest version of this pattern — dispatch/delivery steps included) —
this is the simpler variant, since a claim has nothing to fulfill once
approved.

## Files

- `expense_claim_form_screen.dart` — an MR files a claim: category, date,
  amount, optional description and receipt photo. Offline-first except the
  receipt photo (see below); `_save` queues it locally either way.
- `my_expense_claims_screen.dart` — the signed-in MR's own filed claims and
  their live status (`MyExpenseClaimsController`, route `/expenses`).
- `my_expense_claims_controller.dart` — `myExpenseClaimsControllerProvider`.
  Reads live from Firestore, same reasoning as `MyOrdersController`: a
  claim's status only matters once it's reached the server, so
  not-yet-uploaded claims don't show here (see the sync banner/progress
  overlay for that instead).
- `expense_claim_approval_screen.dart` / `expense_claim_approval_controller.dart`
  — a manager's review queue (route `/team/expenses`), scoped to their own
  reporting-chain downline via `resolveVisibleEmployees`, or everyone for a
  `view_global_data` holder. Only pending claims show (approved/rejected are
  terminal, mirrors `OrderApprovalController` minus the dispatch/delivery
  statuses `Order` has and `ExpenseClaim` doesn't).

## Data layer

- `data/local/expense_claim_local_data_source.dart` — the offline queue
  (`expense_claims` sqflite table, see `AppDatabase` v8).
- `data/remote/expense_claim_remote_data_source.dart` — the `ExpenseClaims`
  Firestore collection. Approve/reject are direct client writes (gated by
  `firestore.rules`' `approve_expenses` check), not Cloud Functions — unlike
  `Order.dispatch`, there's no second resource (stock) needing an atomic
  transaction, so a plain rules-gated write is enough.
- `data/repositories/expense_claim_repository.dart` — combines the two:
  `submit` only ever queues locally; `uploadPending` (called from
  `CatalogController.sync`) is what actually reaches Firestore.

## Receipt photos are not offline-first

Every other field on an `ExpenseClaim` follows this app's offline-first
rule (queue locally, upload on next sync). The optional receipt photo does
not: `PhotoPickerField` (shared with the admin's product/employee photo
fields) uploads to Firebase Storage immediately on pick, which needs
connectivity. Submitting a claim without a photo, entirely offline, works
fine — the photo just isn't there yet. There is no local-blob-then-sync
pipeline for images anywhere in this app; adding one is a bigger change
than this feature needed.

## Targeted notifications

`functions/src/index.ts`'s `onExpenseClaimWritten` reacts to the same
direct writes above — a new `pending` claim pushes whoever in the MR's
reporting chain holds `approve_expenses`; an approve/reject decision
pushes the MR back. See `features/orders/SKILL.md`'s equivalent note for
the shared `notifyReportingChainWithPermission` helper.

## Extending

New expense categories: `domain/models/expense_claim.dart`'s
`ExpenseCategory` enum — it's a fixed set (not tenant-configurable like
`Designation`), since TA/DA categories are standard across pharma
field-force claims; `ExpenseCategory.other` + the free-text `description`
covers anything a fixed enum can't.
