import XCTest

/// Walks the first-launch path the way a reviewer would and captures screenshots.
/// Navigation is discovered through the accessibility tree. Do not retarget this test.
///
/// The helper script uninstalls first so the app starts at the introduction with a clean store.
final class SmokeUITests: XCTestCase {

    private static let onboardingCTAs = [
        "Next", "Continue", "Get started", "Get Started", "Start", "Begin", "Let's go", "Done",
    ]
    private var app: XCUIApplication!
    private var shotIndex = 0

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testReviewerWalkthrough() {
        completeOnboarding()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(
            tabBar.waitForExistence(timeout: 10),
            "No tab bar after onboarding — the app never reaches its main surface"
        )
        let tabCount = tabBar.buttons.count
        XCTAssertGreaterThanOrEqual(tabCount, 3, "Need ≥3 tabs on iOS 17, found \(tabCount)")

        // Pass 1 captures the submission screenshots, pass 2 proves the loop survives a repeat.
        sweepTabs(capture: true)
        sweepTabs(capture: false)

        checkLegalLinks()
        checkDeleteAllData()

        XCTAssertEqual(app.state, .runningForeground, "App left the foreground during the walkthrough")
    }

    // MARK: - Steps

    /// Driven by the onboarding CTA, never by the tab bar: a paged onboarding `TabView`
    /// exposes its page indicator as a tab bar, which would look like the main surface.
    private func completeOnboarding() {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "App never reached the foreground")
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 10)
        settle()
        capture(named: "launch")
        for _ in 0..<8 {
            // Once the main TabView is up, onboarding is finished — a single hittable
            // hero button on the first tab is NOT an onboarding CTA, do not tap it.
            if app.tabBars.firstMatch.exists { break }
            guard let cta = onboardingButton() else { break }
            cta.tap()
            settle(0.5)
            if app.tabBars.firstMatch.exists { break }
            capture(named: "onboarding")
        }
        if !app.tabBars.firstMatch.waitForExistence(timeout: 5) {
            XCTFail("Onboarding never hands off to the main surface — dead end at first launch")
        }
    }

    private func sweepTabs(capture shouldCapture: Bool) {
        let tabBar = app.tabBars.firstMatch
        for index in 0..<tabBar.buttons.count {
            let tab = tabBar.buttons.element(boundBy: index)
            guard tab.exists else { continue }
            let label = tab.label
            tab.tap()
            XCTAssertTrue(
                tab.waitForExistence(timeout: 5),
                "Tab \(label) did not stay reachable"
            )
            settle(0.6)
            let density = app.staticTexts.count + app.cells.count + app.images.count
            XCTAssertGreaterThanOrEqual(
                density, 3,
                "Tab \(label) renders almost nothing — empty or dead tab"
            )
            if shouldCapture {
                capture(named: label)
            }
            XCTAssertEqual(app.state, .runningForeground, "App died while opening tab \(label)")
        }
    }

    private func checkLegalLinks() {
        openSettings()
        // "Privacy Policy" / "Terms of Use" / a plain Link all count.
        for title in ["Privacy", "Terms"] {
            let match = NSPredicate(format: "label CONTAINS[c] %@", title)
            let found = app.buttons.matching(match).firstMatch.exists
                || app.links.matching(match).firstMatch.exists
                || app.staticTexts.matching(match).firstMatch.exists
            XCTAssertTrue(found, "Settings has no \(title) entry")
        }
        // No capture here: the tab sweep already shot this surface, and a duplicate
        // would be rejected by the 2.3.3 gate.
    }

    private func checkDeleteAllData() {
        openSettings()
        let delete = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Delete All")
        ).firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "Settings offers no Delete All Data")
        XCTAssertTrue(
            scrollIntoView(delete),
            "Delete All Data never came on screen; a tap on its off-screen frame lands on the tab bar "
                + "and quietly switches tabs instead of clearing the phone"
        )
        delete.tap()
        confirmDestructiveAction()

        // Onboarding is back when the tab bar is gone or a first-run CTA is on screen.
        // Wait through the run loop: a busy loop here gets the runner killed as unresponsive.
        let tabBarGone = expectation(
            for: NSPredicate(format: "exists == false"),
            evaluatedWith: app.tabBars.firstMatch
        )
        let waited = XCTWaiter().wait(for: [tabBarGone], timeout: 10)
        if waited != .completed && onboardingButton() == nil {
            capture(named: "delete-failed")
            let visible = app.buttons.allElementsBoundByIndex.prefix(12).map(\.label)
            XCTFail(
                "Delete All Data did not return to onboarding — the completion flag survived the wipe. "
                    + "Visible buttons: \(visible)"
            )
        }
        XCTAssertEqual(app.state, .runningForeground, "App crashed on Delete All Data")
    }

    /// Confirmation can arrive as an action sheet, an alert, or not at all — accept all three.
    private func confirmDestructiveAction() {
        var dialog: XCUIElement?
        if app.sheets.firstMatch.waitForExistence(timeout: 3) {
            dialog = app.sheets.firstMatch
        } else if app.alerts.firstMatch.waitForExistence(timeout: 1) {
            dialog = app.alerts.firstMatch
        }
        guard let dialog else { return }
        let confirm = dialog.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@ AND NOT label CONTAINS[c] %@", "Delete", "Cancel")
        ).firstMatch
        if confirm.waitForExistence(timeout: 2) {
            confirm.tap()
        } else if dialog.buttons.count > 0 {
            dialog.buttons.element(boundBy: 0).tap()
        }
    }

    // MARK: - Helpers

    private func openSettings() {
        let tabBar = app.tabBars.firstMatch
        let settings = tabBar.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Settings")
        ).firstMatch
        if settings.exists {
            settings.tap()
        } else if tabBar.buttons.count > 0 {
            tabBar.buttons.element(boundBy: tabBar.buttons.count - 1).tap()
        }
    }

    private func onboardingButton() -> XCUIElement? {
        for title in Self.onboardingCTAs {
            let button = app.buttons[title]
            if button.exists && button.isHittable { return button }
        }
        // Deliberately no "single hittable button" fallback: on a niche-worded
        // hero screen the primary CTA is a single hittable button ("Pick tonight"),
        // and the fallback used to tap it, sneaking the smoke past the contract.
        return nil
    }

    /// Brings a control on screen before it is tapped. Settings is taller than the
    /// display, and a tap on an element whose frame is far below the fold is resolved
    /// at those coordinates — which is the tab bar, so the tap silently lands on
    /// another tab and the step it was meant to prove never runs.
    private func scrollIntoView(_ element: XCUIElement, swipes: Int = 6) -> Bool {
        for _ in 0..<swipes {
            if element.isHittable { return true }
            app.swipeUp()
            settle(0.4)
        }
        return element.isHittable
    }

    /// Run-loop friendly pause. A busy wait here gets the runner killed as unresponsive.
    private func settle(_ seconds: TimeInterval = 1.2) {
        _ = XCTWaiter().wait(for: [XCTestExpectation(description: "settle")], timeout: seconds)
    }

    private func capture(named label: String) {
        shotIndex += 1
        let slug = label
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = String(format: "%02d-%@", shotIndex, slug.isEmpty ? "screen" : slug)
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
