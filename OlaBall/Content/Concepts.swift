import Foundation

/// A single Playbook entry. Taught in-context by a Coach's Tip, then collected in the Playbook.
struct Concept: Identifiable, Hashable {
    enum Category: String, CaseIterable {
        case basics = "The Basics"
        case downs = "Downs"
        case plays = "Play Calls"
        case scoring = "Scoring"
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
        Concept(id: "downs", title: "The Goal & Four Tries", symbol: "flag.checkered",
                body: "Move the ball into the far end zone for a touchdown. You get 4 plays, called downs, to gain 10 yards. Make it and you get 4 more. Fall short and the other team takes over.",
                category: .basics, unlockHint: "Play your first snap."),
        Concept(id: "defense", title: "Now You're on Defense", symbol: "shield.lefthalf.filled",
                body: "The other team has the ball and is driving toward YOUR end zone on the left. Your defense's job is to stop them within 4 downs. Sit back and watch how their drive goes.",
                category: .basics, unlockHint: "Finish your first drive."),
        Concept(id: "kickoff", title: "Kickoff & the 25", symbol: "arrow.up.forward",
                body: "After a score, the other team gets the ball back with a kickoff. Usually the returner kneels in the end zone, called a touchback, and the drive starts at the 25-yard line.",
                category: .basics, unlockHint: "Score, or get scored on."),
        Concept(id: "quarters", title: "Four Quarters", symbol: "clock",
                body: "A game has four quarters. In Ola Ball, each team gets one drive per quarter. Halftime comes after the 2nd. Real games run a clock, but the rhythm is the same: take turns.",
                category: .basics, unlockHint: "Reach the 2nd quarter."),
        Concept(id: "midfield", title: "Midfield", symbol: "circle.and.line.horizontal",
                body: "The 50-yard line splits the field in half. Cross it and you're in the other team's territory. From here, every yard is a yard closer to points.",
                category: .basics, unlockHint: "Cross the 50-yard line."),
        Concept(id: "overtime", title: "Overtime", symbol: "arrow.clockwise",
                body: "Tied after four quarters? Each team gets one more drive. Still tied? Do it again.",
                category: .basics, unlockHint: "Finish regulation tied."),

        // Downs
        Concept(id: "notation", title: "Reading \"2nd & 7\"", symbol: "textformat.123",
                body: "The first number is which try you're on. The second is how many yards you still need. \"2nd & 7\" means it's your second try and you need 7 more yards for a fresh set of downs.",
                category: .downs, unlockHint: "Reach 2nd down."),
        Concept(id: "thirdDown", title: "Third Down: Money Down", symbol: "3.circle.fill",
                body: "This is the big one. Gain the distance now and you keep the ball. Miss, and you'll face a tough decision on 4th down.",
                category: .downs, unlockHint: "Reach 3rd down."),
        Concept(id: "fourthDown", title: "Fourth Down: Decision Time", symbol: "4.circle.fill",
                body: "Last try. Go for it (risky: fail and the other team gets the ball right here), punt it away (safe: they get the ball, but far from your end zone), or kick a field goal if you're close enough.",
                category: .downs, unlockHint: "Reach 4th down."),
        Concept(id: "firstDown", title: "First Down!", symbol: "checkmark.seal.fill",
                body: "You gained the 10 yards. Fresh set of 4 downs! The yellow line on the field shows where you need to get for the next one.",
                category: .downs, unlockHint: "Earn a first down."),
        Concept(id: "goalToGo", title: "\"& Goal\"", symbol: "flag.fill",
                body: "When you're within 10 yards of the end zone there's no first-down line anymore. \"1st & Goal\" means the only way forward is a touchdown.",
                category: .downs, unlockHint: "Get inside the 10."),

        // Plays
        Concept(id: "runPlay", title: "Run vs. Pass", symbol: "arrow.triangle.branch",
                body: "A run: the quarterback hands the ball to a runner. Steady and safe, usually 3 to 5 yards. A pass: the quarterback throws it. Bigger gains, but throws can miss or get caught by the wrong team.",
                category: .plays, unlockHint: "Call your second play."),
        Concept(id: "incomplete", title: "Incomplete", symbol: "xmark.circle",
                body: "The pass hit the ground before anyone caught it. Nobody gains or loses yards, but you used up a down.",
                category: .plays, unlockHint: "Throw an incomplete pass."),
        Concept(id: "sack", title: "Sacked!", symbol: "exclamationmark.triangle.fill",
                body: "The defense tackled your quarterback before he could throw. That's a sack, and you lose the yards. Deep passes take longer to develop, so they get sacked more.",
                category: .plays, unlockHint: "Get sacked."),
        Concept(id: "punt", title: "Flipping the Field", symbol: "arrow.left.arrow.right",
                body: "Where the other team starts matters. Making them travel 80 yards to score is far safer than 30. A punt trades the ball for distance, which is why coaches punt on 4th down when they're far away.",
                category: .plays, unlockHint: "Punt the ball."),

        // Scoring
        Concept(id: "touchdown", title: "Touchdown: 6 (+1)", symbol: "star.fill",
                body: "You made it! A touchdown is 6 points. Then you kick a short extra point for 1 more, so most touchdowns are worth 7.",
                category: .scoring, unlockHint: "Score a touchdown."),
        Concept(id: "fieldGoal", title: "Field Goal: 3 Points", symbol: "target",
                body: "Close enough? Your kicker can boot the ball through the goalposts for 3 points. Kick distance is yards to the end zone plus 17. Under 40 is pretty safe. Over 50 is a coin flip.",
                category: .scoring, unlockHint: "Reach 4th down in kicking range."),
        Concept(id: "missedFG", title: "Missed Field Goal", symbol: "target",
                body: "No points, and the other team takes over where the kick was attempted. Long kicks are a gamble, and this is the downside.",
                category: .scoring, unlockHint: "Miss a field goal."),

        // Turnovers
        Concept(id: "interception", title: "Interception", symbol: "hand.raised.fill",
                body: "A defender caught your pass. That's a turnover: the other team gets the ball right there. The riskier the throw, the more often this happens.",
                category: .turnovers, unlockHint: "Throw an interception."),
        Concept(id: "fumble", title: "Fumble", symbol: "football.fill",
                body: "The ball carrier dropped it and the defense pounced. Turnover. It's rare, but it can happen on any play.",
                category: .turnovers, unlockHint: "Lose a fumble."),
        Concept(id: "turnoverOnDowns", title: "Turnover on Downs", symbol: "arrow.uturn.backward",
                body: "You went for it on 4th down and came up short. The other team takes over right there. That's why going for it near your own end zone is so dangerous.",
                category: .turnovers, unlockHint: "Fail a 4th-down attempt."),

        // Strategy
        Concept(id: "redZone", title: "The Red Zone", symbol: "flame.fill",
                body: "Inside the other team's 20. Scoring is likely now, but the field is cramped, so deep passes stop working. Runs and short passes shine here.",
                category: .strategy, unlockHint: "Get inside their 20."),
        Concept(id: "backedUp", title: "Backed Up", symbol: "arrow.left.to.line",
                body: "You're inside your own 10. Careful: a sack or fumble here is a disaster. Coaches call safe runs to get some breathing room.",
                category: .strategy, unlockHint: "Start a drive inside your own 10."),
        Concept(id: "clutchFG", title: "Down by 3 or Less", symbol: "scope",
                body: "A field goal ties or wins it. You don't need a touchdown, so play safe and just get into kicking range.",
                category: .strategy, unlockHint: "Trail by 1 to 3 in the 4th quarter."),
        Concept(id: "clutchTD", title: "You Need a Touchdown", symbol: "bolt.fill",
                body: "Down by 4 to 8? A field goal (3) isn't enough. Only a touchdown (7) gets you there. Be aggressive, and go for it on 4th down.",
                category: .strategy, unlockHint: "Trail by 4 to 8 in the 4th quarter."),
        Concept(id: "twoScores", title: "Two-Score Game", symbol: "2.circle",
                body: "Trailing by more than 8? Even a touchdown won't catch you up on one drive. When you hear \"two-score game,\" this is what it means.",
                category: .strategy, unlockHint: "Trail by 9 or more in the 4th quarter."),
        Concept(id: "protectLead", title: "Protect the Lead", symbol: "lock.fill",
                body: "You're ahead in the 4th. The other team needs the ball back to score, so don't give it to them. Run the ball, avoid turnovers, and punt on 4th down.",
                category: .strategy, unlockHint: "Lead in the 4th quarter."),
    ]
}
