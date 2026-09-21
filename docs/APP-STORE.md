# Submitting Spinola to the App Store

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
| Dynamic Type up to xxLarge, Reduce Motion, 44pt targets | `Views/Theme.swift`, `Views/HUD.swift` |
| Privacy policy and support reachable in the app (5.1.1(i), 1.5) | `Views/AboutView.swift`, home menu > "Privacy & support" |
| iPad layout that is not a stretched phone app | `Viewport`/`UI.scale`, `Stage`/`StageScroll` (see below) |
| Tests | 14 unit tests, 2 full UI play-throughs, 1 in-app privacy/support check |

## Before you upload

0. **Agree to the Apple Developer Program License Agreement.** Done on September 20, 2026. Until it is signed, Apple refuses to create the App ID, the provisioning profile, or any certificate, and `xcodebuild archive` fails with "PLA Update available" rather than anything about your code. If it ever reappears, it is at [developer.apple.com/account](https://developer.apple.com/account) as a banner.

   While you are there: the account has **no card on file for auto-renew**. That does not block this submission, but if the membership lapses, apps come off the App Store.

1. **Test Game Center on two real iPhones.** It is the one path the simulator can't exercise. Put a TestFlight build on your phone and your wife's, sign both into Game Center (Settings > Game Center), start "Challenge your partner", and play a full match both directions. Also try "Challenge another couple" with a second pair if you can. A crash here is the likeliest rejection.
2. **Create a new app record, named Spinola.** Do not try to reuse the existing "Ola Ball" record in App Store Connect: it is the old football app, its bundle ID is `com.olaball.app`, and ours is `co.nsgsolutions.spinola`. A bundle ID cannot be changed once a record exists, so this has to be a new record.

   - **Name:** `Spinola: Couples Trivia` (23 characters, inside Apple's 30 limit). Plain "Ola" was never viable, because the ride-hailing company holds it.
   - **Bundle ID:** `co.nsgsolutions.spinola`, **SKU:** `spinola`, primary language English (U.S.).
   - The home-screen name stays the single word **Spinola** (`CFBundleDisplayName`), which is separate from the store name.
   - Ola is the host character inside the game and keeps her name. The app is Spinola; you spin Ola's wheel.

   **What sank the old submission, for reference.** "Ola Ball" 1.0 was rejected in December 2025 on three counts, all of which are structurally impossible in this build:

   | Apple's finding | Why it cannot recur |
   |---|---|
   | 2.1 Completeness: "An error message occurred when we try to sign up with Apple" | There is no sign-up, no Sign in with Apple, and no account of any kind |
   | 2.1 Information Needed: wanted a demo account with pre-populated content | Nothing is behind a login; pass-and-play reaches every screen |
   | 2.1 Information Needed: questions about paid digital content and the business model | There is no paid content, no in-app purchase, and no subscription |

   Note they reviewed on an **iPad Air running iPadOS 26.1**. Apple reviews on iPad, which is why this version is a proper universal build rather than a letterboxed phone app.

3. **Privacy and support pages: done.** Both are live, served by GitHub Pages from the public
   `nsgnoah/ola` repo (the source of truth stays here in `site/`; that repo only publishes it).

   | App Store Connect field | URL |
   |---|---|
   | Privacy Policy URL | `https://nsgnoah.github.io/ola/privacy.html` |
   | Support URL | `https://nsgnoah.github.io/ola/` |

   The Support URL had to be a web page rather than a `mailto:`, which is why the support page
   exists. The policy is also inside the app under "Privacy & support" in the home-screen menu,
   with a link to the hosted copy, which is what guideline 5.1.1(i) asks for.

   To change either page: edit it in `site/`, then copy both into a clone of `nsgnoah/ola` and push.

## App Store Connect

1. **Certificates, Identifiers & Profiles**: automatic signing in Xcode creates the App ID `co.nsgsolutions.spinola` and turns on the Game Center capability the first time you archive with your team selected. Your team ID is `S6QW7SV228` (from the Apple Development certificate on this Mac). Only that development certificate exists here; Xcode creates the distribution certificate on the first archive. Simulator builds are ad-hoc signed and drop the Game Center entitlement (Xcode keeps only the app identifier there), so the entitlement can only be verified on the archive: after archiving, run the check under "Archive and upload" and expect `com.apple.developer.game-center`.
2. **New app**: the details are in "Create a new app record" above. SKU `spinola`.
3. **Features > Game Center**: enable Game Center for the app. No leaderboards or achievements needed; turn-based matches work with just the toggle. Then, on the version page, under Game Center, tick it for 1.0.
4. **App Privacy**: answer "No, we do not collect data from this app." This matches the privacy manifest. Game Center's own data is Apple's.
5. **Age rating**: answer the questionnaire honestly and let App Store Connect calculate the rating. Do not assume a number in advance, and do not trim content to chase a lower one: the test suite asserts every deck holds exactly 36 questions with 12 per tier, so pulling questions means authoring tier-matched replacements.

   Declare at least these:
   - **Alcohol, Tobacco, or Drug Use or References → Infrequent/Mild.** The "Grilling, Beer & Whiskey" deck asks factual questions about beer and whiskey.
   - **Contests.** Apple's descriptor covers competitive quizzes, and that is the whole game. Read Apple's current definition and pick the frequency it describes rather than answering "None".
   - **Health or wellness topics.** The wellness deck covers sleep, fasting and supplements (`Content/HerWorldMore.swift`). Check whether any question reads as medical advice; factual questions about a drug or a supplement still belong in this descriptor.
   - **Mature or suggestive themes.** The romance, reality-TV and celebrity decks deal in dating and relationships. This is a separate descriptor from sexual content and nudity, which the app does not have.
   - **Violence references.** A handful of questions name a hammer, a boxer's bite, and an action film's plot. These are text references, not depictions. Read each descriptor's wording before answering; several will be "None".

   Everything else None; Unrestricted Web Access No; no gambling.

   Apple replaced 12+ and 17+ with 13+, 16+ and 18+ in 2025, but the older tiers still apply on older OS versions, which matters here because the deployment target is iOS 17. App Store Connect works this out from the answers, so give it accurate ones and read the result rather than predicting it.

6. **Category**: Games > Trivia (secondary: Games > Family or Word).
7. **Screenshots**: the app is universal, so App Store Connect needs BOTH sizes: 6.9" iPhone (1320×2868) and 13" iPad (2064×2752). `scripts/store_shots.sh` plays a real match and saves the set (home, hand-off, wheel, round intro, question, answered, reveal, match over); pick 3 to 6 of each.

   ```bash
   ./scripts/store_shots.sh && ./scripts/store_shots.sh ipad
   ```

   They land in `build/shots-store/iphone` (1320×2868) and `build/shots-store/ipad` (2064×2752),
   ten each: home, the match list, the wheel, hand-off, round intro, a question, an answered
   question, the round reveal, the final screen, and the home screen afterwards. Both directories
   are gitignored; upload them straight from disk. Good picks for a listing are the wheel, a
   question, the round reveal and the final screen, in that order.
8. **Description** (draft):

   > A trivia game for two people who share a couch and not a knowledge base. Declare the world you know, His World or Her World, then pick what your partner gets quizzed on: football, cars, grilling, tech and fight night on one side; skincare, fashion, rom-coms, reality TV and pop divas on the other. Seven questions a round, fifteen seconds each, difficulty climbing from Rookie to Legend. First to three crowns wins. Play from two phones through Game Center, or pass one phone back and forth. Couples mode lets your team take on another couple.

9. **Keywords**: Apple allows 100 bytes, commas and spaces included, so no spaces after the commas. This is 91:

   ```
   couples,trivia,date night,quiz,pass and play,sports,pop culture,party,two player,game night
   ```

   Do not repeat words already in the app name or subtitle; Apple indexes those separately.
10. **Review notes** (paste into "Notes for review"):

   > No account or login is required. First launch asks only for a first name and which "world" you know; nothing is verified or sent. Everything the reviewer needs is then on the home screen under "Pass & play": tap "New pass & play", enter two names, and play a full match on one device; hand-offs are shown on screen. "Online, two phones" uses Apple's Game Center turn-based matches only, with no server of ours, and needs two Game Center accounts on two devices; pass-and-play exercises the same rules, decks, and screens. Trivia content is factual public knowledge about sports, cars, beauty, fashion, film, TV, and music. Real people, products and titles are named in both questions and answers as matters of fact, with no endorsement or affiliation implied. The privacy policy is in the app under "Privacy & support" in the home-screen menu.

## Archive and upload

Run from the repo root with your team ID:

```bash
xcodebuild -project OlaBall.xcodeproj -scheme OlaBall -configuration Release -destination 'generic/platform=iOS' -archivePath build/Spinola.xcarchive archive -allowProvisioningUpdates DEVELOPMENT_TEAM=S6QW7SV228
```

```bash
xcodebuild -exportArchive -archivePath build/Spinola.xcarchive -exportOptionsPlist scripts/ExportOptions.plist -exportPath build/export -allowProvisioningUpdates DEVELOPMENT_TEAM=S6QW7SV228
```

Both of these were run on September 20, 2026 and passed. The exported `.ipa` came back signed by
`Apple Distribution: Noah Greensweig (S6QW7SV228)`, with `get-task-allow` false and
`com.apple.developer.game-center` true, which is the only place that entitlement can be confirmed:
simulator builds are ad-hoc signed and drop it.

Note the archive itself is development-signed; that is normal. The export step re-signs it for
distribution, which is what the checks above are looking at.

To produce an `.ipa` on disk without uploading, use `scripts/ExportOptions-local.plist` instead,
which is identical except it writes to `build/export`:

```bash
xcodebuild -exportArchive -archivePath build/Spinola.xcarchive -exportOptionsPlist scripts/ExportOptions-local.plist -exportPath build/export -allowProvisioningUpdates
```

Verify the entitlement made it in before exporting:

```bash
codesign -d --entitlements - build/Spinola.xcarchive/Products/Applications/OlaBall.app | grep game-center
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
