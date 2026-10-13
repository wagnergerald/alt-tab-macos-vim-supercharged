# SnapLayout — Specs

## Summary

Snap mode opens when the user confirms a window with **Enter** (`focusAndSnapWindowShortcut`), or when they
complete a window hint with an **uppercase** letter (e.g. `H` for hint `h`) in focus-hint mode. The switcher
stays open and shows a snap panel of fixed Rectangle-style presets. Choosing a preset key moves/resizes the
locked window on its screen via AX, then focuses it. **Space** / **Escape** in that mode focus without
resizing. Lowercase hint letters still focus immediately, unchanged.

`SnapLayout` owns the preset list, preference key ids, default keys, and the AppKit-`visibleFrame` → Quartz
top-left rect math used by AX `kAXPosition` / `kAXSize`.

## Behavior & edge cases

- **Fractions are of `visibleFrame`**, not `frame`, so the menu bar and Dock stay clear.
- **Height is always the full visible height**; only the horizontal band changes.
- **Quartz Y** is `mainScreenFrameMaxY - appKitMaxY`, matching `Window.isOnScreen`'s screen conversion.
- **Target screen** is the locked window's current screen, falling back to `NSScreen.preferred`.
- **Enter with no selectable window / windowless app** is a no-op (does not enter snap).
- **Enter in non-focus hint modes** (minimize/close/quit/…) is a no-op.
- **Fullscreen / minimized** windows: exit that state before applying the frame (best-effort, delayed like
  `Window.minDemin`).
- **Hold-release and mouse click** never enter snap; only Enter does.
- **Pattern shortcuts** only act while `SnapSession` is active; they no-op otherwise.

## Scenarios

- `testLeftHalfUsesFirstHalfOfVisibleWidth` — left half origin at visible minX, width = half.
- `testRightHalfStartsAtMidpoint` — right half origin at midX.
- `testCenterHalfStartsAtQuarter` — center half at 25% width, half wide.
- `testThirdsPartitionVisibleWidth` — left/center/right thirds abut without gaps.
- `testCenterTwoThirdsIsCentered` — origin at 1/6, width 2/3.
- `testQuartzYFlipsFromAppKitVisibleFrame` — top of visible frame maps to Quartz y correctly.
- `testPreferenceKeysAreUniqueAndStable` — each case has a distinct `preferenceKey`.
- `testDefaultKeyEquivalentsAreVimKeys` — defaults are `h`/`l`/`k`/`j`/`u`/`i`/`o` (Shift+letter also matches at runtime).
