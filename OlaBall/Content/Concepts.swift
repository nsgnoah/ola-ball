import Foundation

/// A single Playbook entry. Taught in-context by a Coach's Tip, then collected in the Playbook.
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
                body: "Move the ball into the far end zone for a touchdown. You get 4 plays, called downs, to gain 10 yards. Make it and you get 4 more. Fall short and the other team takes over.",
                category: .basics, unlockHint: "Start your first game."),
        Concept(id: "drawThePlay", title: "Draw the Play", symbol: "hand.draw.fill",
                body: "The players with a glowing ring can get the ball. Drag from one of them to draw where they should run. Let go, and the ball is snapped. Where you draw is where they go.",
                category: .basics, unlockHint: "Line up for your first play."),
        Concept(id: "defense", title: "Now You're on Defense", symbol: "shield.lefthalf.filled",
                body: "The other team has the ball. Pick how your defense lines up, then watch. Stop them within 4 downs and you get the ball back.",
                category: .basics, unlockHint: "Finish your first drive."),
        Concept(id: "kickoff", title: "Kickoff & the 25", symbol: "arrow.up.forward",
                body: "After a score, the other team gets the ball back with a kickoff. Usually the returner kneels in the end zone, called a touchback, and the drive starts at the 25-yard line.",
                category: .basics, unlockHint: "Score, or get scored on."),
        Concept(id: "quarters", title: "Four Quarters", symbol: "clock",
                body: "A game has four quarters. In Ola Ball each team gets one drive per quarter. Halftime comes after the 2nd.",
                category: .basics, unlockHint: "Reach the 2nd quarter."),
        Concept(id: "sideline", title: "Out of Bounds", symbol: "arrow.left.to.line",
                body: "The white lines on the sides are the sidelines. Step over one and the play is over right there. Running toward the sideline is safe, but it's also a dead end.",
                category: .basics, unlockHint: "Run out of bounds."),
        Concept(id: "overtime", title: "Overtime", symbol: "arrow.clockwise",
                body: "Tied after four quarters? Each team gets one more drive. Still tied? Do it again.",
                category: .basics, unlockHint: "Finish regulation tied."),

        // Reading the defense
        Concept(id: "theBox", title: "The Box", symbol: "rectangle.stack.fill",
                body: "The box is the area right in front of the ball where the big guys stand. Count the defenders in it. 8 in the box means they expect a run, and there's less help deep. That's when you throw.",
                category: .reading, unlockHint: "Face a stacked box."),
        Concept(id: "safeties", title: "Safeties: the Deep Help", symbol: "umbrella.fill",
                body: "The two defenders way in the back are safeties. They stop long passes. When both are deep, throws downfield are risky, but there are fewer bodies near the line, so runs work.",
                category: .reading, unlockHint: "Face two safeties deep."),
        Concept(id: "cornerbacks", title: "Cornerbacks", symbol: "person.2.fill",
                body: "The defenders lined up across from your wide receivers are cornerbacks. Each one shadows a receiver. A sharp cut in your route makes them a step late, and a step is all you need.",
                category: .reading, unlockHint: "Draw a route for a wide receiver."),
        Concept(id: "blitz", title: "The Blitz", symbol: "bolt.fill",
                body: "A blitz sends extra defenders after the quarterback. Long routes get you sacked. Beat it with a quick, short throw, or a run away from where they're coming.",
                category: .reading, unlockHint: "Face a blitz."),
        Concept(id: "gaps", title: "Gaps: Run Where They Aren't", symbol: "arrow.triangle.branch",
                body: "Your blockers can only hold so many defenders. Look at the line before the snap and draw the run through the side with fewer bodies. Fewer defenders at the point of attack means more yards.",
                category: .reading, unlockHint: "Call your first run."),
        Concept(id: "linemen", title: "Blockers vs. Rushers", symbol: "figure.stand.line.dotted.figure.stand",
                body: "The five big guys in front of the quarterback are the offensive line. They block. The defenders across from them try to get past. Blocks hold for a couple of seconds, so slow plays get caught.",
                category: .reading, unlockHint: "Call a pass play."),

        // Plays
        Concept(id: "runPlay", title: "The Run", symbol: "figure.run",
                body: "Drag from the running back to hand him the ball. Runs are steady and safe. Aim for daylight, then keep going straight.",
                category: .plays, unlockHint: "Call a run."),
        Concept(id: "passPlay", title: "The Pass", symbol: "arrow.up.right",
                body: "Drag from a receiver to draw his route. The quarterback throws when the receiver finishes the route. Short routes are quick and safe. Long ones are slow and risky, but big.",
                category: .plays, unlockHint: "Throw a pass."),
        Concept(id: "separation", title: "Separation", symbol: "arrow.left.and.right",
                body: "How far the receiver is from the nearest defender when the ball arrives. Three yards of separation is an easy catch. Less than one is a coin flip, and a good way to throw an interception.",
                category: .plays, unlockHint: "Complete a pass."),
        Concept(id: "incomplete", title: "Incomplete", symbol: "xmark.circle",
                body: "The pass hit the ground. No yards lost, but you used up a down.",
                category: .plays, unlockHint: "Throw an incomplete pass."),
        Concept(id: "sack", title: "Sacked!", symbol: "exclamationmark.triangle.fill",
                body: "A defender reached the quarterback before he could throw. That's a sack, and it costs yards. The longer the route, the longer the quarterback waits, the more this happens.",
                category: .plays, unlockHint: "Get sacked."),
        Concept(id: "keeper", title: "The Quarterback Keeper", symbol: "figure.walk",
                body: "Drag from the quarterback and he runs it himself. The defense doesn't expect it. Great near the goal line, dangerous if he gets hit.",
                category: .plays, unlockHint: "Run with the quarterback."),

        // Downs
        Concept(id: "notation", title: "Reading \"2nd & 7\"", symbol: "textformat.123",
                body: "The first number is which try you're on. The second is how many yards you still need. \"2nd & 7\" means it's your second try and you need 7 more yards to earn a fresh set of downs.",
                category: .downs, unlockHint: "Reach 2nd down."),
        Concept(id: "firstDown", title: "First Down!", symbol: "checkmark.seal.fill",
                body: "You crossed the yellow line. Fresh set of 4 downs, and the yellow line moves 10 yards ahead.",
                category: .downs, unlockHint: "Earn a first down."),
        Concept(id: "thirdDown", title: "Third Down: Money Down", symbol: "3.circle.fill",
                body: "This is the big one. Make the distance now and you keep the ball. Miss, and it's a tough decision on 4th down.",
                category: .downs, unlockHint: "Reach 3rd down."),
        Concept(id: "fourthDown", title: "Fourth Down: Decision Time", symbol: "4.circle.fill",
                body: "Last try. Draw a play to go for it (fail and they get the ball right here), punt it away (safe), or kick a field goal if you're close enough.",
                category: .downs, unlockHint: "Reach 4th down."),
        Concept(id: "goalToGo", title: "\"& Goal\"", symbol: "flag.fill",
                body: "Within 10 yards of the end zone there's no yellow line anymore. \"1st & Goal\" means the only way forward is a touchdown.",
                category: .downs, unlockHint: "Get inside the 10."),

        // Scoring & kicking
        Concept(id: "touchdown", title: "Touchdown: 6 (+1)", symbol: "star.fill",
                body: "You made it! A touchdown is 6 points. Then you kick a short extra point for 1 more, so most touchdowns are worth 7.",
                category: .scoring, unlockHint: "Score a touchdown."),
        Concept(id: "fieldGoal", title: "Field Goal: 3 Points", symbol: "target",
                body: "Close enough? Kick the ball through the goalposts for 3 points. Tap when the needle is in the green. Kick distance is yards to the end zone plus 17, and the green zone shrinks as the kick gets longer.",
                category: .scoring, unlockHint: "Reach 4th down in kicking range."),
        Concept(id: "punt", title: "The Punt", symbol: "arrow.up.to.line",
                body: "Too far to kick a field goal? Punt it. You give up the ball, but the other team has to start way back. Tap in the green for a longer punt.",
                category: .scoring, unlockHint: "Punt the ball."),
        Concept(id: "missedFG", title: "Missed Field Goal", symbol: "target",
                body: "No points, and the other team takes over where the kick was attempted. Long kicks are a gamble.",
                category: .scoring, unlockHint: "Miss a field goal."),

        // Turnovers
        Concept(id: "interception", title: "Interception", symbol: "hand.raised.fill",
                body: "A defender caught your pass. It's a turnover: the other team gets the ball right there. Throwing into tight coverage is how this happens.",
                category: .turnovers, unlockHint: "Throw an interception."),
        Concept(id: "fumble", title: "Fumble", symbol: "football.fill",
                body: "The ball carrier dropped it and the defense pounced. Turnover. It's rare, but it can happen on any hit.",
                category: .turnovers, unlockHint: "Lose a fumble."),
        Concept(id: "turnoverOnDowns", title: "Turnover on Downs", symbol: "arrow.uturn.backward",
                body: "You went for it on 4th down and came up short. The other team takes over right there.",
                category: .turnovers, unlockHint: "Fail a 4th-down attempt."),

        // Strategy
        Concept(id: "redZone", title: "The Red Zone", symbol: "flame.fill",
                body: "Inside the other team's 20. Scoring is likely, but the field is cramped and deep routes run out of room. Runs and quick throws shine here.",
                category: .strategy, unlockHint: "Get inside their 20."),
        Concept(id: "clutchFG", title: "Down by 3 or Less", symbol: "scope",
                body: "A field goal ties or wins it. You don't need a touchdown, so play safe and just get into kicking range.",
                category: .strategy, unlockHint: "Trail by 1 to 3 in the 4th quarter."),
        Concept(id: "clutchTD", title: "You Need a Touchdown", symbol: "bolt.fill",
                body: "Down by 4 to 8? A field goal (3) isn't enough. Only a touchdown (7) gets you there. Be aggressive, and go for it on 4th down.",
                category: .strategy, unlockHint: "Trail by 4 to 8 in the 4th quarter."),
        Concept(id: "twoScores", title: "Two-Score Game", symbol: "2.circle",
                body: "Trailing by more than 8? Even a touchdown won't catch you up on one drive. That's what \"two-score game\" means.",
                category: .strategy, unlockHint: "Trail by 9 or more in the 4th quarter."),
        Concept(id: "protectLead", title: "Protect the Lead", symbol: "lock.fill",
                body: "You're ahead in the 4th. Don't give the ball away: run it, keep throws short, and punt on 4th down.",
                category: .strategy, unlockHint: "Lead in the 4th quarter."),
        Concept(id: "defenseCalls", title: "Calling the Defense", symbol: "rectangle.grid.2x2.fill",
                body: "Stack the box to stop runs. Play the pass to stop throws. Blitz to gamble on a sack. It's rock-paper-scissors: guess what they'll do and line up against it.",
                category: .strategy, unlockHint: "Make your first defensive call."),
    ]
}
