# Spinola for Android

The Android build of Spinola, the his-world/her-world trivia game for couples. It is a native
Kotlin + Jetpack Compose port of the iOS app in `../OlaBall`: the same rules, the same screens,
Ola's lines word for word, and the same game-show look (sunburst rays, halftone band, paper grain,
cream chunky panels, 3D buttons, drawn icons, mascots, the spin wheel, the timer ring, confetti).
Nothing is downloaded, nothing is sent: no accounts, no server, no permissions, no third-party
SDKs. AndroidX and kotlinx only.

## Layout

| Module | What it is |
|---|---|
| `core/` | Pure Kotlin JVM. `model/` (`Deck`, `Question`, `MatchState`, `Profile`), `engine/` (`MatchEngine` rules, `MatchController` state machine, the `MatchTransport` seam), `services/` (`MatchJson` wire format, `ProfileStore`, `LocalMatchStore`, `PassAndPlayTransport`), `support/SeededRNG` (SplitMix64, bit-for-bit with the Swift one). No Android imports, so it runs and is tested on the JVM. |
| `app/` | The Compose app. `ui/theme/` (palette, canvas scale, type roles), `ui/hud/` (the design system: `Stage`, `GameBackground`, `StickerText`, `ChunkyButton`, `Mascot`, `WheelView`, `TimerRing`, `ConfettiBurst`, the drawn `Icons`), `ui/screens/` (one file per iOS view), `audio/` (synthesized sounds, haptics). `SpinolaApp` loads the decks and owns the stores; `RootView` is the shell. |
| `play/` | Play Console art: the 512 px icon, the feature graphic and its SVG source. See `play/README.md`. |
| `scripts/store_shots.sh` | Plays a full match on an emulator and pulls store screenshots. |

The question content is not in this tree. It lives in `../content/assets/decks.json`, which the
app build includes as an asset (`app/build.gradle.kts`, `sourceSets`), so both apps ship the same
questions from one file.

## Requirements

- JDK 17. Homebrew's `openjdk@17` works; Android Studio is not needed for anything here.
- The Android SDK with `platforms;android-37.0` and `build-tools;36.0.0` (the command-line tools are
  enough; `sdkmanager` installs both). The wrapper downloads Gradle and the Android Gradle plugin.
- `local.properties` with `sdk.dir=/path/to/sdk` (present on the build Mac; not committed).

Export these before every command (the Mac keeps the system Java elsewhere):

```bash
export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
export ANDROID_HOME=$HOME/Library/Android/sdk
cd android
```

The app compiles against platform 37 (`compileSdk = 37`, which the Compose 1.12 and core-ktx 1.19
libraries require) and targets 36 (`targetSdk = 36`, the current Play requirement).

## Build, test, install

```bash
./gradlew :core:test                      # JVM tests: rules, state, controller, stores, golden parity
./gradlew :app:testDebugUnitTest          # JVM tests in the app: the sound synth
./gradlew :app:compileDebugKotlin         # type-check the app without packaging it
./gradlew :app:assembleDebug              # app/build/outputs/apk/debug/app-debug.apk
./gradlew :app:bundleRelease              # the .aab Play wants (needs the signing key, see ../docs/PLAY-STORE.md)
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

Both test tasks together: `./gradlew :core:test :app:testDebugUnitTest`.

The instrumented play-through (`app/src/androidTest/.../PlayThroughTest.kt`) drives a whole
pass-and-play match through the same accessibility identifiers the iOS UI test uses
(`testTag` here, `accessibilityIdentifier` there) and saves screenshots. It needs a booted device
or emulator: `./gradlew :app:connectedDebugAndroidTest`, or `./scripts/store_shots.sh` to boot an
AVD, run it and pull the shots.

## Shared content and golden fixtures

`../content/README.md` is the full explanation. In short: the iOS test suite
(`OlaBallTests/CrossPlatformExportTests.swift`) writes `content/assets/decks.json` (18 decks x 36
questions) and `content/golden/*.json` (random streams, hashes, question draws, points, a whole
`MatchState` exactly as Swift's `JSONEncoder` encodes it, and the facts Kotlin must derive from
it). The `core` tests replay every fixture, so a rule change on one platform fails the other's
tests until both agree. `MatchState` JSON is the contract between the two apps; keep it stable.

To regenerate after editing questions or rules, run the iOS export test, commit the new fixtures,
then `./gradlew :core:test` here.

## What is not on Android

Online play. The iOS app carries a match between two phones through Apple's Game Center, which
has no Android counterpart (Google retired Play Games' turn-based multiplayer in 2020). This build
is pass-and-play on one phone, in both modes: me vs my partner, and our couple vs theirs. The home
screen has no "online" section and the About screen says so.

The seam for adding it later is `MatchTransport` in
`core/src/main/kotlin/co/nsgsolutions/spinola/engine/MatchController.kt`: `activePlayerID`,
`isMyTurn`, `isPassAndPlay`, `submitTurn(state)` and `save(state)`. `PassAndPlayTransport` in
`services/Storage.kt` is the one implementation; `MatchController` already handles the online
paths (`Waiting`, a failed submit with "Try again", the reveal that outlives its mover's turn),
and the waiting screen keeps the online copy. An online transport is a second class implementing
that interface plus a home-screen section to list its matches.

## Fonts

iOS uses Rockwell (slab serif) for anything loud or read and DIN Condensed Bold for scoreboard
numbers and kickers; both ship with iOS. Android ships neither, so the app bundles the closest
open-licence faces, picked side by side against the real iOS fonts: **Arvo** (Regular and Bold)
for Rockwell and **Barlow Condensed Bold** for DIN Condensed Bold. The files are in
`app/src/main/res/font/`, their SIL Open Font License texts ship in `app/src/main/assets/licenses/`
(the OFL allows bundling in any app, free or paid). `Fonts` in `ui/theme/Theme.kt` is the one place
they are named; every text style goes through `AppText`, which applies the same size factors iOS
gives DIN Condensed (1.12 for scores, 1.15 for labels).

## Short screens

Every match screen that iOS lays out as header, Spacer, middle, Spacer, buttons uses `PinnedColumn`
(`ui/hud/Hud.kt`): the header and buttons are pinned, and the middle is centred when it fits and
scrolls when it does not. On a 16:9 phone (411x731 dp) the question screen's middle does not fit
once Ola's verdict appears, and without this the Next button was crushed to a sliver. The question
screen scrolls itself to the verdict on reveal. Test short screens with
`emulator -avd spinola_phone -skin 1080x1920`.

## Design rules the port keeps

The same non-negotiables as the iOS app (see `../CLAUDE.md`): every glyph is drawn from paths in
`ui/hud/Icons.kt` (no Material icons); full-screen colour always goes through `GameBackground`;
reading text never below 14 sp (`AppText` enforces the floors) and secondary text uses `Theme.ink2`;
tap targets at least 44 dp; every looping animation and the confetti respect
`LocalReduceMotion` ("Remove animations" in Android's accessibility settings); the text-size
setting is honoured but capped at 1.5x, as iOS caps Dynamic Type at xxLarge. The layout is authored
at 393x852 dp and `Viewport`/`UI.s()` scale it to the window on tablets, the same dial as iOS.
