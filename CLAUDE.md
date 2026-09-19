# Ola

Native SwiftUI iOS trivia game for couples (iOS 17+). Two "worlds": His World and Her World. Each player declares the world they know; each round the challenger picks the deck their partner gets quizzed on (from the challenger's own world). Five rounds, seven questions each, difficulty escalates from Rookie to Legend, first to three crowns wins. Async on two phones through Game Center turn-based matches, or pass-and-play on one phone.

## Non-negotiables
- **Opinionated, not generic.** The his/her framing is the identity. Ola (the host) has a voice: dry, warm, never scolding.
- **Facts must be right.** Every question is a verifiable public fact. No opinions dressed as facts. Real people, brands, and titles are fine in trivia; keep them factual and non-defamatory.
- **App Store safe.** No accounts of our own, no passwords, no server, no third-party SDKs. Game Center only (the `com.apple.developer.game-center` entitlement). Keep `PrivacyInfo.xcprivacy` accurate.
- **Design system (game register, like Trivia Crack)**: saturated world-colored striped backgrounds (`GameBackground`), white chunky panels with a bottom edge (`.panel()`), 3D `ChunkyButtonStyle` buttons, gold crowns, a `Mascot` per deck with moods, a spinning `WheelView` for picks, `TimerRing`, `ConfettiBurst`. Type: Futura Condensed ExtraBold for loud text, rounded system for reading. Never revert to a flat text/paper interface.

## Architecture
- `Models/`: `Deck`/`Question` (content), `MatchState` (the JSON both phones agree on), `Profile`.
- `Content/HerWorld.swift`, `Content/HisWorld.swift`: 12 decks × 36 questions (12 per tier). Author with `Q(tier, prompt, correct, [wrong×3], fact?)`. Option order is shuffled deterministically per question id.
- `Engine/MatchEngine.swift`: pure rules (question draw, tiers per round, scoring). `Engine/MatchController.swift`: one match's UI state machine; it talks to a `MatchTransport`.
- `Services/GameCenterService.swift` (+ `GameCenterTransport`), `Services/LocalMatchStore.swift` (+ `PassAndPlayTransport`).
- `Views/`: `HomeView` (match lists), `MatchView` (stage switch), `DeckPickView`, `QuestionView`, `RoundRevealView`, `MatchOverView`, `ProfileSetupView`.
- `Audio/SoundKit.swift`: synthesized cues, no audio files.

## Workflow
- Project is generated: edit `project.yml`, run `xcodegen generate`. Never hand-edit the `.xcodeproj`.
- Build/test: `xcodebuild test -project OlaBall.xcodeproj -scheme OlaBall -destination 'platform=iOS Simulator,id=22F189D4-EAEA-44E5-A62A-DFF364B638E5'` (iPhone 16 Pro). UI test plays a full pass-and-play match; set `TEST_RUNNER_OLABALL_SHOTS=<dir>` for screenshots.
- Game Center needs a signed-in sandbox account on the simulator (Settings > Game Center) to test online; pass-and-play covers everything else.
- The football prototype lives at tag `v1-football-draw-the-play`.
