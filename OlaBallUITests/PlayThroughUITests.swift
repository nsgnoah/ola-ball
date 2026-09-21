import XCTest

/// Plays a whole pass-and-play match on one phone and saves screenshots to $OLABALL_SHOTS.
final class PlayThroughUITests: XCTestCase {
    /// Where play-through screenshots land. $OLABALL_SHOTS if set (xcodebuild passes it as
    /// TEST_RUNNER_OLABALL_SHOTS); otherwise build/shots next to this source file, so a plain
    /// cmd-U still leaves you something to look at.
    private var shotDir: String? {
        if let fromEnv = ProcessInfo.processInfo.environment["OLABALL_SHOTS"] { return fromEnv }
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let dir = repo.appendingPathComponent("build/shots")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.path
    }

    /// OLABALL_LANDSCAPE=1 rotates the device first (iPad screenshots).
    private func orient() {
        if ProcessInfo.processInfo.environment["OLABALL_LANDSCAPE"] == "1" { XCUIDevice.shared.orientation = .landscapeLeft }
    }

    /// Captures the whole screen rather than just the app window: `app.screenshot()` composites a
    /// rotated device wrongly and made a perfectly good landscape layout look broken.
    ///
    /// Waits out the entrance springs first. Several screens pop their centrepiece in from 0.2
    /// scale, and catching the trophy or the crown mid-flight makes a useless App Store screenshot.
    private func snap(_ app: XCUIApplication, _ name: String) {
        guard let shotDir else { return }
        Thread.sleep(forTimeInterval: 0.9)
        let url = URL(fileURLWithPath: shotDir).appendingPathComponent("\(name).png")
        do { try XCUIScreen.main.screenshot().pngRepresentation.write(to: url) }
        catch { XCTFail("could not write screenshot \(name) to \(url.path): \(error)") }
    }

    func testPassAndPlayMatch() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset", "-ui-testing-seed"]
        orient()
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

    func testPassAndPlayCouplesMatch() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset", "-ui-testing-seed"]
        orient()
        app.launch()
        XCTAssertTrue(app.buttons["new-local-match"].waitForExistence(timeout: 8))
        let row = app.buttons["local-match-seed-teams"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        var shots: Set<String> = []
        var steps = 0
        while steps < 900 {
            steps += 1
            if app.staticTexts["match-over"].exists { snap(app, "t9-match-over"); break }
            if app.buttons["handoff-continue"].exists { if shots.insert("handoff").inserted { snap(app, "t5-handoff") }; app.buttons["handoff-continue"].tap(); continue }
            if app.buttons["start-round"].exists { if shots.insert("intro").inserted { snap(app, "t6-round-intro") }; app.buttons["start-round"].tap(); continue }
            if app.buttons["next-question"].exists { app.buttons["next-question"].tap(); continue }
            if app.buttons["option-0"].exists { if shots.insert("question").inserted { snap(app, "t7-question") }; app.buttons["option-\(steps % 4)"].tap(); continue }
            if app.buttons["reveal-continue"].exists { if shots.insert("reveal").inserted { snap(app, "t8-round-reveal") }; app.buttons["reveal-continue"].tap(); continue }
            let deckButtons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'deck-'"))
            if deckButtons.count > 0 { if shots.insert("pick").inserted { snap(app, "t4-pick") }; deckButtons.element(boundBy: steps % deckButtons.count).tap(); continue }
            usleep(200_000)
        }
        XCTAssertTrue(app.staticTexts["match-over"].waitForExistence(timeout: 5), "couples match never finished after \(steps) steps")
    }
}
