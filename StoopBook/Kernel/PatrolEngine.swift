import Foundation

protocol PatrolComputing {
    func loadMinutes(round: VisitRound, stops: [VisitStop]) -> Int
    func progressRatio(run: PatrolRun, round: VisitRound) -> Double
    func planningMinutes(for bin: TravelBin) -> Int
}

struct PatrolEngine: PatrolComputing {
    private let readingEngine = ReadingEngine()

    func loadMinutes(round: VisitRound, stops: [VisitStop]) -> Int {
        let byID = Dictionary(uniqueKeysWithValues: stops.map { ($0.id, $0) })
        var total = 0
        var previous: VisitStop?
        for stopID in round.stopIds {
            guard let stop = byID[stopID] else { continue }
            total += stop.dwellMinutes
            if let previous {
                let bin = readingEngine.pinTravel(from: previous, to: stop)
                total += planningMinutes(for: bin)
            }
            previous = stop
        }
        return total
    }

    func progressRatio(run: PatrolRun, round: VisitRound) -> Double {
        let total = max(round.stopIds.count, 1)
        return Double(run.completedStopIds.count) / Double(total)
    }

    func planningMinutes(for bin: TravelBin) -> Int {
        bin.planningMinutes
    }
}
