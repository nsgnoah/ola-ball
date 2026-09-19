# Progress

Live log of build rounds, newest first. One entry per round: what was built, what the critic said, what changed.

## 2026-09-19 08:38 (autonomous overnight session)
- Confirmed build compiles, 29 GB disk free. Ran the simlab balance harness cold against the uncommitted PlaySim tuning from the previous session:
  runs 1.0-2.0 yd (no gap-vs-crowd differentiation, BAR wants <3 crowd / 5+ gap), "X go vs blitz" sacked 81% of the time, interceptions up to 21% on some routes.
- Round 1, two parallel builders on disjoint files (Sim/ vs Scene/+Views/), no file conflicts:
  1. **Play balance builder** — root-causing and fixing PlaySim.swift pursuit/coverage/pressure logic against the simlab harness and BAR's numeric targets (gap vs crowd rushing yards, separation-gated completion %, blitz sack rate, interception rate).
  2. **Graphics builder** — rebuilding OlaBall/Scene/FieldScene.swift player models and field texture off the "slop" capsule-body look, plus fixing the presnap camera/HUD overlap bug that fails testDrawGestureStartsAPlay.
- Next: read both builders' reports, run a critic pass against fresh screenshots/harness output, then continue the Gauntlet Loop on the next-highest-impact pieces (pre-snap defense callout, post-play "why" lines, kick meter, onboarding).
- Rejected the menu-driven prototype (tagged `v0-menu-prototype`) as too close to the old app.
- Started the 3D "Draw the Play" build: field geometry, formations, tick-based play simulation (`PlaySim`), AI playcaller, post-play analyst, SceneKit field scene, draw-gesture host view, kick meter.
- Next: new `GameSession` flow, new `GameView`, rewritten Coach's Tips, tests, first build.

## 2026-09-19 03:30 (lead session, after usage-limit reset)
- 3D build now compiles and completes a full autoplay game (185 s) in the simulator. Crash on game start fixed (a recursive UIColor initializer).
- Built a swiftc command-line balance harness (`build/simlab/main.swift`) to tune the sim without Xcode:
  `swiftc -O -o build/simlab/simlab build/simlab/main.swift OlaBall/Sim/*.swift OlaBall/Engine/SeededRNG.swift OlaBall/Engine/RulesEngine.swift OlaBall/Models/Play.swift OlaBall/Models/Situation.swift OlaBall/Models/PlayCall.swift`
- Found and fixed: receivers sprinting past the ball (now run to the landing spot); throws now lead the receiver to where they'll be; defenders stop aiming at a lead point once within 3 yd. Overshot: runs now ~0 yd; tuning continues.
- Graphics builder relaunched (first attempt died on the usage limit). Overnight scheduled task moved to 08:30 so it gets a fresh usage window.

## 2026-09-19 08:50 (original lead session, handing off)
- The overnight session started at 04:25 while this session was still alive (its clock had drifted ~5 h behind under rate limiting), so for a while two leads and three builders were editing `OlaBall/Sim/PlaySim.swift` and `OlaBall/Scene/FieldScene.swift` concurrently. This session has now STOPPED editing and stopped its own graphics builder. The overnight session owns the repo from here.
- Last changes this session made to `PlaySim.swift` (all uncommitted, verify they survived): second-level run blocking (tight end and play-side lineman `climbing` to the linebackers nearest the point of attack, assigned by proximity, combo-block handoff); blitzers left to the TE/RB with short holds instead of being picked up by linemen; a 0.35 s throw wind-up (`throwDecisionTime`) so pressure can become a sack; cornerback hip-flip penalty after a sharp cut; receiver runs to the ball once thrown; open-at-throw credit for separation. Harness before handoff: gap run 4.9 yd vs crowd run 1.4 yd; slant 84% caught; go routes ~40%; blitz sacks still 0 because the QB's pressure threshold kept getting rid of the ball (was tuning `mustThrow` distance when the overlap was discovered).
- `OlaBall/Views/GameView.swift`: the pre-snap situation pill and info panel now `allowsHitTesting(false)` so drags reach the QB/RB.
- `OlaBallTests/EngineTests.swift`: balance tests updated to BAR targets (gap ≥ 5 & crowd < 3 on stackTheBox with the +6 crowd path; blitz sacks ≥ 40/200 on a go route; new `quickSlantBeatsTheBlitz`). These may fail until the sim is tuned; do not lower them.
- `build/simlab/run.sh [lab|debug]` compiles and runs the harness; `build/simlab/main.swift` also gained BAR completion-by-separation checks from the other session.

## 2026-09-19 09:05 (original lead session, live with Noah)
- Noah's verdict on the first graphics pass: "AI slop"; he wants truly beautiful graphics. The original lead session now OWNS `OlaBall/Scene/` and `OlaBall/Views/GameView.swift` and is building a new renderer under `OlaBall/Scene/Stadium/` (stylized night game under lights: articulated players with run cycles and jersey numbers, stadium bowl and light towers, generated grass, bloom/vignette/depth of field, cinematic camera with slow-motion on big plays, particles). Overnight session: hands off those paths.
- Checkpoint commit of everything in the working tree as of 09:05 so no in-flight work can be lost.
