# Build

Agent-oriented notes for compiling, signing, testing, and running AltTab locally. Human-oriented overview lives in [`docs/contributing.md`](docs/contributing.md). Coding conventions live in [`AGENTS.md`](AGENTS.md).

Do **not** drive builds from the Xcode GUI. Prefer the CLI scripts below so DerivedData, signing identity, and product paths stay predictable.

## Prerequisites

* macOS with a recent Xcode (CI currently pins `Xcode_26.0.1`; local Debug builds usually work on the machine’s default Xcode as long as Swift 5.8 is available)
* Command-line tools selected: `xcode-select -p` should point at an Xcode.app
* No remote SPM fetch at build time — dependencies are vendored under `vendor/`

## Certificates (reuse this)

Signing identity must exist **before** the first app build. Without it, `xcodebuild` fails at CodeSign on an embedded framework with `no identity found`, often before the app target’s Swift sources are compiled — so a green-looking partial log can mean nothing of `src/` was checked.

### Local Debug — `Local Self-Signed`

Stable self-signed identity so TCC permissions (Accessibility, Screen Recording, …) stick across rebuilds instead of resetting every time the code signature changes.

One-time per machine (or when the identity is missing from the login keychain):

```bash
scripts/codesign/setup_local.sh
```

What it does:

1. `scripts/codesign/generate_selfsigned_certificate.sh` — creates a PKCS#12 whose CN is **`Local Self-Signed`** (matches `CODE_SIGN_IDENTITY` in `config/debug.xcconfig`)
2. `scripts/codesign/import_certificate_into_main_keychain.sh` — imports into the login keychain and trusts it for code signing

Verify:

```bash
security find-identity -v -p codesigning
# expect a line containing: "Local Self-Signed"
```

Generated artifacts (`codesign.p12`, `.crt`, `.key`, `.conf`) are gitignored. Re-run `setup_local.sh` if the identity disappears; a new cert will require re-granting TCC permissions once.

**Reuse across agents / worktrees on the same Mac:** the identity lives in the shared login keychain. Do not regenerate per worktree. Only re-run `setup_local.sh` when `security find-identity` no longer lists `Local Self-Signed`.

### Release / CI — Developer ID

`config/release.xcconfig` hard-codes:

```text
CODE_SIGN_IDENTITY = Developer ID Application: Louis Pontoise (QXD7GW8FHY)
```

Team ID `QXD7GW8FHY`, bundle ID `com.lwouis.alt-tab-macos`. These must stay stable — Keychain license items are tied to the code signature (see License / Keychain invariant in `AGENTS.md`).

* CI master: `scripts/codesign/setup_ci_master.sh` decodes `APPLE_P12_CERTIFICATE` and imports into a temporary keychain
* CI PR-style / unsigned-selfsigned path: `scripts/codesign/setup_ci_pr.sh` (ephemeral self-signed in a throwaway keychain)

Local agents should not need the Developer ID cert for day-to-day Debug work.

## `config/local.xcconfig` (optional overrides)

`debug.xcconfig` and `release.xcconfig` both `#include? "local.xcconfig"`. The file is **gitignored**.

Use it for per-developer overrides (`CODE_SIGN_IDENTITY`, `APPCENTER_SECRET`, `DOMAIN`, `API_DOMAIN`, …). CI writes one via `scripts/replace_environment_variables_in_app.sh`.

**Git worktrees:** copy `config/local.xcconfig` from the main checkout if that checkout relies on overrides. A missing file is fine when Debug signing already resolves to `Local Self-Signed` from `debug.xcconfig` and the identity is in the keychain.

Also gitignored: `config/generated-dev-version.xcconfig` (written by `scripts/write_dev_version_xcconfig.sh` during `ai/build.sh`).

## Daily agent workflow (Debug)

Scripts under `ai/` are the preferred entry points. Prefer **copying the `xcodebuild` invocation** out of them when you only need a compile check (full `ai/build.sh` also quits/relaunches the app).

| Goal | Command | Notes |
|------|---------|--------|
| Compile + install + launch Dev app | `bash ai/build.sh` | Writes version xcconfig, builds Debug scheme into `DerivedData/`, symlinks `/Applications/AltTabDev.app` → product, opens it |
| Compile check only | Copy the `xcodebuild … -scheme Debug …` block from `ai/build.sh` | Same flags; skip the quit/link/open tail |
| Unit tests | `bash ai/test.sh` | Debug config, ~1.3s incremental. **Do not** use `scripts/run_tests.sh` locally — that is CI Release (~34s full recompile) |
| Run with debug logs | `bash ai/run.sh` | Uses `/Applications/AltTabDev.app` if present, else DerivedData product; launches via `open` so TCC sees the app (not the terminal) as responsible process |
| Time profile | `bash ai/profile.sh` | `xctrace` around the Debug product |

Product identity for Debug builds (`config/debug.xcconfig`):

* Bundle ID: `com.lwouis.alt-tab-macos.dev`
* Product name: `AltTabDev`
* Sign identity: `Local Self-Signed`

Stable `/Applications/AltTabDev.app` symlink keeps Launch Services / TCC on a fixed path across rebuilds.

## Release / CI pipeline (reference)

Order on `master` (see `.github/workflows/ci_cd.yml`):

1. `scripts/ensure_generated_files_are_up_to_date.sh`
2. `scripts/determine_next_version.sh`
3. `scripts/replace_environment_variables_in_app.sh` → writes `config/local.xcconfig`
4. `scripts/codesign/setup_ci_master.sh`
5. `scripts/run_tests.sh` (Release)
6. `scripts/build_app.sh` — `xcodebuild -scheme Release`
7. `scripts/package_and_notarize_release.sh`
8. symbols / appcast / website / semantic-release

Local agents almost never run this path.

## Reusable pieces (checklist for another agent or machine)

| Piece | Reuse how |
|-------|-----------|
| `scripts/codesign/setup_local.sh` + friends | Same scripts on any Mac; identity is per-keychain, not per-repo-clone |
| Login-keychain `Local Self-Signed` | Shared by all clones/worktrees on that Mac |
| `ai/build.sh` / `ai/test.sh` / `ai/run.sh` | Copy or invoke as-is; they `cd` to repo root |
| `config/*.xcconfig` | Version-controlled; don’t edit signing identity in GUI |
| `config/local.xcconfig` | Copy between worktrees on the same machine when present |
| `DerivedData/` | Local only (gitignored); `ai/*` scripts pin `-derivedDataPath DerivedData` |
| Developer ID + notarization secrets | Maintainer/CI only; not for routine agent builds |

## Quick smoke sequence (fresh machine / worktree)

```bash
# once per machine, if missing:
security find-identity -v -p codesigning | grep -q 'Local Self-Signed' \
  || scripts/codesign/setup_local.sh

# optional: if main checkout has overrides
# cp /path/to/main/config/local.xcconfig config/local.xcconfig

bash ai/test.sh
bash ai/build.sh   # or only the xcodebuild lines from it
```

## Common failure modes

| Symptom | Likely cause |
|---------|----------------|
| `no identity found` during CodeSign of a framework | Missing `Local Self-Signed` (or Release identity); run `setup_local.sh` / check keychain |
| App builds but switcher never appears; TCC shows not granted | Launched from a shell instead of `open` / `ai/run.sh` / `ai/build.sh` — terminal is the responsible process |
| Worktree build “succeeds” but didn’t compile `src/` | Failed early at dependency CodeSign; or only `unit-tests` target was built (`ai/test.sh` does not build the app target) |
| Codesign / Keychain prompts on every rebuild | Ad-hoc or changing identity; use the stable `Local Self-Signed` cert |
