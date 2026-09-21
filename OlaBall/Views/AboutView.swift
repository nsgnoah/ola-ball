import SwiftUI

/// Privacy and support, in the app itself. App Review guideline 5.1.1(i) wants the privacy policy
/// reachable inside the app, not only from the store listing, and 1.5 wants a way to reach support.
/// Both live here rather than behind a link, so they work with no network at all.
///
/// Keep this in step with `docs/privacy-policy.md`; they are the same statement in two places.
struct AboutView: View {
    let onClose: () -> Void

    private let support = "noah@nsgsolutions.co"

    var body: some View {
        Stage(GameBackground(top: Theme.violet, bottom: Theme.violetDeep)) {
            StageScroll {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Kicker("OLA")
                        Spacer()
                        Button { onClose() } label: {
                            Glyph(kind: .close, size: 15, weight: 18)
                                .frame(width: 44, height: 44)
                                .background(.white.opacity(0.2), in: Circle())
                        }
                        .accessibilityLabel("Close")
                    }

                    StickerText("PRIVACY\n& SUPPORT", size: TypeScale.title, alignment: .leading)
                        .accessibilityIdentifier("about-screen")

                    VStack(alignment: .leading, spacing: 14) {
                        section("THE SHORT VERSION",
                                "Ola has no accounts, no servers of ours, and no analytics. There is no service of ours for your data to go to, and we never receive it.")

                        section("WHAT STAYS ON YOUR PHONE",
                                "Your profile, a first name and which world you know, and any pass-and-play matches are stored in the app on this phone. Clear them any time with Start over on the home screen, or by deleting the app.")

                        section("WHAT ONLINE PLAY SENDS",
                                "Playing from two phones uses Apple's Game Center. To carry a match between phones, Ola puts the match into Game Center: the first names entered on both sides, including a partner's name if you typed one, which world each person answers, the decks chosen, each answer, the scores, and how long each answer took.\n\nApple stores that match and shows it to the other side. It is held under Apple's Game Center privacy policy and stays there until the match is removed from Game Center. Start over inside Ola clears only what is on this phone.\n\nIf you would rather not share a real name, use a nickname.")

                        section("NOTHING ELSE LEAVES",
                                "No network requests other than Game Center's. No advertising, no tracking, no third-party SDKs, and no device permissions: no contacts, no location, no photos, no microphone.")

                        section("SUPPORT",
                                "Questions, bugs, or a wrong answer you want corrected: \(support)")
                    }
                    .panel(padding: 16)

                    Text("Version \(version)")
                        .font(.label(11)).foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(20)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Kicker(title, color: Theme.ink2, size: 11)
            Text(body)
                .font(.bodyRegular(14))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(v) (\(b))"
    }
}
