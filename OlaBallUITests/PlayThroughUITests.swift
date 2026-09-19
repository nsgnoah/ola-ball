import XCTest

/// Plays a full game end-to-end (the session autoplays the user's calls) and saves screenshots to $OLABALL_SHOTS.
final class PlayThroughUITests: XCTestCase {
    private var shotDir: String? { ProcessInfo.processInfo.environment["OLABALL_SHOTS"] }

    private func snap(_ app: XCUIApplication, _ name: String) {
        guard let shotDir else { return }
        let png = app.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: shotDir).appendingPathComponent("\(name).png"))
    }

    func testFullGameAutoplay() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset", "-ui-testing-autoplay"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Ola Ball"].waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Mallards'")).firstMatch.tap()
        snap(app, "01-teampick")
        app.buttons["Let's go"].tap()
        XCTAssertTrue(app.buttons["Play a Game"].waitForExistence(timeout: 5))
        snap(app, "02-home")
        app.buttons["Play a Game"].tap()

        let start = Date()
        var shots: Set<String> = []
        var ticks = 0
        while ticks < 900 {   // up to ~7.5 minutes
            ticks += 1
            if app.buttons["Play again"].exists { snap(app, "09-game-over"); break }
            if !shots.contains("presnap") && app.staticTexts["draw-hint"].exists { snap(app, "03-presnap"); shots.insert("presnap") }
            if !shots.contains("live") && app.staticTexts["LIVE"].exists { snap(app, "04-live"); shots.insert("live") }
            if !shots.contains("result") && app.staticTexts["result-headline"].exists { snap(app, "05-result"); shots.insert("result") }
            if !shots.contains("driveover") && app.otherElements["drive-over"].exists { snap(app, "06-drive-over"); shots.insert("driveover") }
            if !shots.contains("defense") && app.staticTexts["YOUR DEFENSE"].exists && app.staticTexts["LIVE"].exists == false { snap(app, "07-defense-live"); shots.insert("defense") }
            if ticks % 40 == 0 { snap(app, "mid-\(ticks / 40)") }
            usleep(500_000)
        }
        let elapsed = Date().timeIntervalSince(start)
        print("OLABALL game length: \(Int(elapsed)) s")
        XCTAssertTrue(app.buttons["Play again"].waitForExistence(timeout: 5), "Game never reached the final screen")
        app.buttons["Back to home"].tap()
        XCTAssertTrue(app.buttons["Play a Game"].waitForExistence(timeout: 15))
        snap(app, "08-home-after-game")
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Playbook'")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["The Goal & Four Tries"].waitForExistence(timeout: 5))
        snap(app, "10-playbook")
    }

    func testDrawGestureStartsAPlay() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset"]
        app.launch()
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Dragons'")).firstMatch.tap()
        app.buttons["Let's go"].tap()
        app.buttons["Play a Game"].tap()
        XCTAssertTrue(app.staticTexts["draw-hint"].waitForExistence(timeout: 8))
        snap(app, "11-presnap-manual")
        // Dismiss any tip so the field is unobstructed, then drag from the backfield straight upfield.
        if app.buttons["dismiss-tip"].exists { app.buttons["dismiss-tip"].tap() }
        let window = app.windows.firstMatch
        let from = window.coordinate(withNormalizedOffset: CGVector(dx: 0.645, dy: 0.645))
        let to = window.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.34))
        from.press(forDuration: 0.1, thenDragTo: to)
        let live = app.staticTexts["LIVE"].waitForExistence(timeout: 3)
        snap(app, "12-after-drag")
        XCTAssertTrue(live || app.staticTexts["result-headline"].waitForExistence(timeout: 8), "Drag did not start a play")
        snap(app, "13-manual-result")
    }
}
