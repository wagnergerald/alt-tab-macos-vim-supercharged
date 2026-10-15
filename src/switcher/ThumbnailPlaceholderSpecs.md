# ThumbnailPlaceholder — Specs

## Summary

When a window has no usable screenshot (KeePassXC and others set `NSWindowSharingNone`), the tile
must not look empty. We draw a soft window-proportioned card with the **app icon centered** at
~42% of the shorter edge — readable, not a full-bleed logo, not louder than real thumbnails.

Blank/transparent captures are treated as missing so they do not stick as empty tiles.

## Behavior & edge cases

- **`isVisuallyEmpty`**: fully transparent, or a flat near-black void with no luminance structure.
- **Dark real UIs** with detail are not empty (luminance variance stays).
- **`compose`**: rounded soft fill + centered icon; works with a nil icon (card only).
- **Tile layout** still uses `ThumbnailPlaceholderLayout.reservesWindowGeometry` for aspect when
  screen recording is granted and the window size is known.
- **Windowless apps** do not use this card — they keep the plain app icon plus `WindowlessAppIndicator`.
- **Blocked / missing preview** on a real window uses this card plus `PreviewUnavailableIndicator` (lock).

## Scenarios

- `testVisuallyEmptyTransparentImage`
- `testVisuallyEmptySolidBlackImage`
- `testVisuallyEmptyRejectsDetailedDarkImage`
- `testComposeCentersIconAndKeepsPixelSize`
