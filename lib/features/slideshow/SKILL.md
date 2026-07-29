# Slideshow feature

Full-screen presentation view for whatever products the user selected on the
catalog screen. Read-only, offline by construction — it renders a
`List<Product>` handed to it by the router (`state.extra`), so it doesn't
depend on any controller or repository.

## Files

- `slideshow_screen.dart` — a horizontally-swipeable `CarouselSlider` of
  `CachedNetworkImage`s, each wrapped in `WidgetZoom` for pinch-to-zoom.

## Notes

- Product images are loaded via `CachedNetworkImage`, so once an image has
  been viewed once (e.g. right after a sync while online), it stays
  available offline afterwards. A full sync doesn't pre-warm this cache —
  only images actually rendered get cached.
- This screen intentionally has no *data* state management of its own — its
  only local `StatefulWidget` state is forcing landscape orientation on
  enter and restoring the app's normal orientation set on exit (see
  `initState`/`dispose`). If you need to add e.g. autoplay or reordering,
  keep that local here too rather than promoting it into a global
  controller.
