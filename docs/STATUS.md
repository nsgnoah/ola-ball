# Spinola — Status / Handoff

_Updated: 2026-09-25_

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

## Android (built September 24, 2026)

A native Kotlin + Jetpack Compose port lives in `android/`. Same rules, same screens, Ola's lines
word for word, same game-show look, no accounts, no server, no permissions, no third-party SDKs.
It is **pass-and-play only**: Game Center is Apple-only and Google shut down Play Games'
turn-based multiplayer in 2020, so there is no drop-in equivalent. Both modes work on one phone.
The `MatchTransport` seam is kept for an online transport later.

- `android/core`: pure Kotlin (no Android imports): `SeededRNG` (SplitMix64 plus Swift's
  `shuffle(using:)` and `Int.random(in:using:)` reproduced bit for bit), `Deck`/`Question`,
  `MatchState` (immutable, JSON-compatible with Swift's `JSONEncoder` output), `MatchEngine`,
  `MatchController` (a `StateFlow` snapshot instead of `@Observable`), `ProfileStore`,
  `LocalMatchStore`, `PassAndPlayTransport`. 32 JVM tests, including replays of every golden
  fixture the iOS tests write (see below).
- `android/app`: Compose. `ui/theme` (palette, `Viewport`/`UI.s()` canvas scale, `AppText` type
  roles), `ui/hud` (`Stage`, `GameBackground`, `StickerText`, `ChunkyButton`, `Mascot`,
  `WheelView`, `TimerRing`, `ConfettiBurst`, every icon drawn from paths in `Icons.kt`),
  `ui/screens` (one file per iOS view), `audio` (the same synthesized sounds through `AudioTrack`,
  haptics through `performHapticFeedback` so no permission is needed). Adaptive launcher icon as
  vector drawables from the same geometry as `AppIconTests.swift`. Play Store art in `android/play/`.
- **Shared content.** `OlaBallTests/CrossPlatformExportTests.swift` writes
  `content/assets/decks.json` (shipped as an Android asset) and `content/golden/*.json` (RNG
  streams, hashes, draws, scores, one `MatchState` as Swift encodes it). The Kotlin tests replay
  them; the Swift test fails once whenever the export drifts, so a content change cannot ship on one
  platform only. `content/README.md` has the workflow.
- **Fonts.** Rockwell and DIN Condensed ship with iOS, not Android. The port bundles Arvo and
  Barlow Condensed Bold (SIL OFL), chosen side by side against the iOS fonts on September 25.
- **Verified:** JVM tests green, lint clean of errors, `assembleDebug` builds (compileSdk 37, target
  36, min 26), the instrumented `PlayThroughTest` plays a whole pass-and-play match and a couples match
  on the Pixel 8 emulator and writes screenshots (`android/scripts/store_shots.sh`). The R8-minified
  release APK (1.5 MB, signed with the debug key when no upload key is present) was installed and
  played by hand on the emulator: profile, new match, pick, a round, a dark-mode switch mid-question
  (activity recreated, round and clock intact), back mid-question (ignored), force-stop and relaunch
  (everything restored), About and Start over.
- **Review pass (Sep 24):** seven review lenses, each finding checked by two adversarial verifiers;
  31 real findings fixed, among them the controller dying on rotation, the halftone dots drawn in
  pixels instead of dp, a dark status bar on the dark stage in light mode, the timer ring reading 0
  under "Remove animations", test-only launch flags that could wipe a player's data in release, and
  missing thousands separators on scores.
- **Not verified:** a real Android phone (audio levels, haptics, keyboard behaviour, launcher masks),
  a release build through R8 with the upload key, tablets beyond the layout code.
- Submission checklist: `docs/PLAY-STORE.md`. Build notes: `android/README.md`.

## Google Play (Sep 25)
- Privacy and support pages published with the Android wording (nsgnoah/ola, commit c2996c7).
- Upload key created (`android/spinola-upload.jks`, RSA 4096, valid to 2054; passwords in the
  gitignored `android/keystore.properties`); release bundle signed with it.
- Store listing copy, icon, feature graphic, eight 9:16 phone screenshots and four tablet-layout
  screenshots in `android/play/`.
- Short-screen bug found while making 9:16 screenshots (the question screen crushed its Next
  button) and fixed for every match screen with `PinnedColumn`.
- Organization developer account for NSG LLC verified (D-U-N-S 139956326, nsgsolutions.co).
- **1.0 (1) sent for production review on September 25, 2026**, with no closed test (organization
  accounts are exempt): 176 countries (all but Morocco), rated ESRB Teen / PEGI 12. Managed
  publishing is off, so it goes live when approved. Details: `docs/PLAY-STORE.md`.
- Not yet done: installing from Play on a real Android phone.

## Next
1. Play a Game Center match between two devices; fix whatever the first real turn reveals.
2. Turn notifications copy (Game Center's default push text is generic).
3. More decks per world (music, travel, cooking, fitness) and a "wildcard" deck both sides can pick.
4. Stats: lifetime record vs partner, favorite deck, hardest question.
