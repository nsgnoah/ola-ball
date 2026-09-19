import Foundation

/// A single Playbook entry, in Coach Ola's voice. Taught in-context by a tip, then collected in the Playbook.
struct Concept: Identifiable, Hashable {
    enum Category: String, CaseIterable {
        case basics = "The Basics"
        case reading = "Reading the Defense"
        case plays = "Running & Passing"
        case downs = "Downs"
        case scoring = "Scoring & Kicking"
        case turnovers = "Turnovers"
        case strategy = "Coaching Strategy"
    }

    let id: String
    let title: String
    let symbol: String
    let body: String
    let category: Category
    let unlockHint: String

    static func byID(_ id: String) -> Concept? { all.first { $0.id == id } }

    static let all: [Concept] = [
        // Basics
        Concept(id: "objective", title: "The Goal & Four Tries", symbol: "flag.checkered",
                body: "Here's the whole game in one breath: get the ball into that far end zone. You get four tries, called downs, to move it ten yards. Make it and you get four more. Miss, and they take over.",
                category: .basics, unlockHint: "Start your first game."),
        Concept(id: "drawThePlay", title: "Draw the Play", symbol: "hand.draw.fill",
                body: "See the rings? Those players can take the ball. Drag from one of them, draw the path you want, and let go. That's the whole control scheme. Where you draw is where they go.",
                category: .basics, unlockHint: "Line up for your first play."),
        Concept(id: "defense", title: "Now You're on Defense", symbol: "shield.lefthalf.filled",
                body: "Their ball now. I'll give you four ways to line up my defense. Pick one, then we watch. Stop them inside four downs and we get the ball back.",
                category: .basics, unlockHint: "Finish your first drive."),
        Concept(id: "kickoff", title: "Kickoff & the 25", symbol: "arrow.up.forward",
                body: "After a score, the other side gets the ball back on a kickoff. Most of the time the returner kneels in the end zone, a touchback, and they start from their 25. Nothing to decide here.",
                category: .basics, unlockHint: "Score, or get scored on."),
        Concept(id: "quarters", title: "Four Quarters", symbol: "clock",
                body: "Four quarters in a game. In here we each get one drive per quarter, and halftime comes after the second. Real games run a clock; the rhythm is the same, we just skip the commercials.",
                category: .basics, unlockHint: "Reach the 2nd quarter."),
        Concept(id: "sideline", title: "Out of Bounds", symbol: "arrow.left.to.line",
                body: "Those white borders are the sidelines. Step over one and the play ends right there. Running toward the sideline is safe, but it's a dead end.",
                category: .basics, unlockHint: "Run out of bounds."),
        Concept(id: "overtime", title: "Overtime", symbol: "arrow.clockwise",
                body: "Tied after four? Overtime. Each team gets one more drive. Still tied? We go again. Nobody's leaving until someone wins.",
                category: .basics, unlockHint: "Finish regulation tied."),

        // Reading the defense
        Concept(id: "theBox", title: "The Box", symbol: "rectangle.stack.fill",
                body: "The box is the crowd right in front of the ball, the big guys. Count them. Eight in the box means they're betting on a run, which means fewer of them are back deep. That's your cue to throw.",
                category: .reading, unlockHint: "Face a stacked box."),
        Concept(id: "safeties", title: "Safeties: the Deep Help", symbol: "umbrella.fill",
                body: "The two players way in the back are safeties. Their whole job is stopping long passes. When both are deep, throwing far is a bad bet, but there are fewer bodies up front, so a run has room.",
                category: .reading, unlockHint: "Face two safeties deep."),
        Concept(id: "cornerbacks", title: "Cornerbacks", symbol: "person.2.fill",
                body: "The defenders across from your wide receivers are cornerbacks. Each one shadows a receiver. A sharp cut in your route makes them a step late, and a step is all you need.",
                category: .reading, unlockHint: "Draw a route for a wide receiver."),
        Concept(id: "blitz", title: "The Blitz", symbol: "bolt.fill",
                body: "A blitz means they're sending extra players after my quarterback. Long routes get you sacked. Beat it with a quick, short throw, or run the other way.",
                category: .reading, unlockHint: "Face a blitz."),
        Concept(id: "gaps", title: "Gaps: Run Where They Aren't", symbol: "arrow.triangle.branch",
                body: "Blockers can only hold so many defenders. Before you draw, look at the line and find the side with fewer bodies, then draw the run through it. Fewer defenders at the hole is more yards, every time.",
                category: .reading, unlockHint: "Call your first run."),
        Concept(id: "linemen", title: "Blockers vs. Rushers", symbol: "figure.stand.line.dotted.figure.stand",
                body: "The five big guys in front of the quarterback are the offensive line. They block. The defenders across from them try to get past. A block holds for a couple of seconds, so slow plays get caught.",
                category: .reading, unlockHint: "Call a pass play."),

        // Plays
        Concept(id: "runPlay", title: "The Run", symbol: "figure.run",
                body: "Drag from the running back to hand him the ball. Runs are steady and safe. Aim for daylight, then keep going.",
                category: .plays, unlockHint: "Call a run."),
        Concept(id: "passPlay", title: "The Pass", symbol: "arrow.up.right",
                body: "Drag from a receiver to draw his route. My quarterback throws when the receiver finishes it. Short routes are quick and safe. Long ones are slow and risky, but they're how you get the big ones.",
                category: .plays, unlockHint: "Throw a pass."),
        Concept(id: "separation", title: "Separation", symbol: "arrow.left.and.right",
                body: "Separation is how much room the receiver has from the nearest defender when the ball arrives. Three yards is an easy catch. Under one is a coin flip, and it's how interceptions happen.",
                category: .plays, unlockHint: "Complete a pass."),
        Concept(id: "incomplete", title: "Incomplete", symbol: "xmark.circle",
                body: "The pass hit the ground. Nobody lost anything, you just used a down. Shake it off.",
                category: .plays, unlockHint: "Throw an incomplete pass."),
        Concept(id: "sack", title: "Sacked!", symbol: "exclamationmark.triangle.fill",
                body: "A sack: they got to my quarterback before he could throw, and it costs yards. The longer the route, the longer he waits, the more this happens.",
                category: .plays, unlockHint: "Get sacked."),
        Concept(id: "keeper", title: "The Quarterback Keeper", symbol: "figure.walk",
                body: "Drag from the quarterback and he keeps it and runs himself. The defense never expects it. Great near the goal line, dangerous if he takes a hit.",
                category: .plays, unlockHint: "Run with the quarterback."),

        // Downs
        Concept(id: "notation", title: "Reading \"2nd & 7\"", symbol: "textformat.123",
                body: "Here's how to read it. The first number is which try you're on, the second is how far you still need. \"2nd & 7\" means second try, seven more yards. Now you can read any scoreboard on TV.",
                category: .downs, unlockHint: "Reach 2nd down."),
        Concept(id: "firstDown", title: "First Down!", symbol: "checkmark.seal.fill",
                body: "You crossed the yellow line. First down: four fresh tries, and the line moves ten yards ahead. This is the rhythm of the whole sport.",
                category: .downs, unlockHint: "Earn a first down."),
        Concept(id: "thirdDown", title: "Third Down: Money Down", symbol: "3.circle.fill",
                body: "Third down is the money down. Make the distance and you keep the ball. Miss, and fourth down gets complicated.",
                category: .downs, unlockHint: "Reach 3rd down."),
        Concept(id: "fourthDown", title: "Fourth Down: Decision Time", symbol: "4.circle.fill",
                body: "Last try. Three choices: go for it (miss and they take over right here), punt it away (safe), or kick a field goal if you're close enough. I'll tell you the odds.",
                category: .downs, unlockHint: "Reach 4th down."),
        Concept(id: "goalToGo", title: "\"& Goal\"", symbol: "flag.fill",
                body: "Inside their ten there's no yellow line anymore. \"1st & Goal\" means the only thing left to earn is the end zone.",
                category: .downs, unlockHint: "Get inside the 10."),

        // Scoring & kicking
        Concept(id: "touchdown", title: "Touchdown: 6 (+1)", symbol: "star.fill",
                body: "That's a touchdown. Six points, then a short kick for one more, so call it seven. Enjoy this one. I'll wait.",
                category: .scoring, unlockHint: "Score a touchdown."),
        Concept(id: "fieldGoal", title: "Field Goal: 3 Points", symbol: "target",
                body: "Close enough to kick? A field goal is three points if it goes through the posts. Tap when the needle is in the green. The kick is the distance to the end zone plus 17, and the green zone shrinks as it gets longer.",
                category: .scoring, unlockHint: "Reach 4th down in kicking range."),
        Concept(id: "punt", title: "The Punt", symbol: "arrow.up.to.line",
                body: "Too far to kick a field goal? Punt. You give the ball up, but they have to start way back. Tap in the green for a long one.",
                category: .scoring, unlockHint: "Punt the ball."),
        Concept(id: "missedFG", title: "Missed Field Goal", symbol: "target",
                body: "Missed. No points, and they take over where the kick was attempted. Long kicks are a gamble, and that's the downside.",
                category: .scoring, unlockHint: "Miss a field goal."),

        // Turnovers
        Concept(id: "interception", title: "Interception", symbol: "hand.raised.fill",
                body: "A defender caught your pass. Turnover: their ball, right there. Throwing into tight coverage is how this happens.",
                category: .turnovers, unlockHint: "Throw an interception."),
        Concept(id: "fumble", title: "Fumble", symbol: "football.fill",
                body: "The ball popped loose and they fell on it. Turnover. It's rare, it's bad luck, and it's not on you.",
                category: .turnovers, unlockHint: "Lose a fumble."),
        Concept(id: "turnoverOnDowns", title: "Turnover on Downs", symbol: "arrow.uturn.backward",
                body: "You went for it on fourth and came up short, so they take over right there. That's the price of being bold. Sometimes it's worth paying.",
                category: .turnovers, unlockHint: "Fail a 4th-down attempt."),

        // Strategy
        Concept(id: "redZone", title: "The Red Zone", symbol: "flame.fill",
                body: "Inside their 20 is the red zone. Scoring is likely now, but the field is cramped and long routes run out of room. Runs and quick throws are your friends here.",
                category: .strategy, unlockHint: "Get inside their 20."),
        Concept(id: "clutchFG", title: "Down by 3 or Less", symbol: "scope",
                body: "Down by three or less. A field goal ties or wins it, so you don't need the end zone. Play it safe and just get into kicking range.",
                category: .strategy, unlockHint: "Trail by 1 to 3 in the 4th quarter."),
        Concept(id: "clutchTD", title: "You Need a Touchdown", symbol: "bolt.fill",
                body: "Down by four to eight? Three points won't do it. Only a touchdown gets you there, so be bold. Go for it on fourth down.",
                category: .strategy, unlockHint: "Trail by 4 to 8 in the 4th quarter."),
        Concept(id: "twoScores", title: "Two-Score Game", symbol: "2.circle",
                body: "Down by more than eight. Even a touchdown won't catch you up on this drive. When the TV says \"two-score game,\" this is what they mean.",
                category: .strategy, unlockHint: "Trail by 9 or more in the 4th quarter."),
        Concept(id: "protectLead", title: "Protect the Lead", symbol: "lock.fill",
                body: "You're ahead in the fourth. They need the ball back to catch you, so don't give it to them. Run it, keep throws short, punt on fourth.",
                category: .strategy, unlockHint: "Lead in the 4th quarter."),
        Concept(id: "defenseCalls", title: "Calling the Defense", symbol: "rectangle.grid.2x2.fill",
                body: "Calling the defense is rock-paper-scissors. Stack the box to stop runs. Play the pass to stop throws. Blitz to gamble on a sack. Guess what they'll do and line up against it.",
                category: .strategy, unlockHint: "Make your first defensive call."),
    ]
}
