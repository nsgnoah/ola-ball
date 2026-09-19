import Foundation
import Observation

/// How a match's state reaches the other phone. Game Center or the same phone handed across the couch.
protocol MatchTransport: AnyObject {
    /// The player acting on this phone right now. For pass-and-play this is whoever holds the phone.
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
        case handoff(to: String)          // pass-and-play: hand the phone over
        case intro(round: Int)            // "Round 3: Legend territory. Deck: Cars & Engines."
        case answering
        case picking(round: Int)
        case roundReveal(round: Int)
        case waiting                      // their move
        case finished
    }

    private(set) var state: MatchState
    let transport: MatchTransport
    private(set) var stage: Stage = .waiting
    private(set) var error: String?
    private(set) var isSubmitting = false

    // Answering
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
    var meName: String { state.player(me)?.name ?? transport.activePlayerName }
    var partner: MatchPlayer? { state.partner(of: me) }
    var currentQuestion: Question? { index < questions.count ? questions[index] : nil }
    var secondsLeft: Double { max(0, MatchEngine.secondsPerQuestion - Date().timeIntervalSince(questionStart)) }

    // MARK: Entry

    /// Work out what this player should be doing right now.
    /// `announce`: for pass-and-play, first show whose phone it should be, so nobody sees the wrong questions.
    func start(announce: Bool = false) {
        stopTimer()
        error = nil
        if announce, transport.isPassAndPlay, state.status == .active, state.isReady {
            stage = .handoff(to: transport.activePlayerName)
            return
        }
        // Join on first contact.
        if state.player(me) == nil, state.players.count < 2 {
            state.join(MatchPlayer(id: me, name: transport.activePlayerName, world: transport.activePlayerWorld))
        }
        if state.status == .finished {
            stage = unrevealedRound().map { .roundReveal(round: $0) } ?? .finished
            return
        }
        guard transport.isMyTurn else { stage = .waiting; return }
        if let r = unrevealedRound() { stage = .roundReveal(round: r); return }
        if let pending = state.pendingAnswer(for: me) {
            prepareRound(pending)
            stage = .intro(round: pending.number)
            return
        }
        if let r = state.pendingPick(for: me) { stage = .picking(round: r); return }
        stage = .waiting
    }

    /// A completed round this player hasn't seen the results of yet.
    private func unrevealedRound() -> Int? { unrevealedRoundFor(me) }

    private func unrevealedRoundFor(_ player: String) -> Int? {
        let seen = state.revealed[player] ?? 0
        return state.completedRounds.map(\.number).filter { $0 > seen }.min()
    }

    func acknowledgeReveal() {
        guard case .roundReveal(let r) = stage else { return }
        state.revealed[me] = max(state.revealed[me] ?? 0, r)
        Task { try? await transport.save(state) }
        if state.status == .finished { stage = .finished; return }
        // After seeing a result it may still be my move (answer or pick), or theirs.
        if let pending = state.pendingAnswer(for: me) { prepareRound(pending); stage = .intro(round: pending.number); return }
        if let r = state.pendingPick(for: me) { stage = .picking(round: r); return }
        stage = .waiting
    }

    // MARK: Answering

    private func prepareRound(_ round: Round) {
        guard let deckID = round.picks[me], let d = Decks.byID(deckID) else { return }
        roundNumber = round.number
        deck = d
        questions = MatchEngine.questions(deck: d, round: round.number, playerID: me, seed: state.seed, excluding: state.usedQuestionIDs)
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
        let result = MatchEngine.score(questions: questions, answers: answers, timesMs: timesMs)
        state.record(result, forRound: roundNumber, by: me)
        if let r = unrevealedRound() {
            Task { try? await transport.save(state) }
            stage = .roundReveal(round: r)
        } else if state.status == .finished {
            stage = .finished
            Task { await finishTurn() }
        } else if let r = state.pendingPick(for: me) {
            Task { try? await transport.save(state) }
            stage = .picking(round: r)
        } else {
            Task { await finishTurn() }
        }
    }

    // MARK: Picking

    func pick(_ deck: Deck) {
        guard case .picking(let r) = stage else { return }
        state.pick(deckID: deck.id, forRound: r, by: me)
        SoundKit.shared.play(.swoosh)
        Task { await finishTurn() }
    }

    // MARK: Turn hand-off

    @MainActor
    private func finishTurn() async {
        isSubmitting = true
        defer { isSubmitting = false }
        // Capture before submitting: for pass-and-play the transport's active player flips on submit.
        let mover = me
        let nextName = partner?.name ?? "your partner"
        state.endTurn(from: mover)
        do {
            try await transport.submitTurn(state)
            if state.status == .finished {
                stage = unrevealedRoundFor(mover).map { .roundReveal(round: $0) } ?? .finished
            } else if transport.isPassAndPlay {
                stage = .handoff(to: nextName)
            } else {
                stage = .waiting
            }
        } catch {
            self.error = error.localizedDescription
            stage = .waiting
        }
    }

    /// Pass-and-play: the other player has the phone now.
    func continueAfterHandoff() {
        guard case .handoff = stage else { return }
        start()
    }

    // MARK: Summary helpers

    func crowns(_ id: String) -> Int { state.crowns(for: id) }

    func total(_ id: String) -> Int { state.rounds.compactMap { $0.results[id]?.score }.reduce(0, +) }
}
