import XCTest

/// Guards the Stoops sheet. It is the one surface that used to depend on a network:
/// Apple's tiles render a blank grid with no signal, so the plot is drawn from stored
/// coordinates instead. These checks hold the drawing to account — every stored pin
/// lands on the sheet, pins are spread by real distance instead of stacked in a
/// corner, and the pin a tap means is the nearest one, not whichever view a 44pt
/// target left on top.
final class RoutePlotUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testPlotLaysEveryStoredPinOnTheSheet() {
        completeOnboarding()
        openStoopsTab()

        let pins = self.pins()
        XCTAssertTrue(pins.firstMatch.waitForExistence(timeout: 8), "The round plot drew no pins")
        XCTAssertGreaterThanOrEqual(pins.count, 6, "The plot should carry the whole round, found \(pins.count) pins")

        let window = app.windows.firstMatch.frame
        let centres = pinCentres()
        for (index, frame) in pinFrames().enumerated() {
            XCTAssertFalse(frame.width.isNaN || frame.height.isNaN, "Pin \(index + 1) has no size")
            XCTAssertTrue(
                frame.minX >= window.minX - 1 && frame.maxX <= window.maxX + 1
                    && frame.minY >= window.minY - 1 && frame.maxY <= window.maxY + 1,
                "Pin \(index + 1) is drawn outside the sheet: \(frame) in \(window)"
            )
        }

        // A projection that collapsed would stack every pin on one point.
        var widest: CGFloat = 0
        for first in centres {
            for second in centres {
                widest = max(widest, hypot(first.x - second.x, first.y - second.y))
            }
        }
        XCTAssertGreaterThan(widest, 60, "The pins are stacked on one point — the sheet is not using the coordinates")

        // The sheet is either a real basemap with Apple's attribution, or this app's
        // plot that says why it is drawn. What it must never be is a blank tile grid
        // with nothing on the page to explain it.
        if !app.maps.firstMatch.waitForExistence(timeout: 3) {
            XCTAssertTrue(
                app.staticTexts.matching(
                    NSPredicate(format: "label CONTAINS[c] %@", "Map tiles are unreachable")
                ).firstMatch.waitForExistence(timeout: 14),
                "The sheet is a blank map with no explanation of why it is blank"
            )
        }
    }

    func testTappingAPinMovesTheFocusRing() {
        completeOnboarding()
        openStoopsTab()

        let pins = self.pins()
        XCTAssertTrue(pins.firstMatch.waitForExistence(timeout: 8), "The round plot drew no pins")
        XCTAssertGreaterThanOrEqual(pins.count, 4, "Need at least four pins to pick a new focus")

        let pin = pins.element(boundBy: 3)
        XCTAssertFalse(pin.isSelected, "Pin 4 was already focused before it was tapped")

        tap(at: pinCentre(3))

        XCTAssertTrue(pin.isSelected, "Tapping a pin did not put that household in focus")
        XCTAssertTrue(
            app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Open the household card")).firstMatch
                .waitForExistence(timeout: 5),
            "The sheet has no way through to the focused household"
        )
        XCTAssertEqual(app.state, .runningForeground, "App left the foreground from the sheet")
    }

    /// Two households in one building sit about 8pt apart on this sheet. Their 44pt
    /// targets overlap, so the app has to resolve the tap by distance. This is the
    /// check that keeps a tap from opening the wrong door.
    func testTheNearerPinTakesTheTap() {
        completeOnboarding()
        openStoopsTab()

        let pins = self.pins()
        XCTAssertTrue(pins.firstMatch.waitForExistence(timeout: 8), "The round plot drew no pins")
        let count = pins.count
        XCTAssertGreaterThanOrEqual(count, 3, "Need at least three pins to compare distances")

        let centres = pinCentres()
        let focused = (0..<count).first { pins.element(boundBy: $0).isSelected }
        let pair = closestPair(centres, skipping: focused) ?? closestPair(centres, skipping: nil)
        guard let pair else {
            XCTFail("No two pins to compare")
            return
        }

        let first = pins.element(boundBy: pair.first)
        let second = pins.element(boundBy: pair.second)
        let start = centres[pair.first]
        let end = centres[pair.second]
        // A tap a quarter of the way over belongs to the first pin, even though the
        // second one's target covers that point too.
        tap(at: CGPoint(x: start.x + (end.x - start.x) * 0.25, y: start.y + (end.y - start.y) * 0.25))

        XCTAssertTrue(
            first.isSelected,
            "The nearer pin lost the tap: \(first.label) is \(pair.distance)pt from \(second.label)"
        )
        XCTAssertFalse(second.isSelected, "The tap jumped to the pin whose target sat on top")
    }

    // MARK: - Helpers

    private func pins() -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Stop "))
    }

    private func pinFrames() -> [CGRect] {
        let pins = self.pins()
        return (0..<pins.count).map { pins.element(boundBy: $0).frame }
    }

    private func pinCentres() -> [CGPoint] {
        pinFrames().map { CGPoint(x: $0.midX, y: $0.midY) }
    }

    private func pinCentre(_ index: Int) -> CGPoint {
        let frame = pins().element(boundBy: index).frame
        return CGPoint(x: frame.midX, y: frame.midY)
    }

    private func closestPair(_ centres: [CGPoint], skipping skip: Int?) -> (first: Int, second: Int, distance: CGFloat)? {
        var best: (first: Int, second: Int, distance: CGFloat)?
        for first in 0..<centres.count {
            for second in (first + 1)..<centres.count {
                if first == skip || second == skip { continue }
                let distance = hypot(centres[first].x - centres[second].x, centres[first].y - centres[second].y)
                if best == nil || distance < best!.distance {
                    best = (first, second, distance)
                }
            }
        }
        return best
    }

    private func tap(at point: CGPoint) {
        let window = app.windows.firstMatch
        let origin = window.frame.origin
        window
            .coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: point.x - origin.x, dy: point.y - origin.y))
            .tap()
        settle(0.8)
    }

    private func openStoopsTab() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "No tab bar after onboarding")
        let stoops = tabBar.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Stoop")).firstMatch
        XCTAssertTrue(stoops.exists, "The Stoops tab is missing")
        stoops.tap()
        settle()
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

    private func settle(_ seconds: TimeInterval = 1.0) {
        _ = XCTWaiter().wait(for: [XCTestExpectation(description: "settle")], timeout: seconds)
    }
}
