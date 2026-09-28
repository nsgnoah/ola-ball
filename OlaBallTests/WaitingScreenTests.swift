import Testing
import SwiftUI
import UIKit
@testable import OlaBall

/// The waiting screen only shows in an online match (pass-and-play hands the phone straight over),
/// so the play-through UI test never reaches it. These render it at its tallest: four rounds in,
/// the fifth half played, a full scorecard, and in one case a turn that failed to send. They write
/// build/shots/<simulator udid>/waiting-*.png for review; run them on an iPhone SE to see the
/// smallest phone. The header and the "Back to matches" button must stay on screen.
@MainActor
@Suite(.serialized)
struct WaitingScreenTests {
    @Test func theirMove() async throws {
        let c = MatchController(state: Self.lateMatch(teams: false), transport: OnlineStub(fails: false), history: QuestionHistory())
        try await render(c, "waiting-couple")
        #expect(c.stage == .waiting)
    }

    @Test func notSentYet() async throws {
        let c = MatchController(state: Self.lateMatch(teams: false), transport: OnlineStub(fails: true), history: QuestionHistory())
        try await render(c, "waiting-unsent") { c.retrySubmit() }
        #expect(c.stage == .waiting)
        #expect(c.error != nil)
    }

    @Test func teams() async throws {
        let c = MatchController(state: Self.lateMatch(teams: true), transport: OnlineStub(fails: false), history: QuestionHistory())
        try await render(c, "waiting-teams")
        #expect(c.stage == .waiting)
    }

    /// Two crowns each after four rounds; in round five side "a" has answered and "b" hasn't.
    private static func lateMatch(teams: Bool) -> MatchState {
        var s = teams
            ? MatchState(seed: 7, creator: .team(id: "a", members: [("Noah", .his), ("Sam", .hers)]), mode: .teams)
            : MatchState(seed: 42, creator: .solo(id: "a", name: "Noah", world: .his))
        s.join(teams ? .team(id: "b", members: [("Alex", .his), ("Jo", .hers)]) : .solo(id: "b", name: "Sam", world: .hers))
        for r in 1...MatchState.maxRounds {
            for p in s.players {
                for m in p.members { s.pick(deckID: Decks.decks(in: m.answers)[r].id, forMember: m.id, round: r) }
            }
            for p in s.players where r < MatchState.maxRounds || p.id == "a" {
                let won = (r % 2 == 1) == (p.id == "a")
                for m in p.members {
                    s.record(RoundResult(questionIDs: [], answers: [], timesMs: [], score: won ? 820 : 540, correct: won ? 6 : 4), forMember: m.id, round: r)
                }
            }
        }
        s.turnPlayerID = "b"
        return s
    }

    /// Shows the whole match screen in a window the size of this simulator's screen, the way the app
    /// presents it, and saves a picture of it. `then` runs once the screen is up.
    private func render(_ controller: MatchController, _ name: String, then: (() -> Void)? = nil) async throws {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        Viewport.shared.fit(window.bounds.size)
        window.rootViewController = UIHostingController(rootView: MatchView(controller: controller).dynamicTypeSize(...DynamicTypeSize.xxLarge))
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        try await Task.sleep(for: .milliseconds(400))
        then?()
        try await Task.sleep(for: .milliseconds(800))
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            _ = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let device = ProcessInfo.processInfo.environment["SIMULATOR_UDID"] ?? "unknown"
        let dir = repo.appendingPathComponent("build/shots").appendingPathComponent(device)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try #require(image.pngData()).write(to: dir.appendingPathComponent("\(name).png"))
    }
}

/// An online match where it is the other side's turn. `fails` makes every submit fail the way a
/// dropped connection does.
private final class OnlineStub: MatchTransport {
    let fails: Bool
    init(fails: Bool) { self.fails = fails }
    var activePlayerID: String { "a" }
    var activePlayerName: String { "Noah" }
    var activePlayerWorld: World { .his }
    var isMyTurn: Bool { false }
    var isPassAndPlay: Bool { false }
    func submitTurn(_ state: MatchState) async throws {
        if fails {
            throw NSError(domain: "GKErrorDomain", code: 3, userInfo: [NSLocalizedDescriptionKey: "The requested operation could not be completed due to an error communicating with the server."])
        }
    }
    func save(_ state: MatchState) async throws {}
}
