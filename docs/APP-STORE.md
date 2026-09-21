# Submitting Ola to the App Store

Status as of September 20, 2026. The code side is ready; what remains is App Store Connect setup, a real-device Game Center test, and the upload.

## What the build already satisfies

| Requirement | Where |
|---|---|
| No accounts, passwords, or server of our own (the old app's rejection, guidelines 4.8 / 5.1.1) | Game Center only; `Services/GameCenterService.swift` |
| Works without Game Center (2.1, 4.2) | Pass-and-play on one phone covers every screen |
| Game Center entitlement | `OlaBall/OlaBall.entitlements` (`com.apple.developer.game-center`) |
| Privacy manifest, no tracking, no collected data | `OlaBall/PrivacyInfo.xcprivacy` (UserDefaults reason CA92.1) |
| No permission prompts, no third-party SDKs | nothing in `Info.plist`, no packages |
| Export compliance | `ITSAppUsesNonExemptEncryption = false` in `Info.plist` |
| 1024×1024 icon, no alpha | `OlaBall/Resources/Assets.xcassets/AppIcon.appiconset/icon.png` |
| Launch screen; portrait on iPhone, all orientations on iPad; universal (device family 1,2) | `project.yml` |
| Version 1.0, build 1 | `project.yml` (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`; bump the build for every upload) |
| Dynamic Type, Reduce Motion, 44pt targets | `Views/Theme.swift`, `Views/HUD.swift` |
| iPad layout that is not a stretched phone app | `Viewport`/`UI.scale`, `Stage`/`StageScroll` (see below) |
| Tests | 13 unit tests, 2 full UI play-throughs |

## Before you upload

1. **Test Game Center on two real iPhones.** It is the one path the simulator can't exercise. Put a TestFlight build on your phone and your wife's, sign both into Game Center (Settings > Game Center), start "Challenge your partner", and play a full match both directions. Also try "Challenge another couple" with a second pair if you can. A crash here is the likeliest rejection.
2. **Pick the App Store name.** "Ola" is taken (the ride-hailing app), and App Store names must be unique. Suggested: **Ola: His World vs Her World** (27 characters, under the 30 limit). The name on the home screen stays "Ola" (`CFBundleDisplayName`), that's separate.
3. **Host the privacy policy.** `docs/privacy-policy.md` needs a public URL, for example a page on nsgsolutions.co or GitHub Pages from this repo. App Store Connect requires the URL, plus a support URL (a mailto or a page with the same email works).

## App Store Connect

1. **Certificates, Identifiers & Profiles**: automatic signing in Xcode creates the App ID `co.nsgsolutions.olaball` and turns on the Game Center capability the first time you archive with your team selected. Your team ID is `S6QW7SV228` (from the Apple Development certificate on this Mac). Only that development certificate exists here; Xcode creates the distribution certificate on the first archive. Simulator builds are ad-hoc signed and drop the Game Center entitlement (Xcode keeps only the app identifier there), so the entitlement can only be verified on the archive: after archiving, run the check under "Archive and upload" and expect `com.apple.developer.game-center`.
2. **New app**: platform iOS, name from step 2 above, primary language English (U.S.), bundle ID `co.nsgsolutions.olaball`, SKU `olaball`.
3. **Features > Game Center**: enable Game Center for the app. No leaderboards or achievements needed; turn-based matches work with just the toggle. Then, on the version page, under Game Center, tick it for 1.0.
4. **App Privacy**: answer "No, we do not collect data from this app." This matches the privacy manifest. Game Center's own data is Apple's.
5. **Age rating**: App Store Connect uses the current questionnaire, which returns 4+/9+/13+/16+/18+ (there is no 12+ any more). Declare honestly:
   - **Alcohol, Tobacco, or Drug Use or References → Infrequent/Mild.** The "Grilling, Beer & Whiskey" deck asks factual questions about beer and whiskey.
   - **Sexual Content or Nudity / Mature or Suggestive Themes → Infrequent/Mild.** The romance, reality-TV and celebrity decks deal in dating and relationships.
   - Everything else **None**; "Unrestricted Web Access" No, no contests, no gambling.

   Both of those land the app at **13+**, so declaring them costs nothing and removes any chance of a re-rate for under-declaring. Do not trim content to chase 9+: the test suite asserts every deck holds exactly 36 questions with 12 per tier, so pulling questions means authoring tier-matched replacements.
6. **Category**: Games > Trivia (secondary: Games > Family or Word).
7. **Screenshots**: the app is universal, so App Store Connect needs BOTH sizes: 6.9" iPhone (1320×2868) and 13" iPad (2064×2752). `scripts/store_shots.sh` plays a real match and saves the set (home, hand-off, wheel, round intro, question, answered, reveal, match over); pick 3 to 6 of each.

   ```bash
   ./scripts/store_shots.sh && ./scripts/store_shots.sh ipad
   ```
8. **Description** (draft):

   > A trivia game for two people who share a couch and not a knowledge base. Declare the world you know, His World or Her World, then pick what your partner gets quizzed on: football, cars, grilling, tech and fight night on one side; skincare, fashion, rom-coms, reality TV and pop divas on the other. Seven questions a round, fifteen seconds each, difficulty climbing from Rookie to Legend. First to three crowns wins. Play from two phones through Game Center, or pass one phone back and forth. Couples mode lets your team take on another couple.

9. **Keywords**: couples trivia, his world, her world, date night game, family game night, quiz for two, pass and play, sports trivia, pop culture trivia.
10. **Review notes** (paste into "Notes for review"):

   > No account or login is required. Everything the reviewer needs is on the home screen under "Pass & play": tap "New pass & play", enter two names, and play a full match on one device; hand-offs are shown on screen. "Online, two phones" uses Apple's Game Center turn-based matches only (no server of ours) and needs two Game Center accounts on two devices; pass-and-play exercises the same rules, decks, and screens. Trivia content is factual public knowledge about sports, cars, beauty, fashion, film, TV, and music; real names and brands appear only as trivia answers.

## Archive and upload

Run from the repo root with your team ID:

```bash
xcodebuild -project OlaBall.xcodeproj -scheme OlaBall -configuration Release -destination 'generic/platform=iOS' -archivePath build/Ola.xcarchive archive -allowProvisioningUpdates DEVELOPMENT_TEAM=S6QW7SV228
```

```bash
xcodebuild -exportArchive -archivePath build/Ola.xcarchive -exportOptionsPlist scripts/ExportOptions.plist -exportPath build/export -allowProvisioningUpdates DEVELOPMENT_TEAM=S6QW7SV228
```

Verify the entitlement made it in before exporting:

```bash
codesign -d --entitlements - build/Ola.xcarchive/Products/Applications/OlaBall.app | grep game-center
```

`scripts/ExportOptions.plist` uploads straight to App Store Connect (method `app-store-connect`, destination `upload`); it needs Xcode signed in to your Apple ID (Xcode > Settings > Accounts). Or open the `.xcarchive` in Xcode's Organizer and click Distribute. Then in App Store Connect: TestFlight for the two-phone test, then "Add for Review" on the 1.0 version.

## iPad

The app ships as a universal build: `TARGETED_DEVICE_FAMILY "1,2"`, portrait on iPhone, all four
orientations on iPad. It is not a stretched phone app.

How the layout works, so it stays that way:
- `Viewport` in `OlaBall/Views/Theme.swift` measures the window the app actually got and reports a
  scale against the 393x852 phone design. `UI.scale` reads it; the `Font` helpers, `ChunkyButtonStyle`,
  `.panel()` and the drawn art all multiply by it. One dial, so type, buttons, panels and icons grow
  together. It tracks the WINDOW, not the device, because since iPadOS 26 every app gets a resizable one.
- `Stage` (in `HUD.swift`) is the container every screen uses: the background bleeds to all four
  edges, the content sits in a centered play column with the phone's proportions at that scale.
  `StageScroll` is the scrolling variant, which centers content shorter than the screen.
- Two rules when adding to a screen: never nest one `Stage` inside another (it clips the inner
  background to the outer column, which reads as a seam down both sides of an iPad), and any
  hand-placed padding that has to clear scaled art must be wrapped in `UI.s()`.

Verified on iPad Air 11-inch in both orientations: every screen composes, nothing is clipped, and the
full pass-and-play play-through passes. iPhone rendering is unchanged, because the scale is exactly
1.0 at phone sizes.

`UIRequiresFullScreen` is still `true`. On iPadOS 18 that keeps the app out of Split View, which is
the conservative choice for 1.0; on iPadOS 26 and later the key is ignored and the responsive layout
above is what carries it. Dropping the key to support Split View and Slide Over properly is a
sensible 1.1, once narrow windows have been tested.
