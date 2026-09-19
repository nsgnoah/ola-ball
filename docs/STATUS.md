# Ola Ball — Status / Handoff

> **FILE OWNERSHIP (from 2026-09-19 09:05):** Noah is working live with the original lead session on GRAPHICS. That session owns everything under `OlaBall/Scene/` (it is building a new renderer in `OlaBall/Scene/Stadium/` and will delete `FieldScene.swift` when it swaps over) plus `OlaBall/Views/GameView.swift`. Overnight session: do NOT spawn graphics builders or edit those paths; keep working on play balance (`OlaBall/Sim/`), tips/content, tests, and the other Gauntlet pieces. Commit your work in small commits so nothing is lost.

_Updated: 2026-09-19 03:30 CDT_

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
- **Play balance** (`OlaBall/Sim/PlaySim.swift`): after fixing pass leading (receiver now runs to the ball) and pursuit (defenders aim straight at the carrier when close), runs are now over-stuffed (~0 yd avg) and passes complete ~35%. Targets from docs/BAR.md: runs into a gap ≥ 5 yd, into a crowd < 3 yd; open receiver (3+ yd separation) ≥ 85% caught; covered (< 1 yd) < 35%. Knobs: pursuit speedScale (1.1), tackle radius (1.5), LB run reaction (0.35 s), coverage lag (12 frames) and cushion, throw trigger (60% route progress).
- **Graphics**: a builder is rebuilding `OlaBall/Scene/` to shippable quality (articulated players, stadium, grass texture, framing fix so the QB/RB are not under the HUD). Owner's verdict on the capsule version: "slop".
- **Drag gesture UI test** (`testDrawGestureStartsAPlay`) fails: the pre-snap camera puts the QB/RB at the bottom edge under the HUD panels, so the test's drag misses. Fix comes with the camera framing; the HUD's non-interactive panels should also pass touches through.

## Not started
- Gauntlet Loop rounds (builder/critic per piece) against docs/BAR.md.
- Game-over screen and Home still show the old prototype's stat names; fine but unpolished.
- Confetti/haptics on touchdowns exist; camera hold on the end zone does not.

## Environment notes
- Build/test commands and simulator UDID are in CLAUDE.md. The Claude iOS Simulator MCP tool misreports "Xcode not selected"; use xcodebuild/simctl directly. Xcode 27 has no Simulator.app; the simulator window app is `/Applications/Xcode.app/Contents/Applications/DeviceHub.app`.
- Disk: ~28 GB free after deleting the unused iOS 26.1 and 26.2 simulator runtimes (re-downloadable in Xcode > Settings > Components). Tell Noah.
- GitHub: https://github.com/nsgnoah/ola-ball (private).
