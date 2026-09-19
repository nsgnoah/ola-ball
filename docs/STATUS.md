# Ola Ball — Status / Handoff

> **FILE OWNERSHIP (from 2026-09-19 09:05):** Noah is working live with the original lead session on GRAPHICS. That session owns everything under `OlaBall/Scene/` (it is building a new renderer in `OlaBall/Scene/Stadium/` and will delete `FieldScene.swift` when it swaps over) plus `OlaBall/Views/GameView.swift`. Overnight session: do NOT spawn graphics builders or edit those paths; keep working on play balance (`OlaBall/Sim/`), tips/content, tests, and the other Gauntlet pieces. Commit your work in small commits so nothing is lost.

_Updated: 2026-09-19 09:30 CDT_

## What this is now
"Draw the Play": a 3D (SceneKit) football game. Pre-snap you see the defense and a callout ("Defense shows 8 in the box"); you drag from a glowing offensive player to draw the ball carrier's path or receiver's route; the play simulates live (blocking, pursuit, man coverage with reaction lag, passes resolved by separation, tackles). On defense you pick a call (Stack the Box / Balanced / Play the Pass / Blitz) and watch. Kicks use a tap-timing meter. Coach's Tips (max 8 new per game) fill the Playbook. The old menu-driven prototype is tagged `v0-menu-prototype`; do not go back to it.

## Done
- Builds for iPhone 16 Pro (iOS 18.0) simulator. A full game plays end to end via the autoplay UI test (`-ui-testing-autoplay`) in ~3 minutes.
- `OlaBall/Sim/`: FieldGeometry, Formations (offense lineup, 4 defensive looks + goal line), PlayPlan/SimPlayer, PlaySim (tick-based, seeded), AIPlaycaller (AI offense vs the user's defensive call; AI defensive look vs the user), PlayAnalyst ("why" lines).
- `OlaBall/Scene/`: FieldScene (SceneKit scene) and FieldSceneView (SCNView host, pan-to-draw gesture, per-frame sim clock).
- `OlaBall/Game/GameSession.swift`: presnap → live → result → driveOver → next possession, kicks, opponent 4th-down logic, tips, XP.
- `OlaBall/Views/GameView.swift` (HUD over the 3D scene), KickMeterView, DefenseCallView; Home/TeamPick/Playbook/GameOver kept.
- Rewritten Playbook (`Content/Concepts.swift`, 37 entries) and TipDirector for the new mechanics.
- `docs/BAR.md` (the quality bar) and `docs/PROGRESS.md` (round log) for the Gauntlet Loop.
- A command-line balance harness: `build/simlab/main.swift` compiled with `swiftc` against the Sim files (see the swiftc command in PROGRESS.md) prints average yards / completions / sacks per play type. Use it to tune `PlaySim` fast without Xcode.

## In progress
- **Graphics** (live session with Noah): new renderer in `OlaBall/Scene/Stadium/` replacing `FieldScene.swift`; `GameSession.swift` already points at `StadiumScene`. Uncommitted in the working tree as of 09:30. The UI tests (`testFullGameAutoplay`, `testDrawGestureStartsAPlay`) have NOT been re-run since the swap began; run the full suite once it lands.

## Done overnight (2026-09-19, commits db995e3, 31d5d37, 2efa975 + this one)
- **Play balance** meets the BAR run targets and is fair on passes. Harness (`build/simlab`): light-side run vs stacked box 6.5 yd, crowd 0.7; outs/slants ~65% caught at ~1 yd separation; go route 69% vs single-high, 19% vs two deep; deep route vs blitz sacked 48%, quick slant vs blitz 83% caught; edge run vs blitz 5+ yd (was -3 every time). Fumbles 1.5% -> 0.6% per tackle. 2000 AI drives (`build/simlab/drives`): 1.4 points/drive, 59% punts, 15% TD, 12% FG, 9% turnovers.
- Coach's Tip priorities (fundamentals first inside the 8-per-game cap) and "why" lines that always name a next-time adjustment.
- Unit tests: 17/17 pass (`-only-testing:OlaBallTests`), including new `quickSlantBeatsTheBlitz` and `edgeRunBeatsTheBlitz`.
- App icon verified: 1024 px, no alpha.

## Open
- AI offense is mediocre by design (random route vs the look), so opponents score ~5-6 a game. If games feel too easy, make `AIPlaycaller.offensePlan` pick routes against the called defense more often.
- Gauntlet rounds not yet run on: kick meter feel, defense-call experience, onboarding first 60 seconds, game-over/Home polish, touchdown camera hold (needs Scene/, owned by the graphics session).
- The builder subagents hit the account session limit (resets 1:30 pm CDT), so rounds 2-3 were done by the lead alone without a separate critic.

## Suggested next features
1. Touchdown camera hold + scoreboard count-up (after the renderer swap).
2. Smarter AI offense that attacks the user's defensive call.
3. Kick meter: wind/arc preview and a slower needle on the first-ever kick.
4. "Replay that play" button on the result banner.
5. Season mode: 5 games, rising opponent difficulty.

## Not started
- Gauntlet Loop rounds (builder/critic per piece) against docs/BAR.md.
- Game-over screen and Home still show the old prototype's stat names; fine but unpolished.
- Confetti/haptics on touchdowns exist; camera hold on the end zone does not.

## Environment notes
- Build/test commands and simulator UDID are in CLAUDE.md. The Claude iOS Simulator MCP tool misreports "Xcode not selected"; use xcodebuild/simctl directly. Xcode 27 has no Simulator.app; the simulator window app is `/Applications/Xcode.app/Contents/Applications/DeviceHub.app`.
- Disk: ~28 GB free after deleting the unused iOS 26.1 and 26.2 simulator runtimes (re-downloadable in Xcode > Settings > Components). Tell Noah.
- GitHub: https://github.com/nsgnoah/ola-ball (private).
