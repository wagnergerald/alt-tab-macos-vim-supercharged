# MostProbableOrder — Specs

## Summary

Pure scoring for the switcher's **Most Probable** window order. Learns app→app focus
transitions (`bundleIdentifier`); titles never enter the score (Chrome-safe). Persistence is
`AppTransitionStats`; the comparator pins live in `WindowOrderResolver`.

## Behavior & edge cases

- **`appScore`**: `P(to | from)` = weight(from→to) / Σ weight(from→·). Missing from/to → `0`.
- **`record`**: ignores empty ids and same-app transitions (within-Chrome focus does not learn).
- **`decayedWeight` / `decayAll`**: exponential half-life (~1.5 days); edges below dust threshold drop.
- **Cold start**: all scores `0` → resolver falls through to `lastFocusOrder` (classic MRU).
- **Within one app**: identical scores → `lastFocusOrder` (MRU among Chrome windows).

## Resolver contract (`.mostProbable`)

1. Show-at-end buckets / search ranking unchanged.
2. MRU slots `0..<pinCount` (default 3) stay hard-pinned in MRU order.
3. Remaining tiles: higher `probableScore` first, then `lastFocusOrder`.

## Test scenarios

Mirrors `MostProbableOrderTests.swift` / resolver most-probable cases 1:1.

- `testAppScoreIsConditionalProbability`
- `testAppScoreMissingEdgeIsZero`
- `testRecordIgnoresSameAppAndEmpty`
- `testDecayHalvesWeightAtHalfLife`
- `testDecayAllDropsDust`
