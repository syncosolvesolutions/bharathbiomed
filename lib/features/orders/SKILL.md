# Orders feature

An MR places an order against an [Agency](../../domain/models/agency.dart)
(a distributor/stockist — see that model's doc comment: every order here
is, by construction, a *primary* sale, company→distributor; there's no
distributor→pharmacy "secondary sale" order flow in this app). Full
lifecycle: `pending` (created here) -> `approved`/`rejected` -> `dispatched`
-> `invoiced`.

## Files

- `order_form_screen.dart` / `order_controller.dart` — an MR builds an
  order (agency + product lines), offline-first (`OrderRepository.submit`
  only ever queues locally).
- `my_orders_screen.dart` — the MR's own orders and their live status.
- `order_approval_screen.dart` / `order_approval_controller.dart` — the
  team workflow queue: approve/reject (direct, rules-gated writes),
  dispatch and generate-invoice (both Cloud Functions — see below for why).
- `invoices_screen.dart` / `invoice_controller.dart` — every generated
  invoice, plus recording payments against one (`manage_invoices`-gated).

## Dispatch and invoicing are Cloud Functions, not client writes

`dispatchOrder` and `generateInvoice` (`functions/src/index.ts`) both need
an atomic transaction against a second resource a plain rules-gated client
write can't safely coordinate:

- **`dispatchOrder`** decrements `Products.stockQuantity`, and,
  best-effort, walks each product's batch/expiry records FEFO-style (see
  `features/admin/SKILL.md`'s inventory section) — two resources, one
  transaction.
- **`generateInvoice`** assigns a race-safe sequential invoice number via a
  counter doc, and computes tax/due-date from tenant config (see below).

## Tax and payment tracking

Added on top of the original operational lifecycle (approve → dispatch →
invoice), which had no financial depth at all:

- **Tax**: `generateInvoice` bakes in `TAX_LABEL`/`TAX_RATE_PERCENT` from
  `functions/src/generatedTenantConfig.ts` (the Cloud-Functions-side twin
  of `TenantConfig`'s same fields — see `core/tenant/tenant_config.dart`)
  onto the `Invoice` doc **at generation time**, not read live — a later
  tenant tax-rate change must never reinterpret an already-issued invoice.
  This is a single tenant-wide rate, not a per-product tax engine — see
  `TenantConfig.taxRatePercent`'s doc comment for why (this app has no
  per-product HSN/tax-rate field).
- **Payment**: a separate `recordPayment` Cloud Function
  (`manage_invoices`-gated) writes a `Payment` doc and updates
  `Invoice.amountPaid`/`PaymentStatus` atomically — same "needs a
  transaction across two resources" reasoning as dispatch/invoice
  generation. Never blocks/rejects for business reasons beyond "don't let
  this overpay the invoice" — a real dispute or refund is a human decision
  recorded in `Payment.notes`, not something this function infers.
  `Invoice.isOverdue` is derived from `dueDate` (issuedAt +
  `TenantConfig.paymentTermsDays`), re-evaluated on every read rather than
  stored as a fourth `PaymentStatus` value, so a payment recorded after the
  due date doesn't need a separate "was overdue" transition to clean up.

## Targeted notifications

`functions/src/index.ts`'s `onOrderWritten` reacts to the same direct
client writes described above (it doesn't replace them) — a new `pending`
order pushes whoever in the creator's reporting chain holds
`approve_orders`; an `approved`/`rejected`/`dispatched`/`invoiced`
transition pushes the creating MR back. Uses the shared
`notifyReportingChainWithPermission` helper (also used by
`features/expenses`/`features/leave`/the visit-plan approval flow in
`features/doctors`) and the pre-existing `sendPushToUser`/`DeviceTokens`
primitive — see that helper's doc comment in `index.ts`.

## Not built

- **Secondary sales** (distributor→pharmacy, what actually reached retail)
  — genuinely different from everything above, since it would need orders
  placeable against a `Pharmacy`, not just an `Agency`. Flagged as a
  distinct future feature, not shoehorned into `Order` as a same-shape
  field that would always read "primary" today.
- **Accounting-ledger export** (a Tally/Zoho-importable format) — the
  Invoices screen does have a plain CSV/PDF export now (`ReportExportService`,
  see `core/SKILL.md`), but it's a raw dashboard export, not a
  purpose-built accounting ledger format.
