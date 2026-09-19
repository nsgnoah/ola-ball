# Ola Ball — Status / Handoff

_Updated: 2026-09-19 10:00 CDT_

## What this is
"Draw the Play": a native SwiftUI + SceneKit football game for beginners. Pre-snap you see the defense and a plain-English callout ("Defense shows 8 in the box"); you drag from a glowing player to draw the run or route; the play animates in a 3D night stadium with a cinematic camera; every play gets a one-line "why"; rules are taught in the moment by Coach's Tips that fill a Playbook. On defense you pick a look (stack the box, balanced, play the pass, blitz). Field goals and punts use a tap-timing meter. Four quarters, one drive each per quarter, overtime if tied.

## Done (as of this update)
- **Renderer** (`OlaBall/Scene/Stadium/`): procedural night stadium, articulated numbered players with run cycles and stances, glowing path ribbon, particles, bullet time, adaptive framing that fits all 22 on a portrait screen.
- **Home screen** = the stadium with warm-ups and a crane flyover; broadcast-style pre-game package. Team pick, Playbook, in-game HUD and game-over all share the broadcast language (`OlaBall/Views/HUD.swift`).
- **Sound** (`OlaBall/Audio/SoundKit.swift`): all synthesized at launch; crowd bed swells on big plays; drumline cadence on the home screen.
- **Art direction**: adult audience. Monogram crests (no emoji), deep uniform colors, leaner rigs with visors, muted crowd.
- **Simulation** (`OlaBall/Sim/`): balanced against `docs/BAR.md` with the tightened formation. `build/simlab/run.sh lab|ai|debug` compiles the sim with swiftc and prints balance stats without Xcode.
- **Tests**: 17 unit tests green (rules, sim balance, tips, a full simulated game). Both UI tests green: the drag test and a full autoplay game (133 s), screenshots to `TEST_RUNNER_OLABALL_SHOTS`.
- App Store posture unchanged: no accounts, no network, no permissions, no third-party code, privacy manifest accurate.

## Known gaps / next
1. Kick meter and the opponent's 4th-down kicks have not been re-checked visually since the HUD restyle.
2. Landscape is unsupported by design (portrait only); the formation is stylized narrower than real football so it fits.
3. Music is a drumline cadence only; no melodic music by design so far.
4. Coach's Tip copy has not been re-read against the new HUD (line lengths, tone).
5. Replays: a "watch that again" button after big plays would cost little (the sim is deterministic per seed).

## Working agreements
- One lead session at a time. Overnight scheduled runs only when nobody is working live; the 04:25 run overlapped a live session and cost hours to reconcile.
- Project is generated: edit `project.yml`, run `xcodegen generate`.
- Build/test: `xcodebuild ... -destination 'platform=iOS Simulator,id=22F189D4-EAEA-44E5-A62A-DFF364B638E5'` (iPhone 16 Pro, iOS 18.0). The iPhone 17 Pro (`914122DB-...`) is the live-demo simulator. Keep separate `-derivedDataPath` dirs for parallel builds.
- The Claude iOS Simulator tool works now (`xcode-select` was fixed on 2026-09-19).
