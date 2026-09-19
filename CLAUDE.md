# Ola

Native SwiftUI iOS trivia game for couples (iOS 17+). Two "worlds": His World and Her World. Two modes: **couple** (you vs your partner: each declares the world they know and is quizzed on the other's) and **teams** (your couple vs another couple: each member has a lane, the world they answer, and the other couple picks a deck per member; scores add up). Five rounds, seven questions each, difficulty escalates from Rookie to Legend, first to three crowns wins. Async on two phones through Game Center turn-based matches (one phone per side, a couple shares theirs), or pass-and-play on one phone.

## Non-negotiables
- **Opinionated, not generic.** The his/her framing is the identity. Ola (the host) has a voice: dry, warm, never scolding.
- **Facts must be right.** Every question is a verifiable public fact. No opinions dressed as facts. Real people, brands, and titles are fine in trivia; keep them factual and non-defamatory.
- **App Store safe.** No accounts of our own, no passwords, no server, no third-party SDKs. Game Center only (the `com.apple.developer.game-center` entitlement). Keep `PrivacyInfo.xcprivacy` accurate.
- **Design system (game register, like Trivia Crack)**: saturated world-colored striped backgrounds (`GameBackground`), white chunky panels with a bottom edge (`.panel()`), 3D `ChunkyButtonStyle` buttons, gold crowns, a `Mascot` per deck with moods, a spinning `WheelView` for picks, `TimerRing`, `ConfettiBurst`. Type: Futura Condensed ExtraBold for loud text, rounded system for reading. Never revert to a flat text/paper interface.

## Architecture
- **Android is coming later.** Keep rules and match state in plain Swift with no UI imports; keep `MatchState` JSON stable (it is the cross-platform contract); question content should move to a JSON file shared by both apps before the Android build.
- `Models/`: `Deck`/`Question` (content), `MatchState` (the JSON both phones agree on: `MatchPlayer` sides with `Member`s, picks and results keyed by member id), `Profile`.
- `Content/HerWorld.swift`, `Content/HisWorld.swift`: 12 decks × 36 questions (12 per tier). Author with `Q(tier, prompt, correct, [wrong×3], fact?)`. Option order is shuffled deterministically per question id.
- `Engine/MatchEngine.swift`: pure rules (question draw, tiers per round, scoring). `Engine/MatchController.swift`: one match's UI state machine (`route()` is the single source of what's next; hand-offs between members of a couple on one phone); it talks to a `MatchTransport`. Never leave an async submit in flight without first setting a stage the views can render.
- `Services/GameCenterService.swift` (+ `GameCenterTransport`), `Services/LocalMatchStore.swift` (+ `PassAndPlayTransport`).
- `Views/`: `HomeView` (match lists), `MatchView` (stage switch), `DeckPickView`, `QuestionView`, `RoundRevealView`, `MatchOverView`, `ProfileSetupView`.
- `Audio/SoundKit.swift`: synthesized cues, no audio files.

## Workflow
- Project is generated: edit `project.yml`, run `xcodegen generate`. Never hand-edit the `.xcodeproj`.
- Build/test: `xcodebuild test -project OlaBall.xcodeproj -scheme OlaBall -destination 'platform=iOS Simulator,id=22F189D4-EAEA-44E5-A62A-DFF364B638E5'` (iPhone 16 Pro). UI test plays a full pass-and-play match; set `TEST_RUNNER_OLABALL_SHOTS=<dir>` for screenshots.
- Game Center needs a signed-in sandbox account on the simulator (Settings > Game Center) to test online; pass-and-play covers everything else.
- The football prototype lives at tag `v1-football-draw-the-play`.
