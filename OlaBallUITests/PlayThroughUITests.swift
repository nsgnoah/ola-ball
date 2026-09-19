import XCTest

/// Plays a full game end-to-end through the real UI and saves screenshots to $OLABALL_SHOTS (if set).
final class PlayThroughUITests: XCTestCase {
    private var shotDir: String? { ProcessInfo.processInfo.environment["OLABALL_SHOTS"] }

    private func snap(_ app: XCUIApplication, _ name: String) {
        guard let shotDir else { return }
        let png = app.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: shotDir).appendingPathComponent("\(name).png"))
    }

    func testFullGame() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset"]
        app.launch()

        // Team pick
        XCTAssertTrue(app.staticTexts["Ola Ball"].waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Mallards'")).firstMatch.tap()
        snap(app, "01-teampick")
        app.buttons["Let's go"].tap()

        // Home
        XCTAssertTrue(app.buttons["Play a Game"].waitForExistence(timeout: 5))
        snap(app, "02-home")
        app.buttons["Play a Game"].tap()

        XCTAssertTrue(app.staticTexts["What's the call, coach?"].waitForExistence(timeout: 5)
                      || app.staticTexts["4th down. What's the call, coach?"].exists)
        snap(app, "03-first-snap")

        var shotsTaken: Set<String> = []
        var taps = 0
        while taps < 400 {
            taps += 1
            if app.staticTexts["YOU WIN!"].exists || app.staticTexts["Tough loss"].exists || app.staticTexts["Tie game"].exists {
                snap(app, "09-game-over")
                break
            }
            if app.buttons["Next play"].exists && app.buttons["Skip to result"].exists {
                if !shotsTaken.contains("opp") { snap(app, "06-opponent-drive"); shotsTaken.insert("opp") }
                app.buttons["Next play"].tap()
                continue
            }
            if app.buttons["Your ball"].exists {
                app.buttons["Your ball"].tap(); continue
            }
            if app.buttons["Next play"].exists {
                if !shotsTaken.contains("result") { snap(app, "04-play-result"); shotsTaken.insert("result") }
                app.buttons["Next play"].tap(); continue
            }
            if app.buttons["Continue"].exists {
                if !shotsTaken.contains("driveEnd") { snap(app, "05-drive-result"); shotsTaken.insert("driveEnd") }
                app.buttons["Continue"].tap(); continue
            }
            if app.buttons["Now the other team's turn"].exists {
                app.buttons["Now the other team's turn"].tap(); continue
            }
            if app.buttons["Field Goal"].exists {
                if !shotsTaken.contains("fourth") { snap(app, "07-fourth-down"); shotsTaken.insert("fourth") }
                app.buttons["Field Goal"].tap(); continue
            }
            if app.buttons["Punt"].exists {
                if !shotsTaken.contains("fourth") { snap(app, "07-fourth-down"); shotsTaken.insert("fourth") }
                app.buttons["Punt"].tap(); continue
            }
            if app.buttons["Deep Pass"].exists && taps % 3 == 0 {
                app.buttons["Deep Pass"].tap(); continue
            }
            if app.buttons["Short Pass"].exists && taps % 2 == 0 {
                app.buttons["Short Pass"].tap(); continue
            }
            if app.buttons["Run"].exists {
                app.buttons["Run"].tap(); continue
            }
            // Nothing tappable: let animations settle
            sleep(1)
        }
        XCTAssertTrue(app.buttons["Play again"].waitForExistence(timeout: 5), "Game never reached the final screen")
        app.buttons["Back to home"].tap()
        XCTAssertTrue(app.buttons["Play a Game"].waitForExistence(timeout: 5))
        snap(app, "08-home-after-game")

        // Playbook now has entries
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Playbook'")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["The Goal & Four Tries"].waitForExistence(timeout: 5))
        snap(app, "10-playbook")
    }
}
