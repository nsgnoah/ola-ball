# Ola Ball — Status / Handoff

_Updated: 2026-09-18 23:25 CDT_

## Done
- Full SwiftUI app scaffolded and **building** for the iPhone 16 Pro simulator (iOS 18.0).
- Game engine (`Engine/`), Playbook content (`Content/`), game flow (`Game/GameSession.swift`), persistence (`Store/`), and all screens (`Views/`).
- Privacy manifest, 1024px app icon (no alpha), README with App Store readiness notes, `docs/privacy-policy.md`, CLAUDE.md.
- Team-pick screen verified visually in the simulator (looks good).
- Unit tests written in `OlaBallTests/EngineTests.swift` (Swift Testing). UI play-through test written in `OlaBallUITests/PlayThroughUITests.swift`.

## In progress
- `xcodebuild test` currently **fails**. First failure was a missing Info.plist on the test targets (fixed by `GENERATE_INFOPLIST_FILE: YES` in project.yml). After regenerating, the run still failed; the log with `-quiet` only showed an `IDELaunchParametersSnapshot` line, so the real error is not yet identified. Next step: rerun without `-quiet`, grep for `error:` / `Test Case` / `failed`.
- No screenshots beyond the team-pick screen have been captured yet.

## Not started
- GitHub repo `nsgnoah/ola-ball` not created yet; nothing committed yet.
- Visual QA of game screen, opponent drive, game over, playbook.
- Play-quality tuning after seeing a full game.

## Environment notes
- Disk was 100% full; freed ~8 GB by deleting the unused iOS 26.1 and 26.2 simulator runtimes (re-downloadable in Xcode > Settings > Components). Noah should be told this. 14 GB of root-owned simulator caches at /Library/Developer/CoreSimulator/Caches/dyld could be cleared with sudo if more space is needed.
- The Claude iOS Simulator MCP tool misreports "Xcode not selected"; use `xcodebuild` and `xcrun simctl` directly.
