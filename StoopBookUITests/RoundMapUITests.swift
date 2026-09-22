import XCTest

/// Exercises the live-basemap path. It cannot be reached on a machine with no route
/// to a tile service — there the screen draws the plot and says why — so the app
/// takes a launched flag that reports tiles as reachable. With it on, the map view
/// is the one under test, and the same marks, the same labels and the same
/// nearest-pin tap have to hold as on the drawn sheet.
final class RoundMapUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-StoopBookAssumeMapTiles"]
        app.launch()
    }

    func testTheMapCarriesTheAppsOwnMarks() {
        completeOnboarding()
        openStoopsTab()

        let pins = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Stop "))
        XCTAssertTrue(pins.firstMatch.waitForExistence(timeout: 8), "The map drew no households")
        XCTAssertGreaterThanOrEqual(pins.count, 6, "The map should carry the whole round, found \(pins.count) pins")

        // Apple's map view is the ground here, so it has to be on screen: the drawn
        // plot is the fallback, not what should be up while a basemap is available.
        XCTAssertTrue(app.maps.firstMatch.waitForExistence(timeout: 5), "No basemap view on screen")

        let sheet = app.buttons["Sheet"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 5) || app.otherElements["Sheet"].exists, "The sheet control is missing while a map is available")
        XCTAssertTrue(app.buttons["Plot"].exists, "The drawn sheet cannot be chosen by hand")

        // Nearest pin wins on the map too: two households in one building sit about
        // 8pt apart and their targets overlap.
        let centres = (0..<pins.count).map { index -> CGPoint in
            let frame = pins.element(boundBy: index).frame
            return CGPoint(x: frame.midX, y: frame.midY)
        }
        let focused = (0..<pins.count).first { pins.element(boundBy: $0).isSelected }
        var pair: (first: Int, second: Int, distance: CGFloat)?
        for first in 0..<centres.count {
            for second in (first + 1)..<centres.count {
                if first == focused || second == focused { continue }
                let distance = hypot(centres[first].x - centres[second].x, centres[first].y - centres[second].y)
                if pair == nil || distance < pair!.distance {
                    pair = (first, second, distance)
                }
            }
        }
        guard let pair else {
            XCTFail("No two pins to compare")
            return
        }

        let start = centres[pair.first]
        let end = centres[pair.second]
        tap(at: CGPoint(x: start.x + (end.x - start.x) * 0.25, y: start.y + (end.y - start.y) * 0.25))

        XCTAssertTrue(
            pins.element(boundBy: pair.first).isSelected,
            "On the map the nearer pin lost the tap: they are \(pair.distance)pt apart"
        )
        XCTAssertFalse(pins.element(boundBy: pair.second).isSelected, "The map focused the wrong door")
        XCTAssertEqual(app.state, .runningForeground, "App left the foreground on the map")
    }

    func testTheSheetCanBeSwitchedToTheDrawnPlot() {
        completeOnboarding()
        openStoopsTab()

        // The sheet control arrives with the basemap, and a busy machine can take
        // longer than a launch budget to get there; the guard is about the control
        // existing, not about it beating a stopwatch.
        let plot = app.buttons["Plot"]
        XCTAssertTrue(plot.waitForExistence(timeout: 20), "The drawn sheet cannot be chosen")
        plot.tap()
        settle()

        XCTAssertTrue(
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Stop ")).firstMatch
                .waitForExistence(timeout: 5),
            "Switching to the plot lost the households"
        )
        XCTAssertTrue(plot.isSelected, "The sheet control did not follow the choice")
        XCTAssertEqual(app.state, .runningForeground, "App left the foreground switching the sheet")
    }

    // MARK: - Helpers

    private func openStoopsTab() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "No tab bar after onboarding")
        tabBar.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Stoop")).firstMatch.tap()
        settle()
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
