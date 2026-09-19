import Foundation

/// A sensible, slightly conservative AI coach for the other sideline.
enum OpponentCoach {
    static func choose<R: RandomNumberGenerator>(for s: Situation, using rng: inout R) -> PlayCall {
        if s.down == 4 {
            if s.isGoalToGo && s.yardsToGo <= 2 { return .run }
            if s.inFieldGoalRange { return .fieldGoal }
            if s.ballOn >= 58 && s.yardsToGo <= 3 { return Bool.random(using: &rng) ? .run : .shortPass }
            return .punt
        }
        if s.down == 3 && s.yardsToGo >= 7 {
            return Bool.random(using: &rng) ? .deepPass : .shortPass
        }
        let roll = Int.random(in: 0..<100, using: &rng)
        if s.inRedZone { return roll < 55 ? .run : .shortPass }
        if roll < 45 { return .run }
        if roll < 80 { return .shortPass }
        return .deepPass
    }

    static func simulateDrive<R: RandomNumberGenerator>(from start: Situation, using rng: inout R) -> DriveSummary {
        var plays: [Play] = []
        var s = start
        while plays.count < 40 {
            let call = choose(for: s, using: &rng)
            let play = DriveEngine.runPlay(call, from: s, voice: .them, using: &rng)
            plays.append(play)
            if let ending = play.ending {
                return DriveSummary(plays: plays, ending: ending, startBallOn: start.ballOn)
            }
            s = play.after ?? s
        }
        let punt = DriveEngine.runPlay(.punt, from: s, voice: .them, using: &rng)
        plays.append(punt)
        return DriveSummary(plays: plays, ending: .punt, startBallOn: start.ballOn)
    }
}
