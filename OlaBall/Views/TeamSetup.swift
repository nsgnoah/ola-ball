import SwiftUI

/// Two people and the lane each of them answers.
struct TeamDraft: Equatable {
    var name1 = ""
    var name2 = ""
    var lane1: World = .his
    var lane2: World = .hers

    var isComplete: Bool {
        !name1.trimmingCharacters(in: .whitespaces).isEmpty && !name2.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var members: [(name: String, lane: World)] {
        [(name1.trimmingCharacters(in: .whitespaces), lane1), (name2.trimmingCharacters(in: .whitespaces), lane2)]
    }

    static func mine(from profile: Profile?) -> TeamDraft {
        var d = TeamDraft()
        d.name1 = profile?.name ?? ""
        d.lane1 = profile?.teamMyLane ?? profile?.world ?? .his
        d.name2 = profile?.teamPartnerName ?? ""
        d.lane2 = profile?.teamPartnerLane ?? d.lane1.other
        return d
    }
}

/// Name fields plus a lane toggle per person.
struct TeamSetupFields: View {
    let title: String
    @Binding var draft: TeamDraft
    var placeholder1 = "First name"
    var placeholder2 = "Partner's first name"

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Kicker(title, color: Theme.ink2, size: 12)
            memberRow(name: $draft.name1, lane: $draft.lane1, placeholder: placeholder1, id: "\(title)-1")
            memberRow(name: $draft.name2, lane: $draft.lane2, placeholder: placeholder2, id: "\(title)-2")
            Text("Tap the pill to change which questions each person answers.")
                .font(.bodyRegular(11)).foregroundStyle(Theme.ink2)
        }
        .panel(padding: 14)
    }

    private func memberRow(name: Binding<String>, lane: Binding<World>, placeholder: String, id: String) -> some View {
        HStack(spacing: 8) {
            TextField(placeholder, text: name)
                .font(.bodyBold(17)).foregroundStyle(Theme.ink)
                .textInputAutocapitalization(.words).autocorrectionDisabled()
                .padding(.horizontal, 12).frame(height: 46)
                .background(Theme.cream, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityIdentifier("team-name-\(id)")
            Button {
                Haptics.tap()
                lane.wrappedValue = lane.wrappedValue.other
            } label: {
                Text("ANSWERS \(lane.wrappedValue == .his ? "HIS" : "HER")")
                    .font(.label(11)).tracking(0.8)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).frame(height: 46)
                    .background(lane.wrappedValue.color, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .accessibilityIdentifier("team-lane-\(id)")
        }
    }
}

/// Stacked avatars for a side, solo or couple.
struct SideAvatars: View {
    let player: MatchPlayer
    var size: CGFloat = 36

    var body: some View {
        // Avatar scales itself, so it gets the raw size; the layout around it needs the scaled one.
        let s = UI.s(size)
        if player.isTeam {
            ZStack {
                ForEach(Array(player.members.enumerated()), id: \.element.id) { i, m in
                    Avatar(name: m.name, world: m.knows, size: size)
                        .offset(x: CGFloat(i) * s * 0.55 - s * 0.27)
                }
            }
            .frame(width: s * 1.6, height: s)
        } else {
            Avatar(name: player.name, world: player.world, size: size)
        }
    }
}

/// Couples mode over Game Center: the challenged phone says who its two people are before joining.
struct JoinTeamView: View {
    @Environment(ProfileStore.self) private var profiles
    let controller: MatchController
    let onClose: () -> Void
    @State private var draft = TeamDraft()

    var body: some View {
        let challenger = controller.state.players.first
        Stage(GameBackground(top: Theme.violet, bottom: Theme.violetDeep)) {
            StageScroll {
            VStack(spacing: 14) {
                HStack {
                    Button { onClose() } label: {
                        Glyph(kind: .close, size: 15, weight: 18)
                            .frame(width: 44, height: 44).background(.white.opacity(0.2), in: Circle())
                    }
                    .accessibilityLabel("Close")
                    Spacer()
                }
                Kicker("COUPLE VS COUPLE")
                StickerText("YOU'VE BEEN\nCHALLENGED", size: TypeScale.title)
                if let challenger {
                    HStack(spacing: 10) {
                        SideAvatars(player: challenger, size: 40)
                        Text(challenger.name.uppercased()).font(.headline(24)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.6)
                        Spacer()
                    }
                    .panel(padding: 12)
                }
                OlaSays(text: "Who's on your side of the couch? Each of you answers your own lane, unless you'd rather swap.")
                TeamSetupFields(title: "YOUR COUPLE", draft: $draft)
                Button("Join the match") {
                    guard draft.isComplete else { return }
                    Haptics.heavy()
                    remember()
                    controller.joinTeam(members: draft.members)
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.gold))
                .disabled(!draft.isComplete)
                .opacity(draft.isComplete ? 1 : 0.45)
                .accessibilityIdentifier("join-team")
            }
            .padding(20)
        }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear { draft = .mine(from: profiles.profile) }
    }

    private func remember() {
        guard var p = profiles.profile else { return }
        p.teamPartnerName = draft.name2.trimmingCharacters(in: .whitespaces)
        p.teamMyLane = draft.lane1
        p.teamPartnerLane = draft.lane2
        profiles.profile = p
    }
}

/// Before challenging another couple online: confirm your own couple.
struct MyTeamSheet: View {
    @Environment(ProfileStore.self) private var profiles
    let onDone: (TeamDraft) -> Void
    @State private var draft = TeamDraft()

    var body: some View {
        Stage(GameBackground(top: Theme.violet, bottom: Theme.violetDeep)) {
            VStack(alignment: .leading, spacing: 14) {
                Kicker("COUPLE VS COUPLE")
                StickerText("YOUR COUPLE", size: TypeScale.title, alignment: .leading)
                TeamSetupFields(title: "ON THIS PHONE", draft: $draft)
                OlaSays(text: "Next you'll pick the other couple from Game Center. They set up their side on their phone.")
                Spacer()
                Button("Find the other couple") {
                    guard draft.isComplete else { return }
                    Haptics.heavy()
                    if var p = profiles.profile {
                        p.teamPartnerName = draft.name2.trimmingCharacters(in: .whitespaces)
                        p.teamMyLane = draft.lane1
                        p.teamPartnerLane = draft.lane2
                        profiles.profile = p
                    }
                    onDone(draft)
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.gold))
                .disabled(!draft.isComplete)
                .opacity(draft.isComplete ? 1 : 0.45)
            }
            .padding(20)
        }
        .onAppear { draft = .mine(from: profiles.profile) }
        .preferredColorScheme(.dark)
    }
}
