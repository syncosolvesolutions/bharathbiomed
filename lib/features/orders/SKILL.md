# Orders feature

An MR places an order against an [Agency](../../domain/models/agency.dart)
(a distributor/stockist — see that model's doc comment: every order here
is, by construction, a *primary* sale, company→distributor; there's no
distributor→pharmacy "secondary sale" order flow in this app). Full
lifecycle: `pending` (created here) -> `approved`/`rejected` -> `dispatched`
(office marks the product sent) -> `delivered` (the MR who placed the order
marks it physically received). Invoicing, cheques, and payments are handled
entirely offline outside the app — there's no digital replacement for that
step, so `delivered` is the last status an order ever reaches here.

## Files

- `order_form_screen.dart` / `order_controller.dart` — an MR builds an
  order (agency + product lines), offline-first (`OrderRepository.submit`
  only ever queues locally). `order_controller.dart` also holds
  `MyOrdersController.markDelivered`.
- `my_orders_screen.dart` — the MR's own orders and their live status; shows
  a "Mark Delivered" button in place of the status chip once an order is
  `dispatched`.
- `order_approval_screen.dart` / `order_approval_controller.dart` — the
  team workflow queue: approve/reject (direct, rules-gated writes) and
  dispatch (a Cloud Function — see below for why). Nothing to do here once
  dispatched; delivery confirmation is the MR's own action, not a team one.

## Dispatch is a Cloud Function, not a client write

`dispatchOrder` (`functions/src/index.ts`) needs an atomic transaction
against a second resource a plain rules-gated client write can't safely
coordinate: it decrements `Products.stockQuantity`, and, best-effort, walks
each product's batch/expiry records FEFO-style (see `features/admin/
SKILL.md`'s inventory section) — two resources, one transaction.

`markDelivered` (`OrderRemoteDataSource`/firestore.rules), by contrast, is a
plain direct write again — no second resource involved, since
invoicing/payment are out of scope for this app. It's ownership-scoped:
only the order's own `createdByUid`, and only while `dispatched` (see
firestore.rules' `Orders` rule's second `allow update`).

## Targeted notifications

`functions/src/index.ts`'s `onOrderWritten` reacts to the same direct
client writes described above (it doesn't replace them) — a new `pending`
order pushes whoever in the creator's reporting chain holds
`approve_orders`; an `approved`/`rejected`/`dispatched` transition pushes
the creating MR back. There's deliberately no entry for `delivered` in that
trigger's status-message map — that transition is always made by the
creator themselves, so notifying them about their own action would be
pointless. Uses the shared `notifyReportingChainWithPermission` helper
(also used by `features/expenses`/the visit-plan approval flow in
`features/doctors`) and the pre-existing `sendPushToUser`/`DeviceTokens`
primitive — see that helper's doc comment in `index.ts`.

## Not built

- **Secondary sales** (distributor→pharmacy, what actually reached retail)
  — genuinely different from everything above, since it would need orders
  placeable against a `Pharmacy`, not just an `Agency`. Flagged as a
  distinct future feature, not shoehorned into `Order` as a same-shape
  field that would always read "primary" today.
- **In-app invoicing/payment tracking** — deliberately removed (was
  `generateInvoice`/`recordPayment` Cloud Functions, an `Invoices`/
  `Invoices_screen`/`Payment` model layer). The business handles invoices,
  cheques, and payments entirely offline; the app's job stops at confirming
  physical delivery.
