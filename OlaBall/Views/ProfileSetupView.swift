import SwiftUI

/// First launch: your name and the world you know.
struct ProfileSetupView: View {
    @Environment(ProfileStore.self) private var profiles
    @State private var name = ""
    @State private var world: World?
    @State private var wiggle = false

    var body: some View {
        ZStack {
            GameBackground(top: Theme.violet, bottom: Theme.violetDeep)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    VStack(spacing: 2) {
                        Kicker("OLA · TRIVIA FOR TWO")
                        Text("WHOSE WORLD").font(.headline(TypeScale.heading)).foregroundStyle(.white.opacity(0.85))
                        StickerText("DO YOU KNOW?", size: TypeScale.display).padding(.top, -10)
                    }
                    .padding(.top, 10)

                    HStack(spacing: 14) {
                        ForEach(World.allCases) { w in
                            Button {
                                Haptics.tap()
                                withAnimation(.spring(duration: 0.35, bounce: 0.4)) { world = w }
                            } label: {
                                worldCard(w, selected: world == w)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("world-\(w.rawValue)")
                        }
                    }

                    OlaSays(text: "Pick the side you could teach a class on. Your partner gets quizzed on it, you get quizzed on theirs.")

                    VStack(alignment: .leading, spacing: 8) {
                        Kicker("YOUR NAME", color: Theme.ink2, size: 12)
                        TextField("First name", text: $name)
                            .font(.bodyBold(20))
                            .foregroundStyle(Theme.ink)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .onSubmit { commit() }
                            .padding(.horizontal, 14)
                            .frame(height: 54)
                            .background(Theme.cream, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .accessibilityIdentifier("name-field")
                    }
                    .panel(padding: 14)

                    Button {
                        commit()
                    } label: {
                        HStack(spacing: 10) {
                            Text("Let's play")
                            Image(systemName: "arrow.right").font(.system(size: 18, weight: .black))
                        }
                    }
                    .buttonStyle(ChunkyButtonStyle(color: Theme.gold))
                    .disabled(!canCommit)
                    .opacity(canCommit ? 1 : 0.45)
                    .accessibilityIdentifier("profile-done")
                    .padding(.top, 4)
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .preferredColorScheme(.dark)
    }

    private var canCommit: Bool { world != nil && !name.trimmingCharacters(in: .whitespaces).isEmpty }

    private func commit() {
        guard let world, canCommit else { return }
        Haptics.success()
        SoundKit.shared.play(.crown)
        profiles.profile = Profile(name: name.trimmingCharacters(in: .whitespaces), world: world)
    }

    private func worldCard(_ w: World, selected: Bool) -> some View {
        let decks = Decks.decks(in: w)
        return ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous).fill(w.color.mix(with: .black, by: 0.3)).offset(y: 7)
            RoundedRectangle(cornerRadius: 22, style: .continuous).fill(w.color)
            Stripes().fill(.white.opacity(0.07)).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: -18) {
                    ForEach(decks.prefix(3)) { d in Mascot(deck: d, size: 46) }
                }
                .padding(.top, 8)
                Spacer(minLength: 6)
                StickerText(w == .hers ? "HER" : "HIS", size: 44, alignment: .leading).padding(.bottom, -8)
                Text("WORLD").font(.headline(22)).foregroundStyle(.white.opacity(0.9))
                Text(w == .hers ? "Beauty, fashion, rom-coms, reality TV, divas, weddings" : "Football, ball sports, cars, grilling, games, gear")
                    .font(.bodyRegular(11)).foregroundStyle(.white.opacity(0.85)).fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
            .padding(12)
            if selected {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 26, weight: .black)).foregroundStyle(.white, Theme.good)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(10)
            }
        }
        .frame(height: 230)
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white, lineWidth: selected ? 4 : 0))
        .scaleEffect(selected ? 1.03 : 1)
    }
}
