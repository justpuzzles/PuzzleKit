# PuzzleKit

Shared, game-agnostic code for the Just Puzzles family. A local Swift
package that each game references by path (`../PuzzleKit`).

**v0 (2026-11-10)**, adopted by Just Kakuro 1.2:

| Type | Replaces | Fixes |
|---|---|---|
| `DayKey` | each game's `Engine/DailySeed.swift` copy | Gregorian Y-M-D whatever the phone's calendar; DST-proof `previous()`/`next()` by Julian-day arithmetic; `weekday` without `Calendar` |
| `DaySeed` | the FNV-1a in each `DailySeed` | one implementation of the shipped seed hash |
| `DailyRecord` | `ProgressStore.DailyRecord` + its methods | replay guard (`DailyOutcome.replay`), late solve keeps the streak, tolerant decoding |
| `SaveSlots` | the single `saveGame.v1` slot | one slot per mode; a visit with no progress never overwrites |
| `TodayClock` | `DayKey(date: .now)` in view bodies | Home stale after midnight |
| `DailyShare` | (new) | the family's share text for a solved daily |

Not in v0 yet (roadmap §3.1): `PaywallState`, `EntitlementSource`, a widget
timeline, iCloud KVS for streaks.

## Rules

- **Foundation and Observation only.** No SwiftUI, UIKit or StoreKit. A game's
  `Engine/` must still compile under bare `swiftc`; engine files import the kit
  as
  ```swift
  #if canImport(PuzzleKit)
  import PuzzleKit
  #endif
  ```
  and a CLI bench passes the kit's sources in the same module:
  `swiftc -O -o bench Kakuro/Engine/*.swift ../PuzzleKit/Sources/PuzzleKit/*.swift main.swift`.
- **Shipped formats are API.** `DayKey`'s JSON shape and `isoString`,
  `DaySeed`'s hash and `DailyRecord`'s keys are what games already store and
  seed from. Changing them rewrites players' dailies or drops their history.
- Platforms match the widest game: iOS 18, macOS 14, tvOS 17, visionOS 2.

## Test

```bash
swift test
```

## Adopting it in a game

1. In the `.xcodeproj`, add a local package reference to `../PuzzleKit` and
   link the `PuzzleKit` product to the app target (the one edit to
   `project.pbxproj` that synchronized groups cannot do for you).
2. Delete the game's `DayKey`; keep its `DailySeed` (prefix and weekly schedule
   are the game's) but hash through `DaySeed.seed(prefix:day:)`.
3. Move the daily record onto `DailyRecord` under the game's existing key;
   skip stats and best times when `record` returns `.replay`.
4. Replace the save slot with `SaveSlots`, keeping the old key as the standard
   slot so no save is lost.
5. Put a `TodayClock` in the environment and call `refresh()` on
   `scenePhase == .active`.

The compilation (`../compilation`) builds each game from a pinned commit as a
static framework. Bumping a game's pin past its PuzzleKit adoption means
adding this package to that game's Kit target in `project.yml`.
