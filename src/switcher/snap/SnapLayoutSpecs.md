# SnapLayout — Specs

## Summary

Snap mode opens when the user confirms a window with **Enter** (`focusAndSnapWindowShortcut`), or when they
complete a window hint with an **uppercase** letter (e.g. `H` for hint `h`) in focus-hint mode. The switcher
stays open and shows a snap panel. A **layout key** (`k`, `l`, …) applies that layout at its default size and
**focuses immediately**. Digits `1`/`2`/`3` only set a pending size (panel stays open, glyphs update); the
next layout key then applies that size and focuses. **Space** focuses without further resizing. **Escape**
steps back: clears a pending digit, else leaves snap and restores the same window-selection mode as before
snap (e.g. focus hints after an uppercase hint); another Escape then leaves hint mode / dismisses as usual.
Lowercase hint letters still focus immediately.

Width follows `SnapSizeStep`: `1` = half, `2` = two-thirds (larger), `3` = one-third.

Quarters (`y`/`p`/`n`/`m`) use the top or bottom half of `visibleFrame` and the same width steps.

## Behavior & edge cases

- **Fractions are of `visibleFrame`**, not `frame`, so the menu bar and Dock stay clear.
- **Full-height layouts** use `h = 1`; quarters use `h = 0.5` with `y` from the AppKit bottom.
- **Quartz Y** is `mainScreenFrameMaxY - appKitMaxY`, matching `Window.isOnScreen`'s screen conversion.
- **Target screen** is the locked window’s current screen, falling back to `NSScreen.preferred`.
- **Enter with no selectable window / windowless app** is a no-op.
- **Enter while `/` search field captures keys** focuses the selected window (does not open snap).
- **Enter or uppercase hint after Tab yields out of the search field** still opens snap (search mode stays
  `.editing`, but `searchFieldYieldsToHints` means keys go to hints / shortcuts).
- **Layout keys always dismiss** after applying (focus + close panel).
- **Digits alone do not dismiss**; they only arm a size for the next layout key.
- **Escape** clears a pending digit first; otherwise exits snap without focusing and keeps the prior hint mode.
- **Pending digit** is cleared after the next layout key, Escape, or session end.
- **Glyph previews** redraw to the pending digit’s width while a digit is armed.

## Scenarios

- `testLeftHalfUsesFirstHalfOfVisibleWidth`
- `testLargerRightHalfIsTwoThirds`
- `testSmallerLeftHalfIsOneThird`
- `testTopLeftQuarterUsesTopBand`
- `testBottomRightQuarterUsesBottomBand`
- `testSizeStepDigitsMapToFractions`
- `testDefaultKeyEquivalentsIncludeQuarters`
- `testPreferenceKeysAreUniqueAndStable`
