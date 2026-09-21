import Foundation
import Observation

/// How a match's state reaches the other phone. Game Center or the same phone handed across the couch.
protocol MatchTransport: AnyObject {
    /// The side acting on this phone right now. For pass-and-play this is whoever holds the phone.
    var activePlayerID: String { get }
    var activePlayerName: String { get }
    var activePlayerWorld: World { get }
    var isMyTurn: Bool { get }
    var isPassAndPlay: Bool { get }
    /// Persist the state and hand the turn over. Called once per turn, after answering and picking.
    func submitTurn(_ state: MatchState) async throws
    /// Persist without ending the turn (a round was answered but the pick is still pending).
    func save(_ state: MatchState) async throws
}

/// Drives one match on screen. Views render `stage` and call the verbs; all rules live in MatchEngine and MatchState.
@Observable
final class MatchController {
    enum Stage: Equatable {
        case setupTeam                         // couples mode: this phone has to say who its two people are
        case handoff(to: String)               // hand the phone over
        case intro(round: Int)                 // "Round 3: Legend territory. Deck: Cars & Engines."
        case answering
        case picking(round: Int, target: Member)
        case roundReveal(round: Int)
        case waiting                           // their move
        case finished
    }

    private(set) var state: MatchState
    let transport: MatchTransport
    private(set) var stage: Stage = .waiting
    private(set) var error: String?
    private(set) var isSubmitting = false

    // Answering
    private(set) var currentMember: Member?
    private(set) var roundNumber = 0
    private(set) var deck: Deck?
    private(set) var questions: [Question] = []
    private(set) var index = 0
    private(set) var answers: [Int?] = []
    private(set) var timesMs: [Int] = []
    private(set) var selected: Int?
    private(set) var revealed = false
    private(set) var questionStart = Date()
    private(set) var streak = 0
    private(set) var runningScore = 0
    private var timer: Timer?

    init(state: MatchState, transport: MatchTransport) {
        self.state = state
        self.transport = transport
    }

    var me: String { transport.activePlayerID }
    /// Who the screen on show belongs to. Normally `me`, but a pass-and-play submit flips the
    /// transport's active side, so the reveal that follows a turn belongs to whoever just played,
    /// not to whoever is up next. Views that say "you won" must use this.
    var viewer: String { revealOwner ?? me }
    /// Set only while showing a reveal that outlived its mover's turn.
    private(set) var revealOwner: String?
    var meName: String { state.player(me)?.name ?? transport.activePlayerName }
    var partner: MatchPlayer? { state.partner(of: me) }
    var currentQuestion: Question? { index < questions.count ? questions[index] : nil }
    var secondsLeft: Double { max(0, MatchEngine.secondsPerQuestion - Date().timeIntervalSince(questionStart)) }
    /// Two people share this phone: pass-and-play, or a couple playing as a team.
    var sharesPhone: Bool { transport.isPassAndPlay || state.mode == .teams }

    // MARK: Entry

    /// Work out what this side should be doing right now.
    /// `announce`: when people share the phone, first show who should be holding it.
    func start(announce: Bool = false) {
        stopTimer()
        error = nil
        if state.player(me) == nil, state.players.count < 2 {
            if state.mode == .teams { stage = .setupTeam; return }
            state.join(.solo(id: me, name: transport.activePlayerName, world: transport.activePlayerWorld))
        }
        currentMember = nil
        // A Game Center match the moment it is created: only the creator is in the state, so there
        // is no partner to pick a deck for and nothing to answer. Pass the turn straight over so the
        // opponent can join and take the first move. Without this the creator lands on `.waiting`,
        // the seed state is never submitted, and the match is dead before it starts.
        if !transport.isPassAndPlay, state.status == .active, !state.isReady, transport.isMyTurn, !isSubmitting {
            stage = .waiting
            Task { await finishTurn() }
            return
        }
        if announce, sharesPhone, state.status == .active, state.isReady, transport.isMyTurn {
            stage = .handoff(to: handoffName())
            return
        }
        route()
    }

    /// Couples mode: this phone joins as a team of two.
    func joinTeam(members: [(name: String, lane: World)]) {
        guard state.mode == .teams, state.player(me) == nil, members.count == 2 else { return }
        state.join(.team(id: me, members: members))
        saveInBackground()
        start(announce: true)
    }

    /// Whose hands the phone belongs in next: the first member with a deck to answer, else the whole side.
    private func handoffName() -> String {
        state.pendingAnswers(for: me).first?.member.name ?? meName
    }

    /// The single source of "what's next".
    private func route() {
        if state.status == .finished {
            stage = unrevealedRound().map { .roundReveal(round: $0) } ?? .finished
            return
        }
        revealOwner = nil
        guard transport.isMyTurn else { stage = .waiting; return }
        if let r = unrevealedRound() { stage = .roundReveal(round: r); return }
        if let next = state.pendingAnswers(for: me).first {
            // Switching from one member to another on the same phone: hand it over first.
            if state.mode == .teams, let cur = currentMember, cur.id != next.member.id {
                stage = .handoff(to: next.member.name)
                return
            }
            prepare(next)
            stage = .intro(round: next.round)
            return
        }
        if let p = state.pendingPicks(for: me), let target = p.targets.first {
            stage = .picking(round: p.round, target: target)
            return
        }
        stage = .waiting
    }

    /// A completed round this side hasn't seen the results of yet.
    private func unrevealedRound() -> Int? { unrevealedRoundFor(me) }

    private func unrevealedRoundFor(_ player: String) -> Int? {
        let seen = state.revealed[player] ?? 0
        return state.completedRounds.map(\.number).filter { $0 > seen }.min()
    }

    func acknowledgeReveal() {
        guard case .roundReveal(let r) = stage else { return }
        let owner = viewer
        revealOwner = nil
        state.revealed[owner] = max(state.revealed[owner] ?? 0, r)
        saveInBackground()
        if state.status == .finished {
            // There may be a second reveal waiting for the other side before the final screen.
            stage = unrevealedRound().map { .roundReveal(round: $0) } ?? .finished
            return
        }
        route()
        if stage == .waiting, transport.isMyTurn { Task { await finishTurn() } }
    }

    // MARK: Answering

    private func prepare(_ pending: MatchState.PendingAnswer) {
        guard let round = state.rounds.first(where: { $0.number == pending.round }),
              let deckID = round.picks[pending.member.id], let d = Decks.byID(deckID) else { return }
        currentMember = pending.member
        roundNumber = pending.round
        deck = d
        questions = MatchEngine.questions(deck: d, round: pending.round, playerID: pending.member.id, seed: state.seed, excluding: state.usedQuestionIDs)
        index = 0
        answers = []
        timesMs = []
        selected = nil
        revealed = false
        streak = 0
        runningScore = 0
    }

    func beginAnswering() {
        guard case .intro = stage else { return }
        stage = .answering
        startQuestionClock()
    }

    private func startQuestionClock() {
        questionStart = Date()
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: MatchEngine.secondsPerQuestion, repeats: false) { [weak self] _ in
            self?.timedOut()
        }
    }

    private func stopTimer() { timer?.invalidate(); timer = nil }

    func select(_ option: Int) {
        guard stage == .answering, !revealed, let q = currentQuestion else { return }
        stopTimer()
        let elapsed = Int(Date().timeIntervalSince(questionStart) * 1000)
        selected = option
        revealed = true
        let correct = option == q.correctIndex
        streak = correct ? streak + 1 : 0
        runningScore += MatchEngine.points(correct: correct, elapsedMs: elapsed, streak: streak)
        answers.append(option)
        timesMs.append(elapsed)
        SoundKit.shared.play(correct ? .correct : .wrong)
        Haptics.answer(correct: correct)
    }

    private func timedOut() {
        guard stage == .answering, !revealed else { return }
        selected = nil
        revealed = true
        streak = 0
        answers.append(nil)
        timesMs.append(Int(MatchEngine.secondsPerQuestion * 1000))
        SoundKit.shared.play(.wrong)
        Haptics.answer(correct: false)
    }

    func nextQuestion() {
        guard stage == .answering, revealed else { return }
        index += 1
        selected = nil
        revealed = false
        if index >= questions.count {
            finishRound()
        } else {
            startQuestionClock()
        }
    }

    private func finishRound() {
        stopTimer()
        guard let member = currentMember else { return }
        let result = MatchEngine.score(questions: questions, answers: answers, timesMs: timesMs)
        state.record(result, forMember: member.id, round: roundNumber)
        if state.status == .finished {
            stage = .waiting          // never leave `.answering` with no question while the submit is in flight
            Task { await finishTurn() }
            return
        }
        saveInBackground()
        route()
        if stage == .waiting { Task { await finishTurn() } }
    }

    // MARK: Picking

    func pick(_ deck: Deck) {
        guard case .picking(let r, let target) = stage else { return }
        state.pick(deckID: deck.id, forMember: target.id, round: r)
        SoundKit.shared.play(.swoosh)
        if let p = state.pendingPicks(for: me), p.round == r, let next = p.targets.first {
            stage = .picking(round: r, target: next)
        } else {
            stage = .waiting
            Task { await finishTurn() }
        }
    }

    // MARK: Turn hand-off

    /// Saves the current state without blocking the UI. The snapshot matters: `state` is a value
    /// this class keeps mutating on the main thread, and handing it to a Task by reference would let
    /// the save read it mid-edit.
    private func saveInBackground() {
        let snapshot = state
        Task { try? await transport.save(snapshot) }
    }

    @MainActor
    private func finishTurn() async {
        isSubmitting = true
        defer { isSubmitting = false }
        // Capture before submitting: for pass-and-play the transport's active side flips on submit.
        let mover = me
        state.endTurn(from: mover)
        do {
            try await transport.submitTurn(state)
            currentMember = nil
            if state.status == .finished {
                if let r = unrevealedRoundFor(mover) {
                    revealOwner = mover
                    stage = .roundReveal(round: r)
                } else {
                    stage = .finished
                }
            } else if transport.isPassAndPlay {
                stage = .handoff(to: handoffName())
            } else {
                stage = .waiting
            }
        } catch {
            self.error = error.localizedDescription
            stage = .waiting
        }
    }

    /// The next person has the phone now.
    func continueAfterHandoff() {
        guard case .handoff = stage else { return }
        currentMember = nil
        start()
    }

    // MARK: Summary helpers

    func crowns(_ id: String) -> Int { state.crowns(for: id) }
    func total(_ id: String) -> Int { state.total(for: id) }
}
