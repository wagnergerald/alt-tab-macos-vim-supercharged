# Features vs upstream (`lwouis/alt-tab-macos`)

Inventory of what this fork (`vimKeysSelection`) adds or changes relative to upstream
`master` (currently **11.9.2**). Includes committed work and in-progress working-tree changes.

Baseline merge-base: `upstream/master`. Primary remotes: `upstream` = lwouis, `gitea` / `github` = fork.

---

## 1. Window hints (major)

Homerow-style letter badges on thumbnails. Type the label to act on that window.

### Preference

| Key | Default (fork) | Upstream |
|-----|----------------|----------|
| `windowHintsEnabled` | `"true"` | absent / off |

**Settings UI:** Controls → **Additional controls…** → “Show window hints on thumbnails”.

When enabled:

- Switcher opens in **focus-hint mode** (badges visible).
- Shortcut style is forced to **“Do nothing on release”** (hold-release focus would dismiss
  before you finish typing). Previous style is backed up under
  `shortcutStyleBackedUpBeforeWindowHints` and restored when hints are turned off
  (`WindowHintsShortcutStyle`).
- Appearance → “After keys are released” control is **disabled** while hints are on.

### Hint alphabet

Charset (order matters for single-letter assignment):

```text
hjkluiopnmasdfgqwertyzxcvb1234567890
```

Right-hand home row → rest of right hand → left home → rest of left → digits.
The key bound to **“Close the switcher immediately”** (`dismissSwitcherShortcut`) is
**excluded** from the charset so it never collides with a hint.

Labels grow to multi-character sequences when there are more windows than letters
(`WindowHintLabels.labels(for:)`). Shown as Unicode circled glyphs (`WindowHintLabelView`).

### Hint modes (`ChooserHintMode`)

| Mode | How you enter | Typing a hint does |
|------|---------------|--------------------|
| `focusHints` | default when hints on; or Space / `enterHintModeFromNormalShortcut` | focus (lowercase) or open snap (uppercase) |
| `minimizeHints` | `minDeminWindowShortcut` | minimize/deminimize |
| `closeHints` | `closeWindowShortcut` | close |
| `quitHints` | `quitAppShortcut` | quit app |
| `fullscreenHints` | `toggleFullscreenWindowShortcut` | toggle fullscreen |
| `hideHints` | `hideShowAppShortcut` | hide/show app |
| `normal` | Escape from a hint mode | no badges; arrow/vim navigation as usual |

With hints **off**, those same shortcuts act on the **currently selected** window (upstream behavior).

### Related shortcuts (defaults)

| Preference key | Default | Role |
|----------------|---------|------|
| `focusWindowShortcut` | `Space` | focus selected / confirm in current hint mode (was Enter upstream) |
| `dismissSwitcherShortcut` | `Q` | close switcher **only while in hint mode** (or snap); with hints off, works whenever switcher is open |
| `enterHintModeFromNormalShortcut` | `⌃K` | from normal mode → focus hints |
| `openSettingsFromSwitcherShortcut` | `⌘,` | open Settings while switcher visible |
| `searchShortcut` | `/` | search (was `S` upstream) |
| close / min / quit / fullscreen / hide | `⌃C` / `⌃M` / `⌃Q` / `⌃F` / `⌃H` | enter that hint mode when hints on (were bare `W`/`M`/`Q`/`F`/`H`) |

If `dismissSwitcherShortcut` and `quitAppShortcut` share the same binding: in hint/snap mode it
**closes the switcher**; in normal mode it **quits the app**.

### Search + hints

- While the `/` field has the caret, hints are paused.
- **Tab** yields focus to thumbnails for hints (`searchFieldYieldsToHints`); Tab again returns to search.
- With search locked / filtered, hints only cover the filtered list.
- Banner copy: Escape leaves hint mode; `Q` (or configured dismiss) closes switcher.

### Banner chrome

Multi-line banner stack was collapsed to a **single compact label** (min height ~14pt) so the
header stays short while still showing mode + shortcut reminders.

---

## 2. Snap layouts (major)

Rectangle-style tiling after you commit a window. Switcher stays open with a snap panel.

### Entry

1. **Enter** (`focusAndSnapWindowShortcut`, default Return), or
2. Completing a window hint with an **uppercase** letter (e.g. `H` for hint `h`) in focus-hint mode.

Not available for windowless apps / non-resizable targets (beeps). While `/` search still owns
typing, Enter **focuses** instead of opening snap; after Tab yields to hints, Enter opens snap.

### Session (`SnapSession`)

- Locks one window; shows `SnapLayoutPanelView` (glyphs + size status).
- **Layout key** → resize to that layout’s size (or pending digit size) → **focus immediately** → dismiss.
- Digits **`1` / `2` / `3`** only arm a size (panel stays open; glyphs update).
- **Space** → focus without resizing.
- **Escape** → clear pending digit first; else leave snap and restore prior hint/selection mode
  (no focus). Another Escape then leaves hint mode / dismisses as usual.

### Size steps (`SnapSizeStep`)

| Digit | Width fraction |
|-------|----------------|
| `1` | ½ |
| `2` | ⅔ (“larger”) |
| `3` | ⅓ |

Layout defaults when no digit: halves/quarters → ½; thirds → ⅓; center two-thirds → ⅔.

### Layout keys (defaults — rebindable in **Snap layouts…**)

| Layout | Preference key | Default key |
|--------|----------------|-------------|
| Left half | `snapLayoutLeftHalfShortcut` | `h` |
| Right half | `snapLayoutRightHalfShortcut` | `l` |
| Center half | `snapLayoutCenterHalfShortcut` | `k` |
| Center two thirds | `snapLayoutCenterTwoThirdsShortcut` | `j` |
| Left third | `snapLayoutLeftThirdShortcut` | `u` |
| Center third | `snapLayoutCenterThirdShortcut` | `i` |
| Right third | `snapLayoutRightThirdShortcut` | `o` |
| Top-left quarter | `snapLayoutTopLeftQuarterShortcut` | `y` |
| Top-right quarter | `snapLayoutTopRightQuarterShortcut` | `p` |
| Bottom-left quarter | `snapLayoutBottomLeftQuarterShortcut` | `n` |
| Bottom-right quarter | `snapLayoutBottomRightQuarterShortcut` | `m` |

Fractions are of the screen’s AppKit **`visibleFrame`** (menu bar / Dock clear). Quarters use the
top or bottom half (`h = 0.5`). Target screen = locked window’s screen, else preferred.

### Focus ordering (latency)

`Window.focus(..., thenSetFrame:)` fronts the window **before** AX resize, so keyboard input reaches
the target promptly (fullscreen exit can delay `setFrame` by ~1s). New AX helpers:
`AXUIElement.setPosition` / `setSize` / `setFrame`.

### Settings UI

Controls → **Snap layouts…** (`SnapLayoutsSheet`): recorder for Enter + each layout key with
mini glyphs. Also listed under Shortcuts when active for Enter.

### Migration

One-shot: drop early digit defaults (`1`–`7`) on snap preference keys so vim-letter registered
defaults apply (`PreferencesMigrations`).

Specs/tests: `src/switcher/snap/SnapLayoutSpecs.md`, `SnapLayoutTests.swift`.

---

## 3. Vim navigation defaults (minor / config)

| Key | Fork default | Upstream default |
|-----|--------------|------------------|
| `vimKeysEnabled` | `"true"` | `"false"` |
| `vimCycleLeft` / `Right` / `Up` / `Down` | `h` / `l` / `k` / `j` | (same bindings when enabled) |

Dedicated preference keys so vim cycle can be rebound independently of snap layout keys
(which reuse the same letters **only while snap session is active**).

---

## 4. Broader default preference shifts

Fresh installs / registered defaults differ from upstream:

| Preference | Fork | Upstream |
|------------|------|----------|
| `holdShortcut` (per slot) | `⌘` | `⌥` |
| `focusWindowShortcut` | `Space` | Return |
| `searchShortcut` | `/` | `S` |
| Action shortcuts (close/min/…) | Control+letter | bare letter |
| `vimKeysEnabled` | on | off |
| `windowHintsEnabled` | on | n/a |
| `spacesToShow` (indices 0, 1, 9) | **visible** spaces | all spaces |
| `showWindowlessApps` (index 0) | show (not only at end) | show at the end |

Existing user defaults are not rewritten except the snap digit migration above.

---

## 5. Thumbnail placeholders & tile badges (working tree)

Not fully committed at inventory time; implemented in the working tree.

### Missing / blocked screenshots

When capture is empty or visually void (e.g. KeePassXC `NSWindowSharingNone`):

- Draw a soft window-proportioned **card** with centered app icon (~42% of shorter edge)
  (`ThumbnailPlaceholder`).
- Show a small **lock** overlay (`PreviewUnavailableIndicator`) on real windows with blocked preview.
- Blank/transparent/near-black unstructured captures count as empty; detailed dark UIs do not.

Windowless apps still use the plain icon + windowless indicator (not the placeholder card).

Specs/tests: `ThumbnailPlaceholderSpecs.md`, `ThumbnailPlaceholderTests.swift`.

### Windowless app indicator redesign

`WindowlessAppIndicator` redrawn as an empty-window glyph (stroke + title-bar rule) instead of a
tiny filled pill; larger sizes so it stays readable on icon and thumbnail layouts.

### Search ordering with windowless buckets

`WindowOrderResolver`: “show at the end” buckets (windowless / hidden / minimized) apply **during
search filtering** too, so a matching windowless row stays below real windows. Locked-preview
windows stay in the normal (real) bucket.

---

## 6. Dev build identity, versioning, About

### AltTabDev bundle

Debug builds use:

- Bundle ID: `com.lwouis.alt-tab-macos.dev`
- Product name / display name: **AltTabDev** / “AltTab Dev”
- Version injected via `scripts/compute_dev_version.sh` → `git describe --tags --dirty --always`
  into `CURRENT_PROJECT_VERSION` / Info.plist (`scripts/set_dev_version_in_info_plist.sh`,
  `config/generated-dev-version.xcconfig`).

### Build metadata in UI

Build phase `inject_build_date_into_info_plist.sh` writes:

- `AltTabBuildDate` — `YYYY-MM-DD HH:MM`
- `AltTabGitHash` — short hash, `-dirty` if needed

Shown as:

- **General** tab footer: `version · hash · build time` (`App.buildInfoSummary`)
- **About** tab: version + git hash + build date lines

---

## 7. License / Keychain / AppCenter (dev ergonomics)

### Debug license storage

`#if DEBUG`: license uses `UserDefaultsKeychain` (suite) instead of the system Keychain so
rotating self-signed certs does not orphan or fight Keychain ACL prompts.

### No Keychain auth UI

`SystemKeychain` and AppCenter’s `MSACKeychainUtil` set `LAContext.interactionNotAllowed = true`
on queries so signature mismatch never shows “wants to use your confidential information”.

### AppCenter off in Debug

`AppCenterCrash` does not start AppCenter / Crashes in DEBUG builds (avoids Keychain + network
noise from the self-signed AltTabDev identity).

### Codesign script

`generate_selfsigned_certificate.sh` passes OpenSSL `-legacy` for **OpenSSL 3 and 4** (macOS
`security import` rejects modern PKCS#12 defaults).

---

## 8. Agent / build workflow docs (repo hygiene)

Fork-only / local-agent notes (not product features for end users):

- `AGENTS.md` / `BUILD.md` — build, signing, worktree `local.xcconfig`, `ai/test.sh` vs CI
- Main-thread IPC guidance and comment style rules for contributors

---

## 9. File map (quick)

| Area | New / notable paths |
|------|---------------------|
| Hints | `WindowHintLabels.swift`, `WindowHintsShortcutStyle.swift`, `WindowHintLabelView.swift`, `TilesView` hint state, `TileView` badge |
| Snap | `src/switcher/snap/*`, `SnapLayoutsSheet.swift`, `App.enterSnapLayoutMode` / `applySnapLayout` / `handleSnapCancel` |
| Shortcuts | `ShortcutAction.swift`, `KeyboardEventsTestable.swift`, Controls / Additional / Shortcuts sheets |
| Prefs | `Preferences.swift` defaults, `PreferencesMigrations.swift` |
| Placeholders | `ThumbnailPlaceholder.swift`, `PreviewUnavailableIndicator.swift` |
| Dev version | `scripts/*dev_version*`, `inject_build_date_into_info_plist.sh`, About/General tabs |
| License | `Keychain.swift`, `LicenseManager.makeKeychain()`, AppCenter vendor patch |

---

## 10. Intentionally unchanged vs upstream

Everything else (window tracking, Pro licensing model for Release, Sparkle, appearance themes,
spaces engine, etc.) tracks upstream 11.9.x. This branch is a **behavior/UX fork** on top of that
base, not a rewrite of the tracking stack.
