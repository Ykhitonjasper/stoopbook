import XCTest

final class CriticalPathSmokeTests: XCTestCase {
    private static let onboardingCTAs = ["Next", "Continue", "Get started", "Get Started", "Start", "Begin", "Let's go", "Done"]
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testCriticalInteractions() {
        completeOnboarding()
        let control1 = element("smoke.kitRunner.computeCadence")
        XCTAssertTrue(control1.waitForExistence(timeout: 8), "Critical control 1 is unavailable")
        XCTAssertFalse(element("smoke.readingSave.draftReady").exists, "Critical result 1 already exists before its action")
        control1.tap()
        XCTAssertTrue(element("smoke.readingSave.draftReady").waitForExistence(timeout: 8), "Critical result 1 did not appear")
        let control2 = element("smoke.readingSave.saveReading")
        XCTAssertTrue(control2.waitForExistence(timeout: 8), "Critical control 2 is unavailable")
        XCTAssertFalse(element("smoke.readingDetail.savedReadout").exists, "Critical result 2 already exists before its action")
        control2.tap()
        XCTAssertTrue(element("smoke.readingDetail.savedReadout").waitForExistence(timeout: 8), "Critical result 2 did not appear")
        let control3 = element("smoke.readingDetail.showSavedReadout")
        XCTAssertTrue(control3.waitForExistence(timeout: 8), "Critical control 3 is unavailable")
        XCTAssertFalse(element("smoke.places.savedReadout").exists, "Critical result 3 already exists before its action")
        control3.tap()
        XCTAssertTrue(element("smoke.places.savedReadout").waitForExistence(timeout: 8), "Critical result 3 did not appear")
        let control4 = element("smoke.places.openRiverStoop")
        XCTAssertTrue(control4.waitForExistence(timeout: 8), "Critical control 4 is unavailable")
        XCTAssertFalse(element("smoke.exportReadings.stoopReady").exists, "Critical result 4 already exists before its action")
        control4.tap()
        XCTAssertTrue(element("smoke.exportReadings.stoopReady").waitForExistence(timeout: 8), "Critical result 4 did not appear")
        let control5 = element("smoke.exportReadings.copyPack")
        XCTAssertTrue(control5.waitForExistence(timeout: 8), "Critical control 5 is unavailable")
        XCTAssertFalse(element("smoke.exportReadings.copiedText").exists, "Critical result 5 already exists before its action")
        control5.tap()
        XCTAssertTrue(element("smoke.exportReadings.copiedText").waitForExistence(timeout: 8), "Critical result 5 did not appear")
        XCTAssertEqual(app.state, .runningForeground, "App left the foreground during critical interactions")
    }

    private func completeOnboarding() {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "App never reached the foreground")
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 10)
        settle()
        for _ in 0..<8 {
            if app.tabBars.firstMatch.exists { break }
            guard let button = onboardingButton() else { break }
            button.tap()
            settle(0.5)
        }
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 8), "Onboarding did not reach the main surface")
    }

    private func onboardingButton() -> XCUIElement? {
        for title in Self.onboardingCTAs {
            let button = app.buttons[title]
            if button.exists && button.isHittable { return button }
        }
        // No "single hittable button" fallback: a niche-worded hero has one CTA
        // ("Pick tonight") and the fallback used to press it, letting the smoke
        // tap into the primary flow while pretending it was still onboarding.
        return nil
    }

    private func settle(_ seconds: TimeInterval = 0.8) {
        _ = XCTWaiter().wait(for: [XCTestExpectation(description: "settle")], timeout: seconds)
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }
}
