# Ola — Status / Handoff

_Updated: 2026-09-19 17:00 CDT_

## What this is now
A couples trivia game: His World vs Her World. Each player declares the world they know; the challenger picks the deck their partner is quizzed on each round; five rounds, escalating difficulty, first to three crowns. Async over Game Center turn-based matches, or pass-and-play on one phone. Pivoted from the 3D football game on 2026-09-19 (that build is tagged `v1-football-draw-the-play`).

## Done
- **Couples mode**: your couple vs another couple. Each member has a lane (the world they answer, default their own); the other couple picks a deck per member; team scores add up. One phone per couple over Game Center (the challenged phone sets up its two people before joining) or four people on one phone. Unit-tested and UI-tested end to end.
- Content: 12 decks, 432 questions, 3 tiers each, with a unit test that checks structure and uniqueness.
- Engine: deterministic question draw from the match seed, time/streak scoring, tier escalation, crown logic, JSON match state.
- Pass-and-play end to end; Game Center service and transport (sign-in, match list, matchmaker, turn events, submit, rematch).
- Screens: profile setup, home with both match lists, deck pick, question play with timer, round reveal, match over, hand-off.
- Front end rebuilt in a game register (Trivia Crack-like): striped world-colored backgrounds, chunky 3D buttons, a drawn mascot per deck with moods, a spin wheel for picks, countdown ring, confetti and shake feedback. New icon.

## Fixed during the first live walkthrough
- Pass-and-play hand-off named the wrong player (the transport's active player flips on submit; the name is now captured first).
- Opening a pass-and-play match from home now shows the hand-off screen first, so the wrong person never sees the questions.
- Revealed answer rows were dimmed by `.disabled`; they now use `allowsHitTesting`.
- Match rows had a `.contextMenu`, which swallowed XCUITest taps; replaced with a trash button on finished matches.
- Test seeding moved out of `App.init` (stores were created before the seed was written) into a one-time static flag.
- Matches present as full-screen covers rather than navigation pushes.

## Not yet verified
- Game Center on a real device (needs a sandbox Apple ID on the simulator or a device with Game Center signed in). All Game Center code paths are unexercised by tests.
- Audio levels (no audio in the simulator here).

## Next
1. Play a Game Center match between two devices; fix whatever the first real turn reveals.
2. Turn notifications copy (Game Center's default push text is generic).
3. More decks per world (music, travel, cooking, fitness) and a "wildcard" deck both sides can pick.
4. Stats: lifetime record vs partner, favorite deck, hardest question.
