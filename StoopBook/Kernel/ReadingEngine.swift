import Foundation

protocol ReadingComputing {
    func cadenceState(for stop: VisitStop) -> CadenceState
    func windowClash(first: VisitStop, second: VisitStop, travelMinutes: Int) -> Bool
    func pinTravel(from: VisitStop, to: VisitStop) -> TravelBin
    func haversineMetres(originLat: Double, originLon: Double, targetLat: Double, targetLon: Double) -> Double
    func clusterStopIDs(_ stops: [VisitStop], radiusMetres: Double) -> [[String]]
    func accessNotesReady(for stop: VisitStop) -> Bool
    func skipCostDays(stops: [VisitStop], droppedStopID: String) -> Int
    func exportPackText(round: VisitRound, stops: [VisitStop], readings: [KitReading]) -> String
    func compareSummary(first: KitReading, second: KitReading) -> String
}

struct ReadingEngine: ReadingComputing {
    /// The cadence clock a household actually stands on: the stored seed offset,
    /// moved to today if the last recorded outcome was a made visit. A readout
    /// alone never resets the clock — standing at the door does.
    func effectiveDayOffset(for stop: VisitStop, outcomes: [VisitOutcomeRecord]) -> Int {
        guard let last = latestOutcome(for: stop, outcomes: outcomes) else {
            return stop.lastVisitDayOffset
        }
        return last.outcome == .seen ? last.dayOffset : stop.lastVisitDayOffset
    }

    /// The most recent outcome recorded for a household, latest day wins.
    func latestOutcome(for stop: VisitStop, outcomes: [VisitOutcomeRecord]) -> VisitOutcomeRecord? {
        outcomes
            .filter { $0.stopID == stop.id }
            .max { $0.dayOffset < $1.dayOffset }
    }

    func cadenceState(for stop: VisitStop, outcomes: [VisitOutcomeRecord]) -> CadenceState {
        let offset = effectiveDayOffset(for: stop, outcomes: outcomes)
        if offset > stop.cadenceDays { return .overdue }
        if offset == stop.cadenceDays { return .dueToday }
        return .ahead
    }

    func cadenceState(for stop: VisitStop) -> CadenceState {
        cadenceState(for: stop, outcomes: [])
    }

    func windowClash(first: VisitStop, second: VisitStop, travelMinutes: Int) -> Bool {
        let firstEnd = first.windowEndHour * 60 + first.dwellMinutes
        let secondStart = second.windowStartHour * 60
        let secondEnd = second.windowEndHour * 60
        let firstStart = first.windowStartHour * 60
        return firstEnd + travelMinutes > secondStart && secondEnd > firstStart
    }

    func pinTravel(from: VisitStop, to: VisitStop) -> TravelBin {
        let metres = haversineMetres(originLat: from.lat, originLon: from.lon, targetLat: to.lat, targetLon: to.lon)
        if metres < 400 { return .walkShort }
        if metres < 1200 { return .walkLong }
        if metres < 5000 { return .driveShort }
        return .driveLong
    }

    func haversineMetres(originLat: Double, originLon: Double, targetLat: Double, targetLon: Double) -> Double {
        let radius = 6_371_000.0
        let dLat = (targetLat - originLat) * Double.pi / 180
        let dLon = (targetLon - originLon) * Double.pi / 180
        let lat1 = originLat * Double.pi / 180
        let lat2 = targetLat * Double.pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return radius * c
    }

    func clusterStopIDs(_ stops: [VisitStop], radiusMetres: Double) -> [[String]] {
        var unused = stops
        var groups: [[String]] = []
        while let seed = unused.first {
            unused.removeFirst()
            var group = [seed.id]
            var remaining: [VisitStop] = []
            for stop in unused {
                let metres = haversineMetres(originLat: seed.lat, originLon: seed.lon, targetLat: stop.lat, targetLon: stop.lon)
                if metres <= radiusMetres {
                    group.append(stop.id)
                } else {
                    remaining.append(stop)
                }
            }
            unused = remaining
            groups.append(group)
        }
        return groups
    }

    func accessNotesReady(for stop: VisitStop) -> Bool {
        !stop.entryNote.isEmpty && !stop.floor.isEmpty && !stop.petNote.isEmpty && !stop.parkingNote.isEmpty
    }

    func skipCostDays(stops: [VisitStop], droppedStopID: String) -> Int {
        guard let stop = stops.first(where: { $0.id == droppedStopID }) else { return 0 }
        return max(0, stop.lastVisitDayOffset + 1 - stop.cadenceDays)
    }

    func exportPackText(round: VisitRound, stops: [VisitStop], readings: [KitReading]) -> String {
        // The pack a stand-in can walk: the same plot the screen draws — order,
        // hours, one access line per door, who is overdue — not a ledger of ids.
        MorningBook().standInSheet(round: round, stops: stops, readings: readings)
    }

    func compareSummary(first: KitReading, second: KitReading) -> String {
        let delta = second.primaryValue - first.primaryValue
        return "\(first.note) vs \(second.note): delta \(delta)"
    }
}
