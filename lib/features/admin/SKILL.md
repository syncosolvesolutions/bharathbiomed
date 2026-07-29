# Admin feature

This is the largest feature folder (product/department/designation CRUD,
employee management, the usage dashboard, notifications) — this file
doesn't attempt to catalog all of it. It covers the inventory/batch-expiry
subsystem specifically, since that's the newest and least obvious part.

## Inventory & batch/expiry tracking

- `manage_inventory_screen.dart` — flat stock levels per product
  (`Product.stockQuantity`), with a manual "Adjust" delta action
  (`AdminCatalogController.adjustStock`) — this is the original,
  simplest layer and is still the number `dispatchOrder` (Cloud Function)
  checks/decrements when an order ships.
- `product_batches_screen.dart` / `admin_catalog_controller.dart`'s
  `productBatchesProvider` — an **optional, additive** batch/lot tracking
  layer on top of that same `stockQuantity` (`domain/models/product_batch.dart`,
  `Products/{productId}/Batches/{batchId}`). Adding or deleting a batch
  moves `stockQuantity` by the same amount in one Firestore transaction
  (`ProductRemoteDataSource.addBatch`/`deleteBatch`), so the two stay in
  sync **as long as every stock movement goes through batches** — a plain
  "Adjust Stock" delta (no batch attached) is a legitimate, supported way
  to move `stockQuantity` without touching any batch, so the two numbers
  can legitimately diverge if a tenant mixes both methods. The batch
  screen surfaces that mismatch as a visible warning rather than hiding
  it; it's expected, not a bug, if not every product uses batch tracking.
- `expiry_alerts_screen.dart` / `expiringBatchesProvider` — a
  `collectionGroup('Batches')` query across every product, for a
  90-day expiry-alert view.
- `functions/src/index.ts`'s `dispatchOrder` — FEFO (First-Expiry-First-
  Out): when an order ships, it decrements `stockQuantity` (as it always
  did) and, best-effort, also walks that product's `Batches` oldest-
  expiry-first, consuming quantity from each until the dispatched amount
  is covered. If tracked batches don't fully cover the dispatched
  quantity (e.g. no batches recorded for that product), the shortfall
  simply isn't attributed to any batch — `stockQuantity` is still the
  number that gated whether dispatch was allowed at all.

### Office Admin access to `/admin/inventory*` (closed 2026-07-29)

`app_router.dart`'s `onAdminRoute` redirect used to gate every `/admin/*`
route to the hardcoded admin allowlist only, even though `firestore.rules`
already let an Office Admin designation adjust `stockQuantity` and manage
batches (`isOfficeAdmin()`) — there was no in-app path to reach these
screens without direct Firestore access. Fixed: the redirect now also lets
an Office Admin (not the allowlisted admin) through, but only to the three
Inventory routes (`/admin/inventory`, `/admin/inventory/batches`,
`/admin/inventory/expiry-alerts`) — everything else under `/admin/*`
(Employees/Designations/Departments/Products CRUD) stays hardcoded-admin-
only, since those still require the admin allowlist server-side too
(`requireAdmin`-gated Cloud Functions, or admin-only firestore.rules). On
mobile an Office Admin reaches Inventory via a new toolbar icon on the
catalog screen (`product_list_screen.dart`, shown instead of the full
admin shield icon); on web the same redirect sends them to the `/admin`
route itself, where `AdminWebShell` shows a reduced sidebar for this role
— see `features/admin_web/SKILL.md`.

## Pagination — deliberately not added to Manage Employees (or similar lists)

Every admin list screen (Manage Employees, Manage Designations, Usage
Dashboard, ...) fetches its full collection in one `fetchAll()` call and
filters/searches **client-side** over the whole loaded list (see
`docs/TODO.md`'s "search added to every admin list" entry). This was
considered for pagination as part of the production-readiness pass and
deliberately left as-is, for a real reason, not an oversight:

- Flutter's `ListView.builder` already lazily builds only on-screen rows —
  there's no rendering-performance problem at hundreds of rows, which is
  the realistic scale for this app's target customers (small-to-mid pharma
  field-force teams). The `ListView.builder(itemCount: ...)` pattern used
  throughout this codebase already handles that.
- The actual cost pagination would reduce is Firestore *read* volume for a
  collection that grows into the thousands — but Firestore cursor-based
  pagination (`.limit()`/`.startAfter()`) fundamentally conflicts with
  "search across everyone," since a query page only contains a slice of
  the collection. Adding pagination here would either (a) silently make
  search incomplete (it'd only find matches within already-loaded pages —
  a real, easy-to-miss bug, not a cosmetic tradeoff), or (b) require a
  dedicated server-side search index (e.g. Algolia/Typesense/Firestore's
  own newer full-text search extensions) to keep search working across the
  whole collection — a real infrastructure addition, not a small change.

If a tenant's employee/product/order list actually grows past a few
hundred rows and Firestore read cost or initial-load latency becomes a
real problem, revisit this with the search-completeness tradeoff above in
mind — don't add `.limit()` to a `fetchAll()`-backed screen without also
deciding what happens to that screen's search box.
