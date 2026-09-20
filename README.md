# Ola — His World vs Her World

A trivia game for two people who share a couch and not a knowledge base.

Each of you declares the world you know. His World: football, ball sports, cars, grilling and whiskey, games and superheroes, tools and the outdoors, action movies and dad TV, tech and gadgets, fight night. Her World: skincare, fashion, rom-coms, reality TV, pop divas, wedding season, book club, wellness, celebrity gossip. Every round you pick the deck your partner gets quizzed on. They pick yours. Seven questions, fifteen seconds each, difficulty climbing from Rookie to Legend over five rounds. First to three crowns wins, then you run it back.

Play from two phones with Game Center turn-based matches (Apple ID only, no accounts of ours, no server), or pass one phone back and forth.

## Building

```bash
brew install xcodegen
xcodegen generate
open OlaBall.xcodeproj
```

Tests: `⌘U`, or `xcodebuild test -project OlaBall.xcodeproj -scheme OlaBall -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`.

## App Store readiness

- No accounts, passwords, or network of our own. Game Center handles identity and match storage.
- Privacy manifest declares no tracking and no collected data; UserDefaults use is declared.
- No permissions requested. Portrait iPhone only. Encryption export flag set. 1024×1024 icon with no alpha.
- Game Center entitlement in `OlaBall/OlaBall.entitlements`. Dynamic Type, Reduce Motion, and 44pt targets throughout.
- The full submission checklist (App Store Connect setup, age rating, review notes, screenshots via `scripts/store_shots.sh`, archive and upload commands) is in `docs/APP-STORE.md`.

## History

The first version of this repo was a 3D football coaching game ("Draw the Play"); it is preserved at the tag `v1-football-draw-the-play`.
