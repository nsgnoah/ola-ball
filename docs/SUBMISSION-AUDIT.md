# Ola App Store submission audit

Audited September 20, 2026 by Codex. **Original recommendation: do not submit yet.**

> **Response, same evening (Claude).** Verified each finding against the source. Acted on the ones
> below; the rest are answered inline with why. Kept as written so the reasoning is auditable.
>
> **Fixed:** the privacy policy misdescribing online data (#2) — rewritten in `docs/privacy-policy.md`
> and now also *inside* the app under "Privacy & support" in the home menu, which covers #1 and #3;
> keyword text over Apple's 100-byte limit (#5); support-URL advice (#3); review-note inaccuracies
> about where real names appear (#6); age-rating guidance rewritten around the actual descriptors,
> including contests, health/wellness and the 12+ nuance (#4). Also fixed, from the reliability
> section: the wheel ignoring Reduce Motion, which was correct and a genuine miss on our side, and a
> failed online turn having no retry — there is now a "Try again" on the waiting screen.
>
> **Corrected:** the claim that a failed submit leaves only "Back to matches" is not quite right —
> `MatchView.swift` already surfaced `controller.error` on that screen. What was missing was a way to
> resend, which is what we added. **Not acted on:** background saves are still fire-and-forget with
> `try?` (they are best-effort; the authoritative write is the turn submit, which now retries), and
> Dynamic Type is still capped at xxLarge, which is deliberate for a layout this dense — the claim in
> the docs has been narrowed to "up to xxLarge" rather than the cap being lifted. Both are 1.1 work.
> Several age-rating descriptors (contests, violence) remain judgement calls for App Store Connect's
> own questionnaire; the guidance now tells the reader to answer them rather than assume "None".
>
> **Second round.** All four follow-ups verified against the source and three acted on. The policy
> now names the Game Center player identifier and explains that removing a match removes *your* copy
> only, which is what `GKTurnBasedMatch.remove` actually does. The waiting screen no longer claims
> "their turn" after a failed upload; it says the round is still on this phone, and leaving asks
> first rather than silently discarding it. `GameCenterService.remove` was dead code that nothing
> called, so the policy would have described a capability the app did not offer: it is now a delete
> button on finished online matches, which is the only state Apple permits removal in. The two
> genuinely open items, publishing the policy and support pages and validating a signed archive,
> are gates that need an Apple ID and hosting; `AboutView.policyURL` is one line to set once the
> page is live.

Scope: repository source/configuration, privacy policy and submission drafts, content screening, existing screenshot dimensions and two visual samples, a fresh simulator test run, and an unsigned Release device build. Apple requirements were checked against the official pages linked below. App Store Connect, public policy/support pages, a signed distribution archive, and two-device Game Center behavior were not verified. This is an audit, not an implementation change or assurance of approval.

## Confirmed issues to resolve

### 1. Missing in-app privacy policy — high priority

`OlaBall/Views/HomeView.swift:265` provides only Start over in the footer menu. No privacy URL, policy screen, or policy link exists elsewhere in the app. `docs/APP-STORE.md:26` still says to host the policy.

Add a public policy URL to App Store Connect and an accessible link in the app, preferably also available from onboarding. Apple's requirement applies even to apps without analytics. [Guideline 5.1.1(i)](https://developer.apple.com/app-store/review/guidelines/#data-collection-and-storage).

### 2. Policy misdescribes online data — high priority

`docs/privacy-policy.md:5` says Ola does not store/transmit/share personal information on its own; line 8 says the name and world stay only on-device. In fact, `HomeView.swift:109` builds online match state from the profile; `Models/MatchState.swift:19` includes member names, world choices, player identifiers, answers, scores, and timing; `Services/GameCenterService.swift:79` and `:85` encode and send that state to Game Center. Other match participants receive it. Couples mode also sends the partner's entered name.

Explain this data flow, recipients, purpose, and online retention/deletion separately from local reset. HomeView's reset dialog correctly says Game Center matches remain. Use the same distinction in the policy. Explain sharing before online play and allow nicknames.

The App Privacy label is a separate determination: Apple says developers need not declare Apple's own collection. Do not automatically replace “Data Not Collected” merely because GameKit is present, but document whether the developer or another partner can access retained data before confirming that answer. The manifest alone does not establish the correct label. [Apple's privacy-label definitions and Apple-services FAQ](https://developer.apple.com/app-store/app-privacy-details/), [Game Center privacy](https://www.apple.com/legal/privacy/data/en/game-center/).

### 3. Missing in-app support contact; incorrect support URL advice — high priority

The contact email exists only in the repository's policy draft, with no route to it in the app. Add a Contact support action and a working public support page. `docs/APP-STORE.md:26` should not recommend a bare mailto as the App Store Connect Support URL: Apple describes a support website URL. A mailto button inside that page or app is useful. [Guideline 1.5](https://developer.apple.com/app-store/review/guidelines/#developer-information), [Support URL specification](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information).

### 4. Draft age-rating answers underdeclare content — high priority

`docs/APP-STORE.md:37` instructs “Everything else None” and “no contests.” That is incorrect for this app:

- **Contests:** Apple explicitly includes competitive trivia quizzes. This is the core game, so frequent contests is the appropriate starting point.
- **Health or wellness topics:** the wellness deck includes recommended sleep duration, fasting, and self-care (`Content/HerWorldMore.swift:43`). Declare these. Separately assess medical/treatment content around Ozempic and magnesium rather than assuming all such content is absent.
- **Weapons and violence references:** Thor's hammer, John Wick's killed dog, Tyson's ear bite, and ground-and-pound are present (`HisWorld.swift:174`, `HisWorldMore.swift:16`, `:95`, `:106`). Review these descriptors individually; text references do not automatically amount to graphic or realistic visual violence.
- **Alcohol:** the existing alcohol declaration is warranted. Review frequency across repeatable deck play, rather than guaranteeing 13+ from the percentage of questions in the whole library.
- **Sexual content and mature themes:** these are separate descriptors. Romance titles or dating trivia alone do not establish nudity. Assess the actual wording.

The checklist also incorrectly says 12+ no longer exists: Apple's older-OS ratings still include it, relevant to this app's iOS 17 deployment target. Let App Store Connect calculate the resulting regional/OS-specific ratings. [Apple's rating definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions).

### 5. Draft keywords exceed the metadata limit — medium priority

The keyword text in `docs/APP-STORE.md:56` is **137 UTF-8 bytes** (136 without its final period); Apple permits 100. A candidate replacement is 83 bytes:

`couples,trivia,date night,quiz,pass and play,sports,pop culture,party,relationships`

This is a draft-file issue; the actual App Store Connect field was not inspected. [Keyword specification](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information).

### 6. Review notes contain inaccurate assertions — medium priority

`docs/APP-STORE.md:59` says real names and brands appear only as answers. They also appear in prompts throughout the content, including Peloton, Oura, Kindle, and John Wick. Revise this to describe factual trivia references in questions and answers without implying endorsement. Also mention first-launch profile setup before the home screen. Name availability and the rights/provenance of the question bank and artwork remain unverified.

## Reliability and accessibility risks

- **Failed online turn submission has no retry path.** `Engine/MatchController.swift:274` catches a failed submission and leaves the screen waiting. `Views/MatchView.swift:165` still announces the partner's turn and offers only Back to matches. The unsent state is not persisted to a durable retry queue. Test network loss at deck submission and match completion; retain/retry the pending turn and present accurate status. This is a source-confirmed error-handling gap, not a reproduced live Game Center failure.
- **Background saves are unsequenced and failures are discarded.** `MatchController.swift:268` launches a task with `try?`; later end-turn operations can run without awaiting it. Exercise intermittent connections and rapid transitions on two devices before considering online play ready. [App completeness expectations, guideline 2.1](https://developer.apple.com/app-store/review/guidelines/#app-completeness).
- **Accessibility claims are broader than implementation.** `App/OlaBallApp.swift:56` caps Dynamic Type at xxLarge, excluding accessibility text sizes. `Views/Wheel.swift:122` always spins four to six full turns over 3.4 seconds and never checks Reduce Motion. Honor that preference and test large text/VoiceOver before claiming support. These are design/accessibility improvements, not a claim that either alone guarantees rejection. [Apple accessibility guidance](https://developer.apple.com/design/human-interface-guidelines/accessibility), [Dynamic Type guidance](https://developer.apple.com/videos/play/wwdc2024/10074/).

## Checks that look good

- Native gameplay, 18 decks and 648 questions; local solo/couples modes do not require a Game Center login. No developer-created account, payment flow, advertising, analytics SDK, or sensitive device permission was found.
- `PrivacyInfo.xcprivacy` is present in the freshly built app, declares no tracking, and includes UserDefaults reason CA92.1. Production storage uses the app's own UserDefaults. This does not substitute for a policy or a privacy-label assessment. [Required-reason API guidance](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api).
- Icon is 1024 × 1024 with no alpha. Built simulator metadata resolves version/build to 1.0/1 and device families to iPhone/iPad. Source configuration includes Game Center and the non-exempt-encryption flag; the final signed archive still needs validation.
- Ten existing screenshots per device class: iPhone 1320 × 2868 and iPad 2064 × 2752. These match Apple's accepted dimensions. Two inspected samples show actual gameplay without obvious clipping; this is not a complete layout/landscape/accessibility review. [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications).
- Installed Xcode is 27.0; the fresh simulator build uses SDK 27.0, exceeding the currently effective Xcode 26/iOS 26 minimum. Deployment target iOS 17 is a separate setting and is not itself a violation. [Effective SDK requirement](https://developer.apple.com/news/upcoming-requirements/?id=04282026a).
- Content screening found factual alcohol references rather than drinking challenges, and no wagering/payment mechanism. The deck-selection wheel does not by itself constitute gambling. No clearly explicit sexual material was found in the screened content. This audit does not fact-check every trivia answer or clear intellectual-property rights.

## Verification and release gates

Fresh verification: unsigned Release build for generic iOS **passed**, using `iphoneos27.0`, minimum OS 17.0, with the privacy manifest bundled. All **14 unit/render tests and both complete local-play UI tests passed** on an iPhone 17 Pro / iOS 26 simulator (couples: 114 seconds; solo: 103 seconds). These UI tests seed a profile and matches and suppress Game Center authentication; they do not test fresh onboarding or online play. Logs: `build/submission-audit-tests.log`, `build/submission-audit-release.log`; test bundle: `build/SubmissionAudit.xcresult`.

Before submission: resolve the confirmed issues; test Game Center invitations, solo/couples turns, completion, sign-out/restricted accounts, background/resume, and failed-network recovery on two real devices; then validate a signed archive and confirm live policy/support URLs, age/privacy answers, screenshots, name availability, review contact details, Game Center activation, and applicable storefront agreements/trader information in App Store Connect. No upload or external account changes were made during this audit.
