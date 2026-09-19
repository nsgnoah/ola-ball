# Ola Ball

Native SwiftUI iOS game (iOS 17+). You coach a football team drive by drive; football's rules are taught in-context by Coach's Tips, never by quizzes. Target user: an adult who watches sports with a partner and never learned the rules.

## Non-negotiables
- **Not a quiz app.** Learning happens as a side effect of making a decision. Never add "test yourself" mechanics, lesson lists, or right/wrong grading of knowledge.
- **Beginner voice.** Assume zero football knowledge. Define a term the first time it matters (via `Concept` + `TipDirector`), then use it freely.
- **No real teams, players, leagues, or logos.** Fictional teams only (`Team.all`). Never mention the NFL.
- **App Store safe.** No accounts, no network, no permissions, no third-party SDKs. Keep `PrivacyInfo.xcprivacy` accurate if storage changes.

## Architecture
- `Engine/` is pure and seedable (`SeededRNG`). Test it, don't mock it.
- `Game/GameSession` is the single source of truth during a game. Views render it and call its methods; they hold no game logic.
- `Content/Concepts.swift` is the Playbook. `Content/TipDirector.swift` decides which single tip fires at a moment (one per moment, fundamentals first). Every concept must be reachable; there's a test for it.
- `Store/ProgressStore` persists to UserDefaults only.

## Workflow
- The project is generated: edit `project.yml`, then `xcodegen generate`. Don't hand-edit the `.xcodeproj`.
- Run tests before committing: `xcodebuild test -project OlaBall.xcodeproj -scheme OlaBall -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`.
