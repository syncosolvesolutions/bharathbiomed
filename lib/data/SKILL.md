# Data layer

Repository pattern: `features/` only ever depends on the classes in
`repositories/`, never directly on `local/` or `remote/` data sources or on
Firebase packages.

## Structure

- `local/` — sqflite. `app_database.dart` opens the single `catalog.db`;
  `product_local_data_source.dart` is the only class that writes SQL.
- `remote/` — Firestore/FirebaseAuth. Each data source wraps exactly one
  Firebase SDK so it's swappable/mockable.
- `repositories/` — combines local + remote into the API features actually
  use:
  - `ProductRepository` — local-first (see `features/catalog/SKILL.md`
    for the offline-first rule this enforces).
  - `AuthRepository` — thin pass-through to `AuthRemoteDataSource`, exists
    mainly so features never import `firebase_auth` directly.
- `providers.dart` — the only place repositories are constructed
  (`authRepositoryProvider`, `productRepositoryProvider`). Override these in
  tests to inject fakes instead of hitting real Firebase/sqflite.

## Adding a data source

Follow the existing pattern: a `*_remote_data_source.dart` or
`*_local_data_source.dart` class that does raw I/O and returns/accepts
`domain/models/` types, then a repository method that decides *when* to use
local vs. remote. Business/UI logic (loading states, error messages) stays
out of this layer — that's the controllers' job under `features/`.
