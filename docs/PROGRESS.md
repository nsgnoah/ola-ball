# Progress

Live log of build rounds, newest first. One entry per round: what was built, what the critic said, what changed.

## 2026-09-18 (late night, lead session)
- Rejected the menu-driven prototype (tagged `v0-menu-prototype`) as too close to the old app.
- Started the 3D "Draw the Play" build: field geometry, formations, tick-based play simulation (`PlaySim`), AI playcaller, post-play analyst, SceneKit field scene, draw-gesture host view, kick meter.
- Next: new `GameSession` flow, new `GameView`, rewritten Coach's Tips, tests, first build.

## 2026-09-19 03:30 (lead session, after usage-limit reset)
- 3D build now compiles and completes a full autoplay game (185 s) in the simulator. Crash on game start fixed (a recursive UIColor initializer).
- Built a swiftc command-line balance harness (`build/simlab/main.swift`) to tune the sim without Xcode:
  `swiftc -O -o build/simlab/simlab build/simlab/main.swift OlaBall/Sim/*.swift OlaBall/Engine/SeededRNG.swift OlaBall/Engine/RulesEngine.swift OlaBall/Models/Play.swift OlaBall/Models/Situation.swift OlaBall/Models/PlayCall.swift`
- Found and fixed: receivers sprinting past the ball (now run to the landing spot); throws now lead the receiver to where they'll be; defenders stop aiming at a lead point once within 3 yd. Overshot: runs now ~0 yd; tuning continues.
- Graphics builder relaunched (first attempt died on the usage limit). Overnight scheduled task moved to 08:30 so it gets a fresh usage window.
