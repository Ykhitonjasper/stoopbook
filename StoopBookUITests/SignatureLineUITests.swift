import XCTest

/// Guards the two surfaces the design rests on: the drawn street line on the home
/// screen and the lens rail under it. The reviewer walkthrough covers navigation
/// between tabs; this covers the interactions a person actually starts with.
final class SignatureLineUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testStreetLinePutsAHouseholdOnThePage() {
        completeOnboarding()

        let houses = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Stop "))
        XCTAssertGreaterThanOrEqual(houses.count, 6, "The morning line should draw one house per stoop on screen")

        let fourth = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Stop 4,")).firstMatch
        XCTAssertTrue(fourth.waitForExistence(timeout: 5), "Stop 4 is missing from the line")
        fourth.tap()

        let focusAction = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Open the household card")).firstMatch
        XCTAssertTrue(focusAction.waitForExistence(timeout: 5), "Tapping a house did not put that household on the page")

        focusAction.tap()
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Household card")).firstMatch.waitForExistence(timeout: 5),
            "The household card did not open from the focused stoop"
        )
        XCTAssertEqual(app.state, .runningForeground, "App left the foreground from the street line")
    }

    func testLensRailSwitchesWhatTheActionSaves() {
        completeOnboarding()

        let expectations: [(lens: String, action: String)] = [
            ("Windows", "Save the window check"),
            ("Blocks", "Save the block grouping"),
            ("Load", "Save the round load"),
            ("Cadence", "Save the cadence readout")
        ]

        for expectation in expectations {
            let lens = app.buttons[expectation.lens].firstMatch
            XCTAssertTrue(lens.waitForExistence(timeout: 5), "Lens \(expectation.lens) is missing from the rail")
            lens.tap()
            XCTAssertTrue(
                app.buttons[expectation.action].firstMatch.waitForExistence(timeout: 5),
                "Lens \(expectation.lens) did not retarget the primary action"
            )
            XCTAssertEqual(app.state, .runningForeground, "App left the foreground on lens \(expectation.lens)")
        }
    }

    /// The motion law of this app, enforced. A switch may cross-fade, glide the map,
    /// or slide the brass rule to the tab you chose — but the page it leaves behind
    /// is never empty while that happens. Content that depends on an animation
    /// landing is content a person can miss, so the surface has to stay legible on
    /// every frame, not only once the transition finishes.
    func testSwitchingALensNeverLeavesThePageEmpty() {
        completeOnboarding()

        for lens in ["Windows", "Blocks", "Load", "Cadence"] {
            let chip = app.buttons[lens].firstMatch
            XCTAssertTrue(chip.waitForExistence(timeout: 5), "Lens \(lens) is missing from the rail")
            chip.tap()

            for tick in 0..<12 {
                XCTAssertTrue(
                    app.tabBars.firstMatch.exists && app.staticTexts.count >= 3,
                    "The page was empty \(Double(tick) * 0.1)s after switching to \(lens)"
                )
                tick0()
            }
        }
        XCTAssertEqual(app.state, .runningForeground, "App left the foreground while switching lenses")
    }

    /// One run-loop friendly tenth of a second.
    private func tick0() {
        _ = XCTWaiter().wait(for: [XCTestExpectation(description: "tick")], timeout: 0.1)
    }

    private func completeOnboarding() {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "App never reached the foreground")
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 10)
        settle()
        for _ in 0..<8 {
            if app.tabBars.firstMatch.exists { break }
            let ctas = ["Continue", "Get started"].map { app.buttons[$0] }
            guard let cta = ctas.first(where: { $0.exists && $0.isHittable }) else { break }
            cta.tap()
            settle(0.5)
        }
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 8), "Onboarding did not reach the main surface")
    }

    private func settle(_ seconds: TimeInterval = 0.9) {
        _ = XCTWaiter().wait(for: [XCTestExpectation(description: "settle")], timeout: seconds)
    }
}
