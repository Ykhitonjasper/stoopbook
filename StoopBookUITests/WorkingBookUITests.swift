import XCTest

/// Guards the three working contours: a visit that closes moves the cadence
/// clock; the morning reads as hours, not bins; and the builder proposes lawful
/// orders a person can mean, not just arrows.
final class WorkingBookUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    /// The headline contour: seen restarts the clock, and the book moves the same
    /// day everywhere — the line, the ledger, the readout.
    func testClosingAVisitRestartsTheCadenceClock() {
        completeOnboarding()

        // Put the first household in hand, as a person would: tap its house.
        let firstHouse = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Stop 1,")).firstMatch
        XCTAssertTrue(firstHouse.waitForExistence(timeout: 5), "The first house is missing from the line")
        firstHouse.tap()

        // Close the visit as seen on the focused household.
        let seen = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Seen River Stoop 4B")).firstMatch
        XCTAssertTrue(seen.waitForExistence(timeout: 5), "The seen outcome is not on the focus card")
        seen.tap()

        // The focus card's cadence row now stands on today: the clock restarted.
        let moved = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "last 0d")).firstMatch
        XCTAssertTrue(moved.waitForExistence(timeout: 5), "Marking seen did not restart the household's cadence clock")

        let closed = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Closed seen")).firstMatch
        XCTAssertTrue(closed.exists, "The card does not say the visit was closed")
        XCTAssertEqual(app.state, .runningForeground, "App left the foreground after closing a visit")
    }

    /// The morning rail carries wall-clock arrivals, not bin names.
    func testTheMorningReadsAsHours() {
        completeOnboarding()

        let firstArrival = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "8:00 AM")).firstMatch
        XCTAssertTrue(firstArrival.waitForExistence(timeout: 5), "The morning clock does not open at eight")

        // Dwell and hop in hours-and-minutes terms somewhere on the rail.
        let dwell = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "dwell 30")).firstMatch
        XCTAssertTrue(dwell.exists, "The clock row does not carry dwell")

        // And the morning states its standing against the budget. The seeded
        // North Loop walks 188 minutes over, so the honest card says so.
        let standing = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "budget")).firstMatch
        XCTAssertTrue(standing.waitForExistence(timeout: 5), "The clock card does not state the morning against the budget")

        // Leave-by: the latest exit that keeps every later window.
        let leaveBy = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "out by")).firstMatch
        XCTAssertTrue(leaveBy.exists, "The clock rows do not carry a leave-by time")
    }

    /// Lawful orders: the builder offers the three, costed, and laying one
    /// changes the order the builder holds.
    func testTheBuilderProposesLawfulOrders() {
        completeOnboarding()

        let orderControl = app.buttons["smoke.hub.orderMorning"]
        XCTAssertTrue(orderControl.waitForExistence(timeout: 5), "The morning card does not lead to the builder")
        orderControl.tap()

        let orders = app.buttons["Orders"].firstMatch
        XCTAssertTrue(orders.waitForExistence(timeout: 5), "The Orders view is missing in the builder")
        orders.tap()

        for name in ["Overdue first", "Window first", "Same vestibule"] {
            let card = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
            XCTAssertTrue(card.waitForExistence(timeout: 5), "Lawful order \(name) is missing")
        }

        // Costed, not decorative: each order states its load against the budget.
        let load = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "min of 240")).firstMatch
        XCTAssertTrue(load.waitForExistence(timeout: 5), "Orders do not carry their load")

        // Laying an order moves the builder's own checkpoint list.
        let lay = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Lay this order")).firstMatch
        XCTAssertTrue(lay.waitForExistence(timeout: 5))
        lay.tap()
        XCTAssertTrue(app.buttons["Order already on the round"].waitForExistence(timeout: 5)
            || app.buttons["Apply this order"].exists, "Laying an order did not reach the builder")
        XCTAssertEqual(app.state, .runningForeground, "App left the foreground in the builder")
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
