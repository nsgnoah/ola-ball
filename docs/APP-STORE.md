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
| 1024×1024 icon, no alpha, not blank | `icon.png`, rendered and guarded by `OlaBallTests/AppIconTests.swift` |
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

The app record exists: **Spinola: Couples Trivia**, Apple ID **6814338074**, bundle ID
`co.nsgsolutions.spinola`, SKU `spinola`. Set up on September 20, 2026. Do not confuse it with the
old "Ola Ball" record (Apple ID 6756221325, bundle ID `com.olaball.app`), which is last winter's
football app and unrelated.

### Done

| Item | Value |
|---|---|
| Name / subtitle | Spinola: Couples Trivia / His World vs Her World |
| Category | Games > Trivia |
| Description, keywords, support URL, copyright | filled; keywords are 91 of 100 bytes |
| Privacy Policy URL | `https://nsgnoah.github.io/ola/privacy.html` |
| Support URL | `https://nsgnoah.github.io/ola/` |
| App Privacy | Data Not Collected, **saved but not yet published** |
| Age rating | 13+ in 172 regions (16+ Vietnam, 12+ Korea, 12+ on OS older than 26) |
| Screenshots | 4 iPhone at 1284x2778, 4 iPad at 2064x2752 |
| App Review notes | full walkthrough, sign-in explicitly not required |
| Review contact | Noah Greensweig, noah@nsgsolutions.co |

A note on screenshot sizes: the iPhone slot wants **6.5-inch** (1242x2688 or 1284x2778), and rejects
the 6.9-inch 1320x2868 set. `./scripts/store_shots.sh <udid>` against an iPhone 14 Plus or 13 Pro Max
simulator produces 1284x2778. The iPad slot takes 2064x2752 directly.

**1.1 (build 5): uploaded and submitted for review on September 27, 2026 at 9:25 PM**, set to release automatically once approved. What's New:

> 1,500 new questions. Every deck now has 120, from Rookie to Legend, so there's a lot more to argue about.
>
> Spinola also remembers what it has asked you on this phone and saves those for later. Fewer "wait, we've had this one."

**September 27, 2026: 1.0 approved for distribution.** It was not in any country, so it showed as removed from sale; availability set to all countries or regions the same day (Pricing and Availability > App Availability).

**September 22, 2026: 2.1 "Information Needed", answered and resubmitted.** Apple asks new developer
accounts for context before approving: a screen recording from a physical iPhone that starts at launch,
plus purpose and audience, setup steps, external services, regional differences, and any regulated or
third-party material. All six answers went into a reply and into the App Review Notes field (Apple asks
for both, "for reference on future submissions"). The recording was attached as a separate reply. To
resubmit after replying: the version page's "Update Review" first, then "Resubmit to App Review" on the
submission page, which stays greyed out until the first is done.

**Resubmitted on September 21, 2026 at 10:01 PM with build 4** (the harder questions), after
pulling build 3 from the queue so the easy version never ships. Earlier note, for history:
**Submitted for review on September 21, 2026 at 9:39 PM** (version 1.0, build 3), status Waiting for
Review; Apple quotes up to 48 hours. Release is set to automatic on approval. EU trader status: declared non-trader on September 21, 2026.

**Build 3 is attached to version 1.0** (swapped in on September 21, 2026, replacing build 1), with
Game Center enabled on the version and the review notes and "sign-in not required" confirmed intact
after the save. "Add for Review" is live.

**Build 3 is the one to submit.** It adds readable text-field placeholders on top of build 2's icon
fix: the system placeholder is a pale grey that all but vanished on the cream fields, which Noah
spotted on first launch on a real phone. Every field now uses `Text.placeholder` (ink2, about 6:1 on
cream) and `.gameField()`, which also gives the field a visible edge.

**Build 2 superseded build 1.** Build 1's app icon was a solid black square: the old generator
script drew a design and then silently lost it while stripping the alpha channel. Build 2 carries a
real icon, rendered by `OlaBallTests/AppIconTests.swift` from the app's own palette, and that test now
fails if the icon ever comes out as one flat colour or carries alpha. Attach build 2, not build 1.

TestFlight: internal group "Family", automatic distribution on, with Noah (noah@nsgsolutions.co) and
Alex Dye (alexandrad.1999@icloud.com, Customer Support role, app access Ola Ball and Spinola only).

Also done: **price set to free** across all 175 regions, and **build 1.0 (1) uploaded** on
September 20, 2026 at 11:32 PM. It was re-archived first, because the previous archive predated the
commit that set the live policy URL and would have shipped a privacy screen with no link on it.

### Left to do

1. **Wait for the build to finish processing**, then on the version page pick it under Build and
   tick **Game Center**. That checkbox stays greyed out until a processed build carrying the
   entitlement exists.
2. **Test on two real devices.** Put the TestFlight build on both phones, sign both into Game
   Center, play a full match each way, and put one phone into airplane mode mid-turn to exercise
   the failed-upload path. No simulator can do this, and it is the only part of the app that has
   never run for real.
3. **Add for Review.**

For any later upload, bump `CURRENT_PROJECT_VERSION` in `project.yml`. That now actually reaches the
bundle; before today it was a frozen literal and bumping it did nothing.

### Age-rating answers that were judgement calls

Worth a sanity check, because they set the 13+ rather than a lower rating:

- **Contests: Frequent.** Apple defines it as users competing for rankings or rewards, which is the
  entire game.
- **Alcohol: Infrequent.** The grilling deck asks about beer and whiskey. This is also why the app
  will not be sold in Afghanistan or Morocco.
- **Mature or suggestive themes: Infrequent.** Romance, reality TV and celebrity decks.
- **Health or wellness topics: Yes.** The wellness deck covers sleep, fasting and supplements.
- **Realistic violence and weapons: Infrequent.** Fight-night and action-movie decks reference real
  physical conflict. Arguably None, since these are text trivia rather than depictions; under-
  declaring risks a re-rate, so it was answered the conservative way.

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
