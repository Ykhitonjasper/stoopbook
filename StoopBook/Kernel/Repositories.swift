import Foundation

@MainActor protocol VisitStopRepository {
    func listedStops() -> [VisitStop]
    func stop(id: String) -> VisitStop?
}

@MainActor protocol VisitRoundRepository {
    func listedRounds() -> [VisitRound]
    func round(id: String) -> VisitRound?
}

@MainActor protocol NeighbourhoodPlaceRepository {
    func listedPlaces() -> [NeighbourhoodPlace]
    func place(id: String) -> NeighbourhoodPlace?
    func deleteAllPlaces() -> Bool
}

@MainActor protocol KitReadingRepository {
    func listedReadings() -> [KitReading]
    func reading(id: String) -> KitReading?
    func saveReading(_ reading: KitReading) -> KitReading
    func deleteAllReadings() -> Bool
}

@MainActor protocol PatrolRunRepository {
    func listedRuns() -> [PatrolRun]
    func run(id: String) -> PatrolRun?
    func deleteAllRuns() -> Bool
}

@MainActor final class SeededStopRepository: VisitStopRepository {
    private var storedStops: [VisitStop]

    init(stops: [VisitStop]) { storedStops = stops }
    func listedStops() -> [VisitStop] { storedStops }
    func stop(id: String) -> VisitStop? { storedStops.first { $0.id == id } }
}

@MainActor final class SeededRoundRepository: VisitRoundRepository {
    private var storedRounds: [VisitRound]

    init(rounds: [VisitRound]) { storedRounds = rounds }
    func listedRounds() -> [VisitRound] { storedRounds }
    func round(id: String) -> VisitRound? { storedRounds.first { $0.id == id } }
}

@MainActor final class SeededPlaceRepository: NeighbourhoodPlaceRepository {
    private var storedPlaces: [NeighbourhoodPlace]

    init(places: [NeighbourhoodPlace]) { storedPlaces = places }
    func listedPlaces() -> [NeighbourhoodPlace] { storedPlaces }
    func place(id: String) -> NeighbourhoodPlace? { storedPlaces.first { $0.id == id } }
    func deleteAllPlaces() -> Bool { storedPlaces.removeAll(); return storedPlaces.isEmpty }
}

@MainActor final class SeededReadingRepository: KitReadingRepository {
    private var storedReadings: [KitReading]

    init(readings: [KitReading]) { storedReadings = readings }
    func listedReadings() -> [KitReading] { storedReadings }
    func reading(id: String) -> KitReading? { storedReadings.first { $0.id == id } }
    func saveReading(_ reading: KitReading) -> KitReading {
        storedReadings.append(reading)
        return reading
    }
    func deleteAllReadings() -> Bool { storedReadings.removeAll(); return storedReadings.isEmpty }
}

@MainActor final class SeededRunRepository: PatrolRunRepository {
    private var storedRuns: [PatrolRun]

    init(runs: [PatrolRun]) { storedRuns = runs }
    func listedRuns() -> [PatrolRun] { storedRuns }
    func run(id: String) -> PatrolRun? { storedRuns.first { $0.id == id } }
    func deleteAllRuns() -> Bool { storedRuns.removeAll(); return storedRuns.isEmpty }
}
