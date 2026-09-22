import Foundation
import Observation

@MainActor @Observable final class StoopBookStore {
    var hasCompletedOnboarding: Bool
    var selectedRound: VisitRound
    var activeRun: PatrolRun?
    var lastSavedReadingID: String?
    var focusedStopID: String?
    var selectedTab: AppTab
    var draftStopIDs: [String]
    var extraReadings: [KitReading]
    /// Closed visits: the door outcomes that move the cadence clock and flag
    /// households on the line.
    var visitOutcomes: [VisitOutcomeRecord]
    /// How the round sheet is drawn, and whether a real basemap can be drawn here.
    var mapMode: MapMode
    var mapTilesReachable: Bool
    private var mapModeIsChosen = false

    init(
        hasCompletedOnboarding: Bool = false,
        selectedRound: VisitRound = StoopBookSeed.defaultRound,
        activeRun: PatrolRun? = StoopBookSeed.activeRun,
        lastSavedReadingID: String? = nil,
        focusedStopID: String? = nil,
        selectedTab: AppTab = .kits,
        draftStopIDs: [String] = StoopBookSeed.defaultRound.stopIds,
        extraReadings: [KitReading] = [],
        visitOutcomes: [VisitOutcomeRecord] = [],
        mapMode: MapMode = .plot,
        mapTilesReachable: Bool = false
    ) {
        self.mapMode = mapMode
        self.mapTilesReachable = mapTilesReachable
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.selectedRound = selectedRound
        self.activeRun = activeRun
        self.lastSavedReadingID = lastSavedReadingID
        self.focusedStopID = focusedStopID
        self.selectedTab = selectedTab
        self.draftStopIDs = draftStopIDs
        self.extraReadings = extraReadings
        self.visitOutcomes = visitOutcomes
    }

    /// The segmented control binds through this, and choosing the sheet by hand is
    /// remembered: the availability check must not overrule the person.
    var mapModeID: String {
        get { mapMode.rawValue }
        set {
            mapMode = MapMode(rawValue: newValue) ?? .plot
            mapModeIsChosen = true
        }
    }

    func applyDefaultMapMode(reachableTiles: Bool) {
        guard !mapModeIsChosen else { return }
        mapMode = reachableTiles ? .map : .plot
    }

    func completeOnboarding() { hasCompletedOnboarding = true }

    func selectRound(_ round: VisitRound) {
        selectedRound = round
        draftStopIDs = round.stopIds
    }

    func save(reading: KitReading) -> KitReading {
        extraReadings.append(reading)
        lastSavedReadingID = reading.id
        if reading.kind == .cadence || reading.kind == .accessNotes {
            if let stopID = reading.stopIds.first {
                focusedStopID = stopID
            }
        }
        return reading
    }

    func focusStop(_ stopID: String) { focusedStopID = stopID }

    /// Close a visit at the door. Seen restarts that household's cadence clock
    /// from today; the other outcomes leave the clock alone and carry their mark.
    @discardableResult
    func recordOutcome(_ outcome: VisitOutcome, stopID: String, note: String = "", dayOffset: Int = 0) -> VisitOutcomeRecord {
        let record = VisitOutcomeRecord(
            id: "outcome-\(UUID().uuidString.prefix(8))",
            stopID: stopID,
            outcome: outcome,
            dayOffset: dayOffset,
            note: note
        )
        visitOutcomes.append(record)
        return record
    }

    func outcomes(for stopID: String) -> [VisitOutcomeRecord] {
        visitOutcomes.filter { $0.stopID == stopID }
    }

    /// The household as the book now stands: a recorded `seen` moves its cadence
    /// clock to today, every other outcome leaves the seed standing. Every cadence
    /// reading on every screen goes through this, so the line, the ledgers, and
    /// the plot all tell one story.
    func resolvedStop(_ stop: VisitStop) -> VisitStop {
        guard let last = visitOutcomes.filter({ $0.stopID == stop.id }).max(by: { $0.dayOffset < $1.dayOffset }),
              last.outcome == .seen else {
            return stop
        }
        return stop.withLastVisit(dayOffset: last.dayOffset)
    }

    func resolvedStops(_ stops: [VisitStop]) -> [VisitStop] {
        stops.map(resolvedStop)
    }

    func deleteAll() {
        extraReadings = []
        visitOutcomes = []
        lastSavedReadingID = nil
        focusedStopID = nil
        selectedRound = StoopBookSeed.defaultRound
        activeRun = nil
        draftStopIDs = StoopBookSeed.defaultRound.stopIds
        selectedTab = .kits
    }

    func resetOnboarding() {
        hasCompletedOnboarding = false
        selectedTab = .kits
    }
}
