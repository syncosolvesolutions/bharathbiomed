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

### Known gap

`/admin/inventory*` routes are gated to the hardcoded admin allowlist only
(`app_router.dart`'s `onAdminRoute` redirect), even though `firestore.rules`
already lets an Office Admin designation adjust `stockQuantity` and manage
batches (`isOfficeAdmin()`). There's currently no in-app path for an Office
Admin (who isn't also the allowlisted admin) to reach these screens at all
— they'd need direct Firestore access. Flag this if a tenant actually needs
Office Admins to manage inventory day-to-day; fixing it means moving these
routes out of the `/admin/*` prefix (or adding a parallel permission-gated
entry point), not a Firestore rules change.

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
