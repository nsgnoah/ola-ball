import XCTest

/// Plays a whole pass-and-play match on one phone and saves screenshots to $OLABALL_SHOTS.
final class PlayThroughUITests: XCTestCase {
    private var shotDir: String? { ProcessInfo.processInfo.environment["OLABALL_SHOTS"] }

    private func snap(_ app: XCUIApplication, _ name: String) {
        guard let shotDir else { return }
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: shotDir).appendingPathComponent("\(name).png"))
    }

    func testPassAndPlayMatch() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset", "-ui-testing-seed"]
        app.launch()

        // Home with a seeded match
        XCTAssertTrue(app.buttons["new-local-match"].waitForExistence(timeout: 8))
        snap(app, "02-home")
        let row = app.buttons["local-match-seed-match"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        sleep(2)
        if let shotDir {
            try? app.debugDescription.write(to: URL(fileURLWithPath: shotDir).appendingPathComponent("after-row-tap.txt"), atomically: true, encoding: .utf8)
        }
        snap(app, "02b-after-row-tap")

        var shots: Set<String> = []
        var steps = 0
        while steps < 400 {
            steps += 1
            if app.staticTexts["match-over"].exists { snap(app, "09-match-over"); break }
            if app.buttons["handoff-continue"].exists { if shots.insert("handoff").inserted { snap(app, "05-handoff") }; app.buttons["handoff-continue"].tap(); continue }
            if app.buttons["start-round"].exists { if shots.insert("intro").inserted { snap(app, "06-round-intro") }; app.buttons["start-round"].tap(); continue }
            if app.buttons["next-question"].exists { if shots.insert("answered").inserted { snap(app, "07-answered") }; app.buttons["next-question"].tap(); continue }
            if app.buttons["option-0"].exists { if shots.insert("question").inserted { snap(app, "07-question") }; app.buttons["option-\(steps % 4)"].tap(); continue }
            if app.buttons["reveal-continue"].exists { if shots.insert("reveal").inserted { snap(app, "08-round-reveal") }; app.buttons["reveal-continue"].tap(); continue }
            let deckButtons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'deck-'"))
            if deckButtons.count > 0 { if shots.insert("pick").inserted { snap(app, "04-pick") }; deckButtons.element(boundBy: steps % deckButtons.count).tap(); continue }
            usleep(200_000)
        }
        XCTAssertTrue(app.staticTexts["match-over"].waitForExistence(timeout: 5), "match never finished after \(steps) steps")
        app.buttons["back-to-matches"].tap()
        XCTAssertTrue(app.buttons["new-local-match"].waitForExistence(timeout: 5))
        snap(app, "10-home-after")
    }
}
