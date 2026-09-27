package co.nsgsolutions.spinola.engine

import co.nsgsolutions.spinola.model.Deck
import co.nsgsolutions.spinola.model.Decks
import co.nsgsolutions.spinola.model.MatchMode
import co.nsgsolutions.spinola.model.MatchPlayer
import co.nsgsolutions.spinola.model.MatchState
import co.nsgsolutions.spinola.model.MatchStatus
import co.nsgsolutions.spinola.model.Member
import co.nsgsolutions.spinola.model.Question
import co.nsgsolutions.spinola.model.World
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlin.math.max

/** How a match's state reaches the other phone. Play Games (Game Center on iOS) or the same phone handed across the couch. */
interface MatchTransport {
    /** The side acting on this phone right now. For pass-and-play this is whoever holds the phone. */
    val activePlayerID: String
    val activePlayerName: String
    val activePlayerWorld: World
    val isMyTurn: Boolean
    val isPassAndPlay: Boolean

    /** Persist the state and hand the turn over. Called once per turn, after answering and picking. */
    suspend fun submitTurn(state: MatchState)

    /** Persist without ending the turn (a round was answered but the pick is still pending). */
    suspend fun save(state: MatchState)
}

/**
 * The sounds and haptics the rules trigger (`SoundKit` + `Haptics` on iOS). The app implements it;
 * the rules stay free of platform imports.
 */
interface MatchFeedback {
    fun answer(correct: Boolean)
    fun swoosh()
}

/** Silence, for tests and previews. */
object NoFeedback : MatchFeedback {
    override fun answer(correct: Boolean) {}
    override fun swoosh() {}
}

sealed class Stage {
    /** Couples mode: this phone has to say who its two people are. */
    data object SetupTeam : Stage()

    /** Hand the phone over. */
    data class Handoff(val to: String) : Stage()

    /** "Round 3: Legend territory. Deck: Cars & Engines." */
    data class Intro(val round: Int) : Stage()
    data object Answering : Stage()
    data class Picking(val round: Int, val target: Member) : Stage()
    data class RoundReveal(val round: Int) : Stage()

    /** Their move. */
    data object Waiting : Stage()
    data object Finished : Stage()
}

/**
 * Drives one match on screen. Views render [snapshot] (or the convenience getters) and call the
 * verbs; all rules live in [MatchEngine] and [MatchState].
 *
 * Every verb must be called on the dispatcher of [scope] (the app passes a Main scope, tests a
 * test scope): the state is a plain value swapped in whole, and the 15 s question clock and the
 * turn submit are coroutines on that same scope, so nothing races. On iOS the same class is
 * `@Observable` with `@MainActor` submits.
 */
class MatchController(
    initial: MatchState,
    val transport: MatchTransport,
    private val feedback: MatchFeedback,
    private val scope: CoroutineScope,
    private val clock: () -> Long = System::currentTimeMillis,
) {
    data class Snapshot(
        val state: MatchState,
        val stage: Stage = Stage.Waiting,
        val error: String? = null,
        val isSubmitting: Boolean = false,
        // Answering
        val currentMember: Member? = null,
        val roundNumber: Int = 0,
        val deck: Deck? = null,
        val questions: List<Question> = emptyList(),
        val index: Int = 0,
        val answers: List<Int?> = emptyList(),
        val timesMs: List<Int> = emptyList(),
        val selected: Int? = null,
        val revealed: Boolean = false,
        val questionStartMs: Long = 0L,
        val streak: Int = 0,
        val runningScore: Int = 0,
        /** Set only while showing a reveal that outlived its mover's turn. */
        val revealOwner: String? = null,
    )

    private val mutableSnapshot = MutableStateFlow(Snapshot(state = initial, questionStartMs = clock()))
    val snapshot: StateFlow<Snapshot> = mutableSnapshot.asStateFlow()

    /** Swap in a changed snapshot. Views observing [snapshot] see each edit as one value. */
    private inline fun edit(change: Snapshot.() -> Snapshot) {
        mutableSnapshot.value = mutableSnapshot.value.change()
    }

    private var timer: Job? = null

    val state: MatchState get() = snapshot.value.state
    val stage: Stage get() = snapshot.value.stage
    val error: String? get() = snapshot.value.error
    val isSubmitting: Boolean get() = snapshot.value.isSubmitting
    val currentMember: Member? get() = snapshot.value.currentMember
    val roundNumber: Int get() = snapshot.value.roundNumber
    val deck: Deck? get() = snapshot.value.deck
    val questions: List<Question> get() = snapshot.value.questions
    val index: Int get() = snapshot.value.index
    val answers: List<Int?> get() = snapshot.value.answers
    val timesMs: List<Int> get() = snapshot.value.timesMs
    val selected: Int? get() = snapshot.value.selected
    val revealed: Boolean get() = snapshot.value.revealed
    val questionStartMs: Long get() = snapshot.value.questionStartMs
    val streak: Int get() = snapshot.value.streak
    val runningScore: Int get() = snapshot.value.runningScore
    private val revealOwner: String? get() = snapshot.value.revealOwner

    val me: String get() = transport.activePlayerID

    /**
     * Who the screen on show belongs to. Normally [me], but a pass-and-play submit flips the
     * transport's active side, so the reveal that follows a turn belongs to whoever just played,
     * not to whoever is up next. Views that say "you won" must use this.
     */
    val viewer: String get() = revealOwner ?: me
    val meName: String get() = state.player(me)?.name ?: transport.activePlayerName
    val partner: MatchPlayer? get() = state.partner(me)
    val currentQuestion: Question? get() = questions.getOrNull(index)
    val secondsLeft: Double get() = max(0.0, MatchEngine.secondsPerQuestion - (clock() - questionStartMs) / 1000.0)

    /** Two people share this phone: pass-and-play, or a couple playing as a team. */
    val sharesPhone: Boolean get() = transport.isPassAndPlay || state.mode == MatchMode.teams

    // Entry

    /**
     * Work out what this side should be doing right now.
     * [announce]: when people share the phone, first show who should be holding it.
     */
    fun start(announce: Boolean = false) {
        stopTimer()
        edit { copy(error = null) }
        if (state.player(me) == null && state.players.size < 2) {
            if (state.mode == MatchMode.teams) { edit { copy(stage = Stage.SetupTeam) }; return }
            edit { copy(state = state.join(MatchPlayer.solo(id = me, name = transport.activePlayerName, world = transport.activePlayerWorld))) }
        }
        edit { copy(currentMember = null) }
        // An online match the moment it is created: only the creator is in the state, so there is
        // no partner to pick a deck for and nothing to answer. Pass the turn straight over so the
        // opponent can join and take the first move. Without this the creator lands on `Waiting`,
        // the seed state is never submitted, and the match is dead before it starts.
        if (!transport.isPassAndPlay && state.status == MatchStatus.active && !state.isReady && transport.isMyTurn && !isSubmitting) {
            edit { copy(stage = Stage.Waiting) }
            scope.launch { finishTurn() }
            return
        }
        if (announce && sharesPhone && state.status == MatchStatus.active && state.isReady && transport.isMyTurn) {
            edit { copy(stage = Stage.Handoff(to = handoffName())) }
            return
        }
        route()
    }

    /** Couples mode: this phone joins as a team of two. Each pair is (name, lane). */
    fun joinTeam(members: List<Pair<String, World>>) {
        if (state.mode != MatchMode.teams || state.player(me) != null || members.size != 2) return
        edit { copy(state = state.join(MatchPlayer.team(id = me, members = members))) }
        saveInBackground()
        start(announce = true)
    }

    /** Whose hands the phone belongs in next: the first member with a deck to answer, else the whole side. */
    private fun handoffName(): String = state.pendingAnswers(me).firstOrNull()?.member?.name ?: meName

    /** The single source of "what's next". */
    private fun route() {
        if (state.status == MatchStatus.finished) {
            edit { copy(stage = unrevealedRound()?.let { Stage.RoundReveal(it) } ?: Stage.Finished) }
            return
        }
        edit { copy(revealOwner = null) }
        if (!transport.isMyTurn) { edit { copy(stage = Stage.Waiting) }; return }
        val r = unrevealedRound()
        if (r != null) { edit { copy(stage = Stage.RoundReveal(r)) }; return }
        val next = state.pendingAnswers(me).firstOrNull()
        if (next != null) {
            // Switching from one member to another on the same phone: hand it over first.
            val cur = currentMember
            if (state.mode == MatchMode.teams && cur != null && cur.id != next.member.id) {
                edit { copy(stage = Stage.Handoff(to = next.member.name)) }
                return
            }
            prepare(next)
            edit { copy(stage = Stage.Intro(round = next.round)) }
            return
        }
        val p = state.pendingPicks(me)
        val target = p?.targets?.firstOrNull()
        if (p != null && target != null) {
            edit { copy(stage = Stage.Picking(round = p.round, target = target)) }
            return
        }
        edit { copy(stage = Stage.Waiting) }
    }

    /** A completed round this side hasn't seen the results of yet. */
    private fun unrevealedRound(): Int? = unrevealedRoundFor(me)

    private fun unrevealedRoundFor(player: String): Int? {
        val seen = state.revealed[player] ?: 0
        return state.completedRounds.map { it.number }.filter { it > seen }.minOrNull()
    }

    fun acknowledgeReveal() {
        val r = (stage as? Stage.RoundReveal)?.round ?: return
        val owner = viewer
        edit {
            copy(
                revealOwner = null,
                state = state.copy(revealed = state.revealed + (owner to max(state.revealed[owner] ?: 0, r))),
            )
        }
        saveInBackground()
        if (state.status == MatchStatus.finished) {
            // There may be a second reveal waiting for the other side before the final screen.
            edit { copy(stage = unrevealedRound()?.let { Stage.RoundReveal(it) } ?: Stage.Finished) }
            return
        }
        route()
        if (stage == Stage.Waiting && transport.isMyTurn) scope.launch { finishTurn() }
    }

    // Answering

    private fun prepare(pending: MatchState.PendingAnswer) {
        val round = state.rounds.firstOrNull { it.number == pending.round } ?: return
        val deckID = round.picks[pending.member.id] ?: return
        val d = Decks.byID(deckID) ?: return
        edit {
            copy(
                currentMember = pending.member,
                roundNumber = pending.round,
                deck = d,
                questions = MatchEngine.questions(deck = d, round = pending.round, playerID = pending.member.id, seed = state.seed, excluding = state.usedQuestionIDs),
                index = 0,
                answers = emptyList(),
                timesMs = emptyList(),
                selected = null,
                revealed = false,
                streak = 0,
                runningScore = 0,
            )
        }
    }

    fun beginAnswering() {
        if (stage !is Stage.Intro) return
        edit { copy(stage = Stage.Answering) }
        startQuestionClock()
    }

    private fun startQuestionClock() {
        edit { copy(questionStartMs = clock()) }
        stopTimer()
        timer = scope.launch {
            delay((MatchEngine.secondsPerQuestion * 1000).toLong())
            timedOut()
        }
    }

    private fun stopTimer() {
        timer?.cancel()
        timer = null
    }

    fun select(option: Int) {
        if (stage != Stage.Answering || revealed) return
        val q = currentQuestion ?: return
        stopTimer()
        val elapsed = (clock() - questionStartMs).toInt()
        val correct = option == q.correctIndex
        val newStreak = if (correct) streak + 1 else 0
        edit {
            copy(
                selected = option,
                revealed = true,
                streak = newStreak,
                runningScore = runningScore + MatchEngine.points(correct = correct, elapsedMs = elapsed, streak = newStreak),
                answers = answers + option,
                timesMs = timesMs + elapsed,
            )
        }
        feedback.answer(correct)
    }

    private fun timedOut() {
        if (stage != Stage.Answering || revealed) return
        edit {
            copy(
                selected = null,
                revealed = true,
                streak = 0,
                answers = answers + null,
                timesMs = timesMs + (MatchEngine.secondsPerQuestion * 1000).toInt(),
            )
        }
        feedback.answer(false)
    }

    fun nextQuestion() {
        if (stage != Stage.Answering || !revealed) return
        edit { copy(index = index + 1, selected = null, revealed = false) }
        if (index >= questions.size) {
            finishRound()
        } else {
            startQuestionClock()
        }
    }

    private fun finishRound() {
        stopTimer()
        val member = currentMember ?: return
        val result = MatchEngine.score(questions = questions, answers = answers, timesMs = timesMs)
        edit { copy(state = state.record(result, memberID = member.id, round = roundNumber)) }
        if (state.status == MatchStatus.finished) {
            edit { copy(stage = Stage.Waiting) }   // never leave `Answering` with no question while the submit is in flight
            scope.launch { finishTurn() }
            return
        }
        saveInBackground()
        route()
        if (stage == Stage.Waiting) scope.launch { finishTurn() }
    }

    // Picking

    fun pick(deck: Deck) {
        val (r, target) = stage as? Stage.Picking ?: return
        edit { copy(state = state.pick(deckID = deck.id, memberID = target.id, round = r)) }
        feedback.swoosh()
        val p = state.pendingPicks(me)
        val next = if (p != null && p.round == r) p.targets.firstOrNull() else null
        if (next != null) {
            edit { copy(stage = Stage.Picking(round = r, target = next)) }
        } else {
            edit { copy(stage = Stage.Waiting) }
            scope.launch { finishTurn() }
        }
    }

    // Turn hand-off

    /**
     * Re-sends a turn whose submit failed. Nothing was lost locally, but the other phone never
     * received the move, so the match would sit on "their turn" forever with no way forward.
     */
    fun retrySubmit() {
        if (isSubmitting) return
        edit { copy(error = null, stage = Stage.Waiting) }
        scope.launch { finishTurn() }
    }

    /**
     * Saves the current state without blocking the UI. The snapshot matters: `state` keeps being
     * replaced on the main thread, and reading it inside the coroutine would let the save pick up
     * a later edit.
     */
    private fun saveInBackground() {
        val snapshot = state
        scope.launch {
            try {
                transport.save(snapshot)
            } catch (e: CancellationException) {
                throw e
            } catch (_: Exception) {
                // Best effort, as on iOS (`try? await transport.save`).
            }
        }
    }

    private suspend fun finishTurn() {
        edit { copy(isSubmitting = true) }
        try {
            // Capture before submitting: for pass-and-play the transport's active side flips on submit.
            val mover = me
            edit { copy(state = state.endTurn(fromID = mover)) }
            try {
                transport.submitTurn(state)
                edit { copy(currentMember = null) }
                if (state.status == MatchStatus.finished) {
                    val r = unrevealedRoundFor(mover)
                    if (r != null) {
                        edit { copy(revealOwner = mover, stage = Stage.RoundReveal(r)) }
                    } else {
                        edit { copy(stage = Stage.Finished) }
                    }
                } else if (transport.isPassAndPlay) {
                    edit { copy(stage = Stage.Handoff(to = handoffName())) }
                } else {
                    edit { copy(stage = Stage.Waiting) }
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                edit { copy(error = e.message ?: e.toString(), stage = Stage.Waiting) }
            }
        } finally {
            edit { copy(isSubmitting = false) }
        }
    }

    /** The next person has the phone now. */
    fun continueAfterHandoff() {
        if (stage !is Stage.Handoff) return
        edit { copy(currentMember = null) }
        start()
    }

    /** Stops the question clock. Call when the screen showing this match goes away. */
    fun dispose() {
        stopTimer()
    }

    // Summary helpers

    fun crowns(id: String): Int = state.crowns(id)
    fun total(id: String): Int = state.total(id)
}
