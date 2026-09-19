import SwiftUI

/// First launch: your name and the world you know. Your partner gets quizzed on your world.
struct ProfileSetupView: View {
    @Environment(ProfileStore.self) private var profiles
    @State private var name = ""
    @State private var world: World?

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Text("OLA").font(.condensed(13)).tracking(3).foregroundStyle(Theme.ink)
                    Circle().fill(Theme.ink3).frame(width: 3, height: 3)
                    Text("TRIVIA FOR TWO").font(.condensed(13)).tracking(3).foregroundStyle(Theme.ink3)
                }
                Text("WHOSE WORLD")
                    .font(.condensed(22)).tracking(4).foregroundStyle(Theme.ink2)
                    .padding(.top, 14)
                Text("DO YOU KNOW?")
                    .font(.headline(58)).foregroundStyle(Theme.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .padding(.top, -10)
                Text("Pick the side you could teach a class on. Your partner gets quizzed on it. You get quizzed on theirs.")
                    .font(.body(15)).foregroundStyle(Theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)

                VStack(spacing: 12) {
                    ForEach(World.allCases) { w in
                        Button {
                            Haptics.tap()
                            withAnimation(.spring(duration: 0.3)) { world = w }
                        } label: {
                            worldCard(w, selected: world == w)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("world-\(w.rawValue)")
                    }
                }
                .padding(.top, 20)

                VStack(alignment: .leading, spacing: 6) {
                    Kicker("YOUR NAME", color: Theme.ink2)
                    TextField("First name", text: $name)
                        .font(.bodyBold(18))
                        .foregroundStyle(Theme.ink)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 14)
                        .frame(height: 50)
                        .background(Theme.paperCard, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.rule, lineWidth: 1))
                        .accessibilityIdentifier("name-field")
                }
                .padding(.top, 20)

                Spacer(minLength: 12)

                Button {
                    guard let world, !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    Haptics.success()
                    SoundKit.shared.play(.crown)
                    profiles.profile = Profile(name: name.trimmingCharacters(in: .whitespaces), world: world)
                } label: {
                    HStack(spacing: 10) {
                        Text("Let's play")
                        Image(systemName: "arrow.right").font(.system(size: 15, weight: .black))
                    }
                }
                .buttonStyle(InkButtonStyle())
                .disabled(world == nil || name.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(world == nil || name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.35 : 1)
                .accessibilityIdentifier("profile-done")
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .preferredColorScheme(.light)
    }

    private func worldCard(_ w: World, selected: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(w.color)
                Image(systemName: w == .hers ? "sparkles" : "flame.fill").font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
            }
            .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 3) {
                Text(w.iKnowLine.uppercased()).font(.headline(24)).foregroundStyle(Theme.ink)
                Text(w.blurb).font(.body(13)).foregroundStyle(Theme.ink2).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Theme.paperCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(selected ? w.color : Theme.rule, lineWidth: selected ? 3 : 1))
        .shadow(color: .black.opacity(selected ? 0.12 : 0.05), radius: selected ? 14 : 8, y: 6)
    }
}
