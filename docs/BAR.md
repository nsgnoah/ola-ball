# The Bar

What "good" means for Ola Ball. Concrete, inspectable. Critics judge against this; builders build toward it. Refine it, never lower it.

## The one-sentence test
A 35-year-old who has never learned football should be able to pick up the phone, play one game without reading anything longer than two sentences, understand what a first down and a field goal are by the end, and want to play again.

## Feel
- A play takes 6 to 9 seconds from pre-snap to result banner. A full game takes 5 to 7 minutes. Time it in the UI test log.
- Zero "Next" taps to keep a drive moving: after a result, the next pre-snap appears automatically (tap-to-skip allowed).
- The drawn path visibly matters. Test: running into the side with 4+ defenders should gain under 3 yards on average; running into a gap with 0 or 1 defender should average 5+ yards. Throwing to a receiver with 3+ yards of separation completes 85%+; under 1 yard completes under 35%. Write these as unit tests over 300 seeded plays each.
- Touchdowns: confetti, heavy haptic, the scoreboard number animates, the camera holds on the end zone for a beat.
- Bad outcomes never feel like a scolding. Every "why" line names something the player can do differently next time, in plain words.

## Look (compare against the latest screenshots in the UI test output)
- The 3D field reads as a football field at a glance: green turf with visible yard lines and numbers, two colored end zones, goalposts, a blue line of scrimmage and a yellow first-down line.
- Players are clearly two teams (team colors), clearly facing each other, and the offense's eligible players have a visible glowing ring. Labels (QB, RB, WR, CB, S...) are legible on an iPhone 16 Pro screenshot.
- Camera: behind and above the offense, slightly tilted, looking downfield. You can see the whole box and both safeties before the snap. During the play it follows the ball smoothly.
- No text is clipped or truncated. Nothing overlaps. Every screen has one obvious primary action.
- Dark theme, one gold accent, rounded typography. No default-system-looking white screens anywhere.

## Learning
- Coach's Tips: 2 to 3 sentences, plain words, no jargon that hasn't been defined. One at a time. At most 8 new tips per game. Every Playbook entry is reachable (unit test).
- Every position label the player sees is explained by a tip the first time it matters (QB and RB in game one; CB, S, LB when a tip about reading the defense fires).
- After game one the player has been told, in-context: what a down is, what "2nd & 7" means, what the box is, what a safety does, what a field goal is worth.

## Correctness
- Downs, distance, goal-to-go, touchbacks, field goal distance (+17), overtime: the rules unit tests pass.
- No crashes in a 5-game UI soak run.
- Progress persists across launches; "Reset progress" wipes everything.

## App Store
- No accounts, no network, no permissions, no third-party SDKs, no real teams or league names. Privacy manifest accurate. Icon has no alpha. Supports only portrait iPhone.
