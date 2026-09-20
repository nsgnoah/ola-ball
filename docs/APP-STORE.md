# Submitting Ola to the App Store

Status as of September 19, 2026. The code side is ready; what remains is App Store Connect setup, a real-device Game Center test, and the upload.

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
| Launch screen, portrait only, iPhone only | `project.yml` |
| Version 1.0, build 1 | `project.yml` (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`; bump the build for every upload) |
| Dynamic Type, Reduce Motion, 44pt targets | `Views/Theme.swift`, `Views/HUD.swift` |
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
5. **Age rating**: everything "None" except **Alcohol, Tobacco, or Drug Use or References → Infrequent/Mild** (the "Grilling, Beer & Whiskey" deck asks factual questions about beer and whiskey). Expect 12+. Also "Contests → None" and "Unrestricted Web Access → No".
6. **Category**: Games > Trivia (secondary: Games > Family or Word).
7. **Screenshots**: 6.9" iPhone is the only required size (1320×2868). `scripts/store_shots.sh` plays a match on an iPhone 16 Pro Max simulator and drops them in `build/shots-store/` (home, hand-off, wheel, question, answered, reveal, match over). Pick 3 to 6. No iPad screenshots are needed while the app is iPhone-only.
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

The app targets iPhone only (`TARGETED_DEVICE_FAMILY: "1"`). On an iPad it installs and runs in a letterboxed iPhone-size window. App Review accepts that; the store listing says "Designed for iPhone". Real iPad support would mean adding device family 2, a centered max-width column in every screen, landscape handling (or `UIRequiresFullScreen`), a second set of screenshots (13"), and iPad testing. Sensible as a 1.1.
