# Architecture refactor plan

Baseline: `948dc26` on `feature/smart-next-destination`.

## Goal

Reduce `_SeichiMapPageState` to UI coordination without changing user-visible behavior, stamp eligibility, offline guarantees, or onboarding timing.

## Rules

- One responsibility at a time.
- Preserve existing behavior before optimizing.
- Do not combine GPS/stamp rule changes with structural refactors.
- Every phase must pass `flutter analyze`, `flutter test`, and `git diff --check`.
- Runtime-check GPS, first-launch onboarding, stamp collection, event switching, offline sync, and settings after relevant phases.

## Responsibility map

| Responsibility currently coordinated by main.dart | Target |
| --- | --- |
| Jomo Karuta card ordering | domain utility |
| onboarding persistence | onboarding service |
| authentication/session bootstrap | app/session bootstrap service |
| current event loading/participation/preference | event controller/service |
| profile display state | profile service/controller |
| collection cache/cloud history/pending sync | collection controller around CollectionHistoryService |
| location permission/service/stream/lifecycle | location controller |
| stamp eligibility and anti-jump checks | pure stamp eligibility policy/service |
| next destination/manual selection | destination controller around NextDestinationService |
| recommended route persistence/state | route controller |
| weather refresh throttling/state | real-world state controller around WeatherService |
| level/achievement/rank refresh | progression controller |
| interstitial timing | keep in InterstitialAdService; UI only triggers safe points |
| map camera/marker/dialog rendering | UI layer |
| tab navigation/screen composition | UI layer |

## Planned phases

1. Low-risk constants and persistence extraction.
2. Add pure, unit-testable stamp eligibility policy without changing thresholds.
3. Extract location state/permission/stream ownership.
4. Extract collection synchronization orchestration.
5. Extract event state and event switching orchestration.
6. Extract destination and recommended-route state.
7. Extract progression/profile refresh state.
8. Extract weather/real-world refresh state.
9. Simplify startup orchestration.
10. Final dead-code/import cleanup and regression pass.

## Explicit non-goals during refactor

- No state-management framework migration.
- No database schema changes.
- No RLS/RPC changes.
- No GPS threshold changes.
- No UI redesign.
- No ad-frequency changes.
