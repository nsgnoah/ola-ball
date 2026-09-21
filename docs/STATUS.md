# Ola — Status / Handoff

_Updated: 2026-09-20 20:00 CDT_

## What this is now
A couples trivia game: His World vs Her World. Each player declares the world they know; the challenger picks the deck their partner is quizzed on each round; five rounds, escalating difficulty, first to three crowns. Async over Game Center turn-based matches, or pass-and-play on one phone. Pivoted from the 3D football game on 2026-09-19 (that build is tagged `v1-football-draw-the-play`).

## Done
- **Couples mode**: your couple vs another couple. Each member has a lane (the world they answer, default their own); the other couple picks a deck per member; team scores add up. One phone per couple over Game Center (the challenged phone sets up its two people before joining) or four people on one phone. Unit-tested and UI-tested end to end.
- Content: 18 decks (9 per world), 648 questions, 3 tiers each, with a unit test that checks structure and uniqueness. Each deck lasts about 12 matches before questions repeat within it.
- Engine: deterministic question draw from the match seed, time/streak scoring, tier escalation, crown logic, JSON match state.
- Pass-and-play end to end; Game Center service and transport (sign-in, match list, matchmaker, turn events, submit, rematch).
- Screens: profile setup, home with both match lists, deck pick, question play with timer, round reveal, match over, hand-off.
- Front end rebuilt in a game register (Trivia Crack-like): striped world-colored backgrounds, chunky 3D buttons, a drawn mascot per deck with moods, a spin wheel for picks, countdown ring, confetti and shake feedback. New icon.
- Visual identity pass (Sep 19, late): Rockwell slab + DIN Condensed type, sunburst/halftone/grain backgrounds instead of gradients, and 18 deck icons plus every UI glyph drawn from scratch in `Views/Icons.swift` (no SF Symbols). Icon contact sheet via `IconSheetTests`.
- All-ages pass (Sep 19, late): Dynamic Type scaling with a legibility floor, higher-contrast secondary text, 44pt close/trash/menu targets, bigger answer rows, Reduce Motion honored for sunburst spin, mascot idle, hand-off wobble and confetti.
- Palette calmed (Sep 19, late): world/deck colors pulled toward night for full-bleed backgrounds (`GameBackground.base`), quieter rays and dots, wheel slices inked 14%, less neon his/hers/violet/gold/good/bad values. Feedback was "the colors are a bit much".

## iPad and the pre-submission audit (Sep 20)
- **Universal build.** Device family 1,2; portrait on iPhone, all four orientations on iPad. Not a stretched phone app: `Viewport` measures the window and reports a scale against the 393x852 phone design, and fonts, buttons, panels and drawn art all read it, so one dial grows everything together. `Stage`/`StageScroll` give every screen a full-bleed background behind a centered play column. iPhone rendering is byte-identical, because the scale is exactly 1.0 at phone sizes. Verified on iPad Air 11-inch in both orientations, screen by screen.
- **Five-lens audit** (App Store config, iPad layout, accessibility, correctness, trivia content), each finding adversarially verified: 18 confirmed, 5 refuted. All 18 are fixed. The ones that mattered most:
  - Game Center matches were **dead on arrival**. A new match holds only the creator, so the controller found nothing to pick and nothing to answer, parked on `.waiting`, and never submitted the seed state; the opponent could never take a turn either. The creator's first turn now hands straight over. There is a unit test for it now, because the simulator cannot exercise Game Center at all.
  - The matchmaker sheet was never dismissed before the match opened, so the full-screen cover was dropped and the new match never appeared.
  - A round could come up short or empty once a deck's unused question pool ran out; a deck now repeats rather than showing a blank timer.
  - Background saves read `state` while the main thread was mutating it.
  - The final round reveal was credited to whoever was up next instead of whoever had just played.
  - Version numbers were frozen literals in Info.plist, so bumping the build number would have silently done nothing on the second upload.

## Fixed during the first live walkthrough
- Pass-and-play hand-off named the wrong player (the transport's active player flips on submit; the name is now captured first).
- Opening a pass-and-play match from home now shows the hand-off screen first, so the wrong person never sees the questions.
- Revealed answer rows were dimmed by `.disabled`; they now use `allowsHitTesting`.
- Match rows had a `.contextMenu`, which swallowed XCUITest taps; replaced with a trash button on finished matches.
- Test seeding moved out of `App.init` (stores were created before the seed was written) into a one-time static flag.
- Matches present as full-screen covers rather than navigation pushes.

## Not yet verified
- Game Center on a real device (needs a sandbox Apple ID on the simulator or a device with Game Center signed in). All Game Center code paths are unexercised by tests.
- Audio levels (no audio in the simulator here).

## Android (planned, not started)
Noah wants a Google Play version later. Keep that in mind now:
- Keep game rules, scoring, question draw, and match-state JSON in plain Swift with no UIKit/SwiftUI imports (`Models/`, `Engine/MatchEngine.swift`) so they can be ported line for line to Kotlin, and keep `MatchState`'s JSON shape stable and documented; it is the cross-platform contract if the two apps ever share a backend.
- Question content lives in Swift source today. Before the Android build, export it to a JSON file both apps load, with a unit test that the Swift and JSON copies match.
- Game Center is iOS-only. Cross-platform async play needs a small backend (or Google Play Games on Android with no cross-play). Decide before building.

## Next
1. Play a Game Center match between two devices; fix whatever the first real turn reveals.
2. Turn notifications copy (Game Center's default push text is generic).
3. More decks per world (music, travel, cooking, fitness) and a "wildcard" deck both sides can pick.
4. Stats: lifetime record vs partner, favorite deck, hardest question.
