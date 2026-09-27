# Submitting Spinola to Google Play

**Status, September 25, 2026: version 1.0 (1) is in review for production.** The NSG LLC
organization account is verified (developer account 5710476944949805415). "Spinola: Couples Trivia"
(package `co.nsgsolutions.spinola`, app 4973204147980836777) went straight to production with no
closed test, since the 14-day testing rule only applies to personal accounts. The submission
covered 12 changes: the release with its notes, 176 countries and regions (all except Morocco;
Afghanistan is not offered), the store listing with all graphics, the content rating, store
settings, and every App content form. Managed publishing is off, so the app goes live as soon as
Google approves it. Google's estimate is up to 7 days. The only warning was about missing native
debug symbols, which comes from AndroidX `graphics-path` and affects only crash-report readability.
An internal-testing draft of the same bundle was left unsent; it can be discarded.

The sections below are the record of how it was set up, and the checklist for later releases.

| Ready | Where |
|---|---|
| Signed release bundle, versionCode 1 (3.8 MB) | `android/app/build/outputs/bundle/release/app-release.aab` (rebuild with `./gradlew :app:bundleRelease`) |
| Upload key (RSA 4096, valid to 2054) and its passwords | `android/spinola-upload.jks` and `android/keystore.properties`, both gitignored and **only on this Mac**: copy both into the password manager now |
| Store icon, feature graphic | `android/play/icon-512.png`, `android/play/feature-graphic.png` |
| Eight phone screenshots, 1080x1920 | `android/play/screenshots/phone/` |
| Title, short and full description, release notes | `android/play/listing/en-US/` (the `fastlane supply` layout, so a later automated upload can read it as is) |
| Privacy policy and support pages with the Android wording, live | `https://nsgnoah.github.io/ola/privacy.html`, `https://nsgnoah.github.io/ola/` |

## What the build already satisfies

| Requirement | Where |
|---|---|
| No accounts, passwords, server, analytics, ads or third-party SDKs (AndroidX and kotlinx only) | `android/app/build.gradle.kts` dependencies |
| No permissions at all (no `INTERNET`, no `VIBRATE`; haptics use `View.performHapticFeedback`) | `android/app/src/main/AndroidManifest.xml` |
| Target API 36, minimum API 26 (Android 8.0). The only native code is AndroidX `graphics-path` (pulled in by Compose), shipped for arm64-v8a, armeabi-v7a, x86 and x86_64 and 16 KB page aligned, so both the 64-bit and the 16 KB page-size requirements are met; check with `zipalign -c -P 16 -v 4 <apk>` | `android/app/build.gradle.kts` |
| Adaptive launcher icon drawn from the same palette as the game, plus a monochrome layer | `android/app/src/main/res/drawable/ic_launcher_*.xml` |
| Edge to edge, portrait on phones, all orientations on tablets, one layout that scales | `MainActivity.kt`, `ui/theme/Theme.kt` (`Viewport`), `ui/hud/Hud.kt` (`Stage`) |
| Text-size setting honoured (capped like iOS Dynamic Type at xxLarge), reading floors, 44dp targets, "Remove animations" respected | `ui/theme/Theme.kt`, `LocalReduceMotion` |
| Privacy policy and support reachable in the app | `ui/screens/AboutScreen.kt`, home menu > "Privacy & support" |
| Backup rules limited to the app's own preferences | `res/xml/backup_rules.xml`, `data_extraction_rules.xml` |
| Rules, scoring, question draw and match JSON identical to iOS | `android/core` tests replay `content/golden/*.json` written by the iOS tests |
| Version 1.0, versionCode 1 | `android/app/build.gradle.kts` (bump `versionCode` for every upload) |

What is **not** in the Android build: online play. Game Center is Apple-only, and Google shut down
Play Games' turn-based multiplayer in 2020, so the honest Android 1.0 is pass-and-play on one phone
(both modes: me vs my partner, and our couple vs theirs). The `MatchTransport` interface in
`android/core/.../engine/MatchController.kt` is where an online transport plugs in later; nothing in
the screens assumes one phone except the home screen's section title.

## The developer account (Noah)

Play Console at [play.google.com/console](https://play.google.com/console), signed in as
noah@nsgsolutions.co, currently shows the sign-up page: there is no developer account yet. The
Google account used there owns the developer account for good, so sign up with the one that should.

**Recommended: an organization account for NSG LLC.** Google tells businesses to choose
organization, and the "Yourself" option is described as being for people who "don't currently have
an organization or business". The practical differences, from Google's help pages (checked
September 25, 2026):

| | Organization (NSG LLC) | Personal |
|---|---|---|
| Fee | US$25 once, credit or debit card | US$25 once |
| Before the first production release | nothing extra, as far as Google's pages say: the testing rule is written for personal accounts only (Google never states the exemption outright) | a **closed test with at least 12 testers opted in for 14 days in a row**, then an "apply for production" review (about a week) |
| Verification | D-U-N-S number, a state or IRS business document, a photo ID, a verified website | photo ID, and a real **Android phone** running the Play Console app |
| Shown publicly on the store page | legal name, legal address, developer email and phone | legal name, country, developer email |

Organization checklist, in order. Use the **same legal name and address everywhere**, exactly as
they appear on the IRS EIN letter: D&B, the Google payments profile and the documents must match, and
a mismatch gets the account restricted.

1. **Website: done (September 25, 2026).** `nsgsolutions.co` is a verified Domain property in Google
   Search Console under noah@nsgsolutions.co, auto-verified by the Google Workspace TXT record already
   in its DNS. Play approves a website automatically when the same Google account owns it in Search
   Console. Keep that TXT record.
2. **D-U-N-S number.** Start at D&B's route for Google developers, United States:
   [my.dnb.com/signup?flow=GAD](https://my.dnb.com/signup?flow=GAD) (from
   [dnb.com's Google developer page](https://www.dnb.com/en-us/smb/duns/google-developers.html)).
   It first asks for a MyD&B account (name, business email, password), then searches for the
   business: if NSG is already in D&B's database (small LLCs often are, from state filings), the
   number shows there. If not, request one; it is free and takes up to 30 business days (D&B sells
   an expedited option of about 8 business days; not needed). The request asks for:
   - legal name of the business, business address, business phone
   - owner's name (Noah Greensweig), legal structure (LLC), year founded
   - primary industry: software publishing / computer programming services
   - number of employees
   D&B may call to confirm, then emails the number.
3. **Documents, as PDFs or photos:** the IRS EIN letter (**CP575**, sent when the EIN was issued; if
   it is lost, the IRS Business & Specialty Tax Line, 800-829-4933, issues a **147C** by fax or mail),
   or the state's certificate of organization; and a government photo ID for Noah.
4. **Play Console sign-up** at [play.google.com/console](https://play.google.com/console) as
   noah@nsgsolutions.co, once the D-U-N-S number is in hand:

   | Field | Value |
   |---|---|
   | Who is the account for | An organization; type: company or business |
   | Developer name (public, changeable) | NSG LLC (the same as the legal name, which Play also shows on the store page) |
   | Payments profile | Organization; legal name and address exactly as on the EIN letter and D&B; the D-U-N-S number |
   | Website | `https://nsgsolutions.co` (already verified) |
   | Contact name, email, phone (private, for Google) | Noah Greensweig, noah@nsgsolutions.co, a phone that can receive a code |
   | Developer email and phone (**shown publicly on the store page**) | noah@nsgsolutions.co; for the phone, consider a business line (a Google Voice number works) rather than a personal mobile |
   | Documents | the EIN letter, the photo ID |
   | Fee | US$25, credit or debit card (no prepaid cards) |

   Every email and phone gets a one-time code. Apps cannot be sent for review until Google finishes
   verifying the account.

A personal account can be converted to an organization later (verify the website, link a payments
profile with the D-U-N-S number, then wait 72 hours before submitting new apps), so a personal
account is not a trap, only slower to first release because of the 14-day test.

Turn on 2-Step Verification for the Google account either way.

## Once the account exists

1. **Create the app**: All apps > Create app. Name "Spinola: Couples Trivia", default language
   English (United States), **Game**, **Free**. Creating it registers the package name
   `co.nsgsolutions.spinola` to the account, which also covers Android's developer verification.
2. **Upload the bundle to Internal testing**: Test and release > Testing > Internal testing >
   Create new release > upload `app-release.aab`. Play App Signing is set up automatically on the
   first upload (Google holds the app signing key; the upload key above only proves the upload is
   ours). Release notes are in `android/play/listing/en-US/changelogs/1.txt`. The first upload must
   be done in Play Console by hand; the Publishing API only works after that.
3. **Store listing**: Grow users > Store presence > Main store listing. Paste the three texts from
   `android/play/listing/en-US/`, upload the icon, the feature graphic and the screenshots.
   Category **Trivia**, contact email noah@nsgsolutions.co, website `https://nsgnoah.github.io/ola/`.
4. **App content**: every item under Policy and programs > App content (answers below).
5. **Test it**: add your own Google account (and your wife's) as internal testers, install through
   the Play link on an Android phone, play a whole match of each mode.
6. **Production**: Test and release > Production > Create new release > add the same bundle >
   countries (all, as on iOS) > Send for review. First reviews for a new account can take several
   days.

The upload key is the one thing that cannot be recreated here: if it is lost, Play can reset it
(Protected with Play > Play Store protection > Manage Play app signing > Request upload key reset,
with a new key's PEM certificate), and the app signing key Google holds does not change.

## Play Console listing

| Field | Value |
|---|---|
| App name (30 max) | `android/play/listing/en-US/title.txt`: Spinola: Couples Trivia |
| Short description (80 max) | `short_description.txt`: His World vs Her World. Pick your partner's questions. First to three crowns. |
| Full description (4000 max) | `full_description.txt` (1,579 characters: how it plays, both modes, 648 questions, nothing to sign up for). No ranking words, prices or calls to action, which the metadata policy discourages |
| Category | Game > Trivia |
| Tags | Trivia, Couples, Party |
| Contact email | noah@nsgsolutions.co |
| Website / support | `https://nsgnoah.github.io/ola/` |
| Privacy policy URL | `https://nsgnoah.github.io/ola/privacy.html` (published September 25, 2026 with the Android wording) |
| App icon | `android/play/icon-512.png` (512x512, 32-bit PNG, every pixel opaque) |
| Feature graphic | `android/play/feature-graphic.png` (1024x500, 24-bit PNG) |
| Phone screenshots | `android/play/screenshots/phone/`, eight 1080x1920 24-bit PNGs in listing order. Play rejects screenshots more than twice as tall as wide, so these come from a 9:16 emulator (`emulator -avd spinola_phone -skin 1080x1920`, then `./scripts/store_shots.sh phone-9x16`), not the 20:9 Pixel 8 default. Three or more 1080x1920 portrait shots make a game eligible for Play's large recommendation formats |
| Tablet screenshots | **Required for games** in both the 7-inch and 10-inch slots. The same four `android/play/screenshots/tablet/` shots (1080x1920, the tablet layout taken at `wm density 240` on the 9:16 emulator) went into both. Full-size tablet captures time out on this Mac's software GPU |
| Uploading graphics | Dropping files on the page only puts them in the app's asset library. Each slot then needs Add assets > the file > Add, and then Save |
| Price | Free, all countries except where the App Store build is withheld (Afghanistan, Morocco: the grilling deck mentions alcohol) |

## App content answers

Policy and programs > App content. Every declaration is required, even the ones that do not apply;
Play's pre-review checks block publication while any is missing. Answers checked against Google's
help pages on September 25, 2026.

| Declaration | Answer |
|---|---|
| Privacy policy | `https://nsgnoah.github.io/ola/privacy.html` (live, titled "Spinola Privacy Policy", names the app, has a contact, covers Android) |
| App access | All functionality is available without special access (no login, nothing restricted) |
| Ads | No, the app does not contain ads |
| Content rating | Category: game. Answer the questionnaire as the App Store one was (see `docs/APP-STORE.md`): **references** to alcohol (beer and whiskey facts in the grilling deck), fighting **referred to** in text only (fight night, action movies), mild romantic themes, no depicted violence, no bad language, no gambling or simulated gambling, no user interaction or chat, no location sharing, no digital purchases, and **No** to "age-restricted physical goods" (that is for apps selling alcohol). Expect roughly Teen from ESRB; an alcohol reference can push PEGI to 16 and Indonesia's rating to 18+, which is fine. Redo it whenever a new deck changes these answers. **Submitted September 25, 2026**: violence against humans referred to only, in a realistic setting with unrealistic reactions; suggestive references in text; minor profanity, rarely; references to medical drugs and alcohol, rarely. Result: ESRB Teen, PEGI 12, USK 12, ACB PG, ClassInd 10, GRAC 15, IARC 12+ |
| Target audience | **18 and over only.** It matches the privacy policy ("made for adults playing together") and keeps the alcohol questions clear of the rules for teens. Never tick an under-13 group: that brings in the Families policy |
| Data safety | **No** to "Does your app collect or share any of the required user data types?" Google counts data as collected only when it leaves the device; names and matches stay on the phone, and the app has no internet permission. The follow-up questions only appear after a Yes. (Android's own backup to the user's Google Drive is the user's backup under Google's terms, which Google's Data safety FAQ treats as not collected) |
| Government apps | No, not developed by or for a government |
| Financial features | My app doesn't provide any financial features |
| Health apps | My app doesn't provide any health features. The wellness deck is trivia, and the listing makes no health or brain-training claims (those would make it a health app) |
| News and magazine | No |
| COVID-19 contact tracing and status | Neither |
| Advertising ID | No. The merged manifest has no `AD_ID` permission, and no library adds one |
| Data deletion / account deletion | Not applicable: there are no accounts; the profile and matches are on the phone and "Start over" or uninstalling removes them |

## Release checklist

1. Bump `versionCode` (and `versionName` when the marketing version changes) in
   `android/app/build.gradle.kts`.
2. `./gradlew :core:test :app:testDebugUnitTest` green.
3. Smoke-test the shrunk build before uploading it. R8 minifies release builds, and the only place
   that exercises the kept serializers is a real run. The release APK is signed with the upload key
   (or with the debug key on a machine without `keystore.properties`; Play rejects debug-signed
   uploads, so that cannot ship by accident). Uninstall a debug build first, since the signatures
   differ:

   ```bash
   ./gradlew :app:assembleRelease && adb install -r app/build/outputs/apk/release/app-release.apk
   ```

   Launch it, set up a profile, play one round in each mode, open Privacy & support, force-stop and
   relaunch (the profile and the match must come back).
4. `./gradlew :app:bundleRelease` with `keystore.properties` in place, upload the `.aab` to the
   **internal testing** track, add the testers by email, install through the Play link (not
   `adb`), play a whole match.
5. Promote to **production** with a staged rollout if you want to hedge, or 100%.
6. Reviews take from a few hours to a few days for a new account. Common first-submission holds:
   missing privacy policy URL (set above), the data-safety form left incomplete, or screenshots that
   do not match the app.

## Fonts

iOS uses Rockwell and DIN Condensed Bold, which Apple ships. Android ships neither, so the app
bundles the closest open-licence faces, chosen side by side against the real iOS fonts on September
25, 2026: **Arvo** (Regular and Bold) for Rockwell, a geometric slab of the same build, and **Barlow
Condensed Bold** for DIN Condensed Bold, which matches it almost stroke for stroke. Both are under
the SIL Open Font License 1.1, which allows bundling in a free or paid app; the font files are in
`android/app/src/main/res/font/`, their licence texts ship in `android/app/src/main/assets/licenses/`.
They are wired in one place, `Fonts` in `ui/theme/Theme.kt`, with the same size factors iOS applies
to DIN Condensed (1.12 for scores, 1.15 for labels).
