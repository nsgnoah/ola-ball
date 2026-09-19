import Foundation

/// One entry point: call → result → rules → narration.
enum DriveEngine {
    static func runPlay<R: RandomNumberGenerator>(_ call: PlayCall, from s: Situation, voice: Narrator.Voice, using rng: inout R) -> Play {
        let result = PlaySimulator.simulate(call, in: s, using: &rng)
        let outcome = RulesEngine.apply(result, call: call, to: s)
        let narration = Narrator.line(for: call, result: result, before: s, outcome: outcome, voice: voice, using: &rng)
        return Play(before: s, call: call, result: result, after: outcome.after, ending: outcome.ending, gainedFirstDown: outcome.firstDown, narration: narration)
    }
}
