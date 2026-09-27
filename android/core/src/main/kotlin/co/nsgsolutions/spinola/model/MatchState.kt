package co.nsgsolutions.spinola.model

import kotlinx.serialization.Serializable

/*
 * Everything two phones need to agree on. Encoded as JSON into the Game Center match data
 * (or into local storage for pass-and-play). Kept small and boring on purpose.
 *
 * This is the cross-platform contract: the JSON written here is byte-compatible with what
 * `MatchState.swift` writes through Swift's JSONEncoder (enums as their raw strings, missing
 * optionals omitted rather than `null`, the seed as an unsigned 64-bit literal, dates as seconds
 * since Apple's reference date). Where the Swift struct has `mutating func`s, every mutation here
 * returns a new value: `state = state.pick(...)`.
 */

/** Apple's reference date, 2001-01-01T00:00:00Z, as seconds since the Unix epoch. */
private const val REFERENCE_EPOCH_SECONDS = 978_307_200.0

/**
 * "Now" as Swift's JSONEncoder writes a `Date`: seconds since 2001-01-01T00:00:00Z. Both platforms
 * store `createdAt`/`updatedAt` this way so a match started on one phone reads correctly on the other.
 */
fun nowReferenceSeconds(): Double = System.currentTimeMillis() / 1000.0 - REFERENCE_EPOCH_SECONDS

/** Turns a stored reference-date value back into Unix epoch milliseconds for the platform's date APIs. */
fun referenceSecondsToEpochMillis(seconds: Double): Long = Math.round((seconds + REFERENCE_EPOCH_SECONDS) * 1000.0)

@Serializable
enum class MatchMode {
    couple,   // you vs your partner
    teams;    // your couple vs another couple

    val title: String
        get() = when (this) {
            couple -> "Me vs my partner"
            teams -> "Our couple vs theirs"
        }
}

/** One person holding a phone. A solo player has one member; a couple has two. */
@Serializable
data class Member(
    val id: String,          // "$playerID/$index"
    val name: String,
    val knows: World,        // colors and the avatar
    val answers: World,      // the world this member gets quizzed on
)

@Serializable
data class MatchPlayer(
    val id: String,          // Game Center gamePlayerID, or "local-a" / "local-b"
    val name: String,        // "Noah" or "Noah & Sam"
    val world: World,        // the world this side knows (first member's, for teams)
    val members: List<Member>,
) {
    val isTeam: Boolean get() = members.size > 1

    companion object {
        fun solo(id: String, name: String, world: World): MatchPlayer =
            MatchPlayer(id = id, name = name, world = world, members = listOf(Member(id = "$id/0", name = name, knows = world, answers = world.other)))

        /** Each pair is (name, lane): the world that member both knows and answers. */
        fun team(id: String, members: List<Pair<String, World>>): MatchPlayer {
            val built = members.mapIndexed { i, (name, lane) -> Member(id = "$id/$i", name = name, knows = lane, answers = lane) }
            return MatchPlayer(id = id, name = built.joinToString(" & ") { it.name }, world = built.firstOrNull()?.knows ?: World.his, members = built)
        }
    }
}

@Serializable
data class RoundResult(
    val questionIDs: List<String>,
    val answers: List<Int?>,     // chosen option index per question; null = timed out
    val timesMs: List<Int>,
    val score: Int,
    val correct: Int,
)

@Serializable
data class Round(
    val number: Int,
    /** deckID each member must answer, keyed by member id. Chosen by the other side. */
    val picks: Map<String, String> = emptyMap(),
    val results: Map<String, RoundResult> = emptyMap(),
) {
    fun isComplete(memberIDs: List<String>): Boolean = memberIDs.all { results[it] != null }

    fun score(player: MatchPlayer): Int = player.members.mapNotNull { results[it.id]?.score }.sum()
}

@Serializable
enum class MatchStatus { active, finished }

@Serializable
data class MatchState(
    val version: Int = 3,
    val mode: MatchMode = MatchMode.couple,
    val seed: ULong,
    val players: List<MatchPlayer>,          // players[0] created the match and moves first
    val rounds: List<Round> = emptyList(),
    val status: MatchStatus = MatchStatus.active,
    val winnerID: String? = null,
    /** For pass-and-play. Game Center tracks the current participant itself. */
    val turnPlayerID: String? = null,
    /** Highest round number each player has seen the results of. */
    val revealed: Map<String, Int> = emptyMap(),
    val createdAt: Double = nowReferenceSeconds(),
    val updatedAt: Double = nowReferenceSeconds(),
) {
    companion object {
        const val roundsToWin = 3
        const val maxRounds = 5
        const val questionsPerRound = 7

        /** Swift's `init(seed:creator:mode:)`: one player in, and the creator holds the turn. */
        fun create(seed: ULong, creator: MatchPlayer, mode: MatchMode = MatchMode.couple): MatchState =
            MatchState(seed = seed, mode = mode, players = listOf(creator), turnPlayerID = creator.id)
    }

    // Lookup

    fun player(id: String): MatchPlayer? = players.firstOrNull { it.id == id }
    fun partner(ofID: String): MatchPlayer? = players.firstOrNull { it.id != ofID }
    fun member(id: String): Member? = players.flatMap { it.members }.firstOrNull { it.id == id }
    val playerIDs: List<String> get() = players.map { it.id }
    val allMemberIDs: List<String> get() = players.flatMap { p -> p.members.map { it.id } }
    val isReady: Boolean get() = players.size == 2

    fun crowns(forID: String): Int = rounds.count { roundWinner(it) == forID }

    fun total(forID: String): Int {
        val p = player(forID) ?: return 0
        return rounds.sumOf { it.score(p) }
    }

    /** Winner of a completed round, null if incomplete or tied. */
    fun roundWinner(round: Round): String? {
        if (!isReady || !round.isComplete(allMemberIDs)) return null
        val a = players[0]
        val b = players[1]
        val sa = round.score(a)
        val sb = round.score(b)
        if (sa == sb) return null
        return if (sa > sb) a.id else b.id
    }

    val completedRounds: List<Round> get() = rounds.filter { it.isComplete(allMemberIDs) }

    data class PendingAnswer(val round: Int, val member: Member)
    data class PendingPick(val round: Int, val targets: List<Member>)

    /** Members of this side who have a deck to answer, lowest round first, in member order. */
    fun pendingAnswers(forID: String): List<PendingAnswer> {
        if (status != MatchStatus.active) return emptyList()
        val p = player(forID) ?: return emptyList()
        for (r in rounds) {
            val missing = p.members.filter { r.picks[it.id] != null && r.results[it.id] == null }
            if (missing.isNotEmpty()) return missing.map { PendingAnswer(round = r.number, member = it) }
        }
        return emptyList()
    }

    /** The other side's members this side still owes a deck, in the lowest such round. */
    fun pendingPicks(forID: String): PendingPick? {
        if (status != MatchStatus.active) return null
        val partner = partner(forID) ?: return null
        for (r in rounds) {
            val missing = partner.members.filter { r.picks[it.id] == null }
            if (missing.isNotEmpty()) return PendingPick(round = r.number, targets = missing)
        }
        if (rounds.size < maxRounds) return PendingPick(round = rounds.size + 1, targets = partner.members)
        return null
    }

    // Mutation (each returns the changed state; the receiver is untouched)

    fun join(player: MatchPlayer): MatchState {
        if (players.size >= 2 || players.any { it.id == player.id }) return this
        return copy(players = players + player, updatedAt = nowReferenceSeconds())
    }

    fun pick(deckID: String, memberID: String, round: Int): MatchState {
        var rs = rounds
        if (rs.none { it.number == round }) rs = rs + Round(number = round)
        val r = rs[round - 1]
        rs = rs.toMutableList().also { it[round - 1] = r.copy(picks = r.picks + (memberID to deckID)) }
        return copy(rounds = rs, updatedAt = nowReferenceSeconds())
    }

    fun record(result: RoundResult, memberID: String, round: Int): MatchState {
        if (round - 1 >= rounds.size) return this
        val r = rounds[round - 1]
        val rs = rounds.toMutableList().also { it[round - 1] = r.copy(results = r.results + (memberID to result)) }
        return copy(rounds = rs, updatedAt = nowReferenceSeconds()).evaluate()
    }

    fun endTurn(fromID: String): MatchState = copy(turnPlayerID = partner(fromID)?.id, updatedAt = nowReferenceSeconds())

    /** Settle the match if someone has three crowns or five rounds are complete. */
    fun evaluate(): MatchState {
        if (status != MatchStatus.active || !isReady) return this
        val a = players[0].id
        val b = players[1].id
        val ca = crowns(a)
        val cb = crowns(b)
        if (ca >= roundsToWin) return copy(status = MatchStatus.finished, winnerID = a)
        if (cb >= roundsToWin) return copy(status = MatchStatus.finished, winnerID = b)
        if (completedRounds.size >= maxRounds) {
            return copy(status = MatchStatus.finished, winnerID = if (ca == cb) tiebreak(a, b) else if (ca > cb) a else b)
        }
        return this
    }

    private fun tiebreak(a: String, b: String): String? {
        val ta = total(a)
        val tb = total(b)
        if (ta == tb) return null
        return if (ta > tb) a else b
    }

    /** Every question used so far, so a later round never repeats one. */
    val usedQuestionIDs: Set<String>
        get() = rounds.flatMap { r -> r.results.values.flatMap { it.questionIDs } }.toSet()
}
