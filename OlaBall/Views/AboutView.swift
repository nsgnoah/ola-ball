import SwiftUI

/// Privacy and support, in the app itself. App Review guideline 5.1.1(i) wants the privacy policy
/// reachable inside the app, not only from the store listing, and 1.5 wants a way to reach support.
/// Both live here rather than behind a link, so they work with no network at all.
///
/// Keep this in step with `docs/privacy-policy.md`; they are the same statement in two places.
struct AboutView: View {
    let onClose: () -> Void

    private let support = "noah@nsgsolutions.co"

    /// Set this to the published policy URL once it is live, and the button below appears.
    /// Left empty on purpose: a link that 404s is worse than no link, and the full text is here
    /// anyway, which is what matters when someone has no signal.
    private let policyURL = ""

    var body: some View {
        Stage(GameBackground(top: Theme.violet, bottom: Theme.violetDeep)) {
            StageScroll {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Kicker("SPINOLA")
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
                                "Spinola has no accounts, no servers of ours, and no analytics. There is no service of ours for your data to go to, and we never receive it.")

                        section("WHAT STAYS ON YOUR PHONE",
                                "Your profile, a first name and which world you know, and any pass-and-play matches are stored in the app on this phone. Clear them any time with Start over on the home screen, or by deleting the app.")

                        section("WHAT ONLINE PLAY SENDS",
                                "Playing from two phones uses Apple's Game Center. To carry a match between phones, Spinola puts the match into Game Center: the first names entered on both sides, including a partner's name if you typed one, the identifier Game Center gives each player, which world each person answers, the decks chosen, each answer, the scores, and how long each answer took.\n\nApple stores that match and shows it to the other side, and holds it under Apple's Game Center privacy policy.\n\nIf you would rather not share a real name, use a nickname.")

                        section("REMOVING A MATCH",
                                "Once a match has finished, a delete button appears beside it, and Game Center lets you remove matches from its own screens. Either way this removes your copy only. The other player keeps theirs, with the names and answers still in it, and there is no way for Spinola or for you to delete their copy.\n\nStart over is separate: it clears what is on this phone and touches nothing held by Game Center.")

                        section("NOTHING ELSE LEAVES",
                                "No network requests other than Game Center's. No advertising, no tracking, no third-party SDKs, and no device permissions: no contacts, no location, no photos, no microphone.")

                        section("SUPPORT",
                                "Questions, bugs, or a wrong answer you want corrected: \(support)")
                    }
                    .panel(padding: 16)

                    if let url = URL(string: policyURL), !policyURL.isEmpty {
                        Link(destination: url) {
                            Text("Read this policy on the web")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ChunkyButtonStyle(color: .white, edge: Theme.panelEdge, ink: Theme.ink, height: 48, fontSize: 17))
                        .accessibilityIdentifier("policy-link")
                    }

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
