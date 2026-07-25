# Catalog feature

The main screen: products grouped by department, multi-select, feeds the
slideshow. This is an **offline-first** feature — read that carefully before
changing anything here, it's the core design constraint of the whole app.

## Offline-first rule

`CatalogController.build()` only ever reads the local sqflite cache
(`ProductRepository.loadCachedCatalog()`). It never touches Firestore on its
own. The *only* place Firestore is queried is `CatalogController.sync()`,
called explicitly from:

- the login screen, right after a successful sign-in, and
- the download-icon sync button in the catalog app bar.

If you're tempted to make `build()` "auto-refresh from the network when
online" — don't. That breaks the guarantee that opening this app never
makes an unexpected network call, which is the whole point of the app for
field reps with unreliable connectivity.

## Files

- `catalog_controller.dart` — `catalogControllerProvider`
  (`AsyncNotifier<CatalogSnapshot>`). `sync()` deliberately leaves `state`
  untouched on failure (old data stays on screen); callers must catch and
  report the error themselves (see `product_list_screen.dart`'s `_syncCatalog`).
- `selection_controller.dart` — which products are queued for the slideshow.
  Kept alive for the whole app session, not just this screen, so the
  selection survives pushing to `/slideshow` and popping back.
- `product_list_screen.dart` — the screen itself: sync button, empty-state
  messaging ("no data synced yet"), department list, FAB to open the
  slideshow with the current selection.
- `widgets/category_section.dart`, `widgets/product_card.dart` — presentation
  only, no data fetching.

## Extending

- New catalog fields: extend `domain/models/product.dart` and the two data
  sources (`data/local/product_local_data_source.dart`,
  `data/remote/product_remote_data_source.dart`) together — the local sqflite
  schema and the Firestore shape must both change.
